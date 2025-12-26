// lib/core/services/beverage_summary_service.dart

import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Apne actual model ka import lagao.
// Yaha maan ke chal raha hun ki BeverageRow isi file/folder me hai:
import '../../ui/screens/inventory/beverage_inventory_screen.dart';

/// Daily beverage summary: total closing stock/value.
class BeverageDailySummary {
  final double totalClosing;

  const BeverageDailySummary({
    required this.totalClosing,
  });
}

/// Service: beverage Hive box se read karke closing total nikalta hai.
class BeverageSummaryService {
  // Box name wahi jo BeverageInventoryScreen me use kar rahe ho.
  static const String _boxName = 'beverage_inventory';

  static String _dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  /// Given date ke liye beverage ka total closing.
  static Future<BeverageDailySummary> getSummaryForDate(
    DateTime date,
  ) async {
    final box = await Hive.openBox(_boxName);
    final key = _dateKey(date);
    final raw = box.get(key);

    if (raw == null || raw is! List) {
      return const BeverageDailySummary(totalClosing: 0);
    }

    double totalClosing = 0;

    for (final item in raw) {
      if (item is! Map) continue;

      // BeverageInventoryScreen ke model se map convert
      final row = BeverageRow.fromMap(
        Map<String, dynamic>.from(item as Map),
      );

      totalClosing += row.closing;
    }

    return BeverageDailySummary(totalClosing: totalClosing);
  }
}
