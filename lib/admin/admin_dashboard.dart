import 'package:flutter/material.dart';
import '../services/session.dart';
import '../services/rbac_service.dart' as rbac;
import '../app.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../api.dart' as api;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  static const String routeName = '/admin';

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _currentUserRole;
  String? _username;

  int _totalUsers = 0;
  int _totalProperties = 0;
  int _totalReservations = 0;
  double _occupancyRate = 0.0;
  double _revPAR = 0.0;
  double _totalRevenue = 0.0;
  double _averageRevenue = 0.0;
  double _guestSatisfaction = 0.0;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadDashboardStats();
  }

  Future<void> _loadUserRole() async {
    final userRole = await Session.getUserGroup();
    final username = await Session.getUsername();
    setState(() {
      _currentUserRole = userRole;
      _username = username;
    });
  }

  List<dynamic> _extractList(Map<String, dynamic> data, List<String> keys) {
    for (var key in keys) {
      if (data[key] != null && data[key] is List) return List<dynamic>.from(data[key]);
    }
    return [];
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final customersData = await api.fetchCustomers();
      final customers = _extractList(customersData, ['customers', 'data', 'users']);
      final moderatorsData = await api.fetchModerators();
      final moderators = _extractList(moderatorsData, ['moderators', 'data', 'users']);
      final adminsData = await api.fetchAdministrators();
      final admins = _extractList(adminsData, ['administrators', 'admins', 'data', 'users']);
      if (mounted) setState(() => _totalUsers = customers.length + moderators.length + admins.length);
    } catch (_) {}

    try {
      final propertiesData = await api.fetchPropertiesListingTable();
      final properties = propertiesData['properties'] ?? propertiesData['data'] ?? [];
      if (mounted) setState(() => _totalProperties = (properties as List).length);
    } catch (_) {}

    try {
      final reservations = await api.fetchReservation();
      if (mounted) setState(() => _totalReservations = reservations.length);
    } catch (_) {}

    final userid = await Session.getUserId();
    if (userid != null) {
      try {
        final occupancyData = await api.fetchOccupancyRate(userid, paidOnly: true);
        double rate = 0.0;
        if (occupancyData['occupancyRate'] != null) {
          rate = _parseDouble(occupancyData['occupancyRate']);
        } else if (occupancyData['monthlyData'] is List) {
          final list = occupancyData['monthlyData'] as List;
          if (list.isNotEmpty) {
            final last = list.last;
            rate = _parseDouble(last['occupancy_rate'] ?? last['occupancyRate'] ?? last['rate']);
          }
        }
        if (mounted) setState(() => _occupancyRate = rate);
      } catch (_) {}

      try {
        final revPARData = await api.fetchRevPAR(userid, paidOnly: true);
        if (revPARData['monthlyData'] is List) {
          final list = revPARData['monthlyData'] as List;
          if (list.isNotEmpty) {
            if (mounted) setState(() => _revPAR = _parseDouble(list.last['revpar']));
          }
        }
      } catch (_) {}

      try {
        final financeData = await api.fetchFinance(userid, paidOnly: true);
        if (financeData['monthlyData'] is List) {
          final list = financeData['monthlyData'] as List;
          if (list.isNotEmpty) {
            if (mounted) setState(() => _totalRevenue = _parseDouble(list.last['monthlyrevenue']));
          }
        }
      } catch (_) {}

      try {
        final avg = await api.fetchAverageRevenue(userid);
        if (mounted) setState(() => _averageRevenue = avg);
      } catch (_) {}

      try {
        final satData = await api.fetchGuestSatisfactionScore(userid, paidOnly: true);
        if (satData['monthlyData'] is List) {
          final list = satData['monthlyData'] as List;
          if (list.isNotEmpty) {
            if (mounted) setState(() => _guestSatisfaction = _parseDouble(list.last['guest_satisfaction_score']));
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isLoadingStats = false);
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: AdminColors.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Session.clear();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/before-login', (route) => false);
    }
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) { setState(() => _selectedIndex = 0); return; }
    if (index == 1) { Navigator.of(context).pushNamed('/manage-services'); return; }
    if (index == 2) { Navigator.of(context).pushNamed('/admin-stock-manager'); return; }
    if (index == 3) { Navigator.of(context).pushNamed('/profile'); return; }
    setState(() => _selectedIndex = index);
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard': return;
      case 'User Management':
      case 'Customer':
      case 'Moderator':
        Navigator.of(context).pushNamed('/user-management', arguments: AppRole.admin); return;
      case 'Property Listing':
      case 'Properties':
        Navigator.of(context).pushNamed('/manage-services'); return;
      case 'Reservation':
      case 'Stock Manager':
        Navigator.of(context).pushNamed('/admin-stock-manager'); return;
      case 'Activity Logs':
        Navigator.of(context).pushNamed('/admin-activity-logs'); return;
      case 'Ledger':
        Navigator.of(context).pushNamed('/admin-ledger'); return;
      case 'Customer Review':
        Navigator.of(context).pushNamed('/admin-customer-reviews'); return;
      case 'Profile':
        Navigator.of(context).pushNamed('/profile'); return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      body: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        color: AdminColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverHeader(),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel('Platform Overview'),
                  const SizedBox(height: 4),
                  const Text(
                    'Monitor platform statistics',
                    style: TextStyle(fontSize: 13, color: AdminColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Dashboard',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.admin,
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: AdminColors.primary,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello Sarawak',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Admin Panel',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => Navigator.of(context).pushNamed('/admin-notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome back,',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
                ),
                Text(
                  _username ?? (_currentUserRole != null
                      ? rbac.RBACService.getRoleDisplayName(_currentUserRole!)
                      : 'Administrator'),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your platform from here',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AdminColors.textPrimary,
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('Total Users', '$_totalUsers', Icons.people_outline, AdminColors.accent,
          onTap: () => Navigator.pushNamed(context, '/user-management', arguments: AppRole.admin)),
      _StatItem('Properties', '$_totalProperties', Icons.apartment, AdminColors.success,
          onTap: () => Navigator.pushNamed(context, '/manage-services')),
      _StatItem('Reservations', '$_totalReservations', Icons.calendar_today, AdminColors.primaryLight,
          onTap: () => Navigator.pushNamed(context, '/admin-stock-manager')),
      _StatItem('Booking Revenue', 'MYR ${_occupancyRate.toStringAsFixed(2)}', Icons.attach_money, AdminColors.accent),
      _StatItem('Net Earning', 'MYR ${_revPAR.toStringAsFixed(2)}', Icons.payments, AdminColors.success),
      _StatItem('Deposit Collected', 'MYR ${_totalRevenue.toStringAsFixed(2)}', Icons.receipt_long, AdminColors.primary),
      _StatItem('Pending Balance', 'MYR ${_averageRevenue.toStringAsFixed(2)}', Icons.hourglass_empty, AdminColors.textMuted),
      _StatItem('Customer Rating', '${_guestSatisfaction.toStringAsFixed(1)}/5.0', Icons.star, AdminColors.accentLight),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
              color: AdminColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                if (item.onTap != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_ios, size: 12, color: AdminColors.textMuted),
                  ),
              ],
            ),
            const Spacer(),
            _isLoadingStats
                ? Container(
                    height: 20,
                    width: 60,
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
            const SizedBox(height: 4),
            Text(item.title,
                style: const TextStyle(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Quick Actions'),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildActionButton(Icons.people, 'Users',
                () => Navigator.pushNamed(context, '/user-management', arguments: AppRole.admin)),
            const SizedBox(width: 12),
            _buildActionButton(Icons.apartment, 'Properties',
                () => Navigator.pushNamed(context, '/manage-services')),
            const SizedBox(width: 12),
            _buildActionButton(Icons.inventory_2, 'Stock',
                () => Navigator.pushNamed(context, '/admin-stock-manager')),
            const SizedBox(width: 12),
            _buildActionButton(Icons.account_balance_wallet, 'Ledger',
                () => Navigator.pushNamed(context, '/admin-ledger')),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AdminColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.border),
            boxShadow: [
              BoxShadow(
                color: AdminColors.primary.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: AdminColors.primary, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem(this.title, this.value, this.icon, this.color, {this.onTap});
}
