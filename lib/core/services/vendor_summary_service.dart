// lib/core/services/vendor_summary_service.dart

import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Vendor screen ka model import (adjust path as per your structure)
import '../../ui/screens/inventory/vendor_inventory_screen.dart';

/// Daily vendor summary: total purchase amount.
class VendorDailySummary {
  final double totalPurchase;

  const VendorDailySummary({
    required this.totalPurchase,
  });
}

/// Service: vendor Hive box se read karke total purchase nikalta hai.
class VendorSummaryService {
  static const String _boxName = 'vendor_inventory';

  static String _dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  /// Given date ke liye vendor ka total purchase amount.
  static Future<VendorDailySummary> getSummaryForDate(
    DateTime date,
  ) async {
    final box = await Hive.openBox(_boxName);
    final key = _dateKey(date);
    final raw = box.get(key);

    if (raw == null || raw is! List) {
      return const VendorDailySummary(totalPurchase: 0);
    }

    double totalPurchase = 0;

    for (final item in raw) {
      if (item is! Map) continue;

      final row = VendorRow.fromMap(
        Map<String, dynamic>.from(item as Map),
      );

      totalPurchase += row.purchaseAmount; // ya jo field hai total me
    }

    return VendorDailySummary(totalPurchase: totalPurchase);
  }
}
