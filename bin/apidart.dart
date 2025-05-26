




import 'dart:io';

import 'package:apidart/annotations.dart';
import 'package:apidart/example.dart';


// auto_router.dart
import 'dart:mirrors';

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
