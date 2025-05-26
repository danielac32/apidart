

import 'dart:io';

class Router {
  final Map<String, Function(HttpRequest)> routes = {};

  void addRoute(String method, String path, Function(HttpRequest) handler) {
    final key = '$method $path';
    routes[key] = handler;
  }

  void handleRequest(HttpRequest request) {
    final method = request.method;
    final path = request.requestedUri.path;
    final key = '$method $path';

    final handler = routes[key];

    if (handler != null) {
      handler(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      request.response.close();
    }
  }
}



void main(List<String> arguments) {
  final router = Router();

  // Llama a la función generada para registrar rutas
  registerRoutes(router);

  HttpServer.bind('localhost', 3000).then((server) {
    print('Servidor corriendo en http://localhost:3000');
    server.listen((request) {
      router.handleRequest(request);
    });
  });


}
