// models.dart
class User {
  final int id;
  late final String name;
  late final String email;

  User({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
}

class UserRepository {
  final List<User> _users = [];

  List<User> getAll() => [..._users];

  User? getById(int id) => _users.firstWhereOrNull((u) => u.id == id);

  User create(String name, String email) {
    final newUser = User(id: _users.length + 1, name: name, email: email);
    _users.add(newUser);
    return newUser;
  }

  User update(int id, String name, String email) {
    final user = getById(id);
    if (user == null) throw Exception('User not found');
    (user as dynamic).name = name; // late final -> hackear si usas solo late
    (user as dynamic).email = email;
    return user;
  }

  void delete(int id) {
    _users.removeWhere((u) => u.id == id);
  }
}

extension on List {
  T? firstWhereOrNull<T>(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}