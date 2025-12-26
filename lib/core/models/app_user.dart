import 'package:hive/hive.dart';
import '../user_role.dart';

part 'app_user.g.dart'; // agar Hive type adapter use karega to

@HiveType(typeId: 1)
class AppUser extends HiveObject {
  @HiveField(0)
  String id;                // uuid or username

  @HiveField(1)
  String name;

  @HiveField(2)
  String passwordHash;      // plain text mat rakhna (abhi simple bhi chalega)

  @HiveField(3)
  UserRole role;

  @HiveField(4)
  bool isActive;

  AppUser({
    required this.id,
    required this.name,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
  });
}
