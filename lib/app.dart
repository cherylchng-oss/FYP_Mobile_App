// ============================================================================
// app.dart — Owner-only test entry point
//
// Boots directly to OwnerDashboard so you can test without admin/customer pages.
// The class is named CamsApp so main.dart (which calls CamsApp()) works as-is.
//
// When merging to main, restore the full app.dart with the login flow and
// all role routes. Swap _StubProfilePage for the real ProfilePage import.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'owner/owner_dashboard.dart';
import 'owner/owner_users_page.dart';
import 'owner/owner_cluster.dart';
import 'owner/owner_logs_page.dart';
import 'shared/colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CamsApp());
}

class CamsApp extends StatelessWidget {
  const CamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Sarawak — Owner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.outfit().fontFamily,
        scaffoldBackgroundColor: AdminColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AdminColors.drawerBg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      initialRoute: OwnerDashboard.routeName,
      routes: {
        OwnerDashboard.routeName: (_) => const OwnerDashboard(),
        OwnerUsersPage.routeName: (_) => const OwnerUsersPage(),
        OwnerClusterPage.routeName: (_) => const OwnerClusterPage(),
        OwnerLogsPage.routeName: (_) => const OwnerLogsPage(),
        '/profile': (_) => const _StubProfilePage(),
      },
    );
  }
}

// =============================================================================
// Stub Profile Page
// Replace this with: import 'profile/profile_page.dart'; once it's available.
// =============================================================================
class _StubProfilePage extends StatelessWidget {
  const _StubProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Column(
        children: [
          Container(
            color: AdminColors.drawerBg,
            height: MediaQuery.of(context).padding.top,
          ),
          Container(
            color: AdminColors.drawerBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Profile',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AdminColors.primaryLight,
                    child: Text(
                      'O',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Owner',
                    style: GoogleFonts.outfit(
                      color: AdminColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Profile page — coming soon',
                    style: GoogleFonts.outfit(
                      color: AdminColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/owner'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AdminColors.primary,
                    ),
                    label: Text(
                      'Back to Dashboard',
                      style: GoogleFonts.outfit(
                        color: AdminColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}