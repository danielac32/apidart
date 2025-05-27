import 'dart:mirrors';

class Dto {
  const Dto();
}

class DtoField {
  final String? jsonKey;
  final bool ignore;
  final bool required;
  final bool allowEmpty;
  final String? validationMessage;
  final List<Function> validators;  // Quitamos final para permitir listas no-const

  const DtoField({
    this.jsonKey,
    this.ignore = false,
    this.required = false,
    this.allowEmpty = true,
    this.validationMessage,
    this.validators = const [],  // Lista vacía por defecto
  });
}


class MyValidators {
  static const Function nameValidator = _validateName;
  static const Function emailValidator = _validateEmail;

  static String? _validateName(dynamic value) {
    if ((value as String).length > 50) {
      return 'El nombre no puede exceder 50 caracteres';
    }
    return null;
  }

  static String? _validateEmail(dynamic value) {
    if (value != null && !value.contains('@')) {
      return 'El email debe ser válido';
    }
    return null;
  }
}



abstract class JsonSerializable {
  Map<String, dynamic> toJson();
}

@Dto()
class PersonDto implements JsonSerializable {
  @DtoField( required: false)
  int? userId;

  @DtoField(
      required: true,
      allowEmpty: false,
      validationMessage: 'El nombre es obligatorio',
      validators: [MyValidators.nameValidator]
  )
  String? name;

  @DtoField(
      validators: [MyValidators.emailValidator]
  )
  String? email;

  @DtoField(required: true)
  String? password;

  PersonDto({
     this.userId,
     this.name,
     this.email,
     this.password,
  });

  @override
  Map<String, dynamic> toJson() => _DtoConverter.toJson(this);

  factory PersonDto.fromJson(Map<String, dynamic> json) =>
      _DtoConverter.fromJson<PersonDto>(json);
}




class _DtoConverter {
  static Map<String, dynamic> toJson(Object instance) {
    final result = <String, dynamic>{};
    final instanceMirror = reflect(instance);
    final classMirror = instanceMirror.type;

    if (!_hasDtoAnnotation(classMirror)) {
      throw ArgumentError('La clase debe tener la anotación @Dto');
    }

    for (final field in classMirror.declarations.values) {
      if (field is VariableMirror) {
        final fieldMeta = _getFieldMetadata(field);
        if (fieldMeta == null || fieldMeta.ignore) continue;

        final fieldName = MirrorSystem.getName(field.simpleName);
        final jsonKey = fieldMeta.jsonKey ?? fieldName;
        final value = instanceMirror.getField(field.simpleName).reflectee;

        // Solo incluir si no es null o si es campo requerido
        if (value != null || fieldMeta.required) {
          if (value is DateTime) {
            result[jsonKey] = value.toIso8601String();
          } else if (value is Iterable) {
            result[jsonKey] = _processIterable(value, fieldMeta);
          } else {
            result[jsonKey] = value;
          }
        }
      }
    }

    return result;
  }

  static T fromJson<T>(Map<String, dynamic> json) {
    final classMirror = reflectClass(T);
    final instance = classMirror.newInstance(Symbol(''), []).reflectee;

    for (final field in classMirror.declarations.values) {
      if (field is VariableMirror) {
        final fieldMeta = _getFieldMetadata(field);
        if (fieldMeta == null || fieldMeta.ignore) continue;

        final fieldName = MirrorSystem.getName(field.simpleName);
        final jsonKey = fieldMeta.jsonKey ?? fieldName;

        if (json.containsKey(jsonKey)) {
          final value = json[jsonKey];
          _validateField(fieldMeta, value, fieldName);

          final processedValue = _parseValue(
              value,
              field.type.reflectedType,
              fieldMeta
          );

          reflect(instance).setField(field.simpleName, processedValue);
        } else if (fieldMeta.required) {
          throw ArgumentError(
              fieldMeta.validationMessage ?? 'El campo $fieldName es requerido'
          );
        }
      }
    }

    return instance as T;
  }

  static dynamic _parseValue(dynamic value, Type targetType, DtoField fieldMeta) {
    if (value == null) return null;

    // Conversión especial para DateTime
    if (targetType == DateTime && value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        throw ArgumentError(
            fieldMeta.validationMessage ?? 'Formato de fecha inválido para ${fieldMeta.jsonKey}'
        );
      }
    }

    // Conversión para listas
    if (targetType.toString().contains('List<') && value is List) {
      final itemType = targetType.toString().replaceAll('List<', '').replaceAll('>', '');
      return value.map((e) => _parseValue(e, _typeFromString(itemType), fieldMeta)).toList();
    }

    return value;
  }

  static void _validateField(DtoField fieldMeta, dynamic value, String fieldName) {
    // Validación de campo requerido
    if (fieldMeta.required && value == null) {
      throw ArgumentError(
          fieldMeta.validationMessage ?? 'El campo $fieldName no puede ser nulo'
      );
    }

    // Validación de campo no vacío
    if (!fieldMeta.allowEmpty) {
      if (value is String && value.isEmpty) {
        throw ArgumentError(
            fieldMeta.validationMessage ?? 'El campo $fieldName no puede estar vacío'
        );
      }
      if (value is List && value.isEmpty) {
        throw ArgumentError(
            fieldMeta.validationMessage ?? 'El campo $fieldName no puede estar vacío'
        );
      }
      if (value is Map && value.isEmpty) {
        throw ArgumentError(
            fieldMeta.validationMessage ?? 'El campo $fieldName no puede estar vacío'
        );
      }
    }

    // Validadores personalizados
    if (fieldMeta.validators != null) {
      for (final validator in fieldMeta.validators!) {
        final error = validator(value);
        if (error != null) {
          throw ArgumentError(error);
        }
      }
    }
  }

  static List<dynamic> _processIterable(Iterable value, DtoField fieldMeta) {
    return value.map((item) {
      if (item is DateTime) {
        return item.toIso8601String();
      } else if (item is JsonSerializable) {
        return item.toJson();
      }
      return item;
    }).toList();
  }

  static Type _typeFromString(String typeName) {
    switch (typeName) {
      case 'String': return String;
      case 'int': return int;
      case 'double': return double;
      case 'bool': return bool;
      case 'DateTime': return DateTime;
      default: return dynamic;
    }
  }

  static bool _hasDtoAnnotation(ClassMirror classMirror) {
    return classMirror.metadata.any((m) {
      try {
        return m.reflectee is Dto;
      } catch (_) {
        return false;
      }
    });
  }

  static DtoField? _getFieldMetadata(DeclarationMirror field) {
    try {
      final metadata = field.metadata.firstWhere(
            (m) => m.hasReflectee && m.reflectee is DtoField,
      );
      return metadata.reflectee as DtoField;
    } catch (_) {
      return null;
    }
  }
}