import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/colors.dart';

class OwnerStatusBar extends StatelessWidget {
  const OwnerStatusBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).padding.top,
      color: Colors.transparent, 
    );
  }
}

class OwnerHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? greeting;
  final bool showBack;
  final bool showBell;
  final double bottomPadding; 

  const OwnerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.greeting,
    this.showBack = false,
    this.showBell = true,
    this.bottomPadding = 40.0, 
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, bottomPadding),
      decoration: BoxDecoration(
        color: AdminColors.drawerBg,
        image: DecorationImage(
          image: const NetworkImage('https://images.unsplash.com/photo-1596401057633-54a8fe8ef647?q=80&w=1000&auto=format&fit=crop'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(AdminColors.drawerBg.withOpacity(0.85), BlendMode.srcOver),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (greeting != null) ...[
            Text(greeting!, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            const SizedBox(height: 4),
          ],
          Row(
            // Top-alignment keeps the back button locked to the first line of text
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.only(top: 2), // Visually center with text cap-height
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle, // Sleek circle instead of clunky box
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 2), // Optically center the iOS arrow
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(subtitle!, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w400)),
                    ],
                  ],
                ),
              ),
              if (showBell)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.15))),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ... The rest of your existing owner_widgets.dart components remain identical below this line
// (OwnerSectionHeader, BouncyInteractiveCard, OwnerLoading, OwnerEmptyState, OwnerStatusBadge, OwnerInfoBanner)
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
          Text(title, style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (count != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AdminColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Text(count.toString(), style: GoogleFonts.outfit(color: AdminColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class BouncyInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const BouncyInteractiveCard({super.key, required this.child, required this.onTap});

  @override
  State<BouncyInteractiveCard> createState() => _BouncyInteractiveCardState();
}

class _BouncyInteractiveCardState extends State<BouncyInteractiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class OwnerLoading extends StatelessWidget {
  const OwnerLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AdminColors.success)));
}

class OwnerEmptyState extends StatelessWidget {
  final String message;
  const OwnerEmptyState({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AdminColors.textMuted.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(message, style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class OwnerStatusBadge extends StatelessWidget {
  final bool active;
  const OwnerStatusBadge({super.key, required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: active ? AdminColors.success.withOpacity(0.12) : AdminColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: active ? AdminColors.success : AdminColors.danger),
          const SizedBox(width: 6),
          Text(active ? 'Active' : 'Inactive', style: GoogleFonts.outfit(color: active ? AdminColors.success : AdminColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

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
        border: Border.all(color: AdminColors.success.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_off_outlined, color: AdminColors.success, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text('View-only mode. To make changes, visit the web portal.', style: GoogleFonts.outfit(color: AdminColors.success, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
        ],
      ),
    );
  }
}