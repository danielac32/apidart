




import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:apidart/annotations.dart';
import 'package:apidart/dto.dart';
//import 'package:apidart/example.dart';
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
import 'package:apidart/dto/dto_lib.dart';


typedef RequestHandlerWithMiddleware = FutureOr<void> Function(HttpRequest req, HttpResponse res);

class AutoRouter {
  final Alfred app;
  final Object controller;

  AutoRouter(this.app, this.controller) {
    final controllerMirror = reflect(controller);
    final classMirror = controllerMirror.type;

    String basePath = '';

    // Buscar @Controller
    for (var ann in classMirror.metadata) {
      final annotation = ann.reflectee;
      if (annotation is Controller) {
        basePath = annotation.path;
        break;
      }
    }
    if(basePath == null) {
      throw StateError('El controlador debe tener anotación @Controller');
    }
    // Registrar métodos
    for (var declared in classMirror.instanceMembers.values) {
      if (declared is MethodMirror && !declared.isConstructor && !declared.isStatic) {
        for (var ann in declared.metadata) {
          final annotation = ann.reflectee;

          final relativePath = _extractPath(annotation);
          final method = _extractHttpMethod(annotation);

          if (relativePath != null && method != null) {
            final fullPath = joinPaths([basePath, relativePath]);
            print('Ruta registrada: $fullPath');

            // Extraer middlewares del método
            final middlewares = extractMiddlewares(declared);
            // Crear handler con middlewares
            final handler = createHandlerWithMiddlewares(controllerMirror, declared.simpleName);

            /*
             final handler = (HttpRequest req, HttpResponse res) async {
          await controllerMirror.invoke(declared.simpleName, [req, res]).reflectee;
        };
             */
            // Registrar ruta en alfred
            switch (method) {
              case 'GET':
                app.get(fullPath, handler, middleware: middlewares);
              case 'POST':
                app.post(fullPath, handler, middleware: middlewares);
              case 'PUT':
                app.put(fullPath, handler, middleware: middlewares);
              case 'DELETE':
                app.delete(fullPath, handler, middleware: middlewares);
              case 'PATCH':
                app.patch(fullPath, handler, middleware: middlewares);
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

  List<FutureOr Function(HttpRequest, HttpResponse)> extractMiddlewares(MethodMirror declared) {
    final List<FutureOr Function(HttpRequest, HttpResponse)> middlewares = [];

    for (var ann in declared.metadata) {
      final instance = ann.reflectee;
      if (instance is Middleware) {
        middlewares.add(instance.handler);
      }
    }
    return middlewares;
  }

  RequestHandlerWithMiddleware createHandlerWithMiddlewares(InstanceMirror controllerMirror, Symbol methodSymbol) {
    return (HttpRequest request, HttpResponse response) async {
      try {
        // Llamar al método del controlador
        await controllerMirror.invoke(methodSymbol, [request, response]).reflectee;
      } catch (e, stackTrace) {
        response.statusCode = 500;
        await response.json({'error': 'Error interno', 'message': e.toString(), 'stack': stackTrace.toString()});
      }
    };
  }
}









FutureOr IdMiddleware(HttpRequest req, HttpResponse res) async {
  // Parsear el cuerpo de la solicitud como un Map<String, dynamic>
  final params = await req.params;

  // Extraer los campos email y password
  final id = params['id'] as String?;

  // Validar que ambos campos existan
  if (id == null || id.isEmpty) {
    throw AlfredException(400, {'error': 'El id es requerido'});
  }
}

FutureOr statusMiddleware(HttpRequest req, HttpResponse res) async {
  // Parsear el cuerpo de la solicitud como un Map<String, dynamic>
  final body = await req.bodyAsJsonMap;
  // Validar que ambos campos existan
  if (body['status'] == null || body['status'].isEmpty) {
    throw AlfredException(400, {'error': 'El status es requerido'});
  }
}



@Controller("users/")
class UserController {

  @Patch(':id')
  @Middleware(IdMiddleware)
  @Middleware(statusMiddleware)
  Future<void> updateById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario actualizado', 'id': id});
  }

  @Get('')
  Future<void> list(HttpRequest req, HttpResponse res) async {
    res.json({'data': 'Lista de usuarios'});
  }

  @Get('get')
  Future<void> getParams(HttpRequest req, HttpResponse res) async {
    final status = req.uri.queryParameters['status'] ?? 'all';
    res.json({'data': 'params: $status'});
  }

@Middleware(IdMiddleware)
  @Get('{id}')
  Future<void> getById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    //final id2 = req.params['id2'];
    res.json({'data': 'Usuario con ID: $id '});
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


  @Delete(':id')
  Future<void> deleteById(HttpRequest req, HttpResponse res) async {
    final id = req.params['id'];
    res.json({'message': 'Usuario eliminado', 'id': id});
  }
}









Future<void> main(List<String> arguments) async {

  


  final user = PersonDto()
    ..userId = 1
    ..email = 'johnexample.com'
    ..password = 'secret';

  // Convertir a JSON
  final json = user.toJson();
  print(json);
  // Output: {'user_id': 1, 'name': 'John Doe', 'email': 'john@example.com'}

  // Crear desde JSON
  final newUser = PersonDto.fromJson({
    'user_id': 2,
    'name': 'Jane Doe',
    'email': 'jane@example.com',
    'password':'1524466'
  });

  print(newUser.name); // Output: Jane Doe
  final app = Alfred();
  // Registrar rutas automáticamente
  AutoRouter(app, UserController());




  await app.listen(3000);
  print('Servidor corriendo en http://localhost:3000');
}