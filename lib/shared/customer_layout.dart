import 'package:flutter/material.dart';
import '../services/session.dart';
import 'colors.dart';

class CustomerLayout extends StatefulWidget {
  const CustomerLayout({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.backgroundColor = const Color(0xFFFAF6F0),
    this.appBar,
  });

  final Widget body;
  final int selectedIndex;
  final Color backgroundColor;
  final PreferredSizeWidget? appBar;

  @override
  State<CustomerLayout> createState() => _CustomerLayoutState();
}

class _CustomerLayoutState extends State<CustomerLayout> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  static const primary = AdminColors.primary;
  static const primaryLight = AdminColors.primaryLight;
  static const accent = AdminColors.accent;
  static const cream = AdminColors.cream;
  static const border = AdminColors.border;
  static const textMuted = AdminColors.textMuted;
  static const drawerBg = AdminColors.drawerBg;

  static const Color _activeFill1 = Color(0xFFB8752A);
  static const Color _activeFill2 = Color(0xFF6B3210);
  static const Color _inactiveFill = Color(0xFF3A1E0A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar,
      endDrawer: _buildMoreDrawer(context),
      drawerScrimColor: Colors.black.withOpacity(0.55),
      body: widget.body,
      bottomNavigationBar: _buildBottomNav(context, scaffoldKey),
    );
  }

  // ================= BOTTOM NAV DESIGN =================

  Widget _buildBottomNav(
    BuildContext context,
    GlobalKey<ScaffoldState> scaffoldKey,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _navItem(
                context,
                scaffoldKey,
                0,
                Icons.home_rounded,
                Icons.home_outlined,
                'Home',
              ),
              _navItem(
                context,
                scaffoldKey,
                1,
                Icons.hotel_rounded,
                Icons.hotel_outlined,
                'Stay',
              ),
              _navItem(
                context,
                scaffoldKey,
                2,
                Icons.shopping_cart_rounded,
                Icons.shopping_cart_outlined,
                'Cart',
              ),
              _navItem(
                context,
                scaffoldKey,
                3,
                Icons.more_horiz_rounded,
                Icons.more_horiz_rounded,
                'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    GlobalKey<ScaffoldState> scaffoldKey,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final selected = widget.selectedIndex == index;
    final isMore = index == 3;

    return Expanded(
      child: InkWell(
        onTap: () => _handleBottomNavTap(context, scaffoldKey, index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected && !isMore
                ? primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: selected && !isMore
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6B3210),
                            Color(0xFFD4952A),
                          ],
                        )
                      : null,
                  color: selected && !isMore ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected && !isMore ? activeIcon : inactiveIcon,
                  color: selected && !isMore ? Colors.white : textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? primary : textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomNavTap(
    BuildContext context,
    GlobalKey<ScaffoldState> scaffoldKey,
    int index,
  ) {
    if (index == 3) {
      scaffoldKey.currentState?.openEndDrawer();
      return;
    }

    if (index == widget.selectedIndex) return;

    if (index == 0) {
      Navigator.of(context).pushReplacementNamed('/customer-home');
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushReplacementNamed('/customer-rooms');
      return;
    }

    if (index == 2) {
      Navigator.of(context).pushNamed('/customer-cart');
      return;
    }
  }

  // ================= DRAWER DESIGN =================

  Widget _buildMoreDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 480
        ? screenWidth * 0.82
        : screenWidth < 768
            ? screenWidth * 0.65
            : 310.0;

    final topPad = MediaQuery.of(context).padding.top;

    return Drawer(
      width: drawerWidth,
      backgroundColor: drawerBg,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft white glow at top
          Positioned(
            left: -80,
            right: -80,
            top: -80,
            child: Container(
              height: 340,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [
                    Colors.white.withOpacity(0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Warm brown glow in middle
          Positioned(
            left: -60,
            right: -60,
            top: 220,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    _activeFill1.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Circle outline
          Positioned(
            left: -40,
            top: -90,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                  width: 2,
                ),
              ),
            ),
          ),

          // Gradient circle
          Positioned(
            right: -22,
            top: topPad - 20,
            child: Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.0,
                  colors: [
                    _activeFill1.withOpacity(0.90),
                    _activeFill2.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Header card
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPad + 80, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: primaryLight.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello Sarawak',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Discover authentic stays',
                              style: TextStyle(
                                color: Color(0xFFB99B82),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 7),
                            Row(
                              children: [
                                _OnlineDot(),
                                SizedBox(width: 5),
                                Text(
                                  'Customer',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFB99B82),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _drawerItem(
                      context,
                      Icons.notifications_rounded,
                      'Notifications',
                      '/customer-notifications',
                    ),
                    _drawerItem(
                      context,
                      Icons.info_outline_rounded,
                      'About Us',
                      '/about-us',
                    ),
                    _drawerItem(
                      context,
                      Icons.landscape_rounded,
                      'About Sarawak',
                      '/about-sarawak',
                    ),
                    _drawerItem(
                      context,
                      Icons.help_outline_rounded,
                      'FAQ',
                      '/customer-faq',
                    ),
                    _drawerItem(
                      context,
                      Icons.person_rounded,
                      'Profile',
                      '/customer-profile',
                    ),
                  ],
                ),
              ),

              // Separator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _activeFill1.withOpacity(0.60),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withOpacity(0.7),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Logout button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF6B3210),
                        Color(0xFFD4952A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _handleLogout(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 12),
                child: Text(
                  '© 2025 Hello Sarawak',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.28),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final bool selected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF6B3210),
                  Color(0xFFD4952A),
                ],
              )
            : null,
        color: selected ? null : Colors.white.withOpacity(0.08),
        border: Border.all(
          color: selected
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.10),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _activeFill1.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);

            if (!selected) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: selected ? 28 : 0,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Icon box
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.18)
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),

                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? Colors.white : const Color(0xFFD4952A),
                  size: selected ? 17 : 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Session.clear();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/before-login',
          (route) => false,
        );
      }
    }
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}