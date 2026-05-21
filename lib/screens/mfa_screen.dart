import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart' as api;
import '../services/session.dart';
import '../app.dart';
import '../shared/colors.dart';

class MfaScreen extends StatefulWidget {
  final String tempToken;

  const MfaScreen({super.key, required this.tempToken});

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  int _tab = 0; // 0 = Authenticator, 1 = Email OTP
  final List<TextEditingController> _ctrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _sendingOtp = false;
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _code => _ctrl.map((c) => c.text).join();

  void _clearDigits() {
    for (final c in _ctrl) c.clear();
    _nodes[0].requestFocus();
  }

  Future<void> _sendEmailOtp() async {
    setState(() { _sendingOtp = true; _error = null; });
    try {
      final res = await api.sendEmailOtp(widget.tempToken);
      if (res['success'] == true) {
        setState(() => _otpSent = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent to your email'),
              backgroundColor: AdminColors.success,
            ),
          );
        }
      } else {
        setState(() => _error = res['message'] ?? 'Failed to send code');
      }
    } catch (e) {
      setState(() => _error = 'Failed to send code. Please try again.');
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length != 6) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final method = _tab == 0 ? 'authenticator' : 'email';
      final res = await api.verifyMfaLogin(
        tempToken: widget.tempToken,
        token: code,
        method: method,
      );

      if (res['success'] != true) {
        setState(() { _error = res['message'] ?? 'Invalid or expired code'; _loading = false; });
        _clearDigits();
        return;
      }

      final userid = (res['userid'] as num).toInt();
      final usergroup = (res['usergroup'] as String).trim().toLowerCase();
      final uactivation = (res['uactivation'] as String).trim().toLowerCase();
      final username = res['username'] as String? ?? '';

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

      if (!mounted) return;
      setState(() => _loading = false);
      FocusScope.of(context).unfocus();

      final nav = appNavigatorKey.currentState!;
      nav.popUntil((r) => r.isFirst);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await nav.pushReplacementNamed('/after-login');
    } catch (e) {
      if (mounted) setState(() { _error = 'Verification failed. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _StepIndicator(step: 1),
              const SizedBox(height: 36),
              _buildTitle(),
              const SizedBox(height: 8),
              const Text(
                "Unrecognized device. Please verify it's you.",
                style: TextStyle(color: AdminColors.textSecond, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildTabSwitcher(),
              const SizedBox(height: 28),
              const Text(
                'ENTER 6-DIGIT CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              _buildOtpRow(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AdminColors.danger, fontSize: 13),
                  ),
                ),
              if (_tab == 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _sendingOtp ? null : _sendEmailOtp,
                    child: _sendingOtp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primary),
                          )
                        : Text(
                            _otpSent ? 'Resend Code' : 'Send Code to Email',
                            style: const TextStyle(
                              color: AdminColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    disabledBackgroundColor: AdminColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text(
                          'Complete Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.textPrimary,
                  side: const BorderSide(color: AdminColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'Verify ',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
            ),
          ),
          TextSpan(
            text: 'Identity',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AdminColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabButton(label: 'Authenticator', selected: _tab == 0, onTap: () => _switchTab(0)),
          _TabButton(label: 'Email OTP', selected: _tab == 1, onTap: () => _switchTab(1)),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    if (_tab == index) return;
    setState(() { _tab = index; _error = null; });
    _clearDigits();
    if (index == 1 && !_otpSent) _sendEmailOtp();
  }

  Widget _buildOtpRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: AdminColors.textMuted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, _buildDigitField),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitField(int i) {
    return SizedBox(
      width: 30,
      child: TextField(
        controller: _ctrl[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AdminColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: '0',
          hintStyle: TextStyle(color: AdminColors.border, fontSize: 20),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) {
            _nodes[i + 1].requestFocus();
          } else if (val.isEmpty && i > 0) {
            _nodes[i - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step; // 0-indexed active step

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = i == step;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 44 : 30,
            height: 3,
            decoration: BoxDecoration(
              color: active ? AdminColors.primary : AdminColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AdminColors.primary : AdminColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
