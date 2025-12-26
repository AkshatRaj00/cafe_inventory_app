import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;  // ← YE ADD

class BeverageDailySummary {

  final double totalClosing;
  BeverageDailySummary({required this.totalClosing});
}

class BeverageSupabaseService {
  static Future<BeverageDailySummary> getSummaryForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    
    final response = await supabase
        .from('beverage_inventory')
        .select('closing_amount')
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String());
    
    double totalClosing = 0;
    for (var row in response) {
      totalClosing += (row['closing_amount'] ?? 0).toDouble();
    }
    
    return BeverageDailySummary(totalClosing: totalClosing);
  }
}
