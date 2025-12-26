// lib/core/services/supabase/daily_report_supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/daily_report_model.dart';
import '../../user_role.dart';

final supabase = Supabase.instance.client;

class DailyReportSupabaseService {
  
  // =================== SAVE REPORT ===================
  
  static Future<void> save(DailyReport report) async {
    try {
      await supabase.from('daily_reports').upsert({
        'date': DateFormat('yyyy-MM-dd').format(report.date), // ✅ FIXED
        'total_sales': report.totalSales,
        'cash_sales': report.cashSales,
        'card_sales': report.cardSales,
        'upi_sales': report.upiSales,
        'discounts': report.discounts,
        'covers': report.covers,
        'kitchen_closing_value': report.kitchenClosingValue, // ✅ Match table column
        'kitchen_waste_value': report.kitchenWasteValue,
        'critical_items_text': report.criticalItemsText,
        'beverage_closing_value': report.beverageClosingValue,
        'vendor_purchase_total': report.vendorPurchaseTotal,
        'vendor_due_added': report.vendorDueAdded,
        'staff_count': report.staffCount,
        'issues': report.issues,
        'actions': report.actions,
        'is_locked': report.isLocked,
        'locked_by_role': report.lockedByRole?.name,
        'created_by_role': report.createdByRole?.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Daily Report saved to Supabase');
    } catch (e) {
      print('❌ Supabase save error: $e');
      rethrow;
    }
  }
  
  // =================== LOAD BY DATE ===================
  
  static Future<DailyReport?> loadByDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final response = await supabase
          .from('daily_reports')
          .select()
          .eq('date', dateStr)
          .maybeSingle();
      
      if (response == null) return null;

      // ✅ MANUAL MAPPING (safer than fromMap)
      return DailyReport(
        date: DateTime.parse(response['date']),
        totalSales: (response['total_sales'] ?? 0).toDouble(),
        cashSales: (response['cash_sales'] ?? 0).toDouble(),
        cardSales: (response['card_sales'] ?? 0).toDouble(),
        upiSales: (response['upi_sales'] ?? 0).toDouble(),
        discounts: (response['discounts'] ?? 0).toDouble(),
        covers: (response['covers'] ?? 0) as int,
        kitchenClosingValue: (response['kitchen_closing_value'] ?? 0).toDouble(),
        kitchenWasteValue: (response['kitchen_waste_value'] ?? 0).toDouble(),
        criticalItemsText: response['critical_items_text'] ?? '',
        beverageClosingValue: (response['beverage_closing_value'] ?? 0).toDouble(),
        vendorPurchaseTotal: (response['vendor_purchase_total'] ?? 0).toDouble(),
        vendorDueAdded: (response['vendor_due_added'] ?? 0).toDouble(),
        staffCount: (response['staff_count'] ?? 0) as int,
        issues: response['issues'] ?? '',
        actions: response['actions'] ?? '',
        isLocked: response['is_locked'] ?? false,
        lockedByRole: _parseUserRole(response['locked_by_role']),
        createdByRole: _parseUserRole(response['created_by_role']),
        createdAt: response['created_at'] != null 
            ? DateTime.parse(response['created_at']) 
            : null,
        updatedAt: response['updated_at'] != null 
            ? DateTime.parse(response['updated_at']) 
            : null,
      );
    } catch (e) {
      print('❌ Supabase load error: $e');
      return null;
    }
  }

  // =================== LOAD MONTH ===================
  
  static Future<List<DailyReport>> loadMonth(int year, int month) async {
    try {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      
      final response = await supabase
          .from('daily_reports')
          .select()
          .gte('date', DateFormat('yyyy-MM-dd').format(firstDay))
          .lte('date', DateFormat('yyyy-MM-dd').format(lastDay))
          .order('date');

      return (response as List).map((item) {
        return DailyReport(
          date: DateTime.parse(item['date']),
          totalSales: (item['total_sales'] ?? 0).toDouble(),
          cashSales: (item['cash_sales'] ?? 0).toDouble(),
          cardSales: (item['card_sales'] ?? 0).toDouble(),
          upiSales: (item['upi_sales'] ?? 0).toDouble(),
          discounts: (item['discounts'] ?? 0).toDouble(),
          covers: (item['covers'] ?? 0) as int,
          kitchenClosingValue: (item['kitchen_closing_value'] ?? 0).toDouble(),
          kitchenWasteValue: (item['kitchen_waste_value'] ?? 0).toDouble(),
          criticalItemsText: item['critical_items_text'] ?? '',
          beverageClosingValue: (item['beverage_closing_value'] ?? 0).toDouble(),
          vendorPurchaseTotal: (item['vendor_purchase_total'] ?? 0).toDouble(),
          vendorDueAdded: (item['vendor_due_added'] ?? 0).toDouble(),
          staffCount: (item['staff_count'] ?? 0) as int,
          issues: item['issues'] ?? '',
          actions: item['actions'] ?? '',
          isLocked: item['is_locked'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('❌ Load month error: $e');
      return [];
    }
  }

  // =================== DELETE REPORT ===================
  
  static Future<void> delete(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      await supabase.from('daily_reports').delete().eq('date', dateStr);
      print('✅ Daily Report deleted');
    } catch (e) {
      print('❌ Delete error: $e');
      rethrow;
    }
  }

  // =================== HELPER ===================
  
  static UserRole? _parseUserRole(String? role) {
    if (role == null) return null;
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'chef':
        return UserRole.chef;
      default:
        return null;
    }
  }
}

// =================== KITCHEN SUMMARY ===================

class KitchenSupabaseService {
  static Future<KitchenSummary> getSummaryForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final response = await supabase
          .from('kitchen_inventory')
          .select('closing_value, waste_value')
          .eq('date', dateStr)
          .maybeSingle();

      if (response == null) {
        return KitchenSummary(totalClosing: 0, totalWaste: 0);
      }

      return KitchenSummary(
        totalClosing: (response['closing_value'] ?? 0).toDouble(),
        totalWaste: (response['waste_value'] ?? 0).toDouble(),
      );
    } catch (e) {
      print('❌ Kitchen summary error: $e');
      return KitchenSummary(totalClosing: 0, totalWaste: 0);
    }
  }
}

class KitchenSummary {
  final double totalClosing;
  final double totalWaste;
  KitchenSummary({required this.totalClosing, required this.totalWaste});
}

// =================== BEVERAGE SUMMARY ===================

class BeverageSupabaseService {
  static Future<BeverageSummary> getSummaryForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final response = await supabase
          .from('beverage_inventory')
          .select('closing_value')
          .eq('date', dateStr)
          .maybeSingle();

      if (response == null) {
        return BeverageSummary(totalClosing: 0);
      }

      return BeverageSummary(
        totalClosing: (response['closing_value'] ?? 0).toDouble(),
      );
    } catch (e) {
      print('❌ Beverage summary error: $e');
      return BeverageSummary(totalClosing: 0);
    }
  }
}

class BeverageSummary {
  final double totalClosing;
  BeverageSummary({required this.totalClosing});
}

// =================== VENDOR SUMMARY ===================

class VendorSupabaseService {
  static Future<VendorSummary> getSummaryForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final response = await supabase
          .from('vendor_ledger')
          .select('total_purchase, due_amount')
          .eq('date', dateStr)
          .maybeSingle();

      if (response == null) {
        return VendorSummary(totalPurchase: 0, totalDue: 0);
      }

      return VendorSummary(
        totalPurchase: (response['total_purchase'] ?? 0).toDouble(),
        totalDue: (response['due_amount'] ?? 0).toDouble(),
      );
    } catch (e) {
      print('❌ Vendor summary error: $e');
      return VendorSummary(totalPurchase: 0, totalDue: 0);
    }
  }
}

class VendorSummary {
  final double totalPurchase;
  final double totalDue;
  VendorSummary({required this.totalPurchase, required this.totalDue});
}