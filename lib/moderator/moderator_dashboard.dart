import 'package:flutter/material.dart';
import '../services/session.dart';
import '../services/rbac_service.dart' as rbac;
import '../app.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../api.dart' as api;
import '../shared_admin_moderator/user_management.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});
  static const String routeName = '/moderator';

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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
    if (index == 2) { Navigator.of(context).pushNamed('/moderator-stock-manager'); return; }
    if (index == 3) { Navigator.of(context).pushNamed('/profile'); return; }
    setState(() => _selectedIndex = index);
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard': return;
      case 'User Management':
        Navigator.of(context).pushNamed('/user-management', arguments: AppRole.moderator); return;
      case 'Properties':
        Navigator.of(context).pushNamed('/manage-services'); return;
      case 'Stock Manager':
        Navigator.of(context).pushNamed('/moderator-stock-manager'); return;
      case 'Activity Logs':
        Navigator.of(context).pushNamed('/moderator-activity-logs'); return;
      case 'Ledger':
        Navigator.of(context).pushNamed('/moderator-ledger'); return;
      case 'Customer Reviews':
        Navigator.of(context).pushNamed('/moderator-customer-reviews'); return;
      case 'Profile':
        Navigator.of(context).pushNamed('/profile'); return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
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
                    style: TextStyle(fontSize: 13, color: AdminColors.textMuted, height: 1.0),
                  ),
                  const SizedBox(height: 0),
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
      endDrawerEnableOpenDragGesture: false,
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Dashboard',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
    );
  }

  Widget _buildSliverHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/dashboard.png', fit: BoxFit.cover),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.manage_accounts, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello Sarawak',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.72), height: 1.4)),
                            Text('Moderator Panel',
                                style: AppTextStyles.h2.copyWith(
                                    color: Colors.white, height: 1.2)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed('/moderator-notifications'),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back,',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.75)),
                  ),
                  Text(
                    _username ?? (_currentUserRole != null
                        ? rbac.RBACService.getRoleDisplayName(_currentUserRole!)
                        : 'Moderator'),
                    style: AppTextStyles.h1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your platform from here',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.65)),
                  ),
                ],
              ),
            ),
          ],
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
          onTap: () => Navigator.pushNamed(context, '/user-management', arguments: AppRole.moderator)),
      _StatItem('Properties', '$_totalProperties', Icons.apartment, AdminColors.success,
          onTap: () => Navigator.pushNamed(context, '/manage-services')),
      _StatItem('Reservations', '$_totalReservations', Icons.calendar_today, AdminColors.primaryLight,
          onTap: () => Navigator.pushNamed(context, '/moderator-stock-manager')),
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
        childAspectRatio: 1.15,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
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
              child: Icon(item.icon, size: 68, color: item.color.withOpacity(0.07)),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
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
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 16, color: item.color),
                  ),
                  const SizedBox(height: 8),
                  Text(item.title,
                      style: AppTextStyles.caption.copyWith(
                          color: AdminColors.textMuted, fontWeight: FontWeight.w500, fontSize: 11)),
                  const SizedBox(height: 2),
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
                          child: Text(item.value,
                              style: AppTextStyles.bodyDefault.copyWith(
                                  color: AdminColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                        ),
                ],
              ),
            ),
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
                () => Navigator.pushNamed(context, '/user-management', arguments: AppRole.moderator)),
            const SizedBox(width: 12),
            _buildActionButton(Icons.apartment, 'Properties',
                () => Navigator.pushNamed(context, '/manage-services')),
            const SizedBox(width: 12),
            _buildActionButton(Icons.inventory_2, 'Stock',
                () => Navigator.pushNamed(context, '/moderator-stock-manager')),
            const SizedBox(width: 12),
            _buildActionButton(Icons.account_balance_wallet, 'Ledger',
                () => Navigator.pushNamed(context, '/moderator-ledger')),
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
