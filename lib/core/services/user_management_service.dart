// lib/core/services/user_management_service.dart
import 'package:hive_flutter/hive_flutter.dart';

class UserManagementService {
  static const String _boxName = 'users';
  
  static Future<List<User>> getAllUsers() async {
    final box = await Hive.openBox(_boxName);
    return box.values.cast<User>().toList();
  }
  
  static Future<void> addUser(User user) async {
    final box = await Hive.openBox(_boxName);
    await box.put(user.id, user.toMap());
  }
  
  static Future<void> deleteUser(String id) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(id);
  }
}

class User {
  final String id;
  final String name;
  final String role; // 'admin', 'manager', 'staff'
  
  User({required this.id, required this.name, required this.role});
  
  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'role': role
  };
  
  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'], 
    name: map['name'], 
    role: map['role']
  );
}
