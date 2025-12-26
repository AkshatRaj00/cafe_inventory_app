import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_colors.dart';
import 'core/app_routes.dart';
import 'core/user_role.dart';
import 'core/models/app_user.dart';
import 'core/security/password_helper.dart';
import 'services/hive_service.dart';
import 'ui/screens/masala/masala_expense_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 SUPABASE INIT (PHASE 1)
  await Supabase.initialize(
    url: 'https://bsvpucghpsqtxjlhbuuz.supabase.co',
    anonKey: 'sbp_DnvMK1iULOzfpFogm2eBZw_d9KakDVy',
  );
  
  print('✅ Supabase client initialized');

  // Hive init (Fallback)
  await Hive.initFlutter();

  // Common Hive setup
  await HiveService.registerAdapters();
  await HiveService.openBoxes();

  // Ensure user adapters registered
  Hive.registerAdapter(UserRoleAdapter());
  Hive.registerAdapter(AppUserAdapter());

  // Users box open
  await Hive.openBox<AppUser>('users');

  // Default users create (LOCAL fallback)
  await _initDefaultUsers();

  runApp(const LivingRoomCafeApp());
}

// Global Supabase client (Everywhere use: supabase.from('table'))
final supabase = Supabase.instance.client;

/// Default users: admin, manager, chef (LOCAL Hive fallback)
Future<void> _initDefaultUsers() async {
  final box = Hive.box<AppUser>('users');

  if (box.isEmpty) {
    // Admin
    await box.add(
      AppUser(
        id: 'admin',
        name: 'Admin User',
        role: UserRole.admin,
        isActive: true,
        passwordHash: hashPassword('admin123'),
      ),
    );

    // Manager
    await box.add(
      AppUser(
        id: 'mgr1',
        name: 'Manager One',
        role: UserRole.manager,
        isActive: true,
        passwordHash: hashPassword('mgr123'),
      ),
    );

    // Chef
    await box.add(
      AppUser(
        id: 'chef1',
        name: 'Chef One',
        role: UserRole.chef,
        isActive: true,
        passwordHash: hashPassword('chef123'),
      ),
    );
    
    print('✅ Default users created (LOCAL Hive)');
  }
}

class LivingRoomCafeApp extends StatelessWidget {
  const LivingRoomCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Living Room Cafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.card,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.splash,
    );
  }
}
