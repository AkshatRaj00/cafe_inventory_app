// lib/core/services/kitchen_summary_service.dart

import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

// KitchenInventoryScreen wali file se InventoryRow reuse karenge
import '../../ui/screens/inventory/kitchen_inventory_screen.dart';

/// Daily summary object: closing + waste totals.
class KitchenDailySummary {
  final double totalClosing;
  final double totalWaste;

  const KitchenDailySummary({
    required this.totalClosing,
    required this.totalWaste,
  });
}

/// Service layer: Hive box se data read karke totals nikalta hai.
/// UI screens is class ko call karengi, directly Hive access nahi karengi.
class KitchenSummaryService {
  // Wahi box name jo KitchenInventoryScreen me use ho raha hai
  static const String _boxName = 'kitchen_inventory';

  static String _dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  /// Given date ke liye:
  /// - sare items ka closing sum (totalClosing)
  /// - sare items ka waste sum (totalWaste)
  static Future<KitchenDailySummary> getSummaryForDate(
    DateTime date,
  ) async {
    // 1) Box open karo
    final box = await Hive.openBox(_boxName);

    // 2) Date key banayo (KitchenInventoryScreen jaisa hi)
    final key = _dateKey(date);
    final raw = box.get(key);

    // 3) Agar koi data hi nahi mila to zero summary
    if (raw == null || raw is! List) {
      return const KitchenDailySummary(
        totalClosing: 0,
        totalWaste: 0,
      );
    }

    double totalClosing = 0;
    double totalWaste = 0;

    // 4) Har saved row ko InventoryRow me convert karke closing/waste sum
    for (final item in raw) {
      if (item is! Map) continue;

      final row = InventoryRow.fromMap(
        Map<String, dynamic>.from(item as Map),
      );

      totalClosing += row.closing;
      totalWaste += row.waste;
    }

    // 5) Final summary return
    return KitchenDailySummary(
      totalClosing: totalClosing,
      totalWaste: totalWaste,
    );
  }
}
