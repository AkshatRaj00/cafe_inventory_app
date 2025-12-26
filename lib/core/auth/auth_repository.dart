// lib/core/auth/auth_repository.dart

import 'package:hive/hive.dart';
import '../models/app_user.dart';
import '../security/password_helper.dart';

class AuthRepository {
  const AuthRepository();

  Box<AppUser> get _userBox => Hive.box<AppUser>('users');

  /// id + password se login
  Future<AppUser?> authenticate(String id, String password) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty || password.isEmpty) return null;

    // id se user nikalna (safe way)
    final matches = _userBox.values.where((u) => u.id == trimmedId);
    if (matches.isEmpty) {
      return null;
    }

    final user = matches.first;

    // inactive user ko reject
    if (!user.isActive) return null;

    // password check
    final ok = verifyPassword(password, user.passwordHash);
    if (!ok) return null;

    return user;
  }

  /// id se user fetch (optional helpers)
  AppUser? getUserById(String id) {
    final trimmedId = id.trim();
    final matches = _userBox.values.where((u) => u.id == trimmedId);
    if (matches.isEmpty) return null;
    return matches.first;
  }

  /// password change
  Future<bool> changePassword({
    required AppUser user,
    required String newPassword,
  }) async {
    if (newPassword.isEmpty) return false;

    user
      ..passwordHash = hashPassword(newPassword)
      ..save();

    return true;
  }

  Future<void> logout() async {
    // future ke liye placeholder
  }
}
