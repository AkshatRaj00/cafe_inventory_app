import 'package:flutter/material.dart';



import 'package:living_room_cafe_inventory/ui/screens/vendor/vendor_ledger_screen.dart';
import '../ui/screens/splash/splash_screen.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/home/admin_home_screen.dart';
import '../ui/screens/home/manager_home_screen.dart';
import '../ui/screens/home/chef_home_screen.dart';
import '../ui/screens/inventory/kitchen_inventory_screen.dart';
import '../ui/screens/inventory/beverage_inventory_screen.dart';
import '../ui/screens/masala/masala_expense_screen.dart';
import 'package:living_room_cafe_inventory/ui/screens/reports/daily_report_screen.dart';


import 'models/app_user.dart';
import 'user_role.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';

  static const adminHome = '/admin-home';
  static const managerHome = '/manager-home';
  static const chefHome = '/chef-home';

  static const kitchenInventory = '/kitchen-inventory';
  static const beverageInventory = '/beverage-inventory';

  static const masalaExpense = '/masala-expense';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      // Ab yahan arguments cast नहीं कर रहे, dummy AppUser bana रहे
      case adminHome:
        return MaterialPageRoute(
          builder: (_) => AdminHomeScreen(
            user: AppUser(
              id: 'admin',
              name: 'Admin User',
              role: UserRole.admin,
              isActive: true,
              passwordHash: '',
            ),
          ),
        );

      case managerHome:
        return MaterialPageRoute(
          builder: (_) => ManagerHomeScreen(
            user: AppUser(
              id: 'mgr1',
              name: 'Manager One',
              role: UserRole.manager,
              isActive: true,
              passwordHash: '',
            ),
          ),
        );

      case chefHome:
        return MaterialPageRoute(
          builder: (_) => ChefHomeScreen(
            user: AppUser(
              id: 'chef1',
              name: 'Chef One',
              role: UserRole.chef,
              isActive: true,
              passwordHash: '',
            ),
          ),
        );

      case kitchenInventory:
        final role = settings.arguments as UserRole?;
        return MaterialPageRoute(
          builder: (_) => KitchenInventoryScreen(role: role),
        );

      case beverageInventory:
        final role = settings.arguments as UserRole?;
        return MaterialPageRoute(
          builder: (_) => BeverageInventoryScreen(role: role),
        );

      case masalaExpense:
        final role = settings.arguments as UserRole?;
        return MaterialPageRoute(
          builder: (_) => MasalaExpenseScreen(role: role),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Unknown route')),
          ),
        );
    }
  }
}
