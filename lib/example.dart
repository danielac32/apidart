// user_controller.dart
import 'dart:convert';
import 'dart:io';

import 'annotations.dart';
import 'model.dart';

class UserController {
  final UserRepository _repository = UserRepository();

  @Get('/users')
  void getAllUsers(HttpRequest request) {
    final users = _repository.getAll();
    final response = jsonEncode(users.map((u) => u.toJson()).toList());
    request.response.write(response);
    request.response.close();
  }

  @Get('/users/{id}')
  void getUserById(HttpRequest request) {
    final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);
    final user = _repository.getById(id);
    final response = jsonEncode(user!.toJson());
    request.response.write(response);
    request.response.close();
  }

  @Post('/users')
  void createUser(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body);
    final user = _repository.create(data['name'], data['email']);
    final response = jsonEncode(user.toJson());
    request.response.write(response);
    request.response.close();
  }

  @Put('/users/{id}')
  void updateUser(HttpRequest request) async {
    final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body);
    final user = _repository.update(id, data['name'], data['email']);
    final response = jsonEncode(user.toJson());
    request.response.write(response);
    request.response.close();
  }

  @Delete('/users/{id}')
  void deleteUser(HttpRequest request) {
    final id = int.parse(Uri.parse(request.requestedUri.path).pathSegments.last);
    _repository.delete(id);
    request.response.write('User deleted');
    request.response.close();
  }
}