// lib/core/services/report_export_service.dart
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ReportExportService {
  static const String _kitchenBox = 'kitchen_inventory';
  static const String _beverageBox = 'beverage_inventory';
  static const String _vendorBox = 'vendor_inventory';

  /// Daily report Excel export (Kitchen + Beverage + Vendor)
  static Future<String?> exportDailyReport({
    required DateTime date,
    required double kitchenClosing,
    required double kitchenWaste,
    required double beverageClosing,
    required double vendorPurchase,
    required double totalSales,
    required double cashClosing,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Daily Report'];

    // Header
    sheet.appendRow([
      'DAILY RESTAURANT REPORT',
      DateFormat('dd/MM/yyyy').format(date),
    ]);

    // Summary Table
    sheet.appendRow(['SUMMARY', '', '']);
    sheet.appendRow(['Kitchen Closing', kitchenClosing.toStringAsFixed(2), '₹']);
    sheet.appendRow(['Kitchen Waste', kitchenWaste.toStringAsFixed(2), '₹']);
    sheet.appendRow(['Beverage Closing', beverageClosing.toStringAsFixed(2), '₹']);
    sheet.appendRow(['Vendor Purchase', vendorPurchase.toStringAsFixed(2), '₹']);
    sheet.appendRow(['Total Sales', totalSales.toStringAsFixed(2), '₹']);
    sheet.appendRow(['Cash Closing', cashClosing.toStringAsFixed(2), '₹']);

    // Save & Share
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/daily_report_${DateFormat('yyyyMMdd').format(date)}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Daily Report ${DateFormat('dd/MM/yyyy').format(date)}');
    
    return file.path;
  }

  /// Monthly Google Sheets Summary (Kitchen + Beverage + Vendor totals)
  static Future<Map<String, double>> getMonthlySummary(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);
    
    double totalKitchenClosing = 0;
    double totalKitchenWaste = 0;
    double totalBeverageClosing = 0;
    double totalVendorPurchase = 0;

    // Kitchen summary
    await _sumBoxData(_kitchenBox, startDate, endDate, (row) {
      totalKitchenClosing += row['closing'] ?? 0;
      totalKitchenWaste += row['waste'] ?? 0;
    });

    // Beverage summary
    await _sumBoxData(_beverageBox, startDate, endDate, (row) {
      totalBeverageClosing += row['closing'] ?? 0;
    });

    // Vendor summary
    await _sumBoxData(_vendorBox, startDate, endDate, (row) {
      totalVendorPurchase += row['purchaseAmount'] ?? row['total'] ?? 0;
    });

    return {
      'kitchen_closing': totalKitchenClosing,
      'kitchen_waste': totalKitchenWaste,
      'beverage_closing': totalBeverageClosing,
      'vendor_purchase': totalVendorPurchase,
    };
  }

  static Future<void> _sumBoxData(
    String boxName,
    DateTime start,
    DateTime end,
    void Function(Map row) callback,
  ) async {
    final box = await Hive.openBox(boxName);
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    for (final key in box.keys) {
      if (key is String) {
        final date = dateFormat.parse(key);
        if (date.isAfter(start) && date.isBefore(end)) {
          final data = box.get(key);
          if (data is List) {
            for (final item in data) {
              if (item is Map) callback(item);
            }
          }
        }
      }
    }
  }
}
