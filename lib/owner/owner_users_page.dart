import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';

// Warm-taupe surface used for dividers / icon backgrounds.
// Inlined so we never depend on a colour that may not exist in colours.dart.
const _kSurface = Color(0xFFF0EBE5);

class OwnerUsersPage extends StatefulWidget {
  const OwnerUsersPage({super.key});
  static const String routeName = '/owner-users';

  @override
  State<OwnerUsersPage> createState() => _OwnerUsersPageState();
}

class _OwnerUsersPageState extends State<OwnerUsersPage> {
  int _tabIndex = 0;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _customers = [
    {
      'name': 'Alex Johnson',
      'email': 'alex@example.com',
      'role': 'Customer',
      'active': true,
      'phone': '+60 12-345 6789',
      'joinDate': '12 Jan 2024',
    },
    {
      'name': 'Sarah Smith',
      'email': 'sarah@example.com',
      'role': 'Customer',
      'active': true,
      'phone': '+60 11-987 6543',
      'joinDate': '03 Mar 2024',
    },
    {
      'name': 'Mike Ross',
      'email': 'mike@example.com',
      'role': 'Customer',
      'active': false,
      'joinDate': '20 Jun 2023',
    },
  ];

  final List<Map<String, dynamic>> _staff = [
    {
      'name': 'Admin User',
      'email': 'admin@hellosarawak.com',
      'role': 'Admin',
      'active': true,
      'joinDate': '01 Jan 2023',
    },
    {
      'name': 'Mod Team',
      'email': 'mod@hellosarawak.com',
      'role': 'Moderator',
      'active': true,
      'joinDate': '15 Feb 2023',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isLoading = false);
  }

  void _onNavTap(int index) {
    if (index == 1) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed('/owner');
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed('/owner-cluster');
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed('/owner-logs');
        break;
      case 4:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  List<Map<String, dynamic>> get _visibleList {
    final base = _tabIndex == 0 ? _customers : _staff;
    if (_searchQuery.isEmpty) return base;
    return base
        .where(
          (u) => (u['name'] ?? '')
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
              title: 'Users',
              subtitle: 'Manage all platform users',
              notifCount: 3,
              bottomPadding: 40,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: OwnerHeader.spacerHeight()),
                _buildSegmentedToggle(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildSearchBar(),
                ),
                OwnerSectionHeader(
                  title: _tabIndex == 0 ? 'All Customers' : 'All Staff',
                  count: _visibleList.length,
                ),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.only(top: 4, bottom: 100),
                          itemCount: _visibleList.length,
                          itemBuilder: (_, i) =>
                              _buildUserCard(_visibleList[i], i),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 1,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Segmented toggle — solid pill on cream background
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AdminColors.border.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTogglePill('Customers', 0)),
          Expanded(child: _buildTogglePill('Admin / Mod', 1)),
        ],
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
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AdminColors.drawerBg.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? AdminColors.textPrimary : AdminColors.textMuted,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminColors.textPrimary.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintText: 'Search users…',
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

  // ---------------------------------------------------------------------------
  // User card
  // ---------------------------------------------------------------------------
  Widget _buildUserCard(Map<String, dynamic> u, int index) {
    final role = u['role'].toString().toLowerCase();
    // Role colours — no dependency on undefined AdminColors.accent
    final Color avatarColor = role == 'admin'
        ? AdminColors.success
        : role == 'moderator'
            ? AdminColors.secondary
            : AdminColors.primaryLight;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: BouncyInteractiveCard(
        onTap: () => _showUserDetail(u, avatarColor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                backgroundColor: avatarColor.withOpacity(0.12),
                radius: 24,
                child: Text(
                  u['name'].toString().isNotEmpty
                      ? u['name'].toString()[0]
                      : '?',
                  style: GoogleFonts.plusJakartaSans(
                    color: avatarColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u['name'].toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u['email'].toString(),
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
              const SizedBox(width: 8),
              OwnerStatusBadge(active: u['active'] == true),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user, Color avatarColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _UserDetailSheet(user: user, avatarColor: avatarColor),
    );
  }
}

// ---------------------------------------------------------------------------
// User Detail Bottom Sheet
// ---------------------------------------------------------------------------
class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color avatarColor;

  const _UserDetailSheet({required this.user, required this.avatarColor});

  @override
  Widget build(BuildContext context) {
    final isActive = user['active'] == true;
    final initials = user['name'].toString().isNotEmpty
        ? user['name'].toString()[0].toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AdminColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Avatar ring
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AdminColors.textPrimary.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: avatarColor.withOpacity(0.14),
                child: Text(
                  initials,
                  style: GoogleFonts.plusJakartaSans(
                    color: avatarColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user['name']?.toString() ?? 'Unknown',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: avatarColor.withOpacity(0.18)),
              ),
              child: Text(
                user['role'].toString(),
                style: GoogleFonts.plusJakartaSans(
                  color: avatarColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Detail rows card
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: user['email']?.toString() ?? '—',
                  ),
                  const Divider(height: 24, color: _kSurface),
                  if (user['phone'] != null) ...[
                    _DetailRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: user['phone'].toString(),
                    ),
                    const Divider(height: 24, color: _kSurface),
                  ],
                  if (user['joinDate'] != null) ...[
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Joined',
                      value: user['joinDate'].toString(),
                    ),
                    const Divider(height: 24, color: _kSurface),
                  ],
                  _DetailRowStatus(active: isActive),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.drawerBg,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row helpers
// ---------------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 16, color: AdminColors.textMuted),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRowStatus extends StatelessWidget {
  final bool active;

  const _DetailRowStatus({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminColors.success : AdminColors.danger;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.bolt_rounded,
              size: 16, color: AdminColors.textMuted),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Status',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                active ? 'Active' : 'Inactive',
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}