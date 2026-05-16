import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart' as api;
import '../shared/colors.dart'; 
import 'owner_widgets.dart';

class OwnerPropertyDetailPage extends StatefulWidget {
  final Map<String, dynamic> property;
  const OwnerPropertyDetailPage({super.key, required this.property});

  @override
  State<OwnerPropertyDetailPage> createState() => _OwnerPropertyDetailPageState();
}

class _OwnerPropertyDetailPageState extends State<OwnerPropertyDetailPage> {
  final _pageController = PageController();
  int _currentImage = 0;
  List<Map<String, dynamic>> _recentBookings = [];
  bool _loadingBookings = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBookings();
  }

  Future<void> _loadRecentBookings() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final mockBookings = [
      {'guest': 'Alex Smith', 'status': 'Confirmed', 'price': 240.0},
      {'guest': 'Maria Garcia', 'status': 'Checkout', 'price': 120.0},
    ];
    if (!mounted) return;
    setState(() {
      _recentBookings = mockBookings;
      _loadingBookings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final images = (p['images'] as List?)?.cast<String>() ?? const <String>[];
    
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildCinematicHeader(images, p),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildFloatingBentoHero(p), 
                  if ((p['description'] ?? '').toString().isNotEmpty) ...[
                    const OwnerSectionHeader(title: 'About Property'),
                    _buildTextCard((p['description'] ?? '').toString()),
                  ],
                  const OwnerSectionHeader(title: 'Created by'),
                  _buildCreatorCard((p['creator'] ?? '').toString(), (p['creatorRole'] ?? '').toString()),
                  OwnerSectionHeader(title: 'Recent Bookings', count: _recentBookings.length),
                  if (_loadingBookings)
                    const OwnerLoading()
                  else if (_recentBookings.isEmpty)
                    const OwnerEmptyState(message: 'No recent bookings')
                  else
                    ..._recentBookings.map((b) => _buildBookingTicket(b)),
                  const SizedBox(height: 16),
                  const OwnerInfoBanner(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCinematicHeader(List<String> images, Map<String, dynamic> p) {
    // Determine screen height to set a smart max image height
    final screenHeight = MediaQuery.of(context).size.height;
    
    return SliverAppBar(
      expandedHeight: screenHeight * 0.35, // 35% of the screen height ensures it looks good everywhere
      pinned: true,
      stretch: true, 
      backgroundColor: AdminColors.drawerBg,
      leading: IconButton(
        icon: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.2),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            images.isNotEmpty
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover),
                  )
                : Container(color: AdminColors.primaryLight, child: const Icon(Icons.apartment, size: 60, color: Colors.white54)),
            
            Positioned(
              bottom: 0, left: 0, right: 0, height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AdminColors.cream]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBentoHero(Map<String, dynamic> p) {
    final active = p['active'] == true;
    final rate = p['rate'] ?? 0.0;
    final rooms = p['rooms'] ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(offset: Offset(0, 30 * (1 - value)), child: Opacity(opacity: value, child: child)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black.withOpacity(0.02), width: 1),
          boxShadow: [BoxShadow(color: AdminColors.textPrimary.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text((p['name'] ?? '').toString(), style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                OwnerStatusBadge(active: active), 
              ],
            ),
            const SizedBox(height: 24),
            // Flex row prevents horizontal squishing on tiny Android screens!
            Row(
              children: [
                Expanded(child: _buildAnimatedNumberStat(Icons.bed_rounded, rooms, 'Rooms')),
                Container(width: 1, height: 40, color: AdminColors.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Expanded(child: _buildAnimatedNumberStat(Icons.category_rounded, (p['type'] ?? 'N/A').toString(), 'Type', isString: true)),
                if (p['rate'] != null) ...[
                  Container(width: 1, height: 40, color: AdminColors.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(flex: 2, child: _buildAnimatedNumberStat(Icons.attach_money_rounded, rate, 'Per Night', isHighlight: true)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedNumberStat(IconData icon, dynamic targetValue, String label, {bool isHighlight = false, bool isString = false}) {
    double target = targetValue is num ? targetValue.toDouble() : double.tryParse(targetValue.toString()) ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isHighlight ? AdminColors.success : AdminColors.primaryLight),
            const SizedBox(width: 4),
            Expanded( // Allows text to wrap or scale if the number is huge
              child: isString 
                ? Text(targetValue.toString(), style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: target),
                    duration: const Duration(milliseconds: 1500), 
                    curve: Curves.easeOutExpo,
                    builder: (context, value, child) {
                      return Text(isHighlight ? '\$${value.toInt()}' : value.toInt().toString(), style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis);
                    },
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTextCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.02), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Text(text, style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCreatorCard(String name, String role) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.02), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: AdminColors.primaryLight.withOpacity(0.15), radius: 22, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.outfit(color: AdminColors.primary, fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(width: 14),
          Expanded( // Added Expanded
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unknown' : name, style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(role, style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBookingTicket(Map<String, dynamic> booking) {
    return BouncyInteractiveCard(
      onTap: () {}, 
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.02), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AdminColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.receipt_long_rounded, size: 18, color: AdminColors.success),
            ),
            const SizedBox(width: 16),
            Expanded( // Ensures the text collapses cleanly instead of overflowing
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking['guest'].toString(), style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Status: ${booking['status']}', style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('\$${booking['price'] ?? '-'}', style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}