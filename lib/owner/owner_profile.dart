import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api.dart' as api;
import '../services/session.dart';
import '../shared/colors.dart';
import 'owner_widgets.dart';

// ---------------------------------------------------------------------------
// Owner Profile Page
// Route: /profile  (pushed from any owner nav tab via pushNamed)
// Shows: user info, account settings, security, app info, logout
// ---------------------------------------------------------------------------
class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});
  static const String routeName = '/profile';

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  String _userId = '';
  String _userGroup = '';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = await Session.getUserId();
    final username = await Session.getUsername();
    final userGroup = await Session.getUserGroup();

    // Try fetching full profile from backend
    String email = '';
    try {
      if (userId != null) {
        // fetchUserProfile returns map with email, etc.
        // Adjust key names to match your actual API response
        final profile = await api.fetchUserProfile(userId);
        email = (profile['email'] ?? profile['data']?['email'] ?? '').toString();
      }
    } catch (_) {
      // gracefully skip if endpoint unavailable
    }

    if (!mounted) return;
    setState(() {
      _username = username ?? 'Owner';
      _email = email;
      _userId = userId ?? '';
      _userGroup = userGroup ?? 'owner';
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutDialog(),
    );
    if (confirm != true) return;

    // Sign out Google if applicable
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await Session.clearSession();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/before-login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials =
        _username.isNotEmpty ? _username[0].toUpperCase() : 'O';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AdminColors.cream,
        body: _isLoading
            ? const OwnerLoading()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(initials),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildAccountSection(),
                        _buildSettingsSection(),
                        _buildSecuritySection(),
                        _buildAppSection(),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Cinematic Header ──────────────────────────────────────────────────────
  SliverAppBar _buildHeader(String initials) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: AdminColors.drawerBg,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background photo
            Container(
              decoration: const BoxDecoration(
                color: AdminColors.drawerBg,
                image: DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1596401057633-54a8fe8ef647'
                    '?q=80&w=1200&auto=format&fit=crop',
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color(0xD92C1A0E),
                    BlendMode.srcOver,
                  ),
                ),
              ),
            ),
            // Avatar + name centred in the expanded area
            Align(
              alignment: const Alignment(0, 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AdminColors.primary.withOpacity(0.85),
                      child: Text(
                        initials,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _username,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildRolePill(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        _userGroup.isEmpty
            ? 'Owner'
            : _userGroup[0].toUpperCase() + _userGroup.substring(1),
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Account Info Section ──────────────────────────────────────────────────
  Widget _buildAccountSection() {
    return _buildCard(
      title: 'Account',
      children: [
        _buildInfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Username',
          value: _username.isEmpty ? '—' : _username,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _email.isEmpty ? 'Not set' : _email,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.fingerprint_rounded,
          label: 'User ID',
          value: _userId.isEmpty ? '—' : _userId,
          monospace: true,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.badge_outlined,
          label: 'Role',
          value: _userGroup.isEmpty
              ? 'Owner'
              : _userGroup[0].toUpperCase() + _userGroup.substring(1),
          valueColor: AdminColors.success,
        ),
      ],
    );
  }

  // ── Settings Section ──────────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return _buildCard(
      title: 'Preferences',
      children: [
        _buildToggleRow(
          icon: Icons.notifications_outlined,
          label: 'Push Notifications',
          value: _notificationsEnabled,
          onChanged: (v) => setState(() => _notificationsEnabled = v),
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.language_outlined,
          label: 'Language',
          trailing: 'English',
          onTap: () {},
        ),
      ],
    );
  }

  // ── Security Section ──────────────────────────────────────────────────────
  Widget _buildSecuritySection() {
    return _buildCard(
      title: 'Security',
      children: [
        _buildActionRow(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: () => _showChangePasswordSheet(),
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.shield_outlined,
          label: 'Two-Factor Authentication',
          trailing: 'Manage',
          onTap: () {},
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.devices_outlined,
          label: 'Active Sessions',
          onTap: () {},
        ),
      ],
    );
  }

  // ── App Info Section ──────────────────────────────────────────────────────
  Widget _buildAppSection() {
    return _buildCard(
      title: 'About',
      children: [
        _buildInfoRow(
          icon: Icons.info_outline_rounded,
          label: 'App Version',
          value: '1.0.0',
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          onTap: () {},
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.description_outlined,
          label: 'Privacy Policy',
          onTap: () {},
        ),
        _buildDivider(),
        _buildActionRow(
          icon: Icons.article_outlined,
          label: 'Terms of Service',
          onTap: () {},
        ),
      ],
    );
  }

  // ── Logout Button ─────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded,
              color: AdminColors.danger, size: 20),
          label: Text(
            'Sign Out',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminColors.danger.withOpacity(0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: AdminColors.danger.withOpacity(0.04),
          ),
        ),
      ),
    );
  }

  // ── Reusable Card Wrapper ─────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.textPrimary.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(
        height: 1,
        color: AdminColors.border.withOpacity(0.5),
        indent: 56,
      );

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AdminColors.textMuted),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: monospace
                  ? TextStyle(
                      color: valueColor ?? AdminColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    )
                  : GoogleFonts.plusJakartaSans(
                      color: valueColor ?? AdminColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AdminColors.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AdminColors.textMuted.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AdminColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AdminColors.success,
          ),
        ],
      ),
    );
  }

  // ── Change Password Sheet ─────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Logout Confirmation Dialog
// ---------------------------------------------------------------------------
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.danger.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: AdminColors.danger, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            'Sign Out',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Are you sure you want to sign out of your account?',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AdminColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change Password Bottom Sheet
// ---------------------------------------------------------------------------
class _ChangePasswordSheet extends StatefulWidget {
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_newController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // TODO: call api.changePassword(current, newPassword) when endpoint ready
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password updated successfully.',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: AdminColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to update password. Please try again.';
      });
    }
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
      child: SingleChildScrollView(
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
              'Change Password',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AdminColors.danger.withOpacity(0.20)),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _buildPasswordInput(
              controller: _currentController,
              label: 'Current Password',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 16),
            _buildPasswordInput(
              controller: _newController,
              label: 'New Password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 16),
            _buildPasswordInput(
              controller: _confirmController,
              label: 'Confirm New Password',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.drawerBg,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
                        'Update Password',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
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
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AdminColors.textMuted.withOpacity(0.5),
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 18, right: 12),
              child: Icon(Icons.lock_outline_rounded,
                  color: AdminColors.textMuted, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AdminColors.textMuted,
                size: 20,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
          ),
        ),
      ],
    );
  }
}