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
  State<OwnerPropertyDetailPage> createState() =>
      _OwnerPropertyDetailPageState();
}

class _OwnerPropertyDetailPageState
    extends State<OwnerPropertyDetailPage> {
  final _pageController = PageController();
  int _currentImage = 0;
  List<Map<String, dynamic>> _recentBookings = [];
  bool _loadingBookings = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBookings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentBookings() async {
    try {
      final allReservations = await api.fetchReservation();
      final propertyId = widget.property['id']?.toString();

      final filtered = allReservations
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((r) =>
              r['propertyid']?.toString() == propertyId ||
              r['property_id']?.toString() == propertyId)
          .take(5) 
          .map((r) => {
                'guest': r['username'] ?? r['guest'] ?? r['customer_name'] ?? 'Guest',
                'status': r['status'] ?? r['reservation_status'] ?? 'Pending',
                'price': ((r['total_price'] ?? r['price'] ?? r['amount']) as num?)?.toDouble(),
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _recentBookings = filtered;
        _loadingBookings = false;
      });
    } catch (e) {
      debugPrint('Bookings load error: $e');
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final images =
        (p['images'] as List?)?.cast<String>() ?? const <String>[];

    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildCinematicHeader(images, p),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeroCard(p),
                  if ((p['description'] ?? '').toString().isNotEmpty) ...[
                    const OwnerSectionHeader(title: 'About Property'),
                    _buildTextCard(
                        (p['description'] ?? '').toString()),
                  ],
                  const OwnerSectionHeader(title: 'Created by'),
                  _buildCreatorCard(
                    (p['creator'] ?? '').toString(),
                    (p['creatorRole'] ?? '').toString(),
                  ),
                  OwnerSectionHeader(
                    title: 'Recent Bookings',
                    count: _recentBookings.length,
                  ),
                  if (_loadingBookings)
                    const OwnerLoading()
                  else if (_recentBookings.isEmpty)
                    const OwnerEmptyState(message: 'No recent bookings')
                  else
                    ..._recentBookings.map((b) => _buildBookingTile(b)),
                  const SizedBox(height: 12),
                  const OwnerInfoBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildCinematicHeader(
      List<String> images, Map<String, dynamic> p) {
    final expandedH = MediaQuery.of(context).size.height * 0.35;

    return SliverAppBar(
      expandedHeight: expandedH,
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
              color: Colors.black.withOpacity(0.22),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            images.isNotEmpty
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImage = i),
                    itemBuilder: (_, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AdminColors.primaryLight,
                        child: const Icon(Icons.apartment,
                            size: 56, color: Colors.white54),
                      ),
                    ),
                  )
                : Container(
                    color: AdminColors.primaryLight,
                    child: const Icon(Icons.apartment,
                        size: 56, color: Colors.white54),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AdminColors.cream,
                    ],
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 72,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      color: Colors.black.withOpacity(0.28),
                      child: Text(
                        '${_currentImage + 1} / ${images.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(Map<String, dynamic> p) {
    final active = p['active'] == true;
    final rate = p['rate'] ?? 0.0;
    final rooms = p['rooms'] ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 28 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AdminColors.drawerBg.withOpacity(0.10),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (p['name'] ?? '').toString(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                OwnerStatusBadge(active: active),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _BentoStat(
                    icon: Icons.bed_rounded,
                    value: '$rooms',
                    label: 'Rooms',
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _BentoStat(
                    icon: Icons.category_rounded,
                    value: (p['type'] ?? 'N/A').toString(),
                    label: 'Type',
                  ),
                ),
                if (p['rate'] != null) ...[
                  _verticalDivider(),
                  Expanded(
                    flex: 2,
                    child: _BentoStat(
                      icon: Icons.attach_money_rounded,
                      value: 'RM ${rate.toStringAsFixed(0)}',
                      label: 'Per night',
                      highlight: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 36,
        color: AdminColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  Widget _buildTextCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: AdminColors.textMuted,
          fontSize: 14,
          height: 1.65,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCreatorCard(String name, String role) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.primaryLight.withOpacity(0.15),
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unknown' : name,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role.isEmpty ? 'Team' : role,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted,
                    fontSize: 13,
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

  Widget _buildBookingTile(Map<String, dynamic> booking) {
    final isCancelled = (booking['status'] ?? '')
        .toString()
        .toLowerCase()
        .contains('cancel');
    final color = isCancelled ? AdminColors.danger : AdminColors.success;
    final price = booking['price'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 17, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['guest'].toString(),
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Status: ${booking['status']}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            price != null ? 'RM ${price.toStringAsFixed(0)}' : '—',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _BentoStat({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        highlight ? AdminColors.success : AdminColors.primaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}