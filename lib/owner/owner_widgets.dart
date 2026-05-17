import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/colors.dart';

// ---------------------------------------------------------------------------
// Status Bar — kept as no-op; header handles safe area internally
// ---------------------------------------------------------------------------
class OwnerStatusBar extends StatelessWidget {
  const OwnerStatusBar({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Owner Header
// - Photo background + dark overlay
// - TextScaler.noScaling → prevents Android accessibility scaling from
//   breaking the fixed-height Stack layout on any phone size
// - notifCount → red badge on bell
// ---------------------------------------------------------------------------
class OwnerHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? greeting;
  final bool showBack;
  final bool showBell;
  final int notifCount;
  final double bottomPadding;

  const OwnerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.greeting,
    this.showBack = false,
    this.showBell = true,
    this.notifCount = 0,
    this.bottomPadding = 40.0,
  });

  /// Returns the height of header content below the status bar.
  /// Use inside a SafeArea-wrapped Stack to correctly space content:
  ///   SizedBox(height: OwnerHeader.spacerHeight())
  /// Formula: ~70px (16 top-pad + ~47 title+sub + 7 safety) + bottomPadding
  static double spacerHeight({double bottomPadding = 40.0}) =>
      70.0 + bottomPadding;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // Lock text scale so system font-size changes don't expand the header
    // and break the Stack spacer calculation in parent pages.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, bottomPadding),
        decoration: BoxDecoration(
          color: AdminColors.drawerBg,
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1596401057633-54a8fe8ef647'
              '?q=80&w=1000&auto=format&fit=crop',
            ),
            fit: BoxFit.cover,
            // 85% dark overlay preserves the photo texture while keeping text legible
            colorFilter: ColorFilter.mode(
              Color(0xD92C1A0E),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (greeting != null) ...[
              Text(
                greeting!,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle!,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showBell)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showOwnerNotifications(context),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (notifCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: AdminColors.danger,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AdminColors.drawerBg,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  notifCount > 9 ? '9+' : '$notifCount',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ), // GestureDetector
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header — title + count pill
// ---------------------------------------------------------------------------
class OwnerSectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const OwnerSectionHeader({super.key, required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination Widget — For List Heavy Pages
// ---------------------------------------------------------------------------
class OwnerPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const OwnerPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 12),
          ...List.generate(totalPages, (index) {
            final page = index + 1;
            // Simple logic to show surrounding pages or dots if many pages
            if (page == 1 ||
                page == totalPages ||
                (page >= currentPage - 1 && page <= currentPage + 1)) {
              return _buildPageNumber(page);
            } else if (page == currentPage - 2 || page == currentPage + 2) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('...', style: TextStyle(color: AdminColors.textMuted)),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(width: 12),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumber(int page) {
    final isActive = page == currentPage;
    return GestureDetector(
      onTap: () => onPageChanged(page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? AdminColors.drawerBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? null
              : Border.all(color: AdminColors.border, width: 1.5),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AdminColors.drawerBg.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            '$page',
            style: GoogleFonts.plusJakartaSans(
              color: isActive ? Colors.white : AdminColors.textPrimary,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AdminColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AdminColors.border : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AdminColors.textPrimary
              : AdminColors.textMuted.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge — Active / Inactive pill with leading dot
// ---------------------------------------------------------------------------
class OwnerStatusBadge extends StatelessWidget {
  final bool active;

  const OwnerStatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminColors.success : AdminColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info Banner — view-only notice at bottom of detail pages
// ---------------------------------------------------------------------------
class OwnerInfoBanner extends StatelessWidget {
  const OwnerInfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.success.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              color: AdminColors.success, size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'View-only mode. To make changes, visit the web portal.',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bouncy Interactive Card — subtle scale on press
// ---------------------------------------------------------------------------
class BouncyInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncyInteractiveCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<BouncyInteractiveCard> createState() => _BouncyInteractiveCardState();
}

class _BouncyInteractiveCardState extends State<BouncyInteractiveCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading State
// ---------------------------------------------------------------------------
class OwnerLoading extends StatelessWidget {
  const OwnerLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(
            color: AdminColors.success,
            strokeWidth: 2.5,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------
class OwnerEmptyState extends StatelessWidget {
  final String message;

  const OwnerEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 52,
              color: AdminColors.textMuted.withOpacity(0.15),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Sheet
// ---------------------------------------------------------------------------
void _showOwnerNotifications(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OwnerNotificationSheet(),
  );
}

class _OwnerNotificationSheet extends StatefulWidget {
  const _OwnerNotificationSheet();

  @override
  State<_OwnerNotificationSheet> createState() =>
      _OwnerNotificationSheetState();
}

class _OwnerNotificationSheetState extends State<_OwnerNotificationSheet> {
  // Using a local state list so we can clear it dynamically
  List<Map<String, dynamic>> _items = [
    {
      'title': 'New booking request',
      'body': 'Alex Smith booked Riverside Majestic Suite for 3 nights',
      'time': '5 min ago',
      'read': false,
      'icon': Icons.bookmark_added_rounded,
      'color': AdminColors.success,
    },
    {
      'title': 'Payment received',
      'body': 'RM 480 payment confirmed from James Lau',
      'time': '1 hour ago',
      'read': false,
      'icon': Icons.payments_rounded,
      'color': AdminColors.warning,
    },
    {
      'title': 'Booking cancelled',
      'body': 'John Doe has cancelled their reservation',
      'time': '3 hours ago',
      'read': true,
      'icon': Icons.cancel_rounded,
      'color': AdminColors.danger,
    },
    {
      'title': 'New user registered',
      'body': 'Maria Garcia joined the platform',
      'time': 'Yesterday, 4:30 PM',
      'read': true,
      'icon': Icons.person_add_rounded,
      'color': AdminColors.primaryLight,
    },
  ];

  void _clearAll() {
    setState(() {
      _items.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !(n['read'] as bool)).length;

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: AdminColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header row with Clear All
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (_items.isNotEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.drawerBg,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: AdminColors.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AdminColors.border.withOpacity(0.6)),
          // Items or Empty State
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 48, color: AdminColors.textMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'You\'re all caught up!',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._items.map((n) => _buildItem(n)),
          // Bottom safe-area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final isRead = n['read'] as bool;
    final color = n['color'] as Color;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : AdminColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: isRead
            ? Border.all(color: AdminColors.border.withOpacity(0.4))
            : Border.all(color: AdminColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(n['icon'] as IconData, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n['title'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          color: AdminColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AdminColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  n['body'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  n['time'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}