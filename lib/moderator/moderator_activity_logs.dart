import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../app.dart';
import '../api.dart' as api;
import 'moderator_notification.dart';

class ModeratorActivityLogsPage extends StatefulWidget {
  const ModeratorActivityLogsPage({super.key});

  @override
  State<ModeratorActivityLogsPage> createState() => _ModeratorActivityLogsPageState();
}

class _ModeratorActivityLogsPageState extends State<ModeratorActivityLogsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadCount = notifications.where((n) => !(n['isRead'] ?? false)).length;
      });
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false);
    else if (index == 1) Navigator.of(context).pushNamed('/manage-services');
    else if (index == 2) Navigator.of(context).pushNamed('/moderator-stock-manager');
    else if (index == 3) Navigator.of(context).pushNamed('/profile');
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.moderator); break;
      case 'Properties': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager': Navigator.of(context).pushNamed('/moderator-stock-manager'); break;
      case 'Activity Logs': break;
      case 'Ledger': Navigator.of(context).pushNamed('/moderator-ledger'); break;
      case 'Customer Reviews': Navigator.of(context).pushNamed('/moderator-customer-reviews'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Activity Logs',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log Categories',
                      style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Select a category to view detailed records.',
                      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                  const SizedBox(height: 16),
                  _buildLogCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Book & Pay Log',
                    subtitle: 'View booking and payment activity records.',
                    color: AdminColors.success,
                    onTap: () => Navigator.of(context).pushNamed('/moderator-book-and-pay'),
                  ),
                  const SizedBox(height: 14),
                  _buildLogCard(
                    icon: Icons.history_outlined,
                    title: 'Audit Trails',
                    subtitle: 'View moderator system actions and changes.',
                    color: AdminColors.accent,
                    onTap: () => Navigator.of(context).pushNamed('/moderator-audit-trails'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/activity_logs.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3D1E0C).withOpacity(0.62),
                    const Color(0xFF8B4A2F).withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 24, 20, 36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.list_alt_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activity Logs',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 24, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Track booking activity and\nmoderator system changes.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ModeratorNotifications()),
                  ).then((_) => _loadUnreadCount()),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 15),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Color(0xFFE0A43A), shape: BoxShape.circle),
                            child: Text('$_unreadCount',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ),
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

  // ── Log Card ─────────────────────────────────────────────────────────────────
  Widget _buildLogCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
              color: AdminColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_ios,
                  size: 13, color: AdminColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
