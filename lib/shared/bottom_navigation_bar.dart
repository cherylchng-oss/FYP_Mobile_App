import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation_menu.dart';
import 'colors.dart';

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
      case UserRole.moderator:
        return AdminColors.primary;
      case UserRole.owner:
        return const Color(0xFF4188FF);
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
      case UserRole.moderator:
        return const [
          BottomNavItem(Icons.manage_accounts, 'Dashboard'),
          BottomNavItem(Icons.apartment, 'Properties'),
          BottomNavItem(Icons.inventory_2, 'Stock'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
      case UserRole.owner:
        return const [
          BottomNavItem(Icons.dashboard, 'Dashboard'),
          BottomNavItem(Icons.room_service, 'Properties'),
          BottomNavItem(Icons.calendar_today, 'Bookings'),
          BottomNavItem(Icons.person, 'Profile'),
          BottomNavItem(Icons.more_horiz, 'More'),
        ];
      case UserRole.customer:
        return const [
          BottomNavItem(Icons.home, 'Rooms'),
          BottomNavItem(Icons.shopping_cart, 'Cart'),
          BottomNavItem(Icons.calendar_today, 'Bookings'),
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
                .map((entry) => _buildBottomNavItem(
                      entry.value.icon,
                      entry.value.label,
                      entry.key,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;
    final isMoreButton = index == 4 && role != UserRole.customer;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isMoreButton) {
            // More button - show drawer menu (only for non-customer roles)
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem(this.icon, this.label);
}

class MoreMenuDrawer extends StatelessWidget {
  final UserRole role;
  final Function(String) onItemSelected;
  final Future<void> Function()? onLogout;
  final String? currentPageLabel;
  final String? userName;
  final String? userEmail;

  const MoreMenuDrawer({
    super.key,
    required this.role,
    required this.onItemSelected,
    this.onLogout,
    this.currentPageLabel,
    this.userName,
    this.userEmail,
  });

  String get _headerTitle {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.moderator:
        return 'Moderator';
      case UserRole.owner:
        return 'Owner';
      case UserRole.customer:
        return 'Customer';
    }
  }

  IconData get _headerIcon {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.moderator:
        return Icons.manage_accounts;
      case UserRole.owner:
        return Icons.supervised_user_circle;
      case UserRole.customer:
        return Icons.supervised_user_circle;
    }
  }

  List<Color> get _gradientColors {
    switch (role) {
      case UserRole.admin:
        return const [AdminColors.primary, AdminColors.primaryLight];
      case UserRole.moderator:
        return const [AdminColors.primary, AdminColors.primaryLight];
      case UserRole.owner:
        return const [Color(0xFF6366F1), Color(0xFF4188FF)];
      case UserRole.customer:
        return const [Color(0xFF6366F1), Color(0xFF92BBFF)];
    }
  }

  Color get _borderColor {
    switch (role) {
      case UserRole.admin:
        return AdminColors.accent;
      case UserRole.moderator:
        return AdminColors.accent;
      case UserRole.owner:
        return const Color(0xFF4188FF);
      case UserRole.customer:
        return const Color(0xFF92BBFF);
    }
  }

  Color get _drawerBg {
    switch (role) {
      case UserRole.admin:
      case UserRole.moderator:
        return AdminColors.drawerBg;
      default:
        return const Color(0xFF1E293B);
    }
  }

  bool get _isAdminOrMod =>
      role == UserRole.admin || role == UserRole.moderator;

  @override
  Widget build(BuildContext context) {
    final items = drawerMenuItemsForRole(role);
    final topPad = MediaQuery.of(context).padding.top;
    final displayName = userName ?? _headerTitle;
    final displayEmail = userEmail ?? '';

    return Drawer(
      child: Stack(
        children: [
          // Background image (admin/mod only)
          if (_isAdminOrMod)
            Positioned.fill(
              child: Image.asset(
                'assets/navigation_menu.png',
                fit: BoxFit.cover,
              ),
            ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _isAdminOrMod
                      ? [
                          const Color(0xFF2A1004).withOpacity(0.50),
                          const Color(0xFF2A1004).withOpacity(0.20),
                        ]
                      : [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ],
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(20, topPad + 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),
                          child:
                              Icon(_headerIcon, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (displayEmail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  displayEmail,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.60),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AdminColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Online',
                                  style: GoogleFonts.outfit(
                                    color: AdminColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withOpacity(0.10),
              ),
              const SizedBox(height: 8),
              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _buildDrawerItem(
                        items[i],
                        isSelected: currentPageLabel != null &&
                            items[i].label == currentPageLabel,
                      ),
                  ],
                ),
              ),
              // Logout
              if (onLogout != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await onLogout?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAdminOrMod
                          ? AdminColors.primary.withOpacity(0.85)
                          : const Color(0xFF0077B6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 10),
                child: Text(
                  '© 2025 Hello Sarawak',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.30),
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

  Widget _buildDrawerItem(DrawerMenuItem item, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFC4893A),
                  Color(0xFF7A3D15),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Left accent bar for active item
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: isSelected ? 36 : 0,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 2),
              leading: Icon(item.icon, color: Colors.white, size: 20),
              title: Text(
                item.label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              onTap: () => onItemSelected(item.label),
            ),
          ),
        ],
      ),
    );
  }
}

