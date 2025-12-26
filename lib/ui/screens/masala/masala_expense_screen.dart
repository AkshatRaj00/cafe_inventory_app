import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/user_role.dart';

/// Masala / Daily Expense screen
class MasalaExpenseScreen extends StatefulWidget {
  final UserRole? role;

  const MasalaExpenseScreen({
    super.key,
    this.role,
  });

  @override
  State<MasalaExpenseScreen> createState() => _MasalaExpenseScreenState();
}

class _MasalaExpenseScreenState extends State<MasalaExpenseScreen> {
  DateTime _selectedDate = DateTime.now();
  late Box _expenseBox;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  // One row per date (usually 1 row for selected date)
  List<MasalaEntry> _rows = [];

  bool get _isToday =>
      DateUtils.isSameDay(_selectedDate, DateTime.now());

  bool get _isAdminOrManager =>
      widget.role == UserRole.admin || widget.role == UserRole.manager;

  // yahan sabko allow kar rahe (Admin/Manager/Chef)
  bool get _canEdit {
    if (_isAdminOrManager) return true;
    if (widget.role == UserRole.chef && _isToday) return true;
    return false;
  }

  bool get _canAddDelete => _canEdit;

  final List<String> _heads = const [
    'Cash',
    'Ice',
    'Gas',
    'Disposal',
    'Coal',
    'Ice Cream',
    'Coffee',
    'Nestle',
    'Fish',
    'Misc',
  ];

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _expenseBox = await Hive.openBox('masala_expense');
    _loadData();
  }

  String _getDateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d);

  String get _formattedDate =>
      DateFormat('dd/MM/yyyy').format(_selectedDate);

  void _loadData() {
    final key = _getDateKey(_selectedDate);
    final saved = _expenseBox.get(key);

    if (saved != null && saved is List) {
      _rows = saved
          .map((e) => MasalaEntry.fromMap(
                Map<String, dynamic>.from(e as Map),
                _heads,
              ))
          .toList();
    } else {
      // default one empty row for that date
      _rows = [
        MasalaEntry(
          date: _selectedDate,
          values: {for (final h in _heads) h: 0.0},
        ),
      ];
    }

    setState(() {
      _isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveData() async {
    final key = _getDateKey(_selectedDate);
    final toSave = _rows.map((e) => e.toMap()).toList();
    await _expenseBox.put(key, toSave);

    setState(() => _hasUnsavedChanges = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Masala / expense data saved'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_hasUnsavedChanges) {
      final shouldContinue = await _showUnsavedChangesDialog();
      if (shouldContinue != true) return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadData();
    }
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Continue without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _addRow() {
    if (!_canAddDelete) return;
    setState(() {
      _rows.add(
        MasalaEntry(
          date: _selectedDate,
          values: {for (final h in _heads) h: 0.0},
        ),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _deleteRow(int index) {
    if (!_canAddDelete) return;
    if (_rows.length == 1) return; // at least one row
    setState(() {
      _rows.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  Map<String, double> get _columnTotals {
    final Map<String, double> totals = {
      for (final h in _heads) h: 0.0,
    };
    for (final row in _rows) {
      row.values.forEach((head, value) {
        totals[head] = (totals[head] ?? 0) + value;
      });
    }
    return totals;
  }

  @override
  void dispose() {
    _expenseBox.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080910),
        appBar: AppBar(
          leading: const BackButton(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masala / Daily Expense (${widget.role?.label ?? 'Guest'})',
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _pickDate,
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_hasUnsavedChanges && _canEdit)
              IconButton(
                tooltip: 'Save',
                icon: const Icon(
                  Icons.save,
                  color: Colors.greenAccent,
                ),
                onPressed: _saveData,
              ),
            if (_canAddDelete)
              IconButton(
                tooltip: 'Add row',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addRow,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 900, // enough for all columns on web
                        child: ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return MasalaRowWidget(
                              index: index,
                              entry: row,
                              heads: _heads,
                              canEdit: _canEdit,
                              canDelete: _canAddDelete,
                              onChanged: (updated) {
                                if (_canEdit) {
                                  setState(() {
                                    _rows[index] = updated;
                                    _hasUnsavedChanges = true;
                                  });
                                }
                              },
                              onDelete: _canAddDelete
                                  ? () => _deleteRow(index)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  _buildTotalsRow(),
                ],
              ),
        floatingActionButton:
            _hasUnsavedChanges && _canEdit
                ? FloatingActionButton.extended(
                    onPressed: _saveData,
                    backgroundColor: Colors.green,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                  )
                : null,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF151826),
      padding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              'S.No.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(
            width: 80,
            child: Text(
              'Date',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          for (final head in _heads)
            Expanded(
              child: Center(
                child: Text(
                  head,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          const SizedBox(
            width: 40,
            child: Icon(
              Icons.delete_outline,
              color: Colors.white24,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow() {
    final totals = _columnTotals;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111320),
        border: Border(
          top: BorderSide(color: Colors.white24),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              'Total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(
            width: 80,
            child: Text(
              '',
              style: TextStyle(fontSize: 11),
            ),
          ),
          for (final head in _heads)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _fmtOut(totals[head] ?? 0),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _fmtOut(double v) {
    if (v == 0) return '0';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

/// DATA MODEL

class MasalaEntry {
  final DateTime date;
  final Map<String, double> values;

  MasalaEntry({
    required this.date,
    required this.values,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'values': values,
      };

  factory MasalaEntry.fromMap(
    Map<String, dynamic> map,
    List<String> heads,
  ) {
    final raw = Map<String, dynamic>.from(map['values'] ?? {});
    final values = <String, double>{};
    for (final h in heads) {
      values[h] = (raw[h] ?? 0).toDouble();
    }
    return MasalaEntry(
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      values: values,
    );
  }

  MasalaEntry copyWith({
    DateTime? date,
    Map<String, double>? values,
  }) {
    return MasalaEntry(
      date: date ?? this.date,
      values: values ?? this.values,
    );
  }
}

/// ROW WIDGET

class MasalaRowWidget extends StatefulWidget {
  final int index;
  final MasalaEntry entry;
  final List<String> heads;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<MasalaEntry>? onChanged;
  final VoidCallback? onDelete;

  const MasalaRowWidget({
    super.key,
    required this.index,
    required this.entry,
    required this.heads,
    required this.canEdit,
    required this.canDelete,
    this.onChanged,
    this.onDelete,
  });

  @override
  State<MasalaRowWidget> createState() => _MasalaRowWidgetState();
}

class _MasalaRowWidgetState extends State<MasalaRowWidget> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final h in widget.heads)
        h: TextEditingController(
          text: _fmtIn(widget.entry.values[h] ?? 0),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtIn(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  void _onValueChanged(String head, double value) {
    final newValues = Map<String, double>.from(widget.entry.values);
    newValues[head] = value;
    widget.onChanged?.call(
      widget.entry.copyWith(values: newValues),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM').format(widget.entry.date);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '${widget.index + 1}.',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              dateStr,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          for (final head in widget.heads)
            Expanded(
              child: _smallField(
                _controllers[head]!,
                (v) => _onValueChanged(head, v),
              ),
            ),
          SizedBox(
            width: 40,
            child: widget.canDelete && widget.onDelete != null
                ? IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _smallField(
    TextEditingController controller,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        readOnly: !widget.canEdit,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'^\d*\.?\d{0,2}'),
          ),
        ],
        style: const TextStyle(fontSize: 11, color: Colors.white),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        onChanged: widget.canEdit
            ? (value) {
                final v = double.tryParse(value) ?? 0;
                if (v >= 0) {
                  onChanged(v);
                  setState(() {});
                }
              }
            : null,
      ),
    );
  }
}
