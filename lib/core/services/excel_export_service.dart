// lib/core/services/excel_export_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/daily_report_model.dart';
import 'package:open_file/open_file.dart';

class ExcelExportService {
  
  // =================== EXPORT DAILY REPORT ===================
  
  static Future<String> exportDailyReport(DailyReport report) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Daily Report'];

      // Delete default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Set column widths
      sheet.setColWidth(0, 25);
      sheet.setColWidth(1, 20);

      int row = 0;

      // ===== HEADER =====
      _addHeaderRow(sheet, row++, 'DAILY REPORT');
      _addHeaderRow(sheet, row++, DateFormat('dd MMMM yyyy').format(report.date));
      row++; // Empty row

      // ===== SALES SECTION =====
      _addSectionTitle(sheet, row++, 'SALES OVERVIEW');
      _addDataRow(sheet, row++, 'Total Sales', '₹${report.totalSales.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Cash Sales', '₹${report.cashSales.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Card Sales', '₹${report.cardSales.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'UPI Sales', '₹${report.upiSales.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Discounts', '₹${report.discounts.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Net Sales', '₹${(report.totalSales - report.discounts).toStringAsFixed(2)}', isBold: true);
      _addDataRow(sheet, row++, 'Covers (Guests)', report.covers.toString());
      _addDataRow(sheet, row++, 'Avg per Cover', '₹${(report.covers > 0 ? (report.totalSales - report.discounts) / report.covers : 0).toStringAsFixed(2)}');
      row++; // Empty row

      // ===== KITCHEN SECTION =====
      _addSectionTitle(sheet, row++, 'KITCHEN SUMMARY');
      _addDataRow(sheet, row++, 'Closing Value', '₹${report.kitchenClosingValue.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Waste Value', '₹${report.kitchenWasteValue.toStringAsFixed(2)}');
      final wastePercent = report.kitchenClosingValue > 0 
          ? (report.kitchenWasteValue / report.kitchenClosingValue * 100) 
          : 0;
      _addDataRow(sheet, row++, 'Waste %', '${wastePercent.toStringAsFixed(2)}%');
      if (report.criticalItemsText.isNotEmpty) {
        _addDataRow(sheet, row++, 'Critical Items', report.criticalItemsText);
      }
      row++; // Empty row

      // ===== BEVERAGE SECTION =====
      _addSectionTitle(sheet, row++, 'BEVERAGE SUMMARY');
      _addDataRow(sheet, row++, 'Closing Value', '₹${report.beverageClosingValue.toStringAsFixed(2)}');
      row++; // Empty row

      // ===== VENDOR SECTION =====
      _addSectionTitle(sheet, row++, 'VENDOR SUMMARY');
      _addDataRow(sheet, row++, 'Purchase Total', '₹${report.vendorPurchaseTotal.toStringAsFixed(2)}');
      _addDataRow(sheet, row++, 'Due Added', '₹${report.vendorDueAdded.toStringAsFixed(2)}');
      row++; // Empty row

      // ===== OPERATIONS SECTION =====
      _addSectionTitle(sheet, row++, 'OPERATIONS');
      _addDataRow(sheet, row++, 'Staff Count', report.staffCount.toString());
      if (report.issues.isNotEmpty) {
        _addDataRow(sheet, row++, 'Issues/Complaints', report.issues);
      }
      if (report.actions.isNotEmpty) {
        _addDataRow(sheet, row++, 'Actions for Next Day', report.actions);
      }
      row++; // Empty row

      // ===== FOOTER =====
      _addFooter(sheet, row++, 'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      if (report.isLocked) {
        _addFooter(sheet, row++, 'Status: LOCKED 🔒');
      }

      // Save file
      final fileName = 'DailyReport_${DateFormat('yyyy-MM-dd').format(report.date)}.xlsx';
      final filePath = await _saveExcelFile(excel, fileName);
      
      return filePath;
    } catch (e) {
      print('❌ Error exporting Daily Report: $e');
      rethrow;
    }
  }

  // =================== EXPORT MONTH REPORTS ===================
  
  static Future<String> exportMonthReports(List<DailyReport> reports, int year, int month) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Monthly Report'];

      // Delete default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Set column widths
      sheet.setColWidth(0, 15); // Date
      sheet.setColWidth(1, 15); // Total Sales
      sheet.setColWidth(2, 15); // Covers
      sheet.setColWidth(3, 15); // Kitchen Closing
      sheet.setColWidth(4, 15); // Beverage Closing
      sheet.setColWidth(5, 15); // Vendor Purchase

      int row = 0;

      // Header
      _addHeaderRow(sheet, row++, 'MONTHLY REPORT - ${DateFormat('MMMM yyyy').format(DateTime(year, month))}');
      row++; // Empty row

      // Table headers
      final headers = ['Date', 'Total Sales', 'Covers', 'Kitchen Close', 'Beverage Close', 'Vendor Purchase'];
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = headers[col];
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#FFA500',
          fontColorHex: '#FFFFFF',
        );
      }
      row++;

      // Data rows
      double totalSales = 0;
      int totalCovers = 0;
      double totalKitchen = 0;
      double totalBeverage = 0;
      double totalVendor = 0;

      for (final report in reports) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
            DateFormat('dd/MM/yyyy').format(report.date);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = 
            report.totalSales.toStringAsFixed(2);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = 
            report.covers.toString();
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 
            report.kitchenClosingValue.toStringAsFixed(2);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = 
            report.beverageClosingValue.toStringAsFixed(2);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = 
            report.vendorPurchaseTotal.toStringAsFixed(2);

        totalSales += report.totalSales;
        totalCovers += report.covers;
        totalKitchen += report.kitchenClosingValue;
        totalBeverage += report.beverageClosingValue;
        totalVendor += report.vendorPurchaseTotal;

        row++;
      }

      // Total row
      row++; // Empty row
      for (int col = 0; col < 6; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.cellStyle = CellStyle(bold: true, backgroundColorHex: '#FFD700');
        
        switch (col) {
          case 0:
            cell.value = 'TOTAL';
            break;
          case 1:
            cell.value = totalSales.toStringAsFixed(2);
            break;
          case 2:
            cell.value = totalCovers.toString();
            break;
          case 3:
            cell.value = totalKitchen.toStringAsFixed(2);
            break;
          case 4:
            cell.value = totalBeverage.toStringAsFixed(2);
            break;
          case 5:
            cell.value = totalVendor.toStringAsFixed(2);
            break;
        }
      }

      // Save file
      final fileName = 'MonthlyReport_${DateFormat('yyyy-MM').format(DateTime(year, month))}.xlsx';
      final filePath = await _saveExcelFile(excel, fileName);
      
      return filePath;
    } catch (e) {
      print('❌ Error exporting Monthly Report: $e');
      rethrow;
    }
  }

  // =================== HELPER METHODS ===================

  static void _addHeaderRow(Sheet sheet, int row, String text) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = text;
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: '#FFA500',
    );
  }

  static void _addSectionTitle(Sheet sheet, int row, String text) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = text;
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: '#FFA500',
      fontColorHex: '#FFFFFF',
    );
  }

  static void _addDataRow(Sheet sheet, int row, String label, String value, {bool isBold = false}) {
    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = label;
    labelCell.cellStyle = CellStyle(bold: isBold);

    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    valueCell.value = value;
    valueCell.cellStyle = CellStyle(bold: isBold);
  }

  static void _addFooter(Sheet sheet, int row, String text) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = text;
    cell.cellStyle = CellStyle(
      italic: true,
      fontColorHex: '#808080',
    );
  }

  static Future<String> _saveExcelFile(Excel excel, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    
    final fileBytes = excel.save();
    final file = File(filePath);
    await file.writeAsBytes(fileBytes!);
    
    print('✅ Excel file saved: $filePath');
    return filePath;
  }

  // =================== OPEN FILE ===================
  
  static Future<void> openExcelFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      print('❌ Error opening file: $e');
    }
  }
}