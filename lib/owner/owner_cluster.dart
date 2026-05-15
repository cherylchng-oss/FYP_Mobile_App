import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';
import 'owner_cluster_detail.dart';

class OwnerClusterPage extends StatefulWidget {
  const OwnerClusterPage({super.key});
  static const String routeName = '/owner-cluster';

  @override
  State<OwnerClusterPage> createState() => _OwnerClusterPageState();
}

class _OwnerClusterPageState extends State<OwnerClusterPage> {
  List<Map<String, dynamic>> _clusters = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClusters();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadClusters() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final mockData = [
      {'id': '1', 'name': 'Kuching City Center', 'state': 'Sarawak', 'province': 'Kuching', 'propertyCount': 14},
      {'id': '2', 'name': 'Damai Beach Resort', 'state': 'Sarawak', 'province': 'Santubong', 'propertyCount': 3},
      {'id': '3', 'name': 'Miri Commercial Hub', 'state': 'Sarawak', 'province': 'Miri', 'propertyCount': 8},
      {'id': '4', 'name': 'Bintulu Industrial', 'state': 'Sarawak', 'province': 'Bintulu', 'propertyCount': 5},
    ];

    if (!mounted) return;
    setState(() {
      _clusters = mockData;
      _isLoading = false;
    });
  }

  void _onNavTap(int index) {
    if (index == 2) return;
    switch (index) {
      case 0: Navigator.of(context).pushReplacementNamed('/owner'); break;
      case 1: Navigator.of(context).pushReplacementNamed('/owner-users'); break;
      case 3: Navigator.of(context).pushReplacementNamed('/owner-logs'); break;
      case 4: Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  List<Map<String, dynamic>> get _visibleClusters {
    if (_searchQuery.isEmpty) return _clusters;
    return _clusters.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          const Positioned(
            top: 0, left: 0, right: 0,
            child: OwnerHeader(title: 'Clusters', subtitle: 'Regional property groups', bottomPadding: 80),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 90), // Overlap clearance
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: _buildAestheticSearchBar(),
                ),
                OwnerSectionHeader(title: 'All Clusters', count: _visibleClusters.length),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          itemCount: _visibleClusters.length,
                          itemBuilder: (_, i) => _buildTrendyClusterCard(_visibleClusters[i], i),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 2,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  Widget _buildAestheticSearchBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AdminColors.textPrimary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))]),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintText: 'Search locations...',
          hintStyle: GoogleFonts.outfit(color: AdminColors.textMuted.withOpacity(0.6), fontSize: 15),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 12), child: Icon(Icons.search_rounded, color: AdminColors.textMuted.withOpacity(0.6), size: 22)),
        ),
      ),
    );
  }

  Widget _buildTrendyClusterCard(Map<String, dynamic> c, int index) {
    final loc = [c['state'], c['province']].where((s) => s != null && s.toString().isNotEmpty).join(', ');
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 500)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)),
      child: BouncyInteractiveCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnerClusterDetailPage(cluster: c))),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.black.withOpacity(0.02), width: 1), boxShadow: [BoxShadow(color: AdminColors.textPrimary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10))]),
          child: Row(
            children: [
              Hero(
                tag: 'cluster-icon-${c['id']}',
                child: Container(width: 56, height: 56, decoration: BoxDecoration(gradient: LinearGradient(colors: [AdminColors.success.withOpacity(0.15), AdminColors.success.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.forest_rounded, color: AdminColors.success, size: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((c['name'] ?? '').toString(), style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(loc.isEmpty ? 'Location not set' : loc, style: GoogleFonts.outfit(color: AdminColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AdminColors.cream, borderRadius: BorderRadius.circular(16)),
                child: Text('${c['propertyCount'] ?? 0}', style: GoogleFonts.outfit(color: AdminColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}