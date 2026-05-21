import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'customer/home.dart';
import 'customer/customer_rooms.dart';
import 'customer/customer_cart.dart';
import 'customer/customer_bookings.dart';
import 'customer/customer_notification.dart';
import 'customer/customer_profile.dart';
import 'customer/about_sarawak.dart';
import 'customer/about_us.dart';
import 'customer/customer_faq.dart';
import 'beforeLogin/pre_customer_room.dart';
import 'beforeLogin/pre_customer_cart.dart';
import 'beforeLogin/pre_customer_booking.dart';
import 'moderator/moderator_dashboard.dart';
import 'moderator/moderator_notification.dart';
import 'admin/admin_dashboard.dart';
import 'admin/admin_notification.dart';
import 'admin/admin_activity_logs.dart';
import 'admin/admin_stock_manager.dart';
import 'admin/admin_ledger.dart';
import 'admin/admin_customer_reviews.dart';
import 'owner/owner_dashboard.dart';
import 'owner/owner_users_page.dart';
import 'owner/owner_cluster.dart';
import 'admin/admin_audit_trails.dart';
import 'admin/admin_book_and_pay.dart';
import 'moderator/moderator_audit_trails.dart';
import 'moderator/moderator_book_and_pay.dart';
import 'moderator/moderator_ledger.dart';
import 'moderator/moderator_activity_logs.dart';
import 'moderator/moderator_stock_manager.dart';
import 'moderator/moderator_customer_review.dart';
import 'shared_admin_moderator/manage_service.dart';
import 'shared_admin_moderator/user_management.dart';
import 'owner/owner_logs_page.dart';
import 'shared/colors.dart';
import 'profile_page.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/rbac_test_screen.dart';
import 'forget_password.dart';
import 'services/session.dart';
import 'services/rbac_service.dart';

export 'shared_admin_moderator/user_management.dart' show AppRole;

// Global navigator key
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Wraps a widget with Outfit font theme for admin/moderator pages
Widget _outfit(BuildContext context, Widget child) => Theme(
  data: Theme.of(context).copyWith(
    textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
  ),
  child: child,
);

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
      navigatorKey: appNavigatorKey,
      title: 'Hello Sarawak',
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
      home: const _LaunchRouter(),
      routes: {
        OwnerDashboard.routeName: (_) => const OwnerDashboard(),
        OwnerUsersPage.routeName: (_) => const OwnerUsersPage(),
        OwnerClusterPage.routeName: (_) => const OwnerClusterPage(),
        OwnerLogsPage.routeName: (_) => const OwnerLogsPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/before-login': (context) => const CustomerRoomsNotLogin(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forget-password': (context) => const ForgotPasswordRequestPage(),
        '/after-login': (context) => const _PostLoginRedirect(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/admin': (context) => _outfit(context, const AdminDashboard()),
        '/moderator': (context) => _outfit(context, const ModeratorDashboard()),
        '/owner': (context) => const OwnerDashboard(),
        '/customer': (context) => const CustomerRoomsPage(),
        '/manage-services': (context) => _outfit(context, const ManageServicesPage()),
        '/user-management': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          AppRole role;
          if (args is AppRole) {
            role = args;
          } else {
            role = AppRole.admin;
          }
          return _outfit(context, AdminUserManagementPage(viewerRole: role));
        },

        // Pre login routes
        '/pre-customer-rooms': (context) => const CustomerRoomsNotLogin(),
        '/pre-customer-cart': (context) => const CustomerCartNotLogin(),
        '/pre-customer-bookings': (context) => const CustomerBookingsNotLogin(),

        // Customer routes
        '/customer-home': (context) => const HomePage(),
        '/customer-rooms': (context) => const CustomerRoomsPage(),
        '/customer-cart': (context) => const CustomerCart(),
        '/customer-bookings': (context) => const CustomerBookings(),
        '/about-sarawak': (context) => const AboutSarawakPage(),
        '/about-us': (context) => const AboutUsPage(),
        '/customer-faq': (context) => const CustomerFAQ(),
        '/customer-notifications': (context) => const NotificationPage(),
        '/customer-profile': (context) => const CustomerProfilePage(),

        // Admin routes
        '/admin-notifications': (context) => _outfit(context, const AdminNotifications()),
        '/admin-customers': (context) => _outfit(context, AdminUserManagementPage(viewerRole: AppRole.admin)),
        '/admin-moderators': (context) => _outfit(context, AdminUserManagementPage(viewerRole: AppRole.admin)),
        '/admin-stock-manager': (context) => _outfit(context, const AdminStockManagerPage()),
        '/admin-activity-logs': (context) => _outfit(context, const AdminActivityLogsPage()),
        '/admin-ledger': (context) => _outfit(context, const AdminLedgerPage()),
        '/admin-customer-reviews': (context) => _outfit(context, const AdminCustomerReviewsPage()),
        '/admin-audit-trails': (context) => _outfit(context, const AdminAuditTrails()),
        '/admin-book-and-pay': (context) => _outfit(context, const AdminBooknPayLog()),

        // Moderator routes
        '/moderator-notifications': (context) => _outfit(context, const ModeratorNotifications()),
        '/moderator-audit-trails': (context) => _outfit(context, const ModeratorAuditTrails()),
        '/moderator-book-and-pay': (context) => _outfit(context, const ModeratorBooknPayLog()),
        '/moderator-ledger': (context) => _outfit(context, const ModeratorLedger()),
        '/moderator-activity-logs': (context) => _outfit(context, const ModeratorActivityLogsPage()),
        '/moderator-stock-manager': (context) => _outfit(context, const ModeratorStockManagerPage()),
        '/moderator-customer-reviews': (context) => _outfit(context, const ModeratorCustomerReview()),
        '/rbac-test': (context) => const RBACTestScreen(),
      },
    );
  }
}

// Checks session on launch and routes accordingly
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
    final userId = await Session.getUserId();
    if (!mounted) return;

    if (userId == null || userId.toString().isEmpty) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final role = (await Session.getUserGroup() ?? '').toLowerCase().trim();
    if (!mounted) return;
    if (role == 'admin' || role == 'administrator') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else if (role == 'moderator') {
      Navigator.of(context).pushReplacementNamed('/moderator');
    } else if (role == 'owner') {
      Navigator.of(context).pushReplacementNamed('/owner');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

// Routes users to their role-specific home after login
class _PostLoginRedirect extends StatefulWidget {
  const _PostLoginRedirect();

  @override
  State<_PostLoginRedirect> createState() => _PostLoginRedirectState();
}

class _PostLoginRedirectState extends State<_PostLoginRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final role = await Session.getUserGroup();
    if (!mounted) return;
    final normalized = (role ?? '').toLowerCase().trim();
    if (normalized == 'admin' || normalized == 'administrator') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else if (normalized == 'moderator') {
      Navigator.of(context).pushReplacementNamed('/moderator');
    } else if (normalized == 'owner') {
      Navigator.of(context).pushReplacementNamed('/owner');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}