




import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:apidart/annotations.dart';
import 'package:apidart/example.dart';
// auto_router.dart
import 'dart:mirrors';

/*
typedef RequestHandler = void Function(HttpRequest request);
class AutoRouter {
  final Map<String, RequestHandler> routes = {};

  AutoRouter(Object controller) {
    final controllerMirror = reflect(controller);
    final classMirror = controllerMirror.type;

    for (var declared in classMirror.instanceMembers.values) {
      if (declared is MethodMirror && !declared.isConstructor && !declared.isStatic) {
        final methodName = MirrorSystem.getName(declared.simpleName);
        //print(methodName);
        // Verificar si tiene una anotación HTTP
        for (var ann in declared.metadata) {
            final annotation = ann.reflectee;
            if (annotation is Get) {
              routes['GET ${annotation.path}'] = _createHandler(controllerMirror, declared.simpleName);
            } else if (annotation is Post) {
              routes['POST ${annotation.path}'] = _createHandler(controllerMirror, declared.simpleName);
            } else if (annotation is Put) {
              routes['PUT ${annotation.path}'] = _createHandler(controllerMirror, declared.simpleName);
            } else if (annotation is Delete) {
              routes['DELETE ${annotation.path}'] = _createHandler(controllerMirror, declared.simpleName);
          }
        }
      }
    }
  }

  RequestHandler _createHandler(InstanceMirror controllerMirror, Symbol methodSymbol) {
    return (HttpRequest request) {
      try {
        // Invocamos el método y le pasamos HttpRequest como único argumento
        controllerMirror.invoke(methodSymbol, [request]);
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error al ejecutar el método: $e');
        request.response.close();
      }
    };
  }

  void handleRequest(HttpRequest request) {
    final method = request.method;
    final requestedPath = request.requestedUri.path;

    for (var route in routes.keys) {
      final parts = route.split(' ');
      final routeMethod = parts[0];
      final routePath = parts[1];

      if (routeMethod == method && _matchesPath(routePath, requestedPath)) {
        routes[route]!(request);
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    request.response.close();
  }

  bool _matchesPath(String template, String actual) {
    final templateSegments = template.split('/');
    final actualSegments = actual.split('/');

    if (templateSegments.length != actualSegments.length) return false;

    for (var i = 0; i < templateSegments.length; i++) {
      final tSeg = templateSegments[i];
      final aSeg = actualSegments[i];

      if (!tSeg.startsWith('{') || !tSeg.endsWith('}')) {
        if (tSeg != aSeg) return false;
      }
    }
    return true;
  }
}

void main(List<String> arguments) {
  final router = AutoRouter(UserController());

  HttpServer.bind('localhost', 3000).then((server) {
    print('Servidor corriendo en http://localhost:3000');
    server.listen((request) {
      router.handleRequest(request);
    });
  });
}

 */
import 'dart:mirrors';
import 'package:alfred/alfred.dart';


typedef RequestHandler = Future<void> Function(HttpRequest request, HttpResponse response);

class AutoRouter {
  final Alfred app;
  final Object controller;

  AutoRouter(this.app, this.controller) {
    final controllerMirror = reflect(controller);
    final classMirror = controllerMirror.type;

    String basePath = '';

    for (var ann in classMirror.metadata) {
      final annotation = ann.reflectee;
      if (annotation is Controller) {
        basePath = annotation.path;
        break;
      }
    }

    // Registrar métodos
    for (var declared in classMirror.instanceMembers.values) {
      if (declared is MethodMirror && !declared.isConstructor && !declared.isStatic) {
        for (var ann in declared.metadata) {
          final annotation = ann.reflectee;

          final relativePath = _extractPath(annotation);
          final method = _extractHttpMethod(annotation);

          if (relativePath != null && method != null) {
              final fullPath = joinPaths([basePath, relativePath]);// final fullPath = '$basePath$relativePath';
              print('Ruta registrada: $fullPath');
              final handler = _createHandler(controllerMirror, declared.simpleName);

              switch (method) {
                case 'GET':
                  app.get(fullPath, handler, middleware: []);
                case 'POST':
                  app.post(fullPath, handler, middleware: []);
                case 'PUT':
                  app.put(fullPath, handler, middleware: []);
                case 'DELETE':
                  app.delete(fullPath, handler, middleware: []);
                case 'PATCH':
                  app.patch(fullPath, handler, middleware: []);
                default:
                  print('Método HTTP no soportado: $method');
            }
          }
        }
      }
    }
  }


  String joinPaths(List<String> paths) {
    return paths
        .map((p) => p.trim().split('/'))
        .expand((pathSegments) => pathSegments)
        .where((s) => s.isNotEmpty)
        .join('/');
  }
  String? _extractPath(dynamic annotation) {
    if (annotation is Get) return _normalizePath(annotation.path);
    if (annotation is Post) return _normalizePath(annotation.path);
    if (annotation is Put) return _normalizePath(annotation.path);
    if (annotation is Delete) return _normalizePath(annotation.path);
    if (annotation is Patch) return _normalizePath(annotation.path);
    return null;
  }

  String _normalizePath(String path) {
    // Convierte {id} → :id
    path = path.replaceAllMapped(RegExp(r'\{(.+?)\}'), (match) => ':${match.group(1)}');

    // Elimina múltiples barras
    return path.split('/').where((p) => p.isNotEmpty).join('/');
  }
  String? _extractHttpMethod(dynamic annotation) {
    if (annotation is Get) return 'GET';
    if (annotation is Post) return 'POST';
    if (annotation is Put) return 'PUT';
    if (annotation is Delete) return 'DELETE';
    if (annotation is Patch) return 'PATCH';
    return null;
  }

  /*List<Middleware> _extractMiddlewares(dynamic annotation) {
    if (annotation is Get) return annotation.middleware;
    if (annotation is Post) return annotation.middleware;
    if (annotation is Put) return annotation.middleware;
    if (annotation is Delete) return annotation.middleware;
    if (annotation is Patch) return annotation.middleware;
    return [];
  }*/

  RequestHandler _createHandler(InstanceMirror controllerMirror, Symbol methodSymbol) {
    return (HttpRequest request, HttpResponse response) async {
      try {
        await controllerMirror.invoke(methodSymbol, [request, response]).reflectee;
      } catch (e, stackTrace) {
        response.statusCode = 500;
        response.write('Error ejecutando método: $e\n$stackTrace');
        await response.close();
      }
    };
  }
}


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








@Controller("users/")
class UserController {
  @Get('')
  Future<void> list(HttpRequest req, HttpResponse res) async {
    res.json({'data': 'Lista de usuarios'});
  }

  @Get('get'/*, middleware: [authMiddleware, validateIdMiddleware]*/)
  Future<void> getParams(HttpRequest req, HttpResponse res) async {
    final status = req.uri.queryParameters['status'] ?? 'all';
    res.json({'data': 'params: $status'});
  }


  @Get('{id}/get/{id2}'/*, middleware: [authMiddleware, validateIdMiddleware]*/)
  Future<void> getById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    final id2 = req.params['id2'];
    res.json({'data': 'Usuario con ID: $id $id2'});
  }


  @Post('login')
  Future<void> login(HttpRequest req, HttpResponse res) async {
   // final json = await req.bodyAsJsonMap;
    final dto = await parseDto<LoginDto>(req, LoginDto.fromJson);

    print('Nombre: ${dto.name}');
    print('Email: ${dto.email}');

    res.json({
      'message': 'Usuario creado',
      'data': dto.toJson(),
    });

  }


  @Post('')
  Future<void> create(HttpRequest req, HttpResponse res) async {
    /*final dto = await parseDto<CreateUserDto>(req, CreateUserDto.fromJson);

    print('Nombre: ${dto.name}');
    print('Email: ${dto.email}');

    res.json({
      'message': 'Usuario creado',
      'data': dto.toJson(),
    });*/
  }

  @Patch(':id')
  Future<void> updateById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario actualizado', 'id': id});
  }

  @Delete('/users/:id')
  Future<void> deleteById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario eliminado', 'id': id});
  }
}


@Controller("test/")
class TestController {
  @Get('')
  Future<void> list(HttpRequest req, HttpResponse res) async {
    res.json({'data': 'Lista de usuarios'});
  }

  @Get('get'/*, middleware: [authMiddleware, validateIdMiddleware]*/)
  Future<void> getParams(HttpRequest req, HttpResponse res) async {
    final status = req.uri.queryParameters['status'] ?? 'all';
    res.json({'data': 'params: $status'});
  }


  @Get('{id}/get/{id2}'/*, middleware: [authMiddleware, validateIdMiddleware]*/)
  Future<void> getById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    final id2 = req.params['id2'];
    res.json({'data': 'Usuario con ID: $id $id2'});
  }


  @Post('login')
  Future<void> login(HttpRequest req, HttpResponse res) async {
    // final json = await req.bodyAsJsonMap;
    final dto = await parseDto<LoginDto>(req, LoginDto.fromJson);

    print('Nombre: ${dto.name}');
    print('Email: ${dto.email}');

    res.json({
      'message': 'Usuario creado',
      'data': dto.toJson(),
    });

  }


  @Post('')
  Future<void> create(HttpRequest req, HttpResponse res) async {
    final dto = await parseDto<CreateUserDto>(req, CreateUserDto.fromJson);

    print('Nombre: ${dto.name}');
    print('Email: ${dto.email}');

    res.json({
      'message': 'Usuario creado',
      'data': dto.toJson(),
    });
  }

  @Patch(':id')
  Future<void> updateById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario actualizado', 'id': id});
  }

  @Delete('/users/:id')
  Future<void> deleteById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario eliminado', 'id': id});
  }
}



Future<void> main(List<String> arguments) async {



  final app = Alfred();
  // Registrar rutas automáticamente
  AutoRouter(app, UserController());
  AutoRouter(app, TestController());



  await app.listen(3000);
  print('Servidor corriendo en http://localhost:3000');
}