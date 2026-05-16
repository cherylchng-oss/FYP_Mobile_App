import 'package:flutter/material.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import 'moderator_notification.dart';

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
  int _unreadCount = 0;

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
    _loadUnreadCount();
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

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadCount = notifications.where((n) => !(n['isRead'] ?? false)).length;
      });
    } catch (_) {}
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

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/ledger.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3D1E0C).withOpacity(0.62),
                    const Color(0xFF8B4A2F).withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 24, 20, 36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ledger',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 24, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Track income, commission,\nand payment records.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ModeratorNotifications()),
                  ).then((_) => _loadUnreadCount()),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 15),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Color(0xFFE0A43A), shape: BoxShape.circle),
                            child: Text('$_unreadCount',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: AdminColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: Icon(icon, size: 68, color: color.withOpacity(0.07)),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: AppTextStyles.caption.copyWith(
                        color: AdminColors.textMuted, fontWeight: FontWeight.w500, fontSize: 11)),
                const SizedBox(height: 2),
                _isLoading
                    ? Container(
                        height: 20, width: 60,
                        decoration: BoxDecoration(
                          color: AdminColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyDefault.copyWith(
                            color: AdminColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final totalTransactions = _safeText(_summary['total_transactions'], fallback: _ledgerRows.length.toString());
    final totalCredit = _money(_summary['total_credit']);
    final totalDebit = _money(_summary['total_debit']);
    final totalExpected = _money(_summary['total_expected']);
    final totalCommission = _money(_summary['total_commission']);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _buildSummaryCard(title: 'Transactions', value: totalTransactions, icon: Icons.receipt_long,    color: AdminColors.primaryLight),
        _buildSummaryCard(title: 'Credit',       value: totalCredit,       icon: Icons.trending_up,     color: AdminColors.success),
        _buildSummaryCard(title: 'Debit',        value: totalDebit,        icon: Icons.trending_down,   color: AdminColors.danger),
        _buildSummaryCard(title: 'Expected',     value: totalExpected,     icon: Icons.pending_actions, color: AdminColors.accent),
        _buildSummaryCard(title: 'Commission',   value: totalCommission,   icon: Icons.percent,         color: AdminColors.accentLight),
        _buildSummaryCard(title: 'Records',      value: _ledgerRows.length.toString(), icon: Icons.list_alt, color: AdminColors.textMuted),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
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
            child: Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.caption.copyWith(
                    color: AdminColors.textPrimary, fontWeight: FontWeight.w700)),
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
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AdminColors.accent, size: 20),
          ),
          title: Text(propertyName,
              style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
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
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date',
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
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
                    style: AppTextStyles.bodySmall.copyWith(
                        color: _selectedDate.isNotEmpty ? AdminColors.textPrimary : AdminColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Status',
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
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
          Text('Sort By',
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
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
          Text('Search',
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _searchController,
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search property, customer, operator...',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 18),
              filled: true,
              fillColor: AdminColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('Clear Filters',
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
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
        style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600, color: AdminColors.textPrimary),
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
              style: AppTextStyles.label.copyWith(
                  color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
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
                  child: Text('← Previous',
                      style: AppTextStyles.label.copyWith(
                          color: AdminColors.textSecond, fontWeight: FontWeight.w700)),
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
                  child: Text('Next →',
                      style: AppTextStyles.label.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary',
                style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Financial overview of all ledger activity.',
                style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
            const SizedBox(height: 14),
            _buildSummaryGrid(),
            const SizedBox(height: 20),
            Text('Filters',
                style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
            const SizedBox(height: 10),
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
                  color: AdminColors.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.danger.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AdminColors.danger),
                    const SizedBox(height: 12),
                    Text('Unable to load ledger',
                        style: AppTextStyles.h4.copyWith(color: AdminColors.danger)),
                    const SizedBox(height: 4),
                    Text(_errorMsg, textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AdminColors.danger)),
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
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 56, color: AdminColors.border),
                    const SizedBox(height: 12),
                    Text('No ledger entries found',
                        style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Try clearing the filters or choosing another date/status.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
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
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
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
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
