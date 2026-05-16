import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation_menu.dart';
import 'colors.dart';

class MoreMenuDrawer extends StatelessWidget {
  final UserRole role;
  final void Function(String) onItemSelected;
  final Future<void> Function() onLogout;
  final String currentPageLabel;

  const MoreMenuDrawer({
    super.key,
    required this.role,
    required this.onItemSelected,
    required this.onLogout,
    required this.currentPageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final items = drawerMenuItemsForRole(role);

    return Drawer(
      backgroundColor: AdminColors.drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Menu',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = item.label == currentPageLabel;
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isActive ? AdminColors.primary : Colors.white70,
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.outfit(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    tileColor: isActive
                        ? AdminColors.primary.withOpacity(0.18)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    onTap: () => onItemSelected(item.label),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: Colors.white60, size: 20),
              title: Text(
                'Logout',
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 15,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
