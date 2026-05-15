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

  // Mock data
  final double _totalRevenue = 12450.00;
  final int _totalUsers = 142;
  final int _totalProperties = 34;
  final int _totalReservations = 89;
  final double _guestRating = 4.8;
  final int _totalClusters = 6;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isLoading = false);
  }

  void _onNavTap(int index) {
    if (index == 0) return;
    switch (index) {
      case 1: Navigator.of(context).pushReplacementNamed('/owner-users'); break;
      case 2: Navigator.of(context).pushReplacementNamed('/owner-cluster'); break;
      case 3: Navigator.of(context).pushReplacementNamed('/owner-logs'); break;
      case 4: Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream, // Warm premium background
      body: Stack(
        children: [
          // 1. The Deep Photo Header Background (Sits behind everything)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: OwnerHeader(
              greeting: 'Good morning, Owner',
              title: 'Owner Panel',
              bottomPadding: 80.0, // Extra padding so the revenue card overlaps it beautifully
            ),
          ),
          
          // 2. The Scrollable Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Invisible spacer to push the list down over the header text
                const SizedBox(height: 100), 
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
  // Hero Revenue Card (Overlapping, Floating)
  // ---------------------------------------------------------------------------
  Widget _buildHeroRevenueCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - value)), // Slides up
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(28), // Generous whitespace
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32), // High-end squircle
          boxShadow: [
            // Ambient soft shadow for floating effect
            BoxShadow(color: AdminColors.textPrimary.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 15))
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
                  style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AdminColors.cream, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Text(_selectedPeriod, style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.textMuted, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _totalRevenue),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutExpo,
              builder: (context, value, _) => Text(
                'RM ${value.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -2.0),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded, color: AdminColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text('12.5% from last month', style: GoogleFonts.outfit(color: AdminColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Grid — The "Watermark Ghost Icon" Treatment
  // ---------------------------------------------------------------------------
  Widget _buildStatsGrid() {
    final stats = [
      _StatData(label: 'TOTAL USERS', value: _totalUsers.toString(), icon: Icons.people_outline_rounded, isSuccess: false),
      _StatData(label: 'PROPERTIES', value: _totalProperties.toString(), icon: Icons.apartment_outlined, isSuccess: true),
      _StatData(label: 'RESERVATIONS', value: _totalReservations.toString(), icon: Icons.calendar_today_outlined, isSuccess: false),
      _StatData(label: 'GUEST RATING', value: '$_guestRating', icon: Icons.star_outline_rounded, isSuccess: true),
      _StatData(label: 'CLUSTERS', value: _totalClusters.toString(), icon: Icons.location_city_outlined, isSuccess: true),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95, // Tall enough for the ghost icon to breathe
        ),
        itemCount: stats.length,
        itemBuilder: (_, i) => _buildStatCard(stats[i], i),
      ),
    );
  }

  Widget _buildStatCard(_StatData stat, int index) {
    // Determine the accent color based on your video specs
    final baseColor = stat.isSuccess ? AdminColors.success : AdminColors.primary;
    final iconBgColor = baseColor.withOpacity(0.08);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - val)), 
        child: Opacity(opacity: val, child: child),
      ),
      child: BouncyInteractiveCard(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            // FIX: Flutter requires all sides of a border to be identical if using a borderRadius on a BoxDecoration!
            border: Border.all(color: Colors.black.withOpacity(0.02), width: 1),
            boxShadow: [
              BoxShadow(color: AdminColors.textPrimary.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 1. THE GHOST ICON (Watermark at the bottom right)
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Icon(
                    stat.icon, 
                    size: 90, 
                    color: AdminColors.textMuted.withOpacity(0.07), // 7% opacity
                  ),
                ),
                
                // 2. The Card Content
                Padding(
                  padding: const EdgeInsets.all(20), // Generous padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Circular Icon Badge
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                        child: Icon(stat.icon, color: baseColor, size: 22),
                      ),
                      
                      // Bottom Text Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.label,
                            style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stat.value,
                            style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. The 3px Accent Bar at the bottom (Done via Positioned to avoid the borderRadius crash)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(height: 3, color: baseColor),
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