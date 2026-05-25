import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import 'admin_notification.dart';

class AdminBooknPayLog extends StatefulWidget {
  const AdminBooknPayLog({super.key});

  @override
  State<AdminBooknPayLog> createState() => _AdminBooknPayLogState();
}

class _AdminBooknPayLogState extends State<AdminBooknPayLog> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  String _selectedActionType = 'All Actions';
  bool _isLoading = true;
  int _unreadCount = 0;

  List<Map<String, dynamic>> allLogs = [];

  List<Map<String, dynamic>> get filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    return allLogs.where((log) {
      final byType = _selectedActionType == 'All Actions' ||
          log['actionType'] == _selectedActionType;
      if (!byType) return false;
      if (query.isEmpty) return true;
      final text = [
        log['timestamp'],
        log['action'],
        log['actionedBy'],
        log['userId'].toString(),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _searchController.addListener(() => setState(() {}));
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userid = await Session.getUserId();
      final usergroup = await Session.getUserGroup() ?? '';
      if (userid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final logsData = await api.fetchBookAndPayLogs(userid, usergroup);
      if (mounted) {
        setState(() {
          allLogs.clear();
          for (var log in logsData) {
            final actionType = _mapActionType(log['action'] ?? '');
            if (actionType == 'Other') continue;
            allLogs.add({
              'userId': log['userid'] ?? 0,
              'timestamp': log['timestamp'] ?? '',
              'action': log['action'] ?? '',
              'actionedBy': log['username'] ?? 'Unknown',
              'actionType': actionType,
            });
          }
          allLogs = allLogs.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load book and pay logs.', style: TextStyle(color: Colors.white)),
            backgroundColor: AdminColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _mapActionType(dynamic actionType) {
    if (actionType == null) return 'Other';
    final text = actionType.toString().toLowerCase();
    if (text.contains('expired') || text.contains('booking expired') ||
        text.contains('payment expired') || text.contains('reservation expired') ||
        text.contains('time expired') || text.contains('status changed to expired')) {
      return 'Expired';
    }
    if (text.contains('paid deposit') || text.contains('deposit paid') ||
        text.contains('deposit payment') || text.contains('pay deposit') ||
        text.contains('downpayment') || text.contains('down payment') ||
        text.contains('partially paid') || text.contains('partial payment') ||
        text.contains('deposit')) {
      return 'Deposit';
    }
    if (text.contains('balance payment') || text.contains('balance paid') ||
        text.contains('pay balance') || text.contains('paid balance') ||
        text.contains('remaining balance') || text.contains('balance due') ||
        text.contains('settle balance') || text.contains('balance removed') ||
        text.contains('completed balance') || text.contains('balance')) {
      return 'Balance';
    }
    if (text.contains('instant full payment') || text.contains('full payment') ||
        text.contains('fully paid') || text.contains('paid in full') ||
        text.contains('payment received') || text.contains('status changed to paid') ||
        text.contains('booking status changed to paid') ||
        text.contains('reservation status changed to paid')) {
      return 'Full Payment';
    }
    if (text.contains('cancel') || text.contains('cancelled') ||
        text.contains('canceled') || text.contains('rejected') ||
        text.contains('restock') || text.contains('restocked') ||
        text.contains('removed reservation') || text.contains('remove reservation')) {
      return 'Cancel';
    }
    return 'Other';
  }

  Color _actionTypeColor(String type) {
    switch (type) {
      case 'Full Payment': return AdminColors.success;
      case 'Deposit': return AdminColors.accent;
      case 'Balance': return AdminColors.primaryLight;
      case 'Cancel': return AdminColors.danger;
      case 'Expired': return AdminColors.textMuted;
      default: return AdminColors.textMuted;
    }
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    else if (index == 1) Navigator.of(context).pushNamed('/manage-services');
    else if (index == 2) Navigator.of(context).pushNamed('/admin-stock-manager');
    else if (index == 3) Navigator.of(context).pushNamed('/profile');
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'BooknPayLog': break;
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.admin); break;
      case 'Properties':
      case 'PropertyListing': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager':
      case 'Reservation':
      case 'Bookings': Navigator.of(context).pushNamed('/admin-stock-manager'); break;
      case 'Activity Logs': Navigator.of(context).pushNamed('/admin-activity-logs'); break;
      case 'Ledger': Navigator.of(context).pushNamed('/admin-ledger'); break;
      case 'Customer Review': Navigator.of(context).pushNamed('/admin-customer-reviews'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final logs = filteredLogs;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'BooknPayLog',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.admin,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AdminColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildFilterCard(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Records', style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                        Text('${logs.length} found',
                            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: CircularProgressIndicator(color: AdminColors.primary),
                        ),
                      )
                    else
                      _buildLogList(logs),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/book_and_pay.png', fit: BoxFit.cover),
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
                  child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Book & Pay Log',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 24, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor booking and payment\nactivities across the system.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AdminNotifications()),
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

  // ── Search ───────────────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: AdminColors.primary,
      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search logs...',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
        filled: true,
        fillColor: AdminColors.cardBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ── Filter ───────────────────────────────────────────────────────────────────
  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by Action Type',
              style: AppTextStyles.caption.copyWith(color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AdminColors.surface,
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _selectedActionType,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AdminColors.cardBg,
              icon: const Icon(Icons.keyboard_arrow_down, color: AdminColors.textMuted),
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
              items: const ['All Actions', 'Deposit', 'Balance', 'Full Payment', 'Cancel', 'Expired']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedActionType = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Log List ─────────────────────────────────────────────────────────────────
  Widget _buildLogList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          const Icon(Icons.search_off, size: 56, color: AdminColors.border),
          const SizedBox(height: 14),
          Text('No records found',
              style: AppTextStyles.h4.copyWith(color: AdminColors.textSecond)),
          const SizedBox(height: 6),
          Text('Try changing the filter or search keyword.',
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildLogCard(logs[index]),
    );
  }

  // ── Log Card ─────────────────────────────────────────────────────────────────
  Widget _buildLogCard(Map<String, dynamic> log) {
    final typeColor = _actionTypeColor(log['actionType'] ?? '');
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_outlined, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['actionedBy'] ?? '',
                    style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                const SizedBox(height: 3),
                Text(log['action'] ?? '',
                    style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textSecond)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.access_time, size: 12, color: AdminColors.textMuted),
                  const SizedBox(width: 4),
                  Text(log['timestamp'] ?? '',
                      style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(log['actionType'] ?? '',
                    style: AppTextStyles.caption.copyWith(
                        color: typeColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              PopupMenuButton<String>(
                color: AdminColors.cardBg,
                icon: const Icon(Icons.more_horiz, color: AdminColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'view') _showLogDetailsDialog(log);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(children: [
                      const Icon(Icons.visibility, size: 18, color: AdminColors.textMuted),
                      const SizedBox(width: 8),
                      Text('View Details',
                          style: AppTextStyles.label.copyWith(color: AdminColors.textPrimary)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Details Dialog ───────────────────────────────────────────────────────────
  void _showLogDetailsDialog(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AdminColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log Details',
                      style: AppTextStyles.h3.copyWith(color: AdminColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: AdminColors.border),
              const SizedBox(height: 8),
              _buildDetailField('User ID', log['userId'].toString()),
              _buildDetailField('Timestamp', log['timestamp']),
              _buildDetailField('Action', log['action']),
              _buildDetailField('Actioned By', log['actionedBy']),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: AppTextStyles.label.copyWith(color: Colors.white),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value,
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary)),
        ],
      ),
    );
  }
}
