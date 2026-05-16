import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';

class OwnerLogsPage extends StatefulWidget {
  const OwnerLogsPage({super.key});
  static const String routeName = '/owner-logs';

  @override
  State<OwnerLogsPage> createState() => _OwnerLogsPageState();
}

class _OwnerLogsPageState extends State<OwnerLogsPage> {
  int _tabIndex = 0;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _bookLogs = [
    {'action': 'New Booking Created', 'type': 'Booking', 'user': 'Alex Smith', 'time': '13 May 2025, 10:45'},
    {'action': 'Payment Successful — RM 250', 'type': 'Payment', 'user': 'Sarah Connor', 'time': '13 May 2025, 09:12'},
    {'action': 'Booking Cancelled', 'type': 'Cancel', 'user': 'John Doe', 'time': '12 May 2025, 14:30'},
    {'action': 'New Booking — Kuching Suite', 'type': 'Booking', 'user': 'Nurul Ain', 'time': '11 May 2025, 08:00'},
    {'action': 'Payment Received — RM 480', 'type': 'Payment', 'user': 'James Lau', 'time': '10 May 2025, 17:45'},
  ];

  final List<Map<String, dynamic>> _auditLogs = [
    {'action': 'Updated Property Rate', 'type': 'Other', 'user': 'AdminUser', 'time': '13 May 2025, 11:00'},
    {'action': 'Suspended Customer Account', 'type': 'Cancel', 'user': 'ModTeam', 'time': '12 May 2025, 16:20'},
    {'action': 'New Moderator Added', 'type': 'Other', 'user': 'AdminUser', 'time': '10 May 2025, 09:30'},
    {'action': 'Property Listing Approved', 'type': 'Booking', 'user': 'ModTeam', 'time': '08 May 2025, 14:15'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isLoading = false);
  }

  void _onNavTap(int index) {
    if (index == 3) return;
    switch (index) {
      case 0: Navigator.of(context).pushReplacementNamed('/owner'); break;
      case 1: Navigator.of(context).pushReplacementNamed('/owner-users'); break;
      case 2: Navigator.of(context).pushReplacementNamed('/owner-cluster'); break;
      case 4: Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  List<Map<String, dynamic>> get _visibleList {
    final base = _tabIndex == 0 ? _bookLogs : _auditLogs;
    if (_searchQuery.isEmpty) return base;
    return base.where((l) =>
      (l['action'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
      (l['user'] ?? '').toString().toLowerCase().contains(_searchQuery),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          const Positioned(
            top: 0, left: 0, right: 0,
            child: OwnerHeader(
              title: 'Logs & Audit',
              subtitle: 'All platform activity',
              notifCount: 3,
              bottomPadding: 80,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Builder(builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.115)),
                _buildSegmentedToggle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildSearchBar(),
                ),
                OwnerSectionHeader(title: 'Recent Entries', count: _visibleList.length),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : _visibleList.isEmpty
                          ? const OwnerEmptyState(message: 'No log entries found.')
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(top: 4, bottom: 100),
                              itemCount: _visibleList.length,
                              itemBuilder: (_, i) => _buildLogCard(_visibleList[i], i),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 3,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(children: [
            Expanded(child: _buildTogglePill('Book & Pay', 0)),
            Expanded(child: _buildTogglePill('Audit Trails', 1)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTogglePill(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? AdminColors.textPrimary : Colors.white,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AdminColors.textPrimary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.plusJakartaSans(color: AdminColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintText: 'Search logs…',
          hintStyle: GoogleFonts.plusJakartaSans(color: AdminColors.textMuted.withOpacity(0.55), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.search_rounded, color: AdminColors.textMuted.withOpacity(0.55), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final type = (log['type'] ?? 'Other').toString();

    Color badgeBg;
    Color badgeText;
    IconData typeIcon;

    switch (type) {
      case 'Booking':
        badgeBg = AdminColors.success.withOpacity(0.10);
        badgeText = AdminColors.success;
        typeIcon = Icons.bookmark_added_rounded;
        break;
      case 'Payment':
        badgeBg = AdminColors.warning.withOpacity(0.12);
        badgeText = AdminColors.warning;
        typeIcon = Icons.payments_rounded;
        break;
      case 'Cancel':
        badgeBg = AdminColors.danger.withOpacity(0.10);
        badgeText = AdminColors.danger;
        typeIcon = Icons.cancel_rounded;
        break;
      default:
        badgeBg = AdminColors.border;
        badgeText = AdminColors.textMuted;
        typeIcon = Icons.edit_note_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AdminColors.textPrimary.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(typeIcon, size: 16, color: badgeText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    log['action'].toString(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w800, height: 1.35, letterSpacing: -0.2,
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(16)),
                  child: Text(type, style: GoogleFonts.plusJakartaSans(color: badgeText, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 13, color: AdminColors.textMuted.withOpacity(0.45)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log['user'].toString(),
                    style: GoogleFonts.plusJakartaSans(color: AdminColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.access_time_rounded, size: 13, color: AdminColors.textMuted.withOpacity(0.45)),
                const SizedBox(width: 5),
                Text(
                  log['time'].toString(),
                  style: GoogleFonts.plusJakartaSans(color: AdminColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}