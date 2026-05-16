import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart' as api;
import '../shared/colors.dart';

import 'owner_widgets.dart';
import 'owner_property_detail.dart';

// Warm-taupe fallback surface (does not depend on AdminColors.surface)
const _kSurface = Color(0xFFF0EBE5);

class OwnerClusterDetailPage extends StatefulWidget {
  final Map<String, dynamic> cluster;

  const OwnerClusterDetailPage({super.key, required this.cluster});

  @override
  State<OwnerClusterDetailPage> createState() =>
      _OwnerClusterDetailPageState();
}

class _OwnerClusterDetailPageState extends State<OwnerClusterDetailPage> {
  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);
    // ── Mock data (replace with api.fetchPropertiesListingTable() later) ──
    await Future.delayed(const Duration(milliseconds: 600));
    final mockProps = [
      {
        'id': 'p1',
        'name': 'Riverside Majestic Suite',
        'type': 'Suite',
        'rooms': 4,
        'active': true,
        'rate': 120.0,
        'images': [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267'
              '?q=80&w=800&auto=format&fit=crop',
        ],
      },
      {
        'id': 'p2',
        'name': 'Damai Lagoon Resort',
        'type': 'Villa',
        'rooms': 2,
        'active': true,
        'rate': 250.0,
        'images': [
          'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2'
              '?q=80&w=800&auto=format&fit=crop',
        ],
      },
      {
        'id': 'p3',
        'name': 'City Hub Apartment',
        'type': 'Apartment',
        'rooms': 1,
        'active': false,
        'rate': 65.0,
        'images': [],
      },
    ];

    if (!mounted) return;
    setState(() {
      _properties = mockProps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cluster;
    final loc = [c['state'], c['province']]
        .where((s) => s != null && s.toString().isNotEmpty)
        .join(', ');

    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OwnerHeader(
              title: (c['name'] ?? 'Cluster').toString(),
              subtitle: 'Regional properties',
              showBack: true,
              showBell: false,
              bottomPadding: 90,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spacer: content height below status bar minus overlap
                Builder(
                  builder: (ctx) => SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.125,
                  ),
                ),
                // Glass pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        const _GlassPill(
                          icon: Icons.verified_rounded,
                          label: 'Verified Cluster',
                          isHighlight: true,
                        ),
                        const SizedBox(width: 8),
                        _GlassPill(
                          icon: Icons.place_outlined,
                          label: loc.isEmpty ? 'Sarawak' : loc,
                        ),
                      ],
                    ),
                  ),
                ),
                OwnerSectionHeader(
                  title: 'Properties in Cluster',
                  count: _properties.length,
                ),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : RefreshIndicator(
                          onRefresh: _loadProperties,
                          color: AdminColors.success,
                          backgroundColor: Colors.white,
                          child: _properties.isEmpty
                              ? ListView(
                                  children: const [
                                    OwnerEmptyState(
                                      message: 'No properties found here.',
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 40,
                                  ),
                                  itemCount: _properties.length,
                                  itemBuilder: (_, i) =>
                                      _buildPropertyCard(_properties[i], i),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Property card — photo thumbnail on left (2025 real-estate app pattern)
  // ---------------------------------------------------------------------------
  Widget _buildPropertyCard(Map<String, dynamic> p, int index) {
    final rooms = p['rooms'];
    final type = (p['type'] ?? '').toString();
    final isActive = p['active'] == true;
    final images = (p['images'] as List?)?.cast<String>() ?? [];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
          milliseconds: 300 + (index * 100).clamp(0, 500)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: BouncyInteractiveCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OwnerPropertyDetailPage(property: p),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AdminColors.textPrimary.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Photo thumbnail (or colour placeholder) ─────────────────
              Hero(
                tag: 'prop-image-${p['id']}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildImageFallback(isActive),
                          )
                        : _buildImageFallback(isActive),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ── Property info ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['name'] ?? '').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (rooms != null && rooms != 0) '$rooms rooms',
                        if (type.isNotEmpty) type,
                      ].join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    OwnerStatusBadge(active: isActive),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AdminColors.textMuted.withOpacity(0.35),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback(bool isActive) {
    return Container(
      color: isActive
          ? AdminColors.success.withOpacity(0.10)
          : _kSurface,
      child: Icon(
        Icons.apartment_rounded,
        color: isActive
            ? AdminColors.success.withOpacity(0.45)
            : AdminColors.primaryLight.withOpacity(0.45),
        size: 30,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass Pill — shown below the cluster name in the header area
// ---------------------------------------------------------------------------
class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlight;

  const _GlassPill({
    required this.icon,
    required this.label,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHighlight
                ? AdminColors.success.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    isHighlight ? Colors.lightGreenAccent : Colors.white,
                size: 13,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: isHighlight
                        ? Colors.lightGreenAccent
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}