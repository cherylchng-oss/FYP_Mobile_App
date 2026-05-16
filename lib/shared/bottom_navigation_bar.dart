import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'navigation_menu.dart';

// ---------------------------------------------------------------------------
// BottomNavItem — data holder for each tab
// ---------------------------------------------------------------------------
class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem(this.icon, this.label);
}

// ---------------------------------------------------------------------------
// SharedBottomNavigationBar — role-aware bottom nav
// ---------------------------------------------------------------------------

class SharedBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final UserRole role;

  const SharedBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.scaffoldKey,
    required this.role,
  });

  Color get _selectedColor {
    switch (role) {
      case UserRole.admin:
        return AdminColors.primary;
        return AdminColors.primary;
      case UserRole.moderator:
        return AdminColors.primary;
        return AdminColors.primary;
      case UserRole.owner:
        return AdminColors.success;
      case UserRole.customer:
        return const Color(0xFF92BBFF);
    }
  }

  List<BottomNavItem> get _navItems {
    switch (role) {
      case UserRole.admin:
        return const [
          BottomNavItem(Icons.admin_panel_settings, 'Dashboard'),
          BottomNavItem(Icons.apartment, 'Properties'),
          BottomNavItem(Icons.inventory_2, 'Stock'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
        return const [
          BottomNavItem(Icons.admin_panel_settings, 'Dashboard'),
          BottomNavItem(Icons.apartment, 'Properties'),
          BottomNavItem(Icons.inventory_2, 'Stock'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
      case UserRole.moderator:
        return const [
          BottomNavItem(Icons.manage_accounts, 'Dashboard'),
          BottomNavItem(Icons.apartment, 'Properties'),
          BottomNavItem(Icons.inventory_2, 'Stock'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
        return const [
          BottomNavItem(Icons.manage_accounts, 'Dashboard'),
          BottomNavItem(Icons.apartment, 'Properties'),
          BottomNavItem(Icons.inventory_2, 'Stock'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
      case UserRole.owner:
        return const [
          BottomNavItem(Icons.dashboard_rounded, 'Dashboard'),
          BottomNavItem(Icons.people_rounded, 'Users'),
          BottomNavItem(Icons.location_city_rounded, 'Clusters'),
          BottomNavItem(Icons.receipt_long_rounded, 'Logs'),
          BottomNavItem(Icons.person_rounded, 'Profile'),
        ];
      case UserRole.customer:
        return const [
          BottomNavItem(Icons.home, 'Rooms'),
          BottomNavItem(Icons.home, 'Rooms'),
          BottomNavItem(Icons.shopping_cart, 'Cart'),
          BottomNavItem(Icons.calendar_today, 'Bookings'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.person, 'Profile'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems
                .asMap()
                .entries
                .map(
                  (entry) => _buildBottomNavItem(
                    entry.value.icon,
                    entry.value.label,
                    entry.key,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;
    // Admin and Moderator use index 4 as a drawer trigger. Owner/Customer route normally.
    final isMoreButton =
        index == 4 &&
        (role == UserRole.admin || role == UserRole.moderator);
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isMoreButton) {
            scaffoldKey?.currentState?.openEndDrawer();
          } else {
            onTap(index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? _selectedColor : const Color(0xFF94A3B8),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _selectedColor : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}