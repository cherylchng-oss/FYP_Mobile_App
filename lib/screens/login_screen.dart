import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api.dart' as api;
import '../services/session.dart';
import '../shared/colors.dart';
import 'mfa_screen.dart';
import 'signup_screen.dart';

// ---------------------------------------------------------------------------
// Login Screen
// Features: Email/Password login, Google Sign-In, MFA support, forgot password
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email/Password Login ──────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await api.loginUser({
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
      });

      if (!mounted) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage =
              body['message']?.toString() ?? 'Invalid username or password.';
        });
        return;
      }

      // MFA required
      if (body['requiresMFA'] == true) {
        final tempToken = body['tempToken']?.toString() ?? '';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MfaScreen(tempToken: tempToken),
          ),
        );
        return;
      }

      // Direct login success
      if (body['success'] == true || body['userid'] != null) {
        await Session.saveLogin(
          userid: (body['userid'] as num?)?.toInt() ?? 0,
          usergroup: body['usergroup']?.toString() ?? '',
          uactivation: body['uactivation']?.toString() ?? 'active',
          username: body['username']?.toString(),
        );
        if (body['accessToken'] != null) {
          await Session.saveTokens(
            accessToken: body['accessToken']?.toString() ?? '',
            refreshToken: body['refreshToken']?.toString() ?? '',
          );
        }
        if (mounted) Navigator.of(context).pushReplacementNamed('/after-login');
      } else {
        setState(() {
          _errorMessage =
              body['message']?.toString() ?? 'Invalid username or password.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null) throw Exception('No access token');

      final response = await api.googleLogin(accessToken);
      if (!mounted) return;

      if (response['success'] == true || response['userid'] != null) {
        await Session.saveLogin(
          userId: response['userid']?.toString() ?? '',
          username: response['username']?.toString() ?? '',
          userGroup: response['usergroup']?.toString() ?? '',
        );
        if (response['accessToken'] != null) {
          await Session.saveTokens(
            accessToken: response['accessToken']?.toString() ?? '',
            refreshToken: response['refreshToken']?.toString() ?? '',
          );
        }
        if (mounted) Navigator.of(context).pushReplacementNamed('/after-login');
      } else {
        setState(() {
          _errorMessage = response['message']?.toString() ??
              'Google sign-in failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  void _handleForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AdminColors.cream,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildForm(),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildLoginButton(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildGoogleButton(),
                    const SizedBox(height: 40),
                    _buildRegisterLink(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminColors.drawerBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome back',
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue to Hello Sarawak',
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildField(
            controller: _usernameController,
            label: 'Username or Email',
            hint: 'Enter your username',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Username is required' : null,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _handleForgotPassword,
              child: Text(
                'Forgot password?',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(hint: hint, icon: icon),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Password is required' : null,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AdminColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AdminColors.textMuted.withOpacity(0.5),
        fontSize: 15,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18, right: 12),
        child: Icon(icon, color: AdminColors.textMuted, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AdminColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AdminColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AdminColors.danger, width: 1.5),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.danger.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AdminColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.drawerBg,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: AdminColors.drawerBg.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Sign In',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AdminColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AdminColors.border, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AdminColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isGoogleLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AdminColors.primary,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.g_mobiledata, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SignupScreen()),
        ),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: "Don't have an account? "),
              TextSpan(
                text: 'Sign Up',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot Password Bottom Sheet
// ---------------------------------------------------------------------------
class _ForgotPasswordSheet extends StatefulWidget {
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AdminColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reset Password',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email and we\'ll send a reset link.',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          if (!_sent) ...[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textMuted.withOpacity(0.5),
                  fontSize: 15,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 18, right: 12),
                  child: Icon(Icons.email_outlined,
                      color: AdminColors.textMuted, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 52),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      BorderSide(color: AdminColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (_emailController.text.trim().isNotEmpty) {
                    setState(() => _sent = true);
                    // TODO: call api.forgotPassword(_emailController.text.trim())
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.drawerBg,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Send Reset Link',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AdminColors.success.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AdminColors.success, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Reset link sent! Check your email inbox.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Back to Login',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}