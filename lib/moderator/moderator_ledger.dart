import 'package:flutter/material.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';

class ModeratorLedger extends StatefulWidget {
  const ModeratorLedger({super.key});

  @override
  State<ModeratorLedger> createState() => _ModeratorLedgerState();
}

class _ModeratorLedgerState extends State<ModeratorLedger> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMsg = '';

  List<Map<String, dynamic>> _ledgerRows = [];
  Map<String, dynamic> _summary = {};

  String _statusFilter = '';
  String _selectedDate = '';
  String _sortOrder = 'reservation_latest';
  int _page = 1;
  int _totalPages = 1;
  int _totalRecords = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchController.addListener(() {
      setState(() => _page = 1);
      _fetchLedger();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchLedger(), _fetchSummary()]);
  }

  Future<void> _fetchLedger() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final userid = await Session.getUserId();
      if (userid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final data = await api.fetchLedger(
        userid,
        page: _page,
        search: _searchController.text.trim(),
        status: _statusFilter,
        selectedDate: _selectedDate,
        sortOrder: _sortOrder,
      );
      if (mounted) {
        setState(() {
          _ledgerRows = List<Map<String, dynamic>>.from(data['ledger'] ?? []);
          final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
          _totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;
          _totalRecords = (pagination['total'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Failed to load ledger records.';
          _ledgerRows = [];
        });
      }
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final userid = await Session.getUserId();
      if (userid == null) return;
      final s = await api.fetchLedgerSummary(userid, selectedDate: _selectedDate);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      debugPrint('Error fetching ledger summary: $e');
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = '';
      _selectedDate = '';
      _sortOrder = 'reservation_latest';
      _page = 1;
    });
    _loadAll();
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false);
    else if (index == 1) Navigator.of(context).pushNamed('/manage-services');
    else if (index == 2) Navigator.of(context).pushNamed('/moderator-stock-manager');
    else if (index == 3) Navigator.of(context).pushNamed('/profile');
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Ledger': break;
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.moderator); break;
      case 'Properties':
      case 'PropertyListing': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager':
      case 'Reservation':
      case 'Bookings': Navigator.of(context).pushNamed('/moderator-stock-manager'); break;
      case 'Activity Logs': Navigator.of(context).pushNamed('/moderator-activity-logs'); break;
      case 'Customer Reviews': Navigator.of(context).pushNamed('/moderator-customer-reviews'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _money(dynamic value) => 'RM ${_toDouble(value).toStringAsFixed(2)}';

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('paid')) return AdminColors.success;
    if (lower.contains('partial')) return AdminColors.accent;
    if (lower.contains('cancel') || lower.contains('expired') || lower.contains('rejected')) return AdminColors.danger;
    if (lower.contains('reserved') || lower.contains('accepted')) return AdminColors.primaryLight;
    return AdminColors.textMuted;
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [BoxShadow(color: AdminColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            _isLoading
              ? Container(
                  height: 20,
                  width: 60,
                  decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  ),
              )
              : Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.textPrimary,
                  ),
              ),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSummary() {
    final totalTransactions = _safeText(_summary['total_transactions'], fallback: _ledgerRows.length.toString());
    final totalCredit = _money(_summary['total_credit']);
    final totalDebit = _money(_summary['total_debit']);
    final totalExpected = _money(_summary['total_expected']);
    final totalCommission = _money(_summary['total_commission']);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AdminColors.primary, borderRadius: BorderRadius.circular(24)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white70, size: 32),
              SizedBox(height: 12),
              Text('Ledger', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Track booking movement, stock status, commission, credit, debit, and expected amount.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _buildSummaryCard(title: 'Transactions', value: totalTransactions, icon: Icons.receipt_long, color: AdminColors.primaryLight),
          const SizedBox(width: 12),
          _buildSummaryCard(title: 'Credit', value: totalCredit, icon: Icons.trending_up, color: AdminColors.success),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _buildSummaryCard(title: 'Debit', value: totalDebit, icon: Icons.trending_down, color: AdminColors.danger),
          const SizedBox(width: 12),
          _buildSummaryCard(title: 'Expected', value: totalExpected, icon: Icons.pending_actions, color: AdminColors.accent),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _buildSummaryCard(title: 'Commission', value: totalCommission, icon: Icons.percent, color: AdminColors.accentLight),
          const SizedBox(width: 12),
          _buildSummaryCard(title: 'Records', value: _ledgerRows.length.toString(), icon: Icons.list_alt, color: AdminColors.textMuted),
        ]),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: const TextStyle(color: AdminColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerCard(Map<String, dynamic> item) {
    final propertyName = _safeText(item['propertyname'] ?? item['property_name'] ?? item['propertyaddress'], fallback: 'Unnamed Property');
    final roomType = _safeText(item['roomtype'] ?? item['room_type']);
    final activityType = _safeText(item['activity_type']);
    final bookingStatus = _safeText(item['booking_status']);
    final stockStatus = _safeText(item['stock_status']);
    final customerName = _safeText(item['customer_name']);
    final moderatorName = _safeText(item['moderator_username']);
    final reservationId = _safeText(item['reservationid']);
    final timestamp = _safeText(item['formatted_timestamp'] ?? item['timestamp']);
    final remarks = _safeText(item['remarks']);
    final bookingColor = _statusColor(bookingStatus);
    final stockColor = _statusColor(stockStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: AdminColors.accent.withValues(alpha: 0.14),
            child: const Icon(Icons.account_balance_wallet, color: AdminColors.accent),
          ),
          title: Text(propertyName,
              style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _buildChip(bookingStatus, bookingColor),
              _buildChip(stockStatus, stockColor),
            ]),
          ),
          children: [
            _buildInfoRow('Reservation ID', reservationId),
            _buildInfoRow('Room Type', roomType),
            _buildInfoRow('Activity', activityType),
            _buildInfoRow('Customer', customerName),
            _buildInfoRow('Operator', moderatorName),
            _buildInfoRow('Gross Amount', _money(item['gross_amount'])),
            _buildInfoRow('Commission Rate', '${(_toDouble(item['commission_rate']) * 100).toStringAsFixed(2)}%'),
            _buildInfoRow('Commission', _money(item['commission_amount'])),
            _buildInfoRow('Moderator Earn', _money(item['moderator_earning'])),
            _buildInfoRow('Credit', _money(item['credit'])),
            _buildInfoRow('Debit', _money(item['debit'])),
            _buildInfoRow('Expected', _money(item['expected_amount'])),
            _buildInfoRow('Remarks', remarks),
            _buildInfoRow('Timestamp', timestamp),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.textSecond)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate.isNotEmpty ? DateTime.tryParse(_selectedDate) ?? DateTime.now() : DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AdminColors.primary)),
                  child: child!,
                ),
              );
              if (picked != null) {
                final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                setState(() { _selectedDate = formatted; _page = 1; });
                _loadAll();
              }
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                border: Border.all(color: AdminColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AdminColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDate.isNotEmpty ? _selectedDate : 'Select date',
                    style: TextStyle(fontSize: 14, color: _selectedDate.isNotEmpty ? AdminColors.textPrimary : AdminColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.textSecond)),
          const SizedBox(height: 6),
          _filterDropdown<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: '', child: Text('All Status')),
              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
              DropdownMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
              DropdownMenuItem(value: 'Accepted', child: Text('Accepted')),
              DropdownMenuItem(value: 'Expired', child: Text('Expired')),
              DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) { setState(() { _statusFilter = v ?? ''; _page = 1; }); _loadAll(); },
          ),
          const SizedBox(height: 12),
          const Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.textSecond)),
          const SizedBox(height: 6),
          _filterDropdown<String>(
            value: _sortOrder,
            items: const [
              DropdownMenuItem(value: 'reservation_latest', child: Text('Latest Reservation')),
              DropdownMenuItem(value: 'reservation_oldest', child: Text('Oldest Reservation')),
            ],
            onChanged: (v) { setState(() { _sortOrder = v ?? 'reservation_latest'; _page = 1; }); _fetchLedger(); },
          ),
          const SizedBox(height: 12),
          const Text('Search', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.textSecond)),
          const SizedBox(height: 6),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search property, customer, operator...',
              hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 18),
              filled: true,
              fillColor: AdminColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(10),
        color: AdminColors.surface,
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AdminColors.cardBg,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminColors.textPrimary),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          Text('Page $_page of $_totalPages  •  $_totalRecords records',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _page > 1 ? () { setState(() => _page--); _fetchLedger(); } : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AdminColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('← Previous',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AdminColors.textSecond)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _page < _totalPages ? () { setState(() => _page++); _fetchLedger(); } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Next →', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AdminColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSummary(),
            const SizedBox(height: 16),
            _buildFilterCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AdminColors.primary),
                ),
              )
            else if (_errorMsg.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AdminColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AdminColors.danger),
                    const SizedBox(height: 12),
                    const Text('Unable to load ledger',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.danger)),
                    const SizedBox(height: 4),
                    Text(_errorMsg, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AdminColors.danger)),
                  ],
                ),
              )
            else if (_ledgerRows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AdminColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 56, color: AdminColors.border),
                    SizedBox(height: 12),
                    Text('No ledger entries found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Try clearing the filters or choosing another date/status.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                  ],
                ),
              )
            else
              Column(children: [..._ledgerRows.map(_buildLedgerCard), _buildPagination()]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      appBar: AppBar(
        title: const Text('Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Ledger',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
      body: _buildBody(),
    );
  }
}
