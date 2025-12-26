import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../core/models/app_user.dart';
import '../../../core/user_role.dart';

import '../inventory/kitchen_inventory_screen.dart';
import '../inventory/beverage_inventory_screen.dart';
import '../reports/daily_report_screen.dart';

class ChefHomeScreen extends StatelessWidget {
  final AppUser user;

  const ChefHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _showLogoutDialogAndGoLogin(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chef Dashboard - ${user.name}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await _showLogoutDialogAndGoLogin(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            ),
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _HomeTile(
              icon: Icons.kitchen,
              label: 'Kitchen Inventory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KitchenInventoryScreen(
                      role: UserRole.chef,
                    ),
                  ),
                );
              },
            ),
            _HomeTile(
              icon: Icons.local_drink,
              label: 'Beverage Inventory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BeverageInventoryScreen(
                      role: UserRole.chef,
                    ),
                  ),
                );
              },
            ),
            _HomeTile(
              icon: Icons.summarize,
              label: 'Daily Reports',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DailyReportScreen(
                      role: UserRole.chef,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _showLogoutDialogAndGoLogin(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text(
        'Do you want to logout and go back to login screen?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  if (result == true) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
    return true;
  }
  return false;
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HomeTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
