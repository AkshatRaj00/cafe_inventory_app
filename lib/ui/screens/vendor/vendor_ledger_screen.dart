import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

import '../../../core/user_role.dart';

// =================== MODELS ===================

class VendorColumn {
  final String code;
  final String name;
  final IconData icon;
  const VendorColumn({
    required this.code,
    required this.name,
    required this.icon,
  });
}

class VendorLedgerCell {
  final String vendorCode;
  final String rawText;
  final double amount;
  final String? status; // P=Paid, D=Delivered, A=Approved, N=Pending
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;
  final String? notes;

  VendorLedgerCell({
    required this.vendorCode,
    this.rawText = '',
    this.amount = 0,
    this.status,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
    this.notes,
  });

  VendorLedgerCell copyWith({
    String? rawText,
    double? amount,
    String? status,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,
    String? notes,
  }) {
    return VendorLedgerCell(
      vendorCode: vendorCode,
      rawText: rawText ?? this.rawText,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'vendorCode': vendorCode,
        'rawText': rawText,
        'amount': amount,
        'status': status,
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
        'notes': notes,
      };

  factory VendorLedgerCell.fromMap(Map<String, dynamic> map) =>
      VendorLedgerCell(
        vendorCode: map['vendorCode'] ?? '',
        rawText: map['rawText'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        status: map['status'] as String?,
        lastUpdatedBy: map['lastUpdatedBy'] as String?,
        lastUpdatedAt: map['lastUpdatedAt'] != null
            ? DateTime.tryParse(map['lastUpdatedAt'])
            : null,
        notes: map['notes'] as String?,
      );
}

class VendorLedgerDay {
  final DateTime date;
  final List<VendorLedgerCell> cells;

  VendorLedgerDay({
    required this.date,
    required this.cells,
  });

  double totalForDay() => cells.fold(0, (sum, c) => sum + c.amount);

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'cells': cells.map((c) => c.toMap()).toList(),
      };

  factory VendorLedgerDay.fromMap(Map<String, dynamic> map) =>
      VendorLedgerDay(
        date: DateTime.parse(map['date']),
        cells: (map['cells'] as List)
            .map((e) =>
                VendorLedgerCell.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// =================== PARSING HELPERS ===================

double parseAmount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(t);
  if (match == null) return 0;
  return double.tryParse(match.group(0)!) ?? 0;
}

String? parseStatus(String text) {
  final t = text.trim().toUpperCase();
  if (t.contains('P')) return 'P'; // Paid
  if (t.contains('D')) return 'D'; // Delivered
  if (t.contains('A')) return 'A'; // Approved
  if (t.contains('N')) return 'N'; // Pending
  return null;
}

// =================== MAIN SCREEN ===================

class VendorLedgerScreen extends StatefulWidget {
  final UserRole? role;
  const VendorLedgerScreen({super.key, this.role});

  @override
  State<VendorLedgerScreen> createState() => _VendorLedgerScreenState();
}

class _VendorLedgerScreenState extends State<VendorLedgerScreen>
    with TickerProviderStateMixin {
  final List<VendorColumn> _columns = const [
    VendorColumn(code: 'SWEET_HUT', name: 'Sweet Hut', icon: Icons.cake),
    VendorColumn(code: 'DESI_AROMA', name: 'Desi Aroma', icon: Icons.restaurant),
    VendorColumn(code: 'VEG', name: 'Vegetable', icon: Icons.grass),
    VendorColumn(code: 'CHICKEN', name: 'Chicken', icon: Icons.food_bank),
    VendorColumn(code: 'PANEER', name: 'Paneer', icon: Icons.dining),
    VendorColumn(code: 'CASH', name: 'Cash', icon: Icons.attach_money),
    VendorColumn(code: 'ICE', name: 'Ice', icon: Icons.ac_unit),
    VendorColumn(code: 'GAS', name: 'Gas', icon: Icons.local_fire_department),
    VendorColumn(code: 'DISPOSAL', name: 'Disposal', icon: Icons.delete_sweep),
    VendorColumn(code: 'COAL', name: 'Coal', icon: Icons.whatshot),
    VendorColumn(code: 'ICE_CREAM', name: 'Ice Cream', icon: Icons.icecream),
    VendorColumn(code: 'COFFEE', name: 'Coffee', icon: Icons.coffee),
    VendorColumn(code: 'NESTLE', name: 'Nestle', icon: Icons.breakfast_dining),
    VendorColumn(code: 'FISH', name: 'Fish', icon: Icons.set_meal),
    VendorColumn(code: 'MISC', name: 'Misc.', icon: Icons.more_horiz),
  ];

  late Box _box;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final _searchCtrl = TextEditingController();
  List<VendorLedgerDay> _days = [];
  List<VendorLedgerDay> _filteredDays = [];
  
  // Undo/Redo stacks
  final List<List<VendorLedgerDay>> _undoStack = [];
  final List<List<VendorLedgerDay>> _redoStack = [];

  late AnimationController _headerAnimController;
  late Animation<Offset> _headerSlideAnim;

  bool get _isAdminOrManager =>
      widget.role == UserRole.admin || widget.role == UserRole.manager;

  bool get _canEdit => _isAdminOrManager;

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchCtrl.addListener(_applySearch);
    
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    ));
    
    _headerAnimController.forward();
  }

  Future<void> _initHive() async {
    _box = await Hive.openBox('vendor_ledger');
    _loadMonth();
  }

  String _monthKey(DateTime month) => DateFormat('yyyy-MM').format(month);

  void _loadMonth() {
    final key = _monthKey(_currentMonth);
    final saved = _box.get(key);

    if (saved != null && saved is List) {
      _days = saved
          .map((e) =>
              VendorLedgerDay.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      _days = _generateEmptyMonth(_currentMonth);
    }

    _filteredDays = List.from(_days);
    setState(() {
      _isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  List<VendorLedgerDay> _generateEmptyMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final days = nextMonth.difference(first).inDays;

    return List.generate(days, (i) {
      final date = DateTime(month.year, month.month, i + 1);
      return VendorLedgerDay(
        date: date,
        cells: _columns
            .map((col) => VendorLedgerCell(vendorCode: col.code))
            .toList(),
      );
    });
  }

  Future<void> _saveMonth() async {
    final key = _monthKey(_currentMonth);
    final payload = _days.map((d) => d.toMap()).toList();
    await _box.put(key, payload);
    setState(() => _hasUnsavedChanges = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Vendor ledger saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredDays = List.from(_days));
      return;
    }

    setState(() {
      _filteredDays = _days.where((day) {
        final dateStr = DateFormat('dd-MM-yyyy').format(day.date);
        if (dateStr.contains(q)) return true;

        for (final cell in day.cells) {
          if (cell.rawText.toLowerCase().contains(q) ||
              cell.notes?.toLowerCase().contains(q) == true) {
            return true;
          }
        }
        return false;
      }).toList();
    });
  }

  void _changeMonth(int delta) async {
    if (_hasUnsavedChanges) {
      final should = await _showUnsavedChangesDialog();
      if (should != true) return;
    }
    setState(() {
      _isLoading = true;
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + delta,
      );
    });
    _loadMonth();
    _headerAnimController.reset();
    _headerAnimController.forward();
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Unsaved Changes', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Continue without saving?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _addNewDay() {
    final newDate = _days.isEmpty
        ? DateTime(_currentMonth.year, _currentMonth.month, 1)
        : _days.last.date.add(const Duration(days: 1));

    _saveToUndoStack();
    
    final newDay = VendorLedgerDay(
      date: newDate,
      cells: _columns
          .map((col) => VendorLedgerCell(vendorCode: col.code))
          .toList(),
    );

    setState(() {
      _days.add(newDay);
      _applySearch();
      _hasUnsavedChanges = true;
    });
  }

  void _deleteDay(VendorLedgerDay day) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Entry?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Delete entry for ${DateFormat('dd MMM yyyy').format(day.date)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _saveToUndoStack();
      setState(() {
        _days.removeWhere((d) => d.date == day.date);
        _applySearch();
        _hasUnsavedChanges = true;
      });
    }
  }

  void _saveToUndoStack() {
    _undoStack.add(_days.map((d) => VendorLedgerDay(
      date: d.date,
      cells: d.cells.map((c) => VendorLedgerCell(
        vendorCode: c.vendorCode,
        rawText: c.rawText,
        amount: c.amount,
        status: c.status,
        lastUpdatedBy: c.lastUpdatedBy,
        lastUpdatedAt: c.lastUpdatedAt,
        notes: c.notes,
      )).toList(),
    )).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_days));
    setState(() {
      _days = _undoStack.removeLast();
      _applySearch();
      _hasUnsavedChanges = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_days));
    setState(() {
      _days = _redoStack.removeLast();
      _applySearch();
      _hasUnsavedChanges = true;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _headerAnimController.dispose();
    _box.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);

    final Map<String, double> monthlyTotals = {
      for (final c in _columns) c.code: 0,
    };
    double grandTotal = 0;
    for (final day in _days) {
      for (final cell in day.cells) {
        monthlyTotals[cell.vendorCode] =
            (monthlyTotals[cell.vendorCode] ?? 0) + cell.amount;
        grandTotal += cell.amount;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080910),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F111A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () async {
            if (_hasUnsavedChanges) {
              final should = await _showUnsavedChangesDialog();
              if (should == true) Navigator.pop(context);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book_outlined, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Vendor Ledger',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.role?.label ?? 'Guest'} Access',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (_canEdit && _undoStack.isNotEmpty)
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo_rounded, color: Colors.blueAccent),
              onPressed: _undo,
            ),
          if (_canEdit && _redoStack.isNotEmpty)
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo_rounded, color: Colors.blueAccent),
              onPressed: _redo,
            ),
          if (_hasUnsavedChanges && _canEdit)
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_rounded, color: Colors.greenAccent),
              onPressed: _saveMonth,
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF1E2030),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: const [
                    Icon(Icons.file_download_outlined, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Export CSV', style: TextStyle(color: Colors.white)),
                  ],
                ),
                onTap: () {
                  // Export logic placeholder
                  Future.delayed(Duration.zero, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Export feature coming soon!'),
                        backgroundColor: Colors.blueAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
              children: [
                SlideTransition(
                  position: _headerSlideAnim,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade800,
                          Colors.orange.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded,
                                        color: Colors.white, size: 28),
                                    onPressed: () => _changeMonth(-1),
                                  ),
                                  Expanded(
                                    child: Text(
                                      monthLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded,
                                        color: Colors.white, size: 28),
                                    onPressed: () => _changeMonth(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatCard(
                                    'Days',
                                    _days.length.toString(),
                                    Icons.calendar_today_rounded,
                                  ),
                                  _buildStatCard(
                                    'Total',
                                    '₹${grandTotal.toStringAsFixed(0)}',
                                    Icons.currency_rupee_rounded,
                                  ),
                                  _buildStatCard(
                                    'Avg/Day',
                                    '₹${(_days.isEmpty ? 0 : grandTotal / _days.length).toStringAsFixed(0)}',
                                    Icons.trending_up_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by date, amount, vendor...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Colors.amber, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF151826),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildHeaderRow(),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredDays.length,
                    itemBuilder: (context, index) {
                      final day = _filteredDays[index];
                      final originalIndex = _days.indexOf(day);
                      return VendorLedgerDayRow(
                        key: ValueKey(day.date.toIso8601String()),
                        day: day,
                        columns: _columns,
                        canEdit: _canEdit,
                        onChanged: (updated) {
                          _saveToUndoStack();
                          setState(() {
                            _days[originalIndex] = updated;
                            _applySearch();
                            _hasUnsavedChanges = true;
                          });
                        },
                        onDelete: () => _deleteDay(day),
                      );
                    },
                  ),
                ),
                _buildMonthlyTotalsRow(monthlyTotals, grandTotal),
              ],
            ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _addNewDay,
              backgroundColor: Colors.amber,
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: const Text(
                'Add Day',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: const Color(0xFF151826),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 90,
            child: Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.amber,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _columns
                    .map((c) => SizedBox(
                          width: 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(c.icon, color: Colors.white54, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(
            width: 85,
            child: Text(
              'Total',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTotalsRow(
      Map<String, double> monthlyTotals, double grandTotal) {
    return Container(
      color: const Color(0xFF151826),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 90,
            child: Text(
              'MONTHLY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _columns.map((c) {
                  final v = monthlyTotals[c.code] ?? 0;
                  return Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: v == 0
                          ? Colors.transparent
                          : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: v == 0 ? Colors.transparent : Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      v == 0 ? '-' : '₹${v.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: v == 0 ? Colors.white24 : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              grandTotal == 0 ? '-' : '₹${grandTotal.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== DAY ROW WIDGET ===================

class VendorLedgerDayRow extends StatefulWidget {
  final VendorLedgerDay day;
  final List<VendorColumn> columns;
  final bool canEdit;
  final ValueChanged<VendorLedgerDay> onChanged;
  final VoidCallback onDelete;

  const VendorLedgerDayRow({
    super.key,
    required this.day,
    required this.columns,
    required this.canEdit,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<VendorLedgerDayRow> createState() => _VendorLedgerDayRowState();
}

class _VendorLedgerDayRowState extends State<VendorLedgerDayRow>
    with SingleTickerProviderStateMixin {
  late Map<String, TextEditingController> _controllers;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final c in widget.columns)
        c.code: TextEditingController(
          text: widget.day.cells
                  .firstWhere(
                    (cell) => cell.vendorCode == c.code,
                    orElse: () => VendorLedgerCell(vendorCode: c.code),
                  )
                  .rawText ??
              '',
        ),
    };

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    
    _animController.forward();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final dateStr = DateFormat('dd MMM').format(day.date);
    final weekday = DateFormat('EEE').format(day.date);
    final total = day.totalForDay();

    Color badgeColor;
    String badgeText;
    if (total == 0) {
      badgeColor = Colors.grey;
      badgeText = 'NO BUY';
    } else if (total < 5000) {
      badgeColor = Colors.greenAccent;
      badgeText = 'NORMAL';
    } else if (total < 15000) {
      badgeColor = Colors.orangeAccent;
      badgeText = 'HIGH';
    } else {
      badgeColor = Colors.redAccent;
      badgeText = 'ALERT';
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dismissible(
          key: ValueKey(day.date.toIso8601String()),
          direction: widget.canEdit
              ? DismissDirection.endToStart
              : DismissDirection.none,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_forever_rounded,
                color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E2030),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Confirm Delete',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                content: Text(
                  'Delete entry for ${DateFormat('dd MMM yyyy').format(day.date)}?\nThis cannot be undone.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            return confirm == true;
          },
          onDismissed: (_) => widget.onDelete(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF151826),
                  const Color(0xFF1A1F2E),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekday.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: badgeColor.withOpacity(0.5), width: 1),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: widget.columns.map((c) => _cellField(c)).toList(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 85,
                  child: Text(
                    total == 0 ? '-' : '₹${total.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: total == 0 ? Colors.white24 : Colors.amber,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellField(VendorColumn col) {
    final controller = _controllers[col.code]!;
    final cell = widget.day.cells.firstWhere(
      (c) => c.vendorCode == col.code,
      orElse: () => VendorLedgerCell(vendorCode: col.code),
    );

    Color? statusColor;
    if (cell.status == 'P') {
      statusColor = Colors.greenAccent;
    } else if (cell.status == 'D') {
      statusColor = Colors.blueAccent;
    } else if (cell.status == 'A') {
      statusColor = Colors.purpleAccent;
    } else if (cell.status == 'N') {
      statusColor = Colors.orangeAccent;
    }

    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onLongPress: widget.canEdit ? () => _showEditDialog(col, cell) : null,
        child: Stack(
          children: [
            TextField(
              controller: controller,
              readOnly: !widget.canEdit,
              keyboardType: TextInputType.text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                filled: true,
                fillColor: cell.amount > 0
                    ? Colors.amber.withOpacity(0.08)
                    : const Color(0xFF0F111A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: cell.amount > 0
                        ? Colors.amber.withOpacity(0.3)
                        : Colors.white12,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.amber, width: 2),
                ),
                hintText: '0',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              onChanged: widget.canEdit
                  ? (value) {
                      _updateDayFor(col.code, value);
                      setState(() {});
                    }
                  : null,
            ),
            if (statusColor != null)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _updateDayFor(String vendorCode, String value) {
    final amount = parseAmount(value);
    final status = parseStatus(value);

    final updatedCells = widget.day.cells.map((cell) {
      if (cell.vendorCode != vendorCode) return cell;
      return cell.copyWith(
        rawText: value,
        amount: amount,
        status: status,
        lastUpdatedBy: 'USER',
        lastUpdatedAt: DateTime.now(),
      );
    }).toList();

    widget.onChanged(
      VendorLedgerDay(
        date: widget.day.date,
        cells: updatedCells,
      ),
    );
  }

  void _showEditDialog(VendorColumn col, VendorLedgerCell cell) {
    final notesCtrl = TextEditingController(text: cell.notes ?? '');
    String? selectedStatus = cell.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2030),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(col.icon, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit ${col.name}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount: ₹${cell.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Status:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _statusChip('Paid', 'P', Colors.greenAccent,
                      selectedStatus, setDialogState),
                  _statusChip('Delivered', 'D', Colors.blueAccent,
                      selectedStatus, setDialogState),
                  _statusChip('Approved', 'A', Colors.purpleAccent,
                      selectedStatus, setDialogState),
                  _statusChip('Pending', 'N', Colors.orangeAccent,
                      selectedStatus, setDialogState),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0F111A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.amber, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedCells = widget.day.cells.map((c) {
                  if (c.vendorCode != col.code) return c;
                  return c.copyWith(
                    status: selectedStatus,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    lastUpdatedAt: DateTime.now(),
                  );
                }).toList();

                widget.onChanged(VendorLedgerDay(
                  date: widget.day.date,
                  cells: updatedCells,
                ));

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value, Color color,
      String? selectedStatus, StateSetter setDialogState) {
    final isSelected = selectedStatus == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.5)),
      onSelected: (selected) {
        setDialogState(() {
          selectedStatus = selected ? value : null;
        });
      },
    );
  }
}