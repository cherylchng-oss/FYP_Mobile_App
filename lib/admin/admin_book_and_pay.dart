import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';

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
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final logs = filteredLogs;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminColors.primary,
        title: const Text(
          'Book & Pay Log',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [SizedBox.shrink()],
      ),
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'BooknPayLog',
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AdminColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(logs.length),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 14),
              _buildFilterCard(),
              const SizedBox(height: 16),
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
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.admin,
      ),
    );
  }

  Widget _buildHeaderBanner(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.receipt_long, color: Colors.white70, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Book & Pay Log',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Monitor booking and payment activities. $count record${count == 1 ? '' : 's'} found.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: AdminColors.primary,
      decoration: InputDecoration(
        hintText: 'Search logs...',
        hintStyle: const TextStyle(color: AdminColors.textMuted),
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

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Action Type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textMuted),
          ),
          const SizedBox(height: 10),
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
              items: const ['All Actions', 'Deposit', 'Balance', 'Full Payment', 'Cancel', 'Expired']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14)),
                      ))
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

  Widget _buildLogList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off, size: 56, color: AdminColors.border),
            SizedBox(height: 14),
            Text('No records found',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AdminColors.textSecond)),
            SizedBox(height: 6),
            Text('Try changing the filter or search keyword.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
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

  Widget _buildLogCard(Map<String, dynamic> log) {
    final typeColor = _actionTypeColor(log['actionType'] ?? '');
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: typeColor.withValues(alpha: 0.14),
            child: Icon(Icons.receipt_long, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['actionedBy'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                const SizedBox(height: 3),
                Text(log['action'] ?? '',
                    style: const TextStyle(fontSize: 13, color: AdminColors.textSecond)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AdminColors.textMuted),
                    const SizedBox(width: 4),
                    Text(log['timestamp'] ?? '',
                        style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
                  ],
                ),
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
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(log['actionType'] ?? '',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
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
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 18, color: AdminColors.textMuted),
                        SizedBox(width: 8),
                        Text('View Details',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AdminColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogDetailsDialog(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AdminColors.surface,
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
                  const Text('Log Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AdminColors.border),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.textMuted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 14, color: AdminColors.textPrimary)),
        ],
      ),
    );
  }
}
