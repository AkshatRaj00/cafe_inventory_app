import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;  // ← YE ADD

class KitchenDailySummary {

  final double totalClosing;
  final double totalWaste;
  KitchenDailySummary({required this.totalClosing, required this.totalWaste});
}

class KitchenSupabaseService {
  static Future<KitchenDailySummary> getSummaryForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    
    final response = await supabase
        .from('kitchen_inventory')
        .select('closing_amount, waste_amount')
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String());
    
    double totalClosing = 0, totalWaste = 0;
    for (var row in response) {
      totalClosing += (row['closing_amount'] ?? 0).toDouble();
      totalWaste += (row['waste_amount'] ?? 0).toDouble();
    }
    
    return KitchenDailySummary(totalClosing: totalClosing, totalWaste: totalWaste);
  }
}
