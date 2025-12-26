import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/supabase/daily_report_supabase_service.dart';


import '../user_role.dart';

enum DailyReportSyncStatus { pending, synced }

class DailyReport {
  final DateTime date;

  // Sales
  final double totalSales;
  final double cashSales;
  final double cardSales;
  final double upiSales;
  final double discounts;
  final int covers;

  // Kitchen summary
  final double kitchenClosingValue;
  final double kitchenWasteValue;
  final String criticalItemsText;

  // Beverage summary
  final double beverageClosingValue;

  // Vendor summary
  final double vendorPurchaseTotal;
  final double vendorDueAdded;

  // Operations
  final int staffCount;
  final String issues;
  final String actions;

  // Meta
  final bool isLocked;
  final UserRole? createdByRole;
  final UserRole? lockedByRole;
  final DailyReportSyncStatus syncStatus;
  final DateTime? createdAt;  // ✅ ADDED
  final DateTime? updatedAt;  // ✅ ADDED

  DailyReport({
    required this.date,
    this.totalSales = 0,
    this.cashSales = 0,
    this.cardSales = 0,
    this.upiSales = 0,
    this.discounts = 0,
    this.covers = 0,
    this.kitchenClosingValue = 0,
    this.kitchenWasteValue = 0,
    this.criticalItemsText = '',
    this.beverageClosingValue = 0,
    this.vendorPurchaseTotal = 0,
    this.vendorDueAdded = 0,
    this.staffCount = 0,
    this.issues = '',
    this.actions = '',
    this.isLocked = false,
    this.createdByRole,
    this.lockedByRole,
    this.syncStatus = DailyReportSyncStatus.pending,
    this.createdAt,  // ✅ ADDED
    this.updatedAt,  // ✅ ADDED
  });

  bool get canEditLocked => !isLocked;

  String get dateKey =>
      DateFormat('yyyy-MM-dd').format(date);

  DailyReport copyWith({
    DateTime? date,
    double? totalSales,
    double? cashSales,
    double? cardSales,
    double? upiSales,
    double? discounts,
    int? covers,
    double? kitchenClosingValue,
    double? kitchenWasteValue,
    String? criticalItemsText,
    double? beverageClosingValue,
    double? vendorPurchaseTotal,
    double? vendorDueAdded,
    int? staffCount,
    String? issues,
    String? actions,
    bool? isLocked,
    UserRole? createdByRole,
    UserRole? lockedByRole,
    DailyReportSyncStatus? syncStatus,
    DateTime? createdAt,  // ✅ ADDED
    DateTime? updatedAt,  // ✅ ADDED
  }) {
    return DailyReport(
      date: date ?? this.date,
      totalSales: totalSales ?? this.totalSales,
      cashSales: cashSales ?? this.cashSales,
      cardSales: cardSales ?? this.cardSales,
      upiSales: upiSales ?? this.upiSales,
      discounts: discounts ?? this.discounts,
      covers: covers ?? this.covers,
      kitchenClosingValue:
          kitchenClosingValue ?? this.kitchenClosingValue,
      kitchenWasteValue:
          kitchenWasteValue ?? this.kitchenWasteValue,
      criticalItemsText:
          criticalItemsText ?? this.criticalItemsText,
      beverageClosingValue:
          beverageClosingValue ?? this.beverageClosingValue,
      vendorPurchaseTotal:
          vendorPurchaseTotal ?? this.vendorPurchaseTotal,
      vendorDueAdded: vendorDueAdded ?? this.vendorDueAdded,
      staffCount: staffCount ?? this.staffCount,
      issues: issues ?? this.issues,
      actions: actions ?? this.actions,
      isLocked: isLocked ?? this.isLocked,
      createdByRole: createdByRole ?? this.createdByRole,
      lockedByRole: lockedByRole ?? this.lockedByRole,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,  // ✅ ADDED
      updatedAt: updatedAt ?? this.updatedAt,  // ✅ ADDED
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'totalSales': totalSales,
      'cashSales': cashSales,
      'cardSales': cardSales,
      'upiSales': upiSales,
      'discounts': discounts,
      'covers': covers,
      'kitchenClosingValue': kitchenClosingValue,
      'kitchenWasteValue': kitchenWasteValue,
      'criticalItemsText': criticalItemsText,
      'beverageClosingValue': beverageClosingValue,
      'vendorPurchaseTotal': vendorPurchaseTotal,
      'vendorDueAdded': vendorDueAdded,
      'staffCount': staffCount,
      'issues': issues,
      'actions': actions,
      'isLocked': isLocked,
      'createdByRole': createdByRole != null
          ? describeEnum(createdByRole!)
          : null,
      'lockedByRole':
          lockedByRole != null ? describeEnum(lockedByRole!) : null,
      'syncStatus': syncStatus.name,
      'createdAt': createdAt?.toIso8601String(),  // ✅ ADDED
      'updatedAt': updatedAt?.toIso8601String(),  // ✅ ADDED
    };
  }

  factory DailyReport.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.parse(rawDate as String);
    }

    UserRole? parseRole(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return UserRole.values.firstWhere(
        (r) => describeEnum(r) == s,
        orElse: () => UserRole.admin,
      );
    }

    DailyReportSyncStatus parseStatus(dynamic v) {
      final s = v?.toString() ?? DailyReportSyncStatus.pending.name;
      return DailyReportSyncStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => DailyReportSyncStatus.pending,
      );
    }

    return DailyReport(
      date: parsedDate,
      totalSales: (map['totalSales'] ?? 0).toDouble(),
      cashSales: (map['cashSales'] ?? 0).toDouble(),
      cardSales: (map['cardSales'] ?? 0).toDouble(),
      upiSales: (map['upiSales'] ?? 0).toDouble(),
      discounts: (map['discounts'] ?? 0).toDouble(),
      covers: (map['covers'] ?? 0).toInt(),
      kitchenClosingValue:
          (map['kitchenClosingValue'] ?? 0).toDouble(),
      kitchenWasteValue:
          (map['kitchenWasteValue'] ?? 0).toDouble(),
      criticalItemsText:
          (map['criticalItemsText'] ?? '') as String,
      beverageClosingValue:
          (map['beverageClosingValue'] ?? 0).toDouble(),
      vendorPurchaseTotal:
          (map['vendorPurchaseTotal'] ?? 0).toDouble(),
      vendorDueAdded:
          (map['vendorDueAdded'] ?? 0).toDouble(),
      staffCount: (map['staffCount'] ?? 0).toInt(),
      issues: (map['issues'] ?? '') as String,
      actions: (map['actions'] ?? '') as String,
      isLocked: (map['isLocked'] ?? false) as bool,
      createdByRole: parseRole(map['createdByRole']),
      lockedByRole: parseRole(map['lockedByRole']),
      syncStatus: parseStatus(map['syncStatus']),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,  // ✅ ADDED
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,  // ✅ ADDED
    );
  }
}

// ------------ Simple repository over Hive -------------

class DailyReportRepository {
  static const String boxName = 'daily_reports';

  static String _keyForDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static Future<Box<dynamic>> _openBox() async {
    return Hive.openBox<dynamic>(boxName);
  }

  static Future<DailyReport?> loadByDate(DateTime date) async {
    final box = await _openBox();
    final key = _keyForDate(date);
    final raw = box.get(key);
    if (raw == null) return null;

    if (raw is Map) {
      return DailyReport.fromMap(
        Map<String, dynamic>.from(raw),
      );
    }
    return null;
  }

  static Future<void> save(DailyReport report) async {
    final box = await _openBox();
    final key = _keyForDate(report.date);
    await box.put(key, report.toMap());
  }
}