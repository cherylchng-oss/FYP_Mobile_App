import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/colors.dart';
import '../api.dart' as api;

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
class OwnerHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? greeting;
  final bool showBack;
  final bool showBell;
  // notifCount is kept for backward-compat but is ignored — live count is fetched.
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
  /// Pass [context] to get an orientation-aware value.
  static double spacerHeight({
    double bottomPadding = 40.0,
    BuildContext? context,
  }) {
    if (context != null) {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      if (isLandscape) return 50.0 + (bottomPadding * 0.4);
    }
    return 70.0 + bottomPadding;
  }

  @override
  State<OwnerHeader> createState() => _OwnerHeaderState();
}

class _OwnerHeaderState extends State<OwnerHeader> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      // Fetch both backend notifications and reservations in parallel
      final results = await Future.wait([
        api.fetchNotifications(),
        api.fetchReservation(),
      ]);
      if (!mounted) return;

      final notifications = results[0] as List<dynamic>;
      final reservations  = results[1] as List<dynamic>;

      // Backend unread count
      final backendUnread = notifications.where((n) {
        final m = n is Map ? n : {};
        return !(m['is_read'] == true || m['read'] == true || m['isRead'] == true);
      }).length;

      // Owner-synthesised events: reservations from the last 30 days count as unread
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      int ownerUnread = 0;
      for (final r in reservations) {
        final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        final createdRaw = (m['created_at'] ?? m['createdat'] ??
            m['createdAt'] ?? m['checkindatetime'] ?? '').toString();
        DateTime? dt;
        try { dt = DateTime.parse(createdRaw).toLocal(); } catch (_) {}
        if (dt != null && dt.isAfter(cutoff)) {
          ownerUnread += 1; // one for the booking event
          final status = (m['reservationstatus'] ?? m['reservationStatus'] ??
              m['status'] ?? '').toString().toLowerCase();
          final rawAmt = m['totalprice'] ?? m['totalPrice'] ?? m['total_price'];
          double amount = 0.0;
          if (rawAmt is num) amount = rawAmt.toDouble();
          else if (rawAmt is String) amount = double.tryParse(rawAmt) ?? 0.0;
          if ((status == 'paid' || status == 'partial' || status == 'confirmed' ||
              status == 'full') && amount > 0) {
            ownerUnread += 1; // one for the payment event
          }
        }
      }

      setState(() => _unreadCount = backendUnread + ownerUnread);
    } catch (_) {
      // silently ignore — keep badge at 0
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final isLandscape = mq.orientation == Orientation.landscape;
    // In landscape, shrink vertical padding so the header doesn't eat the whole screen
    final effectiveTopPad = isLandscape ? (topPad + 8) : (topPad + 16);
    final effectiveBottomPad =
        isLandscape ? (widget.bottomPadding * 0.4).clamp(8.0, 40.0) : widget.bottomPadding;

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, effectiveTopPad, 20, effectiveBottomPad),
        decoration: BoxDecoration(
          color: AdminColors.drawerBg,
          image: const DecorationImage(
            image: NetworkImage(
              'https://firebasestorage.googleapis.com/v0/b/fypcams2026.firebasestorage.app'
              '/o/images%2FOwnermobileheader.jpg?alt=media',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Color(0xD92C1A0E),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.greeting != null) ...[
              Text(
                widget.greeting!,
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
                if (widget.showBack) ...[
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
                        widget.title,
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
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          widget.subtitle!,
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
                if (widget.showBell)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await _showOwnerNotificationsAsync(context);
                      // Refresh unread count after user dismisses sheet
                      _fetchUnreadCount();
                    },
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
                        if (_unreadCount > 0)
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
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
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
                  ),
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
// Skeleton shimmer — pure Flutter, zero external packages
// ---------------------------------------------------------------------------
// _OwnerShimmerWrap holds ONE AnimationController and passes the current
// animation value (t ∈ 0→1, repeating) to its entire subtree through a
// single builder callback.  Every _shimBox() call in that tree uses the same
// 't' value within the same frame → all boxes sweep in perfect sync.
// ---------------------------------------------------------------------------
class _OwnerShimmerWrap extends StatefulWidget {
  final Widget Function(double t) builder;
  const _OwnerShimmerWrap({required this.builder});

  @override
  State<_OwnerShimmerWrap> createState() => _OwnerShimmerWrapState();
}

class _OwnerShimmerWrapState extends State<_OwnerShimmerWrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => widget.builder(_anim.value),
      );
}

/// Renders one shimmer-animated rounded rectangle.
/// [width] null → fills parent constraints (use inside Expanded / Column stretch).
Widget _shimBox(
  double t, {
  double? width,
  required double height,
  double radius = 10.0,
}) {
  final sweep = t * 2.8 - 0.9; // light sweep moves left → right
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment(sweep - 1.0, 0),
        end: Alignment(sweep + 1.0, 0),
        colors: const [
          Color(0xFFE4DDD6),
          Color(0xFFF0EBE5),
          Color(0xFFFAF8F6),
          Color(0xFFF0EBE5),
          Color(0xFFE4DDD6),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Skeleton — Dashboard
// ---------------------------------------------------------------------------
class OwnerSkeletonDashboard extends StatelessWidget {
  const OwnerSkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return _OwnerShimmerWrap(
      builder: (t) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          _revenueCard(t),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(children: [
              _shimBox(t, width: 90, height: 20, radius: 8),
            ]),
          ),
          _statsGrid(t),
        ],
      ),
    );
  }

  Widget _revenueCard(double t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimBox(t, width: 130, height: 11, radius: 5),
              _shimBox(t, width: 84, height: 28, radius: 14),
            ],
          ),
          const SizedBox(height: 14),
          _shimBox(t, width: 170, height: 40, radius: 10),
          const SizedBox(height: 16),
          Row(children: [
            _shimBox(t, width: 108, height: 50, radius: 14),
            const SizedBox(width: 8),
            _shimBox(t, width: 124, height: 50, radius: 14),
            const SizedBox(width: 8),
            Expanded(child: _shimBox(t, height: 50, radius: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _statsGrid(double t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _statCard(t)),
            const SizedBox(width: 16),
            Expanded(child: _statCard(t)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statCard(t)),
            const SizedBox(width: 16),
            Expanded(child: _statCard(t)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(double t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimBox(t, width: 38, height: 38, radius: 12),
          const SizedBox(height: 12),
          _shimBox(t, width: 52, height: 22, radius: 6),
          const SizedBox(height: 6),
          _shimBox(t, width: 72, height: 10, radius: 5),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton — Users Page  (6 user-card rows)
// ---------------------------------------------------------------------------
class OwnerSkeletonUsers extends StatelessWidget {
  const OwnerSkeletonUsers({super.key});

  @override
  Widget build(BuildContext context) {
    return _OwnerShimmerWrap(
      builder: (t) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: List.generate(6, (_) => _card(t)),
      ),
    );
  }

  Widget _card(double t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          _shimBox(t, width: 48, height: 48, radius: 24),
          const SizedBox(width: 16),
          // Name + email lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.60,
                  alignment: Alignment.centerLeft,
                  child: _shimBox(t, height: 14, radius: 7),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.80,
                  alignment: Alignment.centerLeft,
                  child: _shimBox(t, height: 11, radius: 5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status badge
          _shimBox(t, width: 64, height: 28, radius: 20),
          const SizedBox(width: 8),
          // Menu button
          _shimBox(t, width: 34, height: 34, radius: 10),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton — Clusters Page  (4 cluster-card rows)
// ---------------------------------------------------------------------------
class OwnerSkeletonClusters extends StatelessWidget {
  const OwnerSkeletonClusters({super.key});

  @override
  Widget build(BuildContext context) {
    return _OwnerShimmerWrap(
      builder: (t) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        children: List.generate(4, (_) => _card(t)),
      ),
    );
  }

  Widget _card(double t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon box
          _shimBox(t, width: 54, height: 54, radius: 18),
          const SizedBox(width: 16),
          // Name + location lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.70,
                  alignment: Alignment.centerLeft,
                  child: _shimBox(t, height: 16, radius: 7),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.48,
                  alignment: Alignment.centerLeft,
                  child: _shimBox(t, height: 12, radius: 5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Count pill
          _shimBox(t, width: 44, height: 36, radius: 14),
          const SizedBox(width: 8),
          // Chevron
          _shimBox(t, width: 20, height: 20, radius: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton — Logs Page  (5 log-card rows)
// ---------------------------------------------------------------------------
class OwnerSkeletonLogs extends StatelessWidget {
  const OwnerSkeletonLogs({super.key});

  @override
  Widget build(BuildContext context) {
    return _OwnerShimmerWrap(
      builder: (t) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: List.generate(5, (_) => _card(t)),
      ),
    );
  }

  Widget _card(double t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accent strip (static tinted bar — no shimmer needed here)
          Container(
            height: 3,
            decoration: const BoxDecoration(
              color: Color(0xFFE4DDD6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon box
                _shimBox(t, width: 42, height: 42, radius: 13),
                const SizedBox(width: 12),
                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Type badge + timestamp
                      Row(children: [
                        _shimBox(t, width: 52, height: 18, radius: 8),
                        const Spacer(),
                        _shimBox(t, width: 74, height: 11, radius: 5),
                      ]),
                      const SizedBox(height: 7),
                      // Action text — line 1 (full width)
                      _shimBox(t, height: 13, radius: 6),
                      const SizedBox(height: 5),
                      // Action text — line 2 (shorter)
                      FractionallySizedBox(
                        widthFactor: 0.72,
                        alignment: Alignment.centerLeft,
                        child: _shimBox(t, height: 13, radius: 6),
                      ),
                      const SizedBox(height: 8),
                      // Footer: user + month badge
                      Row(children: [
                        _shimBox(t, width: 80, height: 11, radius: 5),
                        const Spacer(),
                        _shimBox(t, width: 54, height: 16, radius: 6),
                      ]),
                    ],
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

Future<void> _showOwnerNotificationsAsync(BuildContext context) {
  return showModalBottomSheet(
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
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      // Fetch backend notifications + owner reservations in parallel
      final results = await Future.wait([
        api.fetchNotifications(),
        api.fetchReservation(),
      ]);
      if (!mounted) return;

      final rawNotifs    = results[0] as List<dynamic>;
      final reservations = results[1] as List<dynamic>;

      // ── 1. Map backend notifications ──────────────────────────────────────
      final notifItems = rawNotifs.map((n) {
        final m = n is Map ? Map<String, dynamic>.from(n) : <String, dynamic>{};
        final type = (m['type'] ?? m['notification_type'] ?? '').toString().toLowerCase();
        IconData icon;
        Color color;
        if (type.contains('book') || type.contains('reserv')) {
          icon = Icons.bookmark_added_rounded; color = AdminColors.success;
        } else if (type.contains('pay')) {
          icon = Icons.payments_rounded; color = AdminColors.warning;
        } else if (type.contains('cancel') || type.contains('reject')) {
          icon = Icons.cancel_rounded; color = AdminColors.danger;
        } else if (type.contains('user') || type.contains('register')) {
          icon = Icons.person_add_rounded; color = AdminColors.primaryLight;
        } else {
          icon = Icons.notifications_rounded; color = AdminColors.primary;
        }
        final isRead   = m['is_read'] == true || m['read'] == true || m['isRead'] == true;
        final timeRaw  = (m['created_at'] ?? m['timestamp'] ?? '').toString();
        return {
          'title'  : m['title'] ?? m['notification_title'] ?? 'Notification',
          'body'   : m['body'] ?? m['message'] ?? m['notification_body'] ?? '',
          'time'   : _relativeTime(timeRaw),
          'sortDt' : _parseDt(timeRaw),
          'read'   : isRead,
          'icon'   : icon,
          'color'  : color,
          'id'     : (m['id'] ?? m['notification_id'])?.toString() ?? '',
          'source' : 'backend',
        };
      }).toList();

      // ── 2. Synthesise owner-side events from reservation data ─────────────
      // Only surface events from the last 30 days
      final cutoff     = DateTime.now().subtract(const Duration(days: 30));
      final ownerItems = <Map<String, dynamic>>[];

      for (final r in reservations) {
        final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};

        // Customer full name
        String customer = (m['rcfirstname'] ?? m['rcFirstName'] ??
            m['customer'] ?? m['customername'] ?? '').toString().trim();
        final lastName  = (m['rclastname'] ?? m['rcLastName'] ?? '').toString().trim();
        if (lastName.isNotEmpty) customer = '$customer $lastName'.trim();
        if (customer.isEmpty) customer = 'A customer';

        // Property name
        final property = (m['propertyname'] ?? m['propertyName'] ??
            m['propertyaddress'] ?? m['propertyAddress'] ??
            m['propertydescription'] ?? 'your property').toString().trim();

        // Total price
        double amount = 0.0;
        final rawAmt = m['totalprice'] ?? m['totalPrice'] ?? m['total_price'];
        if (rawAmt is num)    amount = rawAmt.toDouble();
        else if (rawAmt is String) amount = double.tryParse(rawAmt) ?? 0.0;
        final amtFmt = amount > 0 ? 'RM ${amount.toStringAsFixed(2)}' : '';

        // Reservation status
        final status = (m['reservationstatus'] ?? m['reservationStatus'] ??
            m['status'] ?? '').toString().toLowerCase();

        // Reservation ID (for de-dupe key)
        final rid = (m['reservationid'] ?? m['reservationId'] ?? '').toString();

        // Created-at datetime
        final createdRaw = (m['created_at'] ?? m['createdat'] ??
            m['createdAt'] ?? m['checkindatetime'] ?? '').toString();
        final createdDt  = _parseDt(createdRaw);

        if (createdDt == null || createdDt.isBefore(cutoff)) continue;

        // New Booking event
        ownerItems.add({
          'title'  : 'New Booking',
          'body'   : '$customer booked $property'
              '${amtFmt.isNotEmpty ? ' · $amtFmt' : ''}',
          'time'   : _relativeTime(createdRaw),
          'sortDt' : createdDt,
          'read'   : false,
          'icon'   : Icons.bookmark_added_rounded,
          'color'  : AdminColors.success,
          'id'     : 'booking_$rid',
          'source' : 'reservation',
        });

        // Payment event — only for paid/partially-paid reservations
        final isPaid = status == 'paid' || status == 'partial' ||
            status == 'confirmed' || status == 'full';
        if (isPaid && amount > 0) {
          ownerItems.add({
            'title'  : status == 'partial'
                ? 'Partial Payment Received'
                : 'Payment Received',
            'body'   : '$customer paid $amtFmt for $property',
            'time'   : _relativeTime(createdRaw),
            'sortDt' : createdDt,
            'read'   : false,
            'icon'   : Icons.payments_rounded,
            'color'  : AdminColors.warning,
            'id'     : 'payment_$rid',
            'source' : 'reservation',
          });
        }
      }

      // ── 3. Merge, de-duplicate by id, sort newest-first ───────────────────
      final seen = <String>{};
      final all  = <Map<String, dynamic>>[];
      for (final item in [...ownerItems, ...notifItems]) {
        final key = item['id']?.toString() ?? '';
        if (key.isEmpty || seen.add(key)) all.add(item);
      }
      all.sort((a, b) {
        final dtA = a['sortDt'] as DateTime?;
        final dtB = b['sortDt'] as DateTime?;
        if (dtA == null && dtB == null) return 0;
        if (dtA == null) return 1;
        if (dtB == null) return -1;
        return dtB.compareTo(dtA);
      });

      setState(() {
        _items     = all;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _parseDt(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw).toLocal(); } catch (_) { return null; }
  }

  String _relativeTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return raw;
    }
  }

  void _clearAll() {
    setState(() => _items.clear());
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
          // Loading / Empty / Items
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.drawerBg),
            )
          else if (_items.isEmpty)
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.50,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final n = _items[i];
                  return Dismissible(
                    key: ValueKey(n['id']?.toString() ?? 'notif_$i'),
                    direction: DismissDirection.endToStart,
                    // Red delete background revealed on swipe
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      decoration: BoxDecoration(
                        color: AdminColors.danger,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Delete',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      setState(() => _items.removeAt(i));
                    },
                    child: _buildItem(n),
                  );
                },
              ),
            ),
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
                Row(
                  children: [
                    Text(
                      (n['time'] ?? '') as String,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textMuted.withOpacity(0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (n['source'] == 'reservation') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Booking',
                          style: GoogleFonts.plusJakartaSans(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
