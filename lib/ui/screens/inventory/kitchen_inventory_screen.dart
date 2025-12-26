import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/user_role.dart'; // global UserRole yahi se

// Local helper: short code for role (ADM/MGR/CHF)
String? userRoleShort(UserRole? role) {
  if (role == null) return null;
  switch (role) {
    case UserRole.admin:
      return 'ADM';
    case UserRole.manager:
      return 'MGR';
    case UserRole.chef:
      return 'CHF';
  }
}

// Number to words helper (Indian system)
String numberToWords(int number) {
  if (number == 0) return 'Zero';
  if (number < 0) return 'Minus ${numberToWords(number.abs())}';

  const ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine'
  ];
  const teens = [
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen'
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety'
  ];

  String helper(int n) {
    if (n == 0) return '';
    if (n < 10) return ones[n];
    if (n < 20) return teens[n - 10];
    if (n < 100) return '${tens[n ~/ 10]} ${ones[n % 10]}'.trim();
    if (n < 1000) {
      return '${ones[n ~/ 100]} Hundred ${helper(n % 100)}'.trim();
    }
    if (n < 100000) {
      return '${helper(n ~/ 1000)} Thousand ${helper(n % 1000)}'.trim();
    }
    if (n < 10000000) {
      return '${helper(n ~/ 100000)} Lakh ${helper(n % 100000)}'.trim();
    }
    return '${helper(n ~/ 10000000)} Crore ${helper(n % 10000000)}'.trim();
  }

  return helper(number);
}

class KitchenInventoryScreen extends StatefulWidget {
  final UserRole? role;
  const KitchenInventoryScreen({super.key, this.role});

  @override
  State<KitchenInventoryScreen> createState() =>
      _KitchenInventoryScreenState();
}

class _KitchenInventoryScreenState extends State<KitchenInventoryScreen> {
  DateTime _selectedDate = DateTime.now();
  late Box _inventoryBox;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  final _searchCtrl = TextEditingController();
  List<InventoryRow> _rows = [];
  List<InventoryRow> _filteredRows = [];

  bool get _isToday =>
      DateUtils.isSameDay(_selectedDate, DateTime.now());
  bool get _isAdminOrManager =>
      widget.role == UserRole.admin || widget.role == UserRole.manager;

  bool get _canEdit {
    if (_isAdminOrManager) return true;
    if (widget.role == UserRole.chef && _isToday) return true;
    return false;
  }

  bool get _canAddDelete => _canEdit;

  final List<String> _itemNames = const [
    'Paneer',
    'Finger Chips',
    'Mozzarella Cheese',
    'Corn',
    'Amul Cheese',
    'Amul Butter',
    'Nut Butter',
    'Cream',
    'Milk',
    'Curd',
    'Matka Rabdi',
    'Chocolava',
    'Gulab Jamun',
    'Brownie',
    'Cheese Cake',
    'Oil',
    'Ghee',
    'Veg Momos',
    'Non Veg',
    'Fish',
    'Egg',
    'Mutton',
    'Non Veg Momos',
    'Chicken Big',
    'Chicken Small',
    'Chicken Boneless',
    'Chicken Tandoori',
    'Lolypop',
    'Curry',
    'Gas',
    'Coal',
    'Red Sauce',
    'White Sauce',
    'Tomato Gravy',
    'Onion Gravy',
    'Dal Makhani',
    'Chop Masala',
    'Kaju',
    'Kitchen King',
    'Chat Masala',
    'Chana Masala',
    'Kashmiri Chili Powder',
    'Chicken Masala',
    'Biryani Masala',
    'Peri Peri Powder',
    'Mayonnaise',
    'White Pepper',
    'Mushroom Tin',
    'P/A Slice Tin',
    'F/C Tin',
    'Baby Corn Tin',
    'Milk Maid Tin',
    'Biryani Rice',
    'Tikka Masala',
    'Biryani Rice Dam',
    'Chocolate Sauce',
    'Nirma',
    'Elaichi',
    'Dalda',
    'Mustard Oil',
    'Tomato Sauce',
    'Honey',
  ];

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchCtrl.addListener(_applySearch);
  }

  Future<void> _initHive() async {
    _inventoryBox = await Hive.openBox('kitchen_inventory');
    _loadData();
  }

  void _loadData() {
    final dateKey = _getDateKey(_selectedDate);
    final savedData = _inventoryBox.get(dateKey);

    if (savedData != null && savedData is List) {
      _rows = savedData
          .map(
            (item) => InventoryRow.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } else {
      _rows = _itemNames
          .map((name) => InventoryRow(itemName: name))
          .toList(growable: true);
    }

    for (final name in _itemNames) {
      if (!_rows.any((r) => r.itemName == name)) {
        _rows.add(InventoryRow(itemName: name));
      }
    }

    _rows.sort((a, b) =>
        a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
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
    await _inventoryBox.put(dateKey, dataToSave);

    setState(() => _hasUnsavedChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kitchen data saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
            'You have unsaved changes. Continue without saving?'),
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
        title: const Text('Add new item'),
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
                    InventoryRow(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white, fontSize: 12),
      child: WillPopScope(
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
                  'Kitchen Inventory (${widget.role?.label ?? 'Guest'})',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search kitchen item...',
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
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.white24),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Colors.amber, width: 1.5),
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
                              physics:
                                  const BouncingScrollPhysics(),
                              itemCount: _filteredRows.length,
                              itemBuilder: (context, index) {
                                final row = _filteredRows[index];
                                final originalIndex =
                                    _rows.indexOf(row);
                                return InventoryRowWidget(
                                  key: ValueKey(row.itemName +
                                      originalIndex.toString()),
                                  index: originalIndex,
                                  row: row,
                                  canEdit: _canEdit,
                                  canDelete: _canAddDelete,
                                  currentRole: widget.role,
                                  onChanged: (updated) {
                                    if (_canEdit) {
                                      setState(() {
                                        _rows[originalIndex] =
                                            updated;
                                        _applySearch();
                                        _hasUnsavedChanges = true;
                                      });
                                    }
                                  },
                                  onDelete: _canAddDelete
                                      ? () {
                                          setState(() {
                                            _rows.removeAt(
                                                originalIndex);
                                            _applySearch();
                                            _hasUnsavedChanges =
                                                true;
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
              'Ope / Rec / Sale / Waste',
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

class InventoryRow {
  final String itemName;
  final double open;
  final double received;
  final double sales;
  final double waste;
  final String? remarks;
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;

  InventoryRow({
    required this.itemName,
    this.open = 0,
    this.received = 0,
    this.sales = 0,
    this.waste = 0,
    this.remarks,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
  });

  double get total => open + received;
  double get closing => total - sales - waste;

  String get autoStatus {
    if (closing < 0) return 'NEGATIVE';
    if (closing == 0 && total > 0) return 'OUT';
    if (total > 0 && closing / total <= 0.2) return 'LOW';
    if (total > 0) return 'OK';
    return 'EMPTY';
  }

  Color get statusColor {
    switch (autoStatus) {
      case 'NEGATIVE':
        return Colors.redAccent;
      case 'OUT':
        return Colors.redAccent;
      case 'LOW':
        return Colors.orangeAccent;
      case 'OK':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  InventoryRow copyWith({
    double? open,
    double? received,
    double? sales,
    double? waste,
    String? remarks,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,
  }) {
    return InventoryRow(
      itemName: itemName,
      open: open ?? this.open,
      received: received ?? this.received,
      sales: sales ?? this.sales,
      waste: waste ?? this.waste,
      remarks: remarks ?? this.remarks,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'open': open,
        'received': received,
        'sales': sales,
        'waste': waste,
        'remarks': remarks,
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      };

  factory InventoryRow.fromMap(Map<String, dynamic> map) => InventoryRow(
        itemName: map['itemName'] ?? '',
        open: (map['open'] ?? 0).toDouble(),
        received: (map['received'] ?? 0).toDouble(),
        sales: (map['sales'] ?? 0).toDouble(),
        waste: (map['waste'] ?? 0).toDouble(),
        remarks: map['remarks'] as String?,
        lastUpdatedBy: map['lastUpdatedBy'] as String?,
        lastUpdatedAt: map['lastUpdatedAt'] != null
            ? DateTime.tryParse(map['lastUpdatedAt'])
            : null,
      );
}

/// ROW WIDGET

class InventoryRowWidget extends StatefulWidget {
  final int index;
  final InventoryRow row;
  final bool canEdit;
  final bool canDelete;
  final UserRole? currentRole;
  final ValueChanged<InventoryRow>? onChanged;
  final VoidCallback? onDelete;

  const InventoryRowWidget({
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
  State<InventoryRowWidget> createState() =>
      _InventoryRowWidgetState();
}

class _InventoryRowWidgetState extends State<InventoryRowWidget>
    with SingleTickerProviderStateMixin {
  late TextEditingController _openCtrl;
  late TextEditingController _recCtrl;
  late TextEditingController _salesCtrl;
  late TextEditingController _wasteCtrl;
  late TextEditingController _remarksCtrl;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _openCtrl =
        TextEditingController(text: _fmtIn(widget.row.open));
    _recCtrl =
        TextEditingController(text: _fmtIn(widget.row.received));
    _salesCtrl =
        TextEditingController(text: _fmtIn(widget.row.sales));
    _wasteCtrl =
        TextEditingController(text: _fmtIn(widget.row.waste));
    _remarksCtrl =
        TextEditingController(text: widget.row.remarks ?? '');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _recCtrl.dispose();
    _salesCtrl.dispose();
    _wasteCtrl.dispose();
    _remarksCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _fmtIn(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  double _parseNum(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(t);
    if (match == null) return 0;
    return double.tryParse(match.group(0)!) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final openVal = _parseNum(_openCtrl.text);
    final recVal = _parseNum(_recCtrl.text);
    final salesVal = _parseNum(_salesCtrl.text);
    final wasteVal = _parseNum(_wasteCtrl.text);
    final total = openVal + recVal;
    final closing = total - salesVal - wasteVal;

    final statusColor = widget.row.statusColor;
    final statusText = widget.row.autoStatus;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) => _animController.reverse(),
        onTapCancel: () => _animController.reverse(),
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      widget.row.itemName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColor, width: 0.8),
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
                  if (widget.canDelete &&
                      widget.onDelete != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18),
                      color: Colors.redAccent,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _smallField('Ope', _openCtrl),
                  _smallField('Rec', _recCtrl),
                  _smallField('Sale', _salesCtrl),
                  _smallField('Waste', _wasteCtrl),
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
                          color: closing < 0
                              ? Colors.redAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '(${numberToWords(closing.round())})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9, color: Colors.white54),
                      ),
                      if (widget.row.lastUpdatedAt != null &&
                          widget.row.lastUpdatedBy != null)
                        Text(
                          'By ${widget.row.lastUpdatedBy} @ '
                          '${DateFormat('HH:mm').format(widget.row.lastUpdatedAt!)}',
                          style: const TextStyle(
                              fontSize: 8, color: Colors.white38),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksCtrl,
                readOnly: !widget.canEdit,
                style: const TextStyle(
                    fontSize: 10, color: Colors.white70),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Remarks (Nil / Absent / Notes...)',
                  hintStyle: TextStyle(
                      fontSize: 10, color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(6)),
                    borderSide:
                        BorderSide(color: Colors.white24, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(6)),
                    borderSide:
                        BorderSide(color: Colors.amber, width: 1.2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                ),
                onChanged:
                    widget.canEdit ? (_) => _updateRow() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallField(
      String label, TextEditingController controller) {
    return SizedBox(
      width: 70,
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
            height: 32,
            child: TextField(
              controller: controller,
              readOnly: !widget.canEdit,
              keyboardType: TextInputType.text,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 6, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(6)),
                  borderSide:
                      BorderSide(color: Colors.white24, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(6)),
                  borderSide:
                      BorderSide(color: Colors.amber, width: 1.2),
                ),
              ),
              onChanged: widget.canEdit
                  ? (value) {
                      _updateRow();
                      setState(() {});
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _updateRow() {
    if (widget.onChanged == null) return;

    final updated = widget.row.copyWith(
      open: _parseNum(_openCtrl.text),
      received: _parseNum(_recCtrl.text),
      sales: _parseNum(_salesCtrl.text),
      waste: _parseNum(_wasteCtrl.text),
      remarks: _remarksCtrl.text.trim().isEmpty
          ? null
          : _remarksCtrl.text.trim(),
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
