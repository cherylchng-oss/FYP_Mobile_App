import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Mock data — replace with real API calls
  final double _totalRevenue = 12450.00;
  final int _totalUsers = 142;
  final int _totalProperties = 34;
  final int _totalReservations = 89;
  final double _guestRating = 4.8;
  final int _totalClusters = 6;
  final double _netEarnings = 9876.50;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _isLoading = false);
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
              // Extra bottom padding creates the "shelf" the revenue card
              // slides up into, giving the floating overlap effect.
              bottomPadding: 80.0,
            ),
          ),

          // ── Scrollable content ────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Spacer height = header content height below status bar
                // (greeting 22 + gap 6 + title 30 + bottomPad 80) − overlap 48
                // ≈ 90. Wrapped in Builder so context reads correct MediaQuery.
                Builder(
                  builder: (ctx) => SizedBox(
                    // Use a proportion of the LOGICAL content area so the
                    // floating card lands correctly on all Android sizes.
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

  // ---------------------------------------------------------------------------
  // Hero Revenue Card — white floating card with warm shadow
  // ---------------------------------------------------------------------------
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
          // 2025 trend: colored ambient shadow (warm espresso tint)
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
            // ── Label + period selector ───────────────────────────────────
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

            // ── Animated revenue counter ──────────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _totalRevenue),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutExpo,
              builder: (context, value, _) => Text(
                'RM ${value.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  // Responsive: slightly smaller on narrow phones
                  fontSize: MediaQuery.of(context).size.width < 380 ? 36 : 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Growth pill ───────────────────────────────────────────────
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

  // ---------------------------------------------------------------------------
  // Stats Grid
  // LayoutBuilder → childAspectRatio adapts to the actual card width,
  // so cards never clip on narrow (360px) or wide (480px) phones.
  // ---------------------------------------------------------------------------
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
        // Available width for the grid (minus outer padding)
        final gridWidth = constraints.maxWidth - 40;
        final cardWidth = (gridWidth - 16) / 2; // 16 = column gap
        // Clamp ensures comfortable content height on all screen sizes
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
              // Colored ambient shadow — 2025 trend
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
                // 1. Ghost watermark icon (bottom-right, 7% opacity)
                Positioned(
                  right: -14,
                  bottom: -14,
                  child: Icon(
                    stat.icon,
                    size: 88,
                    color: AdminColors.textMuted.withOpacity(0.07),
                  ),
                ),

                // 2. Card content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(stat.icon, color: baseColor, size: 20),
                      ),
                      // Bottom stats
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

                // 3. Gradient accent bar — bottom edge (2025 trend)
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

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
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