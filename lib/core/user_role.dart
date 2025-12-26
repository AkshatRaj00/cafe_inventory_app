// lib/core/user_role.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'user_role.g.dart';

@HiveType(typeId: 0)
enum UserRole {
  @HiveField(0)
  admin,
  @HiveField(1)
  manager,
  @HiveField(2)
  chef,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.chef:
        return 'Chef';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manager:
        return Icons.supervisor_account;
      case UserRole.chef:
        return Icons.restaurant_menu;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.chef:
        return Colors.orange;
    }
  }
}

/// small helper for text like "By Admin"
String userRoleShort(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.chef:
      return 'Chef';
    default:
      return 'Guest';
  }
}

