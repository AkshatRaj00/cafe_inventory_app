import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/user_role.dart';
import '../../../core/models/daily_report_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase/kitchen_supabase_service.dart';
import '../../../core/services/supabase/beverage_supabase_service.dart';
import '../../../core/services/supabase/vendor_supabase_service.dart';
import '../../../core/services/supabase/daily_report_supabase_service.dart';


// =================== ENUMS & MODELS ===================

enum _DailyTab { overview, kitchen, beverage, vendor, analytics }

// =================== MAIN SCREEN ===================

class DailyReportScreen extends StatefulWidget {
  final UserRole? role;

  const DailyReportScreen({super.key, this.role});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  DailyReport? _report;
  DailyReport? _previousReport;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  bool _autoFillEnabled = true;

  _DailyTab _currentTab = _DailyTab.overview;

  late Box _reportsBox;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;


  // Controllers - Sales
  final _totalSalesCtrl = TextEditingController();
  final _cashSalesCtrl = TextEditingController();
  final _cardSalesCtrl = TextEditingController();
  final _upiSalesCtrl = TextEditingController();
  final _discountsCtrl = TextEditingController();
  final _coversCtrl = TextEditingController();

  // Controllers - Kitchen
  final _kitchenClosingCtrl = TextEditingController();
  final _kitchenWasteCtrl = TextEditingController();
  final _criticalItemsCtrl = TextEditingController();

  // Controllers - Beverage
  final _beverageClosingCtrl = TextEditingController();
  final _beverageWasteCtrl = TextEditingController();

  // Controllers - Vendor
  final _vendorPurchaseCtrl = TextEditingController();
  final _vendorDueCtrl = TextEditingController();

  // Controllers - Operations
  final _staffCountCtrl = TextEditingController();
  final _issuesCtrl = TextEditingController();
  final _actionsCtrl = TextEditingController();

  bool get _isAdmin => widget.role == UserRole.admin;
  bool get _isManager => widget.role == UserRole.manager;
  bool get _isChef => widget.role == UserRole.chef;

  bool get _canEdit {
    if (_isChef) return false;
    if (_report?.isLocked == true && !_isAdmin) return false;
    return true;
  }

  String get _dateLabel => DateFormat('dd MMM yyyy, EEE').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initHive();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _initHive() async {
    _reportsBox = await Hive.openBox('daily_reports');
    await _loadReport();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _totalSalesCtrl.dispose();
    _cashSalesCtrl.dispose();
    _cardSalesCtrl.dispose();
    _upiSalesCtrl.dispose();
    _discountsCtrl.dispose();
    _coversCtrl.dispose();
    _kitchenClosingCtrl.dispose();
    _kitchenWasteCtrl.dispose();
    _criticalItemsCtrl.dispose();
    _beverageClosingCtrl.dispose();
    _beverageWasteCtrl.dispose();
    _vendorPurchaseCtrl.dispose();
    _vendorDueCtrl.dispose();
    _staffCountCtrl.dispose();
    _issuesCtrl.dispose();
    _actionsCtrl.dispose();
    super.dispose();
  }

  // =================== PARSING HELPERS ===================

  double _parseDouble(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '')) ?? 0;
  }

  int _parseInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? 0;
  }

  String _fmtDouble(double v) => v == 0
      ? ''
      : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2));

  String _fmtInt(int v) => v == 0 ? '' : v.toString();

  // =================== DATA OPERATIONS ===================

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final saved = _reportsBox.get(key);

      DailyReport report;
      if (saved != null && saved is Map) {
        report = DailyReport.fromMap(Map<String, dynamic>.from(saved));
      } else {
        report = DailyReport(
          date: _selectedDate,
          createdByRole: widget.role,
        );
      }

      // Load previous day for comparison
      final prevDate = _selectedDate.subtract(const Duration(days: 1));
      final prevKey = DateFormat('yyyy-MM-dd').format(prevDate);
      final prevSaved = _reportsBox.get(prevKey);
      if (prevSaved != null && prevSaved is Map) {
        _previousReport =
            DailyReport.fromMap(Map<String, dynamic>.from(prevSaved));
      }

      _report = report;
      _populateControllers(report);
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _hasUnsavedChanges = false;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _populateControllers(DailyReport report) {
    _totalSalesCtrl.text = _fmtDouble(report.totalSales);
    _cashSalesCtrl.text = _fmtDouble(report.cashSales);
    _cardSalesCtrl.text = _fmtDouble(report.cardSales);
    _upiSalesCtrl.text = _fmtDouble(report.upiSales);
    _discountsCtrl.text = _fmtDouble(report.discounts);
    _coversCtrl.text = _fmtInt(report.covers);

    _kitchenClosingCtrl.text = _fmtDouble(report.kitchenClosingValue);
    _kitchenWasteCtrl.text = _fmtDouble(report.kitchenWasteValue);
    _criticalItemsCtrl.text = report.criticalItemsText;

    _beverageClosingCtrl.text = _fmtDouble(report.beverageClosingValue);
    _beverageWasteCtrl.text = _fmtDouble(0);

    _vendorPurchaseCtrl.text = _fmtDouble(report.vendorPurchaseTotal);
    _vendorDueCtrl.text = _fmtDouble(report.vendorDueAdded);

    _staffCountCtrl.text = _fmtInt(report.staffCount);
    _issuesCtrl.text = report.issues;
    _actionsCtrl.text = report.actions;
  }

  DailyReport _buildReportFromFields({bool keepLock = true}) {
    final base =
        _report ?? DailyReport(date: _selectedDate, createdByRole: widget.role);

    return base.copyWith(
      date: _selectedDate,
      totalSales: _parseDouble(_totalSalesCtrl.text),
      cashSales: _parseDouble(_cashSalesCtrl.text),
      cardSales: _parseDouble(_cardSalesCtrl.text),
      upiSales: _parseDouble(_upiSalesCtrl.text),
      discounts: _parseDouble(_discountsCtrl.text),
      covers: _parseInt(_coversCtrl.text),
      kitchenClosingValue: _parseDouble(_kitchenClosingCtrl.text),
      kitchenWasteValue: _parseDouble(_kitchenWasteCtrl.text),
      criticalItemsText: _criticalItemsCtrl.text.trim(),
      beverageClosingValue: _parseDouble(_beverageClosingCtrl.text),
      vendorPurchaseTotal: _parseDouble(_vendorPurchaseCtrl.text),
      vendorDueAdded: _parseDouble(_vendorDueCtrl.text),
      staffCount: _parseInt(_staffCountCtrl.text),
      issues: _issuesCtrl.text.trim(),
      actions: _actionsCtrl.text.trim(),
      isLocked: keepLock ? base.isLocked : false,
      createdByRole: base.createdByRole ?? widget.role,
    );
  }

  Future<void> _saveReport() async {
    if (!_canEdit) return;

    final report = _buildReportFromFields();
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await _reportsBox.put(key, report.toMap());

    setState(() {
      _report = report;
      _hasUnsavedChanges = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Daily report saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleLock() async {
    if (!_isAdmin || _report == null) return;

    final locked = !(_report!.isLocked);
    final updated = _report!.copyWith(
      isLocked: locked,
      lockedByRole: locked ? widget.role : null,
    );

    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await _reportsBox.put(key, updated.toMap());

    setState(() => _report = updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(locked ? 'Report locked 🔒' : 'Report unlocked 🔓'),
        backgroundColor: locked ? Colors.red.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_hasUnsavedChanges) {
      final cont = await _showUnsavedDialog();
      if (cont != true) return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF1E2030),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadReport();
    }
  }

  Future<bool?> _showUnsavedDialog() {
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
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

  Future<void> _exportReport() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.file_download_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Excel export feature coming soon! 📊'),
          ],
        ),
        backgroundColor: Colors.amber.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _markAsChanged() {
    if (_canEdit && !_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  // =================== UI BUILD ===================

  @override
  Widget build(BuildContext context) {
    final isLocked = _report?.isLocked == true;

    return Scaffold(
      backgroundColor: const Color(0xFF080910),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F111A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () async {
            if (_hasUnsavedChanges) {
              final cont = await _showUnsavedDialog();
              if (cont == true) Navigator.pop(context);
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
                const Icon(Icons.analytics_outlined,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Daily Report',
                  style: TextStyle(
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
          if (isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.lock_rounded, color: Colors.redAccent, size: 20),
            ),
          IconButton(
            tooltip: 'Export to Excel',
            icon: const Icon(Icons.file_download_outlined, color: Colors.amber),
            onPressed: _exportReport,
          ),
          if (_hasUnsavedChanges && _canEdit)
            IconButton(
              tooltip: 'Save Report',
              icon:
                  const Icon(Icons.save_rounded, color: Colors.greenAccent),
              onPressed: _saveReport,
            ),
          if (_isAdmin && _report != null)
            IconButton(
              tooltip: isLocked ? 'Unlock Report' : 'Lock Report',
              icon: Icon(
                isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: isLocked ? Colors.orangeAccent : Colors.white70,
              ),
              onPressed: _toggleLock,
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF1E2030),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(
                      _autoFillEnabled
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_rounded,
                      color: _autoFillEnabled ? Colors.greenAccent : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Auto-fill Data',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                onTap: () {
                  setState(() => _autoFillEnabled = !_autoFillEnabled);
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: const [
                    Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Reload Data', style: TextStyle(color: Colors.white)),
                  ],
                ),
                onTap: () {
                  Future.delayed(Duration.zero, _loadReport);
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber))
          : _buildBody(),
      floatingActionButton: _hasUnsavedChanges && _canEdit
          ? FloatingActionButton.extended(
              onPressed: _saveReport,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Report',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildHeader(),
          ),
        ),
        _buildTabSelector(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  if (_currentTab == _DailyTab.overview) ...[
                    _sectionCard(
                      title: 'Sales Overview',
                      icon: Icons.point_of_sale_rounded,
                      child: _salesSection(),
                    ),
                    _sectionCard(
                      title: 'Operations & Notes',
                      icon: Icons.description_outlined,
                      child: _operationsSection(),
                    ),
                  ] else if (_currentTab == _DailyTab.kitchen) ...[
                    _sectionCard(
                      title: 'Kitchen Summary',
                      icon: Icons.kitchen_rounded,
                      child: _kitchenSection(),
                    ),
                  ] else if (_currentTab == _DailyTab.beverage) ...[
                    _sectionCard(
                      title: 'Beverage Summary',
                      icon: Icons.local_drink_rounded,
                      child: _beverageSection(),
                    ),
                  ] else if (_currentTab == _DailyTab.vendor) ...[
                    _sectionCard(
                      title: 'Vendor Summary',
                      icon: Icons.store_rounded,
                      child: _vendorSection(),
                    ),
                  ] else if (_currentTab == _DailyTab.analytics) ...[
                    _buildAnalyticsSection(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final report = _report;
    if (report == null) return const SizedBox.shrink();

    final netSales = report.totalSales - report.discounts;
    final avgPerCover = report.covers > 0 ? netSales / report.covers : 0;

    double growthPercent = 0;
    if (_previousReport != null && _previousReport!.totalSales > 0) {
      growthPercent =
          ((report.totalSales - _previousReport!.totalSales) /
                  _previousReport!.totalSales) *
              100;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800, Colors.orange.shade700],
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
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, color: Colors.white70, size: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Net Sales',
                '₹${netSales.toStringAsFixed(0)}',
                Icons.currency_rupee_rounded,
                growthPercent,
              ),
              _buildStatCard(
                'Covers',
                report.covers.toString(),
                Icons.people_rounded,
                null,
              ),
              _buildStatCard(
                'Avg/Cover',
                '₹${avgPerCover.toStringAsFixed(0)}',
                Icons.trending_up_rounded,
                null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, double? growth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (growth != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: growth >= 0
                    ? Colors.greenAccent.withOpacity(0.2)
                    : Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    growth >= 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 10,
                    color: growth >= 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${growth.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color:
                          growth >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    Widget buildTab(_DailyTab tab, IconData icon, String label) {
      final selected = _currentTab == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _currentTab = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [Colors.amber.shade700, Colors.orange.shade600],
                    )
                  : null,
              color: selected ? null : const Color(0xFF151826),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.amber : Colors.white12,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.white70,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          buildTab(_DailyTab.overview, Icons.dashboard_rounded, 'Overview'),
          buildTab(_DailyTab.kitchen, Icons.kitchen_rounded, 'Kitchen'),
          buildTab(_DailyTab.beverage, Icons.local_drink_rounded, 'Beverage'),
          buildTab(_DailyTab.vendor, Icons.store_rounded, 'Vendor'),
          buildTab(_DailyTab.analytics, Icons.analytics_rounded, 'Analytics'),
        ],
      ),
    );
  }

  // =================== SECTION WIDGETS ===================

  Widget _salesSection() {
    return Column(
      children: [
        _numberFieldRow(
          label: 'Total Sales',
          controller: _totalSalesCtrl,
          enabled: _canEdit,
          icon: Icons.currency_rupee_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _numberFieldRow(
                label: 'Cash',
                controller: _cashSalesCtrl,
                enabled: _canEdit,
                icon: Icons.money_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberFieldRow(
                label: 'Card',
                controller: _cardSalesCtrl,
                enabled: _canEdit,
                icon: Icons.credit_card_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _numberFieldRow(
                label: 'UPI',
                controller: _upiSalesCtrl,
                enabled: _canEdit,
                icon: Icons.qr_code_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberFieldRow(
                label: 'Discounts',
                controller: _discountsCtrl,
                enabled: _canEdit,
                icon: Icons.discount_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _numberFieldRow(
          label: 'Covers (Guests)',
          controller: _coversCtrl,
          enabled: _canEdit,
          isInt: true,
          icon: Icons.people_rounded,
        ),
        const SizedBox(height: 16),
        _buildSalesBreakdown(),
      ],
    );
  }

  Widget _buildSalesBreakdown() {
    final cash = _parseDouble(_cashSalesCtrl.text);
    final card = _parseDouble(_cardSalesCtrl.text);
    final upi = _parseDouble(_upiSalesCtrl.text);
    final total = cash + card + upi;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Breakdown',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          _buildBreakdownBar('Cash', cash, total, Colors.greenAccent),
          const SizedBox(height: 6),
          _buildBreakdownBar('Card', card, total, Colors.blueAccent),
          const SizedBox(height: 6),
          _buildBreakdownBar('UPI', upi, total, Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(
      String label, double value, double total, Color color) {
    final percent = total > 0 ? (value / total * 100) : 0;
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent / 100,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            '${percent.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kitchenSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _numberFieldRow(
                label: 'Closing Value',
                controller: _kitchenClosingCtrl,
                enabled: _canEdit,
                icon: Icons.inventory_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberFieldRow(
                label: 'Waste Value',
                controller: _kitchenWasteCtrl,
                enabled: _canEdit,
                icon: Icons.delete_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textFieldRow(
          label: 'Critical Items (LOW / OUT)',
          controller: _criticalItemsCtrl,
          enabled: _canEdit,
          maxLines: 3,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 16),
        _buildWastePercentage(),
      ],
    );
  }

  Widget _buildWastePercentage() {
    final closing = _parseDouble(_kitchenClosingCtrl.text);
    final waste = _parseDouble(_kitchenWasteCtrl.text);
    
    if (closing == 0) return const SizedBox.shrink();

    final wastePercent = (waste / closing * 100);
    Color indicatorColor;
    String status;

    if (wastePercent < 3) {
      indicatorColor = Colors.greenAccent;
      status = 'EXCELLENT';
    } else if (wastePercent < 5) {
      indicatorColor = Colors.amber;
      status = 'GOOD';
    } else if (wastePercent < 8) {
      indicatorColor = Colors.orangeAccent;
      status = 'WARNING';
    } else {
      indicatorColor = Colors.redAccent;
      status = 'CRITICAL';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.pie_chart_rounded, color: indicatorColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waste Percentage',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${wastePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: indicatorColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: indicatorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: indicatorColor.withOpacity(0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: indicatorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _beverageSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _numberFieldRow(
                label: 'Closing Value',
                controller: _beverageClosingCtrl,
                enabled: _canEdit,
                icon: Icons.local_bar_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberFieldRow(
                label: 'Waste Value',
                controller: _beverageWasteCtrl,
                enabled: _canEdit,
                icon: Icons.delete_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vendorSection() {
    return Column(
      children: [
        _numberFieldRow(
          label: 'Purchase Total',
          controller: _vendorPurchaseCtrl,
          enabled: _canEdit,
          icon: Icons.shopping_cart_rounded,
        ),
        const SizedBox(height: 12),
        _numberFieldRow(
          label: 'Due Added Today',
          controller: _vendorDueCtrl,
          enabled: _canEdit,
          icon: Icons.receipt_long_rounded,
        ),
      ],
    );
  }

  Widget _operationsSection() {
    return Column(
      children: [
        _numberFieldRow(
          label: 'Staff Count',
          controller: _staffCountCtrl,
          enabled: _canEdit,
          isInt: true,
          icon: Icons.people_outline_rounded,
        ),
        const SizedBox(height: 12),
        _textFieldRow(
          label: 'Issues / Complaints',
          controller: _issuesCtrl,
          enabled: _canEdit,
          maxLines: 3,
          icon: Icons.report_problem_outlined,
        ),
        const SizedBox(height: 12),
        _textFieldRow(
          label: 'Actions for Next Day',
          controller: _actionsCtrl,
          enabled: _canEdit,
          maxLines: 3,
          icon: Icons.checklist_rounded,
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return Column(
      children: [
        _sectionCard(
          title: 'Quick Insights',
          icon: Icons.insights_rounded,
          child: _buildQuickInsights(report),
        ),
        _sectionCard(
          title: 'Day Comparison',
          icon: Icons.compare_arrows_rounded,
          child: _buildDayComparison(),
        ),
      ],
    );
  }

  Widget _buildQuickInsights(DailyReport report) {
    final netSales = report.totalSales - report.discounts;
    final avgPerCover = report.covers > 0 ? netSales / report.covers : 0;
    final kitchenWastePercent = report.kitchenClosingValue > 0
        ? (report.kitchenWasteValue / report.kitchenClosingValue * 100)
        : 0;

    return Column(
      children: [
        _insightRow(
          'Average per Cover',
          '₹${avgPerCover.toStringAsFixed(0)}',
          avgPerCover > 500 ? Colors.greenAccent : Colors.orangeAccent,
          avgPerCover > 500 ? 'Strong' : 'Needs Improvement',
        ),
        const Divider(color: Colors.white12, height: 20),
        _insightRow(
          'Kitchen Waste %',
          '${kitchenWastePercent.toStringAsFixed(2)}%',
          kitchenWastePercent < 5 ? Colors.greenAccent : Colors.redAccent,
          kitchenWastePercent < 5 ? 'Under Control' : 'High Waste',
        ),
        const Divider(color: Colors.white12, height: 20),
        _insightRow(
          'Staff Efficiency',
          report.staffCount > 0
              ? '₹${(netSales / report.staffCount).toStringAsFixed(0)}/person'
              : 'N/A',
          Colors.blueAccent,
          'Sales per Staff',
        ),
      ],
    );
  }

  Widget _insightRow(
      String label, String value, Color color, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(Icons.trending_up_rounded, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayComparison() {
    if (_previousReport == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No previous day data available',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    final current = _report!;
    final previous = _previousReport!;

    return Column(
      children: [
        _comparisonRow(
          'Total Sales',
          current.totalSales,
          previous.totalSales,
        ),
        const Divider(color: Colors.white12, height: 16),
        _comparisonRow(
          'Covers',
          current.covers.toDouble(),
          previous.covers.toDouble(),
        ),
        const Divider(color: Colors.white12, height: 16),
        _comparisonRow(
          'Kitchen Closing',
          current.kitchenClosingValue,
          previous.kitchenClosingValue,
        ),
      ],
    );
  }

  Widget _comparisonRow(String label, double currentValue, double prevValue) {
    final diff = currentValue - prevValue;
    final percent = prevValue > 0 ? (diff / prevValue * 100) : 0;
    final isPositive = diff >= 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${currentValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'vs ₹${prevValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPositive
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.redAccent.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color:
                          isPositive ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percent.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color:
                            isPositive ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =================== SHARED UI HELPERS ===================

  Widget _sectionCard({
    required String title,
    required Widget child,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF151826),
            const Color(0xFF1A1F2E),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _numberFieldRow({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool isInt = false,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !isInt,
            signed: false,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFF0F111A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.amber, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10, width: 1),
            ),
            hintText: '0',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
          onChanged: enabled ? (_) => _markAsChanged() : null,
        ),
      ],
    );
  }

  Widget _textFieldRow({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    int maxLines = 2,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFF0F111A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.amber, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10, width: 1),
            ),
            hintText: 'Enter details...',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
          onChanged: enabled ? (_) => _markAsChanged() : null,
        ),
      ],
    );
  }
}