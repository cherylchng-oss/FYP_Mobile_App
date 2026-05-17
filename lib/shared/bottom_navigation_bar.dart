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

  String get _defaultEmail {
    switch (role) {
      case UserRole.admin:
        return 'admin@hellosarawak.com';
      case UserRole.moderator:
        return 'moderator@hellosarawak.com';
      default:
        return '';
    }
  }

  static const Color _activeFill1 = Color(0xFFB8752A);
  static const Color _activeFill2 = Color(0xFF6B3210);
  static const Color _inactiveFill = Color(0xFF3A1E0A);
  static const Color _headerCardBg = Color(0xFF3D200E);

  @override
  Widget build(BuildContext context) {
    final items = drawerMenuItemsForRole(role);
    final topPad = MediaQuery.of(context).padding.top;
    final displayName = userName ?? _headerTitle;
    final displayEmail = (userEmail != null && userEmail!.isNotEmpty)
        ? userEmail!
        : _defaultEmail;
    final bg = _isAdminOrMod ? AdminColors.drawerBg : const Color(0xFF1E293B);

    return Drawer(
      backgroundColor: bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft white light exposure at the top
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
          // Subtle warm radial glow in the middle
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
          // Decorative circle outline — top-left
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
          // Decorative gradient filled circle — top-right
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
          // Main content column
          Column(
            children: [
              // Header card
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPad + 80, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(_headerIcon,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: AppTextStyles.h4.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayEmail,
                              style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withOpacity(0.55)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            Row(children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(0.5),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('Online',
                                  style: AppTextStyles.caption.copyWith(
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ],
                        ),
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
                    for (var i = 0; i < items.length; i++)
                      _buildDrawerItem(
                        items[i],
                        isSelected: currentPageLabel != null &&
                            items[i].label == currentPageLabel,
                      ),
                  ],
                ),
              ),
              // Accent separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Full-width line, bright in the middle
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
                      // Subtle dot centered on the line
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD4952A).withOpacity(0.7),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4952A).withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Logout
              if (onLogout != null)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _isAdminOrMod
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFF6B3210), Color(0xFFD4952A)],
                            )
                          : null,
                      color: _isAdminOrMod
                          ? null
                          : const Color(0xFF0077B6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await onLogout?.call();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text('Logout',
                                  style: AppTextStyles.label
                                      .copyWith(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 20, top: 12),
                child: Text(
                  '© 2025 Hello Sarawak',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.28)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(DrawerMenuItem item,
      {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF6B3210), Color(0xFFD4952A)],
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.08),
        border: isSelected
            ? null
            : Border.all(color: Colors.white.withOpacity(0.10)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(item.label),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(children: [
              // Left accent bar
              Container(
                width: 3,
                height: isSelected ? 36 : 0,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Icon box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(item.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

