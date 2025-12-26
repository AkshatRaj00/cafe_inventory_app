import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;  // ← YE ADD

class VendorDailySummary {

  final double totalPurchase;
  VendorDailySummary({required this.totalPurchase});
}

class VendorSupabaseService {
  static Future<VendorDailySummary> getSummaryForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    
    final response = await supabase
        .from('vendor_inventory')
        .select('purchase_amount')
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String());
    
    double totalPurchase = 0;
    for (var row in response) {
      totalPurchase += (row['purchase_amount'] ?? 0).toDouble();
    }
    
    return VendorDailySummary(totalPurchase: totalPurchase);
  }
}
