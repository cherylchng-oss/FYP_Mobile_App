import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart' as api;

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

  // Pagination states
  int _currentPage = 1;
  int _totalPages = 1; 

  @override
  void initState() {
    super.initState();
    _loadClusters();
    _searchController.addListener(
      () => setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClusters() async {
    setState(() => _isLoading = true);
    try {
      final result = await api.fetchClusters();
      // API returns: {'clusters': [{'id': ..., 'name': ..., 'state': ..., 'province': ..., 'propertyCount': ...}, ...]}
      final list = (result['clusters'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      if (!mounted) return;
      setState(() {
        _clusters = list;
        const pageSize = 10;
        _totalPages = (list.length / pageSize).ceil().clamp(1, 999);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Cluster load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (index == 2) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed('/owner');
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed('/owner-users');
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed('/owner-logs');
        break;
      case 4:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  List<Map<String, dynamic>> get _visibleClusters {
    if (_searchQuery.isEmpty) return _clusters;
    return _clusters
        .where(
          (c) => (c['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OwnerHeader(
              title: 'Clusters',
              subtitle: 'Regional property groups',
              notifCount: 3,
              bottomPadding: 80, 
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: OwnerHeader.spacerHeight(bottomPadding: 80) - 45),
                _buildCommandCenter(),
                OwnerSectionHeader(
                  title: 'All Clusters',
                  count: _visibleClusters.length,
                ),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : _visibleClusters.isEmpty
                          ? const OwnerEmptyState(
                              message: 'No clusters found.')
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(top: 4, bottom: 40),
                              itemCount: _visibleClusters.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _visibleClusters.length) {
                                  return OwnerPagination(
                                    currentPage: _currentPage,
                                    totalPages: _totalPages,
                                    onPageChanged: (page) {
                                      setState(() => _currentPage = page);
                                      _loadClusters();
                                    },
                                  );
                                }
                                return _buildClusterCard(_visibleClusters[i], i);
                              },
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

  Widget _buildCommandCenter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AdminColors.drawerBg.withOpacity(0.12),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildSearchBar(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withOpacity(0.4)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.plusJakartaSans(
          color: AdminColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintText: 'Search locations…',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: AdminColors.textMuted.withOpacity(0.55),
            fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              color: AdminColors.textMuted.withOpacity(0.55),
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
        ),
      ),
    );
  }

  Widget _buildClusterCard(Map<String, dynamic> c, int index) {
    final loc = [c['state'], c['province']]
        .where((s) => s != null && s.toString().isNotEmpty)
        .join(', ');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
          milliseconds: 380 + (index * 100).clamp(0, 500)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: BouncyInteractiveCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OwnerClusterDetailPage(cluster: c),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AdminColors.success.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'cluster-icon-${c['id']}',
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AdminColors.success.withOpacity(0.16),
                        AdminColors.success.withOpacity(0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.forest_rounded,
                    color: AdminColors.success,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (c['name'] ?? '').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loc.isEmpty ? 'Location not set' : loc,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${c['propertyCount'] ?? 0}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
}