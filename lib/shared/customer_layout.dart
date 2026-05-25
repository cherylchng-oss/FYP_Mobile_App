import 'package:flutter/material.dart';
import '../services/session.dart';

class CustomerLayout extends StatelessWidget {
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

  static const primary = Color(0xFF6B3F1A);
  static const accent = Color(0xFFBF8040);
  static const accentLight = Color(0xFFE8B97A);
  static const border = Color(0xFFE8D9C5);
  static const textMuted = Color(0xFFA07850);

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: appBar,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: _buildMoreDrawer(context),
      drawerScrimColor: Colors.black.withOpacity(0.55),
      body: body,
      bottomNavigationBar: _buildBottomNav(context, scaffoldKey),
    );
  }

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
            color: primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _navItem(context, scaffoldKey, 0, Icons.home_rounded,
                  Icons.home_outlined, 'Home'),
              _navItem(context, scaffoldKey, 1, Icons.bed_rounded,
                  Icons.bed_outlined, 'Explore'),
              _navItem(context, scaffoldKey, 2, Icons.shopping_cart_rounded,
                  Icons.shopping_cart_outlined, 'Cart'),
              _navItem(context, scaffoldKey, 3, Icons.menu_rounded,
                  Icons.menu_rounded, 'More'),
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
    final selected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _handleBottomNavTap(context, scaffoldKey, index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? primary.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                selected ? activeIcon : inactiveIcon,
                color: selected ? primary : textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? primary : textMuted,
              ),
            ),
          ],
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

    if (index == selectedIndex) return;

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

    if (index == 3) {
      scaffoldKey.currentState?.openEndDrawer();
      return;
    }
  }

  Widget _buildMoreDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 480
        ? screenWidth * 0.80
        : screenWidth < 768
            ? screenWidth * 0.65
            : 300.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E0F04),
              Color(0xFF2C1A0E),
              Color(0xFF3D2512),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 18, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: accentLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello Sarawak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Discover authentic stays',
                            style: TextStyle(
                              color: Color(0xFF9E7B5C),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF9E7B5C),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                color: Colors.white.withOpacity(0.08),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _drawerItem(context, Icons.notifications_rounded,
                        'Notifications', '/customer-notifications'),
                    _drawerItem(
                        context, Icons.info_outline_rounded, 'About Us', '/about-us'),
                    _drawerItem(context, Icons.landscape_rounded,
                        'About Sarawak', '/about-sarawak'),
                    _drawerItem(
                        context, Icons.help_outline_rounded, 'FAQ', '/customer-faq'),
                    _drawerItem(
                        context, Icons.person_rounded, 'My Profile', '/profile'),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.white.withOpacity(0.08)),
                    const SizedBox(height: 8),
                    _drawerLogoutItem(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Text(
                  '© 2025 Hello Sarawak',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFBF8040),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLogoutItem(BuildContext context) {
    return InkWell(
      onTap: () => _handleLogout(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE07070), size: 22),
            SizedBox(width: 14),
            Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFE07070),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
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