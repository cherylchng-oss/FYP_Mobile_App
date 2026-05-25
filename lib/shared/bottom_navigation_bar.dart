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
      case UserRole.moderator:
      case UserRole.owner:
      case UserRole.customer:
        return AdminColors.primary;
    }
  }

  Color get _inactiveColor {
    return AdminColors.textMuted;
  }

  List<Color> get _activeGradient {
    return const [
      Color(0xFF6B3210),
      Color(0xFFD4952A),
    ];
  }

  List<BottomNavItem> get _navItems {
    switch (role) {
      case UserRole.admin:
        return const [
          BottomNavItem(Icons.dashboard_rounded, 'Dashboard'),
          BottomNavItem(Icons.apartment_rounded, 'Properties'),
          BottomNavItem(Icons.inventory_2_rounded, 'Stock'),
          BottomNavItem(Icons.person_rounded, 'Profile'),
          BottomNavItem(Icons.more_horiz_rounded, 'More'),
        ];

      case UserRole.moderator:
        return const [
          BottomNavItem(Icons.dashboard_rounded, 'Dashboard'),
          BottomNavItem(Icons.apartment_rounded, 'Properties'),
          BottomNavItem(Icons.inventory_2_rounded, 'Stock'),
          BottomNavItem(Icons.person_rounded, 'Profile'),
          BottomNavItem(Icons.more_horiz_rounded, 'More'),
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
          BottomNavItem(Icons.home_rounded, 'Rooms'),
          BottomNavItem(Icons.shopping_cart_rounded, 'Cart'),
          BottomNavItem(Icons.calendar_today_rounded, 'Bookings'),
          BottomNavItem(Icons.person_rounded, 'Profile'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: AdminColors.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withOpacity(0.12),
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
    final isMoreButton =
        index == 4 && (role == UserRole.admin || role == UserRole.moderator);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isMoreButton) {
            scaffoldKey?.currentState?.openEndDrawer();
          } else {
            onTap(index);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected && !isMoreButton
                ? _selectedColor.withOpacity(0.08)
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
                  gradient: isSelected && !isMoreButton
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _activeGradient,
                        )
                      : null,
                  color: isSelected && !isMoreButton
                      ? null
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      isSelected && !isMoreButton ? Colors.white : _inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? _selectedColor : _inactiveColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  static const Color _activeFill1 = Color(0xFFB8752A);
  static const Color _activeFill2 = Color(0xFF6B3210);

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
      case UserRole.moderator:
      case UserRole.owner:
        return Icons.dashboard_rounded;
      case UserRole.customer:
        return Icons.home_work_rounded;
    }
  }

  String get _defaultEmail {
    switch (role) {
      case UserRole.admin:
        return 'admin@hellosarawak.com';
      case UserRole.moderator:
        return 'moderator@hellosarawak.com';
      case UserRole.owner:
        return 'owner@hellosarawak.com';
      case UserRole.customer:
        return 'customer@hellosarawak.com';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = drawerMenuItemsForRole(role);
    final topPad = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    final drawerWidth = screenWidth < 480
        ? screenWidth * 0.82
        : screenWidth < 768
            ? screenWidth * 0.65
            : 310.0;

    final displayName = userName ?? _headerTitle;
    final displayEmail = (userEmail != null && userEmail!.isNotEmpty)
        ? userEmail!
        : _defaultEmail;

    return Drawer(
      width: drawerWidth,
      backgroundColor: AdminColors.drawerBg,
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
                          color: AdminColors.primary.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _headerIcon,
                          color: Colors.white,
                          size: 26,
                        ),
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayEmail,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withOpacity(0.55),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
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
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Online',
                                  style: AppTextStyles.caption.copyWith(
                                    color: const Color(0xFF4CAF50),
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
                    for (var i = 0; i < items.length; i++)
                      _buildDrawerItem(
                        items[i],
                        isSelected: currentPageLabel != null &&
                            items[i].label == currentPageLabel,
                      ),
                  ],
                ),
              ),

              // Separator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
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

              // Logout button
              if (onLogout != null)
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
                          await onLogout?.call();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Logout',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white,
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
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.28),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    DrawerMenuItem item, {
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF6B3210),
                  Color(0xFFD4952A),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.08),
        border: Border.all(
          color: isSelected
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.10),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isSelected
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
          onTap: () => onItemSelected(item.label),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: isSelected ? 28 : 0,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.18)
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),

                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: isSelected ? Colors.white : const Color(0xFFD4952A),
                  size: isSelected ? 17 : 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}