import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../app.dart';

class ModeratorActivityLogsPage extends StatefulWidget {
  const ModeratorActivityLogsPage({super.key});

  @override
  State<ModeratorActivityLogsPage> createState() => _ModeratorActivityLogsPageState();
}

class _ModeratorActivityLogsPageState extends State<ModeratorActivityLogsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.list_alt, color: Colors.white70, size: 32),
          SizedBox(height: 12),
          Text(
            'Activity Logs',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Track booking activity and moderator system changes.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
              color: AdminColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AdminColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15, color: AdminColors.border),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminColors.primary,
        title: const Text(
          'Activity Logs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [SizedBox.shrink()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBanner(),
            const SizedBox(height: 20),
            _buildLogCard(
              icon: Icons.receipt_long,
              title: 'Book & Pay Log',
              subtitle: 'View booking and payment activity records.',
              color: AdminColors.success,
              onTap: () => Navigator.of(context).pushNamed('/moderator-book-and-pay'),
            ),
            const SizedBox(height: 14),
            _buildLogCard(
              icon: Icons.history,
              title: 'Audit Trails',
              subtitle: 'View moderator system actions and changes.',
              color: AdminColors.accent,
              onTap: () => Navigator.of(context).pushNamed('/moderator-audit-trails'),
            ),
          ],
        ),
      ),
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
    );
  }
}
