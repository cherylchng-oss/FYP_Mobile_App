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
                  Stack(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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