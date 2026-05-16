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
import 'package:google_fonts/google_fonts.dart';
import 'customer/customer_rooms.dart';
import 'customer/customer_cart.dart';
import 'customer/customer_bookings.dart';
import 'customer/customer_notification.dart';
import 'beforeLogin/pre_customer_room.dart';
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
// Export AppRole for use in navigation
export 'shared_admin_moderator/user_management.dart' show AppRole;
import 'profile_page.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/rbac_test_screen.dart';
import 'forget_password.dart';
import 'services/session.dart';
import 'services/rbac_service.dart';

// Global navigator key (kept inside app.dart as requested)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Wraps a widget with Outfit font theme for admin/moderator pages
Widget _outfit(BuildContext context, Widget child) => Theme(
  data: Theme.of(context).copyWith(
    textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
  ),
  child: child,
);
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
        '/onboarding': (context) => const OnboardingScreen(),
        '/before-login': (context) => const CustomerRoomsNotLogin(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forget-password': (context) => const ForgotPasswordRequestPage(),
        // Centralized post-login redirect so routing happens in app.dart
        '/after-login': (context) => const _PostLoginRedirect(),
        '/home': (context) => const RoomsPage(),
        '/profile': (context) => const ProfilePage(),
        '/admin': (context) => _outfit(context, const AdminDashboard()),
        '/moderator': (context) => _outfit(context, const ModeratorDashboard()),
        '/owner': (context) => const OwnerDashboard(),
        '/customer': (context) => const RoomsPage(),
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
        // Customer routes
        '/customer-cart': (context) => const CustomerCart(),
        '/customer-bookings': (context) => const CustomerBookings(),
        '/customer-notifications': (context) => const CustomerNotifications(),
        // Admin routes
        '/admin-notifications': (context) => _outfit(context, const AdminNotifications()),
        '/admin-customers': (context) => _outfit(context, const AdminUserManagementPage(viewerRole: AppRole.admin)),
        '/admin-moderators': (context) => _outfit(context, const AdminUserManagementPage(viewerRole: AppRole.admin)),
        '/admin-stock-manager': (context) => _outfit(context, const AdminStockManagerPage()),
        '/admin-activity-logs': (context) => _outfit(context, const AdminActivityLogsPage()),
        '/admin-ledger': (context) => _outfit(context, const AdminLedgerPage()),
        '/admin-customer-reviews': (context) => _outfit(context, const AdminCustomerReviewsPage()),
        // Moderator routes
        '/moderator-notifications': (context) => _outfit(context, const ModeratorNotifications()),
        // Owner routes
        '/owner-property-listing': (context) => const OwnerPropertyListingPage(),
        '/owner-reservation': (context) => const OwnerReservationPage(),
        '/owner-manage-customer': (context) => const OwnerManageCustomers(),
        '/owner-manage-moderatoradmin': (context) => const OwnerManageOperators(),
        '/owner-audit-trails': (context) => const OwnerAuditTrails(),
        '/owner-book-and-pay': (context) => const OwnerBooknPayLog(),
        '/owner-cluster': (context) => const OwnerClusterPage(),
        '/admin-audit-trails': (context) => _outfit(context, const AdminAuditTrails()),
        '/admin-book-and-pay': (context) => _outfit(context, const AdminBooknPayLog()),
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