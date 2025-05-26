import 'dart:convert';
import 'dart:io';

import 'annotations.dart';



@Route("GET", "/users")
void getAllUsers(HttpRequest request) {

  request.response.write("ok");
  request.response.close();
}

@Route("GET", "/users/{id}")
void getUserById(HttpRequest request) {
  final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);
  request.response.write("ok");
  request.response.close();
}

@Route("POST", "/users")
void createUser(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  final data = jsonDecode(body);
  request.response.write("ok");
  request.response.close();
}

@Route("PUT", "/users/{id}")
void updateUser(HttpRequest request) async {
  final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);
  final body = await utf8.decoder.bind(request).join();
  final data = jsonDecode(body);

  request.response.write("ok");
  request.response.close();
}

@Route("DELETE", "/users/{id}")
void deleteUser(HttpRequest request) {
  final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);

  request.response.write('User deleted');
  request.response.close();
}