import 'dart:io';

import 'package:alfred/alfred.dart';

abstract class Dto {
  Map<String, dynamic> toJson();
}

typedef DtoFactory<T extends Dto> = T Function(Map<String, dynamic> json);

Future<T> parseDto<T extends Dto>(HttpRequest request, DtoFactory<T> fromJson) async {
  final json = await request.bodyAsJsonMap;
  return fromJson(json);
  //if (json is! Map<String, dynamic>) {
  //     throw AlfredException(HttpStatus.badRequest, {'error': 'El cuerpo debe ser un objeto JSON válido'});
  //   }
}



class CreateUserDto implements Dto {
  final String name;
  final String email;

  CreateUserDto({required this.name, required this.email});

  factory CreateUserDto.fromJson(Map<String, dynamic> json) {
    return CreateUserDto(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
  };
}

class LoginDto implements Dto{
  final String name;
  final String email;
  LoginDto({required this.name, required this.email});
  factory LoginDto.fromJson(Map<String, dynamic> json) {
    return LoginDto(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
  };
}
