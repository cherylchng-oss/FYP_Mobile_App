import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api.dart' as api;
import '../services/session.dart';
import '../shared/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background image — Firebase Storage path: gs://fypcams2026.firebasestorage.app/images/WaterFront.jpeg
//
// The HTTPS URL uses %2F to encode the "/" in the "images/" subfolder.
// If the image stops loading, refresh the token:
//   Firebase Console → Storage → images/WaterFront.jpeg
//   → three-dot menu → "Get download URL" → paste the new token value below.
// ─────────────────────────────────────────────────────────────────────────────
const _kBgUrl =
    'https://firebasestorage.googleapis.com/v0/b/fypcams2026.firebasestorage.app'
    '/o/images%2FWaterFront.jpeg?alt=media&token=0b18d4a9-94cc-4c61-83af-b2e8e0df434f';

// No flat overlay — gradient is applied inline in the build method.

// "Sign Up with Email" warm amber — AdminColors.accent shade
const _kBtnEmail = Color(0xFFB88746);

// "Continue with Google" near-black espresso
const _kBtnGoogle = Color(0xFF1A0F07);

// ─────────────────────────────────────────────────────────────────────────────
//  Page data
// ─────────────────────────────────────────────────────────────────────────────
class _PageData {
  final String eyebrow;
  final String title;
  final String body;

  const _PageData({
    required this.eyebrow,
    required this.title,
    required this.body,
  });
}

const _kPages = [
  _PageData(
    eyebrow: 'EXPLORE SARAWAK',
    title: 'Your Story\nBegins Here',
    body:
        'Discover the land of hornbills, ancient caves,\nand living traditions.',
  ),
  _PageData(
    eyebrow: 'FIND YOUR STAY',
    title: 'Perfect\nHomestays',
    body:
        'Browse and book cozy homestays across\nall 12 divisions of Sarawak.',
  ),
  _PageData(
    eyebrow: 'WELCOME HOME',
    title: 'Begin Your\nJourney',
    body:
        'Join a community of explorers and discover\nthe hidden gems of Sarawak.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _googleLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _nextPage() {
    if (_currentPage < _kPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _goToSignup() async {
    await Session.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _goToLogin() async {
    await Session.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _skipOnboarding() async {
    await Session.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/before-login');
  }

  // ── Google Sign-In (same logic as login_screen.dart) ──────────────────────

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final gsi = GoogleSignIn(scopes: ['email', 'profile']);
      try {
        await gsi.signOut();
      } catch (_) {}

      final googleUser = await gsi.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final auth = await googleUser.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null) throw Exception('Failed to get Google access token');

      final res = await api.googleLogin(accessToken);
      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Google login failed');
      }

      // Save session
      final userid = (res['userid'] as num).toInt();
      final usergroup = (res['usergroup'] as String).trim().toLowerCase();
      final uactivation = (res['uactivation'] as String).trim().toLowerCase();
      final username =
          res['username'] as String? ?? googleUser.email.split('@')[0];

      await Session.saveLogin(
        userid: userid,
        usergroup: usergroup,
        uactivation: uactivation,
        username: username,
      );
      if (res['accessToken'] != null && res['refreshToken'] != null) {
        await Session.saveTokens(
          accessToken: res['accessToken'] as String,
          refreshToken: res['refreshToken'] as String,
        );
      }
      await Session.markOnboardingSeen();

      if (!mounted) return;
      setState(() => _googleLoading = false);
      FocusScope.of(context).unfocus();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/after-login');
    } catch (e) {
      if (mounted) {
        setState(() => _googleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AdminColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF2C1A0E),
        body: Stack(
          children: [
            // ── Hero background photo ──────────────────────────────────────
            // Loaded from Firebase Storage (images/WaterFront.jpeg).
            // Uses CachedNetworkImage so the JPEG is stored on disk after the
            // first load — subsequent launches paint instantly without a network
            // round-trip.
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _kBgUrl,
                fit: BoxFit.cover,
                // Show the dark brand colour while the image loads (first run)
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF2C1A0E)),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF2C1A0E)),
              ),
            ),

            // ── Gradient overlay ───────────────────────────────────────────
            // Transparent at top so the sky shows through; darkens toward the
            // bottom to keep text legible — matching the website's look.
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Color(0x1A2C1A0E), // ~10 % — sky stays vivid
                      Color(0x552C1A0E), // ~33 % — soft mid-tone
                      Color(0x992C1A0E), // ~60 % — readable text zone
                      Color(0xCC2C1A0E), // ~80 % — bottom anchors buttons
                    ],
                  ),
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Skip button (hidden on last page)
                  Align(
                    alignment: Alignment.topRight,
                    child: AnimatedOpacity(
                      opacity: _currentPage < _kPages.length - 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 18, right: 24),
                        child: GestureDetector(
                          onTap: _skipOnboarding,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'SKIP',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pages
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _kPages.length,
                      onPageChanged: (i) {
                        HapticFeedback.lightImpact();
                        setState(() => _currentPage = i);
                      },
                      itemBuilder: (_, i) => _OnboardingPage(
                        data: _kPages[i],
                        isLast: i == _kPages.length - 1,
                        currentDot: _currentPage,
                        totalDots: _kPages.length,
                        onNext: _nextPage,
                        onSignup: _goToSignup,
                        onGoogle: _googleLoading ? null : _googleSignIn,
                        onLogin: _goToLogin,
                        googleLoading: _googleLoading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual onboarding page
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final bool isLast;
  final int currentDot;
  final int totalDots;
  final VoidCallback onNext;
  final VoidCallback onSignup;
  final VoidCallback? onGoogle;
  final VoidCallback onLogin;
  final bool googleLoading;

  const _OnboardingPage({
    required this.data,
    required this.isLast,
    required this.currentDot,
    required this.totalDots,
    required this.onNext,
    required this.onSignup,
    required this.onGoogle,
    required this.onLogin,
    required this.googleLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Upper spacer: lets the photo breathe at the top ───────────────
        const Spacer(),

        // ── Text block ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Eyebrow
              Text(
                data.eyebrow,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 18),

              // Body / subtitle
              Text(
                data.body,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 44),

        // ── CTA: last page = signup buttons, other pages = NEXT pill ──────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: isLast ? _buildLastPageCta() : _buildNextButton(),
        ),

        const SizedBox(height: 36),

        // ── Dot indicators ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalDots, (i) {
            final active = i == currentDot;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        // ── Copyright ─────────────────────────────────────────────────────
        Text(
          'SARAWAK HERITAGE & TOURISM © 2024',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withOpacity(0.30),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),

        const SizedBox(height: 22),
      ],
    );
  }

  // ── Last page CTA: two buttons + log-in link ──────────────────────────────
  Widget _buildLastPageCta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sign Up with Email ─────────────────────────────────────────────
        _PillButton(
          onTap: onSignup,
          backgroundColor: _kBtnEmail,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Sign Up with Email',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Continue with Google ───────────────────────────────────────────
        _PillButton(
          onTap: onGoogle,
          backgroundColor: _kBtnGoogle,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          child: googleLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google "G" logo from local assets
                    Image.asset(
                      'assets/google_logo.png',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // Already have an account? Log In ────────────────────────────────
        GestureDetector(
          onTap: onLogin,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Already have an account?  '),
                  TextSpan(
                    text: 'Log In',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pages 1 & 2 CTA: frosted-glass NEXT pill ─────────────────────────────
  Widget _buildNextButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onNext,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(30),
            border:
                Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NEXT',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable pill-shaped button
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final BoxBorder? border;
  final Widget child;

  const _PillButton({
    required this.onTap,
    required this.backgroundColor,
    required this.child,
    this.border,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? widget.backgroundColor.withOpacity(0.55)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(30),
            border: widget.border,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

