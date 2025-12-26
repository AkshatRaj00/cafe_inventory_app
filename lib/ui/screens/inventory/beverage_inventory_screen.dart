import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/user_role.dart';
import '../../../core/number_to_words_helper.dart';

class BeverageInventoryScreen extends StatefulWidget {
  final UserRole? role;

  const BeverageInventoryScreen({
    super.key,
    this.role,
  });

  @override
  State<BeverageInventoryScreen> createState() =>
      _BeverageInventoryScreenState();
}

class _BeverageInventoryScreenState extends State<BeverageInventoryScreen> {
  DateTime _selectedDate = DateTime.now();
  late Box _beverageBox;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  final _searchCtrl = TextEditingController();
  List<BeverageRow> _rows = [];
  List<BeverageRow> _filteredRows = [];

  bool get _isToday => DateUtils.isSameDay(_selectedDate, DateTime.now());

  bool get _isAdminOrManager =>
      widget.role == UserRole.admin || widget.role == UserRole.manager;

  // Admin + Manager: all dates; Chef: only today
  bool get _canEdit {
    if (_isAdminOrManager) return true;
    if (widget.role == UserRole.chef && _isToday) return true;
    return false;
  }

  bool get _canAddDelete => _canEdit;

  final List<String> _itemNames = const [
    'Bottle Water',
    'Cold Drink',
    'Redbull',
    'Tonic Water',
    'Diet Coke',
    'Banta Soda',
    'Soda',
    'Mouth Fresh(C)',
    'Beverages BL-1',
    'Beverages BL-2',
    'Beverages Res-1',
    'Beverages Res-2',
    'Beverages G',
    'Beverages AB',
    'Beverages JW',
    'Malt Syrup',
    'Can',
    'Peach Syrup 1L',
    'Sangria Syrup 1L',
    'Triple Sec 1L',
    'Raspberry 1L',
    'Hazelnut 1L',
    'Majito Syrup 750 ml',
    'Wetermelon 75 ml',
    'Rose Syrup 750 ml',
    'Kiwi Crush 750 ml',
    'Green Apple Crush 750 ml',
    'Strawberry Crush 750 ml',
    'Banana Crush 750 ml',
    'Blueberry Crush 750 ml',
    'Mango Crush 750 ml',
    'Pineapple Crush 750 ml',
    'Orange Crush 750 ml',
    'Pinacolada Syrup 1L',
    'Blue Curacao 750 ml',
    'Lemon',
    'Ice Cube',
    'Real Juice 1L',
    'Vanilla Ice Cream',
    'Butter Scotch Ice Cream',
    'Chocolate Ice Cream',
    'Strawberry Ice Cream',
    'Coffee Beans',
    'Sugar Pouch',
    'Vanilla Powder',
    'Ice Tea Powder',
  ];

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchCtrl.addListener(_applySearch);
  }

  Future<void> _initHive() async {
    _beverageBox = await Hive.openBox('beverage_inventory');
    _loadData();
  }

  void _loadData() {
    final dateKey = _getDateKey(_selectedDate);
    final savedData = _beverageBox.get(dateKey);

    if (savedData != null && savedData is List) {
      _rows = savedData
          .map(
            (item) => BeverageRow.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } else {
      _rows = _itemNames
          .map((name) => BeverageRow(itemName: name))
          .toList(growable: true);
    }

    // sort by name for consistent order
    _rows.sort((a, b) => a.itemName.toLowerCase().compareTo(
          b.itemName.toLowerCase(),
        ));

    _filteredRows = List.from(_rows);

    setState(() {
      _isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  String _getDateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  String get _formattedDate =>
      DateFormat('dd/MM/yyyy').format(_selectedDate);

  Future<void> _saveData() async {
    final dateKey = _getDateKey(_selectedDate);
    final dataToSave = _rows.map((row) => row.toMap()).toList();
    await _beverageBox.put(dateKey, dataToSave);

    setState(() => _hasUnsavedChanges = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Beverage data saved successfully!'),
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
        _searchCtrl.clear();
      });
      _loadData();
    }
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    if (!_canAddDelete) return;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add new beverage'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(labelText: 'Item name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _rows.add(
                    BeverageRow(
                      itemName: name,
                      lastUpdatedBy: userRoleShort(widget.role),
                      lastUpdatedAt: DateTime.now(),
                    ),
                  );
                  _rows.sort((a, b) => a.itemName
                      .toLowerCase()
                      .compareTo(b.itemName.toLowerCase()));
                  _applySearch();
                  _hasUnsavedChanges = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredRows = List.from(_rows));
    } else {
      setState(() {
        _filteredRows = _rows
            .where((r) => r.itemName.toLowerCase().contains(q))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _beverageBox.close();
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
                'Beverage Inventory (${widget.role?.label ?? 'Guest'})',
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
                tooltip: 'Add item',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _showAddItemDialog,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search beverage...',
                        hintStyle: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF151826),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  _buildHeader(),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: _filteredRows.isEmpty
                        ? const Center(
                            child: Text(
                              'No items found.',
                              style: TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredRows.length,
                            itemBuilder: (context, index) {
                              final row = _filteredRows[index];
                              final originalIndex =
                                  _rows.indexOf(row);
                              return BeverageRowWidget(
                                key: ValueKey(
                                    row.itemName + originalIndex.toString()),
                                index: originalIndex,
                                row: row,
                                canEdit: _canEdit,
                                canDelete: _canAddDelete,
                                currentRole: widget.role,
                                onChanged: (updated) {
                                  if (_canEdit) {
                                    setState(() {
                                      _rows[originalIndex] = updated;
                                      _applySearch();
                                      _hasUnsavedChanges = true;
                                    });
                                  }
                                },
                                onDelete: _canAddDelete
                                    ? () {
                                        setState(() {
                                          _rows.removeAt(originalIndex);
                                          _applySearch();
                                          _hasUnsavedChanges = true;
                                        });
                                      }
                                    : null,
                              );
                            },
                          ),
                  ),
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
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              'No.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Item',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              'Ope / Rec / Sale / Short',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Total / Closing',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// DATA MODEL

class BeverageRow {
  final String itemName;
  final double open;
  final double received;
  final double sales;
  final double shortOrWaste;

  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;

  BeverageRow({
    required this.itemName,
    this.open = 0,
    this.received = 0,
    this.sales = 0,
    this.shortOrWaste = 0,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
  });

  double get total => open + received;
  double get closing => total - sales - shortOrWaste;

  BeverageRow copyWith({
    double? open,
    double? received,
    double? sales,
    double? shortOrWaste,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,
  }) {
    return BeverageRow(
      itemName: itemName,
      open: open ?? this.open,
      received: received ?? this.received,
      sales: sales ?? this.sales,
      shortOrWaste: shortOrWaste ?? this.shortOrWaste,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'open': open,
        'received': received,
        'sales': sales,
        'shortOrWaste': shortOrWaste,
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      };

  factory BeverageRow.fromMap(Map<String, dynamic> map) => BeverageRow(
        itemName: map['itemName'] ?? '',
        open: (map['open'] ?? 0).toDouble(),
        received: (map['received'] ?? 0).toDouble(),
        sales: (map['sales'] ?? 0).toDouble(),
        shortOrWaste: (map['shortOrWaste'] ?? 0).toDouble(),
        lastUpdatedBy: map['lastUpdatedBy'] as String?,
        lastUpdatedAt: map['lastUpdatedAt'] != null
            ? DateTime.tryParse(map['lastUpdatedAt'])
            : null,
      );
}

/// ROW WIDGET (same as tumhara, sirf minor cleanups)

class BeverageRowWidget extends StatefulWidget {
  final int index;
  final BeverageRow row;
  final bool canEdit;
  final bool canDelete;
  final UserRole? currentRole;
  final ValueChanged<BeverageRow>? onChanged;
  final VoidCallback? onDelete;

  const BeverageRowWidget({
    super.key,
    required this.index,
    required this.row,
    required this.canEdit,
    required this.canDelete,
    required this.currentRole,
    this.onChanged,
    this.onDelete,
  });

  @override
  State<BeverageRowWidget> createState() => _BeverageRowWidgetState();
}

class _BeverageRowWidgetState extends State<BeverageRowWidget> {
  late TextEditingController _openCtrl;
  late TextEditingController _recCtrl;
  late TextEditingController _salesCtrl;
  late TextEditingController _shortCtrl;

  @override
  void initState() {
    super.initState();
    _openCtrl = TextEditingController(text: _fmtIn(widget.row.open));
    _recCtrl =
        TextEditingController(text: _fmtIn(widget.row.received));
    _salesCtrl = TextEditingController(text: _fmtIn(widget.row.sales));
    _shortCtrl =
        TextEditingController(text: _fmtIn(widget.row.shortOrWaste));
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _recCtrl.dispose();
    _salesCtrl.dispose();
    _shortCtrl.dispose();
    super.dispose();
  }

  String _fmtIn(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final total = row.total;
    final closing = row.closing;

    Color statusColor;
    String statusText;

    if (closing < 0) {
      statusColor = Colors.redAccent;
      statusText = 'NEGATIVE';
    } else if (closing == 0 && total > 0) {
      statusColor = Colors.redAccent;
      statusText = 'OUT';
    } else if (total > 0 && closing / total <= 0.2) {
      statusColor = Colors.orangeAccent;
      statusText = 'LOW';
    } else if (total > 0) {
      statusColor = Colors.greenAccent.shade400;
      statusText = 'OK';
    } else {
      statusColor = Colors.grey;
      statusText = 'EMPTY';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${widget.index + 1}.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.itemName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 0.7),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (widget.canDelete && widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.redAccent,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _smallField('Ope', _openCtrl, (v) => _updateRow(open: v)),
              _smallField('Rec', _recCtrl, (v) => _updateRow(received: v)),
              _smallField('Sale', _salesCtrl, (v) => _updateRow(sales: v)),
              _smallField(
                  'Short', _shortCtrl, (v) => _updateRow(shortOrWaste: v)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: ${_fmtOut(total)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Closing: ${_fmtOut(closing)}',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          closing < 0 ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(${numberToWords(closing.round())})',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white54),
                  ),
                  if (row.lastUpdatedAt != null &&
                      row.lastUpdatedBy != null)
                    Text(
                      'By ${row.lastUpdatedBy} @ '
                      '${DateFormat('HH:mm').format(row.lastUpdatedAt!)}',
                      style: const TextStyle(
                          fontSize: 8, color: Colors.white38),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallField(
    String label,
    TextEditingController controller,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white54,
            ),
          ),
          SizedBox(
            height: 30,
            child: TextField(
              controller: controller,
              readOnly: !widget.canEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,3}'),
                ),
              ],
              style:
                  const TextStyle(fontSize: 11, color: Colors.white),
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
          ),
        ],
      ),
    );
  }

  void _updateRow({
    double? open,
    double? received,
    double? sales,
    double? shortOrWaste,
  }) {
    if (widget.onChanged == null) return;

    final updated = widget.row.copyWith(
      open: open ?? widget.row.open,
      received: received ?? widget.row.received,
      sales: sales ?? widget.row.sales,
      shortOrWaste: shortOrWaste ?? widget.row.shortOrWaste,
      lastUpdatedBy: userRoleShort(widget.currentRole),
      lastUpdatedAt: DateTime.now(),
    );

    widget.onChanged!(updated);
  }

  String _fmtOut(double v) {
    if (v == 0) return '0';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
