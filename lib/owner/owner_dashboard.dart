import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart' as api;
import '../services/session.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});
  static const String routeName = '/owner';

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  bool _isLoading = true;
  final String _selectedPeriod = 'This month';

  // Live Backend Variables
  double _totalRevenue = 0.0;
  int _totalUsers = 0;
  int _totalProperties = 0;
  int _totalReservations = 0;
  double _guestRating = 0.0;
  int _totalClusters = 0;
  double _netEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final userId = await Session.getUserId();
      if (userId == null) return;

      // Run all API calls in parallel
      final results = await Future.wait([
        api.fetchCustomers(),                      // [0]
        api.fetchPropertiesListingTable(),         // [1]
        api.fetchReservation(),                    // [2]
        api.fetchClusters(),                       // [3]
        api.fetchGuestSatisfactionScore(userId),   // [4]
        api.fetchFinanceLedgerCard(userId),        // [5]
      ]);

      final customersData   = results[0] as Map<String, dynamic>;
      final propertiesData  = results[1] as Map<String, dynamic>;
      final reservations    = results[2] as List<dynamic>;
      final clustersData    = results[3] as Map<String, dynamic>;
      final satisfactionData= results[4] as Map<String, dynamic>;
      final financeData     = results[5] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        // Users
        final customersList = customersData['customers'] as List? ?? [];
        _totalUsers = customersList.length;

        // Properties
        final propList = propertiesData['properties'] as List? ?? [];
        _totalProperties = propList.length;

        // Reservations
        _totalReservations = reservations.length;

        // Clusters
        final clusterList = clustersData['clusters'] as List? ?? [];
        _totalClusters = clusterList.length;

        // Guest rating
        _guestRating = (satisfactionData['averageScore'] as num?)?.toDouble() ?? 0.0;

        // Finance
        _totalRevenue = (financeData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        _netEarnings  = (financeData['netEarnings']  as num?)?.toDouble() ?? 0.0;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (index == 0) return;
    switch (index) {
      case 1:
        Navigator.of(context).pushReplacementNamed('/owner-users');
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed('/owner-cluster');
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed('/owner-logs');
        break;
      case 4:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          // ── Sticky photo header (sits behind everything) ──────────────────
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OwnerHeader(
              greeting: 'Good morning, Owner',
              title: 'Owner Panel',
              notifCount: 3,
              bottomPadding: 80.0,
            ),
          ),

          // ── Scrollable content ────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Builder(
                  builder: (ctx) => SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.115,
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : RefreshIndicator(
                          onRefresh: _loadDashboard,
                          color: AdminColors.success,
                          backgroundColor: Colors.white,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 60),
                            children: [
                              _buildHeroRevenueCard(),
                              const OwnerSectionHeader(title: 'Overview'),
                              _buildStatsGrid(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 0,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  Widget _buildHeroRevenueCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 28 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AdminColors.drawerBg.withOpacity(0.14),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL REVENUE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminColors.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedPeriod,
                        style: GoogleFonts.plusJakartaSans(
                          color: AdminColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AdminColors.textMuted, size: 15),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _totalRevenue),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutExpo,
              builder: (context, value, _) => Text(
                'RM ${value.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  fontSize: MediaQuery.of(context).size.width < 380 ? 36 : 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded,
                      color: AdminColors.success, size: 15),
                  const SizedBox(width: 7),
                  Text(
                    '12.5% from last month',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        label: 'TOTAL USERS',
        value: '$_totalUsers',
        icon: Icons.people_outline_rounded,
        isSuccess: false,
      ),
      _StatData(
        label: 'PROPERTIES',
        value: '$_totalProperties',
        icon: Icons.apartment_outlined,
        isSuccess: true,
      ),
      _StatData(
        label: 'RESERVATIONS',
        value: '$_totalReservations',
        icon: Icons.calendar_today_outlined,
        isSuccess: false,
      ),
      _StatData(
        label: 'GUEST RATING',
        value: '$_guestRating',
        icon: Icons.star_outline_rounded,
        isSuccess: true,
      ),
      _StatData(
        label: 'NET EARNINGS',
        value: 'RM ${_netEarnings.toStringAsFixed(0)}',
        icon: Icons.account_balance_wallet_outlined,
        isSuccess: false,
      ),
      _StatData(
        label: 'CLUSTERS',
        value: '$_totalClusters',
        icon: Icons.location_city_outlined,
        isSuccess: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - 40;
        final cardWidth = (gridWidth - 16) / 2;
        final cardHeight = cardWidth.clamp(155.0, 210.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemCount: stats.length,
            itemBuilder: (_, i) => _buildStatCard(stats[i], i),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData stat, int index) {
    final baseColor =
        stat.isSuccess ? AdminColors.success : AdminColors.primary;
    final iconBg = baseColor.withOpacity(0.09);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + (index * 90)),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: BouncyInteractiveCard(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -14,
                  bottom: -14,
                  child: Icon(
                    stat.icon,
                    size: 88,
                    color: AdminColors.textMuted.withOpacity(0.07),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(stat.icon, color: baseColor, size: 20),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.label,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stat.value,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor.withOpacity(0.25),
                          baseColor,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final bool isSuccess;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.isSuccess,
  });
}