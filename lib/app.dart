import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/session.dart';
import 'shared/colors.dart';

// ── Screens ──────────────────────────────────────────────────────────────────
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/mfa_screen.dart';

// ── Owner Pages ───────────────────────────────────────────────────────────────
import 'owner/owner_dashboard.dart';
import 'owner/owner_cluster.dart';
import 'owner/owner_users_page.dart';
import 'owner/owner_logs_page.dart';
import 'profile_page.dart';

// ── Customer Pages (Cheryl branch) ───────────────────────────────────────────
// Uncomment when merged:
// import 'customer/home_page.dart';

// ── Admin / Moderator Pages ───────────────────────────────────────────────────
// These come from the existing main branch admin folder — keep your existing
// imports here.  Examples shown; adjust to your actual file paths.
// import 'admin/admin_dashboard.dart';
// import 'moderator/mod_dashboard.dart';

// Global navigator key — used by admin/moderator pages (profile_page.dart etc.)
// to navigate without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// =============================================================================
//  CamsApp — root widget
// =============================================================================
class CamsApp extends StatelessWidget {
  const CamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Hello Sarawak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use Plus Jakarta Sans as the app-wide font
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.primary,
          background: AdminColors.cream,
        ),
        scaffoldBackgroundColor: AdminColors.cream,
        // Remove the default blue splash / highlight on Android
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        // Page transitions — smooth iOS-style slide from right
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // ── Initial Route ─────────────────────────────────────────────────────
      // _LaunchRouter decides where to send the user based on saved session.
      home: const _LaunchRouter(),
      // ── Named Routes ──────────────────────────────────────────────────────
      routes: {
        // Auth flow
        '/before-login':              (_) => const OnboardingScreen(),
        LoginScreen.routeName:        (_) => const LoginScreen(),
        SignupScreen.routeName:        (_) => const SignupScreen(),

        // Post-login router (re-checks role and sends to correct section)
        '/after-login':               (_) => const _AfterLoginRouter(),

        // Owner section
        OwnerDashboard.routeName:     (_) => const OwnerDashboard(),
        OwnerUsersPage.routeName:     (_) => const OwnerUsersPage(),
        OwnerClusterPage.routeName:   (_) => const OwnerClusterPage(),
        OwnerLogsPage.routeName:      (_) => const OwnerLogsPage(),
        '/profile':                    (_) => const ProfilePage(),

        // Customer section — uncomment when Cheryl's branch merges
        // '/home': (_) => const HomePage(),

        // Admin / Mod sections — keep your existing routes
        // AdminDashboard.routeName:  (_) => const AdminDashboard(),
        // ModDashboard.routeName:    (_) => const ModDashboard(),
      },
      // ── Unknown Route Handler ─────────────────────────────────────────────
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const _NotFoundPage(),
      ),
    );
  }
}

// =============================================================================
//  _LaunchRouter
//  Checks SharedPreferences on cold-start and routes accordingly:
//    • No saved session    → Onboarding (/before-login)
//    • Onboarding not seen → Onboarding
//    • Has session         → appropriate section based on role
// =============================================================================
class _LaunchRouter extends StatefulWidget {
  const _LaunchRouter();

  @override
  State<_LaunchRouter> createState() => _LaunchRouterState();
}

class _LaunchRouterState extends State<_LaunchRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(Duration.zero); // let the frame render first
    if (!mounted) return;

    final userId = await Session.getUserId();
    final hasSeenOnboarding = await Session.hasSeenOnboarding();

    if (userId == null) {
      // Not logged in
      _push(hasSeenOnboarding ? LoginScreen.routeName : '/before-login');
      return;
    }

    // Logged in — send to the right section
    final role = (await Session.getUserGroup() ?? '').toLowerCase();
    _push(_routeForRole(role));
  }

  String _routeForRole(String role) {
    if (role == 'admin' || role == 'administrator') return '/admin';
    if (role == 'moderator') return '/moderator';
    if (role == 'owner') return OwnerDashboard.routeName;
    return '/home'; // customer default
  }

  void _push(String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // Splash / loading screen while we check the session
    return Scaffold(
      backgroundColor: AdminColors.drawerBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Hello Sarawak',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your journey begins here',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _AfterLoginRouter
//  Called after every successful login/sign-up to redirect to correct section.
//  Replaces the current route so the user cannot navigate back to login.
// =============================================================================
class _AfterLoginRouter extends StatefulWidget {
  const _AfterLoginRouter();

  @override
  State<_AfterLoginRouter> createState() => _AfterLoginRouterState();
}

class _AfterLoginRouterState extends State<_AfterLoginRouter> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final role = (await Session.getUserGroup() ?? '').toLowerCase();
    String route;
    if (role == 'admin' || role == 'administrator') {
      route = '/admin';
    } else if (role == 'moderator') {
      route = '/moderator';
    } else if (role == 'owner') {
      route = OwnerDashboard.routeName;
    } else {
      route = '/home';
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AdminColors.drawerBg,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ),
    );
  }
}

// =============================================================================
//  MFA Screen route — note: we use a pushNamed variant so it can be pushed
//  from LoginScreen. Pass tempToken via arguments.
//
//  In LoginScreen call:
//    Navigator.of(context).push(MaterialPageRoute(
//      builder: (_) => MfaScreen(tempToken: tempToken),
//    ));
//
//  Or add a named route here if you prefer:
//  '/mfa': (ctx) {
//    final token = ModalRoute.of(ctx)!.settings.arguments as String;
//    return MfaScreen(tempToken: token);
//  }
// =============================================================================

// =============================================================================
//  404 — Unknown Route Fallback
// =============================================================================
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: AdminColors.textMuted.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'Page not found',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The route you\'re looking for doesn\'t exist.',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/before-login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.drawerBg,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              child: Text(
                'Go Home',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}