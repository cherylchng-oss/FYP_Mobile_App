import 'dart:ui'; // For ImageFilter (blur)
import 'package:flutter/material.dart';
import 'services/session.dart';
import 'services/rbac_service.dart' as rbac;
import 'api.dart' as api;
import 'app.dart';
import 'shared/navigation_menu.dart' as nav;
import 'shared/bottom_navigation_bar.dart';
import 'shared/colors.dart';
import 'customer/customer_cart.dart';
import 'customer/customer_bookings.dart';
import 'customer/customer_notification.dart';
import 'shared/shared_admin_moderator/user_management.dart';

enum _PasswordStrength { none, weak, medium, strong }

class ProfilePage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfilePage({
    super.key,
    this.userName = 'User',
    this.userEmail = '',
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _userRole;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  bool _isLoading = true;
  String? _errorMessage;
  String? _routeUserRole;
  int _selectedIndex = 3;

  // Store full user data for updates
  Map<String, dynamic>? _fullUserData;

  String? _storedPassword;

  // PayPal & password controllers
  final TextEditingController _paypalController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Edit-profile dialog controllers
  final TextEditingController _editUsernameController =
      TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editDobController = TextEditingController();
  final TextEditingController _editCountryController = TextEditingController();
  String? _editGender;

  // Shake animation for invalid input (dialog)
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  // Password visibility (dialog)
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Password strength
  _PasswordStrength _passwordStrength = _PasswordStrength.none;

  // Saving state inside dialog (for loading spinner)
  bool _isSavingDialog = false;

  Color get _primaryBlue => AdminColors.primary;
  Color get _pageBg => AdminColors.cream;
  Color get _cardBg => AdminColors.cardBg;

  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  final BorderRadius _cardRadius = BorderRadius.circular(16);

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-0.03, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.03, 0), end: const Offset(0.03, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.03, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (_routeUserRole == null && args?['userRole'] != null) {
      _routeUserRole = args?['userRole'].toString();
    }
  }

  @override
  void dispose() {
    _paypalController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _editUsernameController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    _editDobController.dispose();
    _editCountryController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildBaseUpdatePayload(int userid) {
    final payload = {
      'userid': userid,
      'username': _fullUserData!['username'] ?? _userName ?? '',
      'ufirstname': _fullUserData!['ufirstname'] ?? _fullUserData!['firstname'] ?? '',
      'ulastname': _fullUserData!['ulastname'] ?? _fullUserData!['lastname'] ?? '',
      'udob': _fullUserData!['udob'] ?? _fullUserData!['dob'] ?? null,
      'utitle': _fullUserData!['utitle'] ?? _fullUserData!['title'] ?? null,
      'ugender': _fullUserData!['ugender'] ?? _fullUserData!['gender'] ?? null,
      'uemail': _fullUserData!['uemail'] ?? _userEmail ?? '',
      'uphoneno': _fullUserData!['uphoneno'] ?? _userPhone ?? '',
      'ucountry': _fullUserData!['ucountry'] ?? _userAddress ?? '',
      'uzipcode': _fullUserData!['uzipcode'] ?? _fullUserData!['zipcode'] ?? null,
    };

    payload.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    final passwordValue = (_storedPassword ?? '').trim();
    if (passwordValue.isNotEmpty) {
      payload['password'] = passwordValue;
    }

    return payload;
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get user ID from session
      final userid = await Session.getUserId();
      if (userid == null) {
        throw Exception('User not logged in');
      }

      // Fetch user data from API
      final userData = await api.fetchUserData(userid);
      
      // Store full user data for updates
      _fullUserData = userData;

      // Get user role from session
      final userGroup = await Session.getUserGroup();

      if (mounted) {
        setState(() {
          _userName = userData['username'] ?? widget.userName;
          _userEmail = userData['uemail'] ?? widget.userEmail;
          _userPhone = userData['uphoneno']?.toString();
          _userAddress = userData['ucountry'];
          _userRole = userGroup;
          _storedPassword = userData['password']?.toString();
          _isLoading = false;

          // Prefill PayPal ID if backend sends it (check both paypalid and paypal_email)
          _paypalController.text =
              (userData['paypalid'] ?? userData['paypal_email'] ?? '').toString();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _userName = widget.userName;
          _userEmail = widget.userEmail;
          _errorMessage = 'Could not load user data from server: $error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text('Logout', style: TextStyle(color: Colors.black)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Session.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/before-login',
          (route) => false,
        );
      }
    }
  }

  Future<void> _updatePaypal() async {
    final paypalEmail = _paypalController.text.trim();

    if (paypalEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your PayPal email.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(paypalEmail)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      // Get user ID from session
      final userid = await Session.getUserId();
      if (userid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Call API to update PayPal ID
      // Backend requires ALL fields, so we need to include current user data
      if (_fullUserData == null) {
        // Reload user data if not available
        await _loadUserData();
        if (_fullUserData == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load user data. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
      
      // Build update data - PayPal email update only (like website payment tab)
      // Only send userid and paypalid - no password or other fields needed
      final updateData = {
        'userid': userid,
        'paypalid': paypalEmail, // Backend expects 'paypalid' not 'paypal_email'
      };
      
      print('ProfilePage: Updating PayPal ID for userid: $userid');
      print('ProfilePage: PayPal ID: $paypalEmail');
      print('ProfilePage: Update data keys: ${updateData.keys.toList()}');
      
      await api.updateProfile(updateData);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PayPal information updated successfully.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      // Reload user data to reflect changes
      _loadUserData();
    } catch (error) {
      print('Error updating PayPal email: $error');
      
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update PayPal email: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String? get _effectiveRoleString {
    return (_userRole ?? _routeUserRole)?.toLowerCase();
  }

  nav.UserRole? get _userRoleEnum {
    return nav.userRoleFromString(_effectiveRoleString);
  }

  _PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return _PasswordStrength.none;

    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    if (password.length < 6 || !hasNumber || !hasLetter) {
      return _PasswordStrength.weak;
    }
    if (password.length < 8 || !(hasNumber && hasLetter && hasSpecial)) {
      return _PasswordStrength.medium;
    }
    return _PasswordStrength.strong;
  }

  Widget _buildPasswordStrengthBar() {
    if (_passwordStrength == _PasswordStrength.none) {
      return const SizedBox.shrink();
    }

    double value;
    String label;
    Color color;

    switch (_passwordStrength) {
      case _PasswordStrength.weak:
        value = 0.33;
        label = 'Weak';
        color = Colors.redAccent;
        break;
      case _PasswordStrength.medium:
        value = 0.66;
        label = 'Medium';
        color = Colors.orangeAccent;
        break;
      case _PasswordStrength.strong:
        value = 1.0;
        label = 'Strong';
        color = Colors.green;
        break;
      case _PasswordStrength.none:
        value = 0.0;
        label = '';
        color = Colors.transparent;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userName = _userName ?? args?['userName'] ?? widget.userName;
    final userEmail = _userEmail ?? args?['userEmail'] ?? widget.userEmail;
    final userRole = args?['userRole'] ?? _userRole ?? 'customer';
    final roleLower = userRole.toString().toLowerCase();
    final bool canEditPaypal = roleLower == 'owner';
    final navRole = _userRoleEnum;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      drawerEnableOpenDragGesture: false,
      endDrawer: (navRole != null && navRole != nav.UserRole.customer)
          ? MoreMenuDrawer(
              role: navRole,
              onItemSelected: _handleMenuSelection,
              onLogout: _handleLogout,
              currentPageLabel: 'Profile',
            )
          : null,
      body: Column(
        children: [
          _buildProfileHeader(topPad, userName, userEmail, roleLower),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryBlue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) _buildErrorBanner(),
                        _buildMenuSection(),
                        if (canEditPaypal) ...[
                          const SizedBox(height: 16),
                          _buildPaypalSection(),
                        ],
                        const SizedBox(height: 24),
                        _buildLogoutBtn(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: navRole != null
          ? SharedBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onTap: _handleBottomNavTap,
              scaffoldKey: _scaffoldKey,
              role: navRole,
            )
          : null,
    );
  }

  Widget _buildProfileHeader(double topPad, String userName, String userEmail, String roleLower) {
    final roleDisplay = _userRole != null
        ? rbac.RBACService.getRoleDisplayName(_userRole!)
        : roleLower;
    final rawDate = _fullUserData?['created_at']?.toString() ??
        _fullUserData?['createdat']?.toString() ?? '';
    final joinedOn = rawDate.isNotEmpty ? rawDate.split('T').first : '—';

    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/profile.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3D1E0C).withOpacity(0.65),
                    const Color(0xFF8B4A2F).withOpacity(0.58),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('My Profile',
                      style: AppTextStyles.h3.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                child: const Icon(Icons.person,
                                    color: Colors.white, size: 40),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AdminColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userName,
                                    style: AppTextStyles.h3.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(userEmail,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white.withOpacity(0.75))),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Text(roleDisplay.toLowerCase(),
                                      style: AppTextStyles.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoCell(Icons.verified_user_outlined,
                              'Account Status', 'Active', Colors.white),
                          Container(
                              width: 1, height: 36,
                              color: Colors.white.withOpacity(0.2)),
                          _buildInfoCell(Icons.shield_outlined,
                              'MFA Protected', 'Enabled', Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCell(IconData icon, String label, String value, Color valueColor) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: Colors.white.withOpacity(0.6), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.caption.copyWith(
                color: valueColor, fontWeight: FontWeight.w600, fontSize: 11)),
      ],
    );
  }

  Widget _buildProfileStats() {
    final stats = [
      (Icons.apartment, 'Properties\nManaged', AdminColors.primary),
      (Icons.rate_review_outlined, 'Reviews\nReplied', AdminColors.success),
      (Icons.inventory_2_outlined, 'Stock Items\nManaged', AdminColors.accent),
      (Icons.security, 'Security\nScore', AdminColors.warning),
    ];

    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: AdminColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.border),
                boxShadow: [BoxShadow(
                    color: AdminColors.primary.withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: stats[i].$3.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stats[i].$1, size: 16, color: stats[i].$3),
                  ),
                  const SizedBox(height: 8),
                  Text('—',
                      style: AppTextStyles.bodyDefault.copyWith(
                          color: AdminColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(stats[i].$2,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                          color: AdminColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
          if (i < stats.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Profile Information',
              'View and update your personal details',
              () => _showEditProfileDialog()),
          Divider(height: 1, thickness: 1,
              color: AdminColors.border, indent: 16, endIndent: 16),
          _buildMenuItem(Icons.lock_outline, 'Security & Access',
              'Password, MFA and trusted devices',
              () => _showSecurityDialog()),
          Divider(height: 1, thickness: 1,
              color: AdminColors.border, indent: 16, endIndent: 16),
          _buildMenuItem(Icons.settings_outlined, 'Preferences',
              'Notifications, language and theme',
              () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Coming soon'),
                  backgroundColor: AdminColors.primary,
                  duration: const Duration(seconds: 1)))),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AdminColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.label.copyWith(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.caption.copyWith(
                          color: AdminColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 13, color: AdminColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPaypalSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: _primaryBlue.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PayPal Email',
              style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _paypalController,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your PayPal email',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
              filled: true,
              fillColor: AdminColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdminColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdminColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdminColors.primary)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Text('Payment Information',
              style: AppTextStyles.label.copyWith(
                  color: AdminColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'As an owner, you are required to provide your PayPal account for receiving payments.',
            style: AppTextStyles.bodySmall.copyWith(
                color: AdminColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updatePaypal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Update PayPal Information',
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutBtn() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        icon: const Icon(Icons.logout, color: Colors.white, size: 18),
        label: Text('Logout',
            style: AppTextStyles.bodyDefault.copyWith(
                color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: _handleLogout,
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            color: Colors.orange.shade700,
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  Future<void> _showSecurityDialog() async {
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _passwordStrength = _PasswordStrength.none;
    _showNewPassword = false;
    _showConfirmPassword = false;
    _isSavingDialog = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SlideTransition(
          position: _shakeAnimation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: StatefulBuilder(
              builder: (context, setStateSec) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.85),
                          ],
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.7), width: 1.2),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 22, offset: const Offset(0, 10))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40, height: 4,
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(children: [
                                Text('Security & Access',
                                    style: TextStyle(fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark)),
                                const SizedBox(height: 4),
                                Text('Manage your password and MFA settings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13, color: _textMuted)),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            // New Password
                            Text('New Password',
                                style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))],
                              ),
                              child: TextField(
                                controller: _newPasswordController,
                                obscureText: !_showNewPassword,
                                onChanged: (v) => setStateSec(() {
                                  _passwordStrength =
                                      _calculatePasswordStrength(v);
                                }),
                                decoration: InputDecoration(
                                  hintText: 'Enter new password',
                                  hintStyle: TextStyle(
                                      color: _textMuted, fontSize: 13),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: AdminColors.primary),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showNewPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => setStateSec(() =>
                                        _showNewPassword = !_showNewPassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                            _buildPasswordStrengthBar(),

                            const SizedBox(height: 16),

                            // Confirm New Password
                            Text('Confirm New Password',
                                style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))],
                              ),
                              child: TextField(
                                controller: _confirmPasswordController,
                                obscureText: !_showConfirmPassword,
                                decoration: InputDecoration(
                                  hintText: 'Re-enter new password',
                                  hintStyle: TextStyle(
                                      color: _textMuted, fontSize: 13),
                                  prefixIcon: Icon(Icons.lock_reset_outlined,
                                      color: AdminColors.primary),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => setStateSec(() =>
                                        _showConfirmPassword =
                                            !_showConfirmPassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // MFA container
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AdminColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AdminColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AdminColors.primary
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.shield_outlined,
                                          size: 16,
                                          color: AdminColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Multi-Factor Authentication',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textDark)),
                                          const SizedBox(height: 2),
                                          Text(
                                              'Add an extra layer of security to your account.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: _textMuted)),
                                        ],
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AdminColors.primary,
                                        side: const BorderSide(
                                            color: AdminColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 11),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(
                                          Icons.verified_user_outlined,
                                          size: 16),
                                      label: const Text('Enable MFA',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Row(children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _textMuted,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999)),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSavingDialog
                                      ? null
                                      : () async {
                                          final np =
                                              _newPasswordController.text
                                                  .trim();
                                          final cp =
                                              _confirmPasswordController.text
                                                  .trim();
                                          if (np.isEmpty && cp.isEmpty) {
                                            Navigator.of(dialogCtx).pop();
                                            return;
                                          }
                                          if (np.length < 6 ||
                                              !RegExp(r'\d').hasMatch(np)) {
                                            _shakeController.forward(from: 0);
                                            ScaffoldMessenger.of(dialogCtx)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Password must be at least 6 characters and include a number.'),
                                              backgroundColor: Colors.redAccent,
                                            ));
                                            return;
                                          }
                                          if (np != cp) {
                                            _shakeController.forward(from: 0);
                                            ScaffoldMessenger.of(dialogCtx)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Passwords do not match.'),
                                              backgroundColor: Colors.redAccent,
                                            ));
                                            return;
                                          }
                                          final userid =
                                              await Session.getUserId();
                                          if (userid == null) return;
                                          if (_fullUserData == null) {
                                            await _loadUserData();
                                          }
                                          setStateSec(
                                              () => _isSavingDialog = true);
                                          try {
                                            final payload =
                                                _buildBaseUpdatePayload(userid);
                                            payload['password'] = np;
                                            await api.updateProfile(payload);
                                            if (!mounted) return;
                                            setState(() =>
                                                _storedPassword = np);
                                            Navigator.of(dialogCtx).pop();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Password updated successfully.'),
                                              backgroundColor:
                                                  Color(0xFF4CAF50),
                                            ));
                                          } catch (e) {
                                            if (!mounted) return;
                                            setStateSec(() =>
                                                _isSavingDialog = false);
                                            _shakeController.forward(from: 0);
                                            ScaffoldMessenger.of(dialogCtx)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Failed to update password: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ));
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999)),
                                  ),
                                  child: _isSavingDialog
                                      ? const SizedBox(
                                          height: 18, width: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.3,
                                              color: Colors.white))
                                      : const Text('Save',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dialogField(String label, TextEditingController ctrl,
      IconData icon, TextInputType type, {String? hint}) {
    return [
      Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: _textDark)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint ?? 'Enter ${label.toLowerCase()}',
            hintStyle: TextStyle(color: _textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AdminColors.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ];
  }

  // Glassmorphism Edit Profile dialog with username, phone, and password
  Future<void> _showEditProfileDialog() async {
    _editUsernameController.text = _userName ?? widget.userName;
    _editEmailController.text = _userEmail ?? widget.userEmail;
    _editPhoneController.text = _userPhone ?? '';
    _editDobController.text = (_fullUserData?['udob'] ?? _fullUserData?['dob'] ?? '').toString();
    _editCountryController.text = _userAddress ?? '';
    _editGender = (_fullUserData?['ugender'] ?? _fullUserData?['gender'])?.toString();
    _isSavingDialog = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SlideTransition(
            position: _shakeAnimation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(dialogCtx).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.95),
                              Colors.white.withOpacity(0.85),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.3),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Update your personal information.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              ..._dialogField('Username', _editUsernameController,
                                  Icons.person_outline, TextInputType.text),
                              const SizedBox(height: 16),
                              ..._dialogField('Email', _editEmailController,
                                  Icons.email_outlined, TextInputType.emailAddress),
                              const SizedBox(height: 16),
                              ..._dialogField('Phone Number', _editPhoneController,
                                  Icons.phone_outlined, TextInputType.phone),
                              const SizedBox(height: 16),
                              ..._dialogField('Date of Birth', _editDobController,
                                  Icons.cake_outlined, TextInputType.datetime,
                                  hint: 'YYYY-MM-DD'),
                              const SizedBox(height: 16),
                              // Gender
                              Text('Gender',
                                  style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textDark)),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _editGender,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.wc_outlined,
                                        color: AdminColors.primary),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  hint: Text('Select gender',
                                      style: TextStyle(color: _textMuted)),
                                  items: ['Male', 'Female', 'Other',
                                    'Prefer not to say']
                                      .map((g) => DropdownMenuItem(
                                          value: g, child: Text(g)))
                                      .toList(),
                                  onChanged: (val) =>
                                      setStateDialog(() => _editGender = val),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._dialogField('Country', _editCountryController,
                                  Icons.public_outlined, TextInputType.text),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogCtx).pop(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _textMuted,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSavingDialog
                                          ? null
                                          : () async {
                                              await _handleSaveFromDialog(
                                                dialogCtx,
                                                setStateDialog,
                                              );
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AdminColors.primary,
                                        foregroundColor: Colors.white,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: _isSavingDialog
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.3,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Save',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Handles validation + backend update when user taps "Save Changes" in dialog
  Future<void> _handleSaveFromDialog(
    BuildContext dialogCtx,
    void Function(void Function()) setStateDialog,
  ) async {
    final username = _editUsernameController.text.trim();
    final email = _editEmailController.text.trim();
    final phone = _editPhoneController.text.trim();
    final dob = _editDobController.text.trim();
    final country = _editCountryController.text.trim();

    // Username validation: at least 6 characters
    if (username.length < 6) {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(
          content: Text('Username must be at least 6 characters.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Phone validation: digits only if not empty
    final phoneRegex = RegExp(r'^\d+$');
    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(
          content: Text('Phone number should only contain digits.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Get user id
    final userid = await Session.getUserId();
    if (userid == null) {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(
          content: Text('User not logged in.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Ensure we have full user data
    if (_fullUserData == null) {
      await _loadUserData();
      if (_fullUserData == null) {
        _shakeController.forward(from: 0);
        ScaffoldMessenger.of(dialogCtx).showSnackBar(
          const SnackBar(
            content: Text('Failed to load user data. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Build payload
    final updateData = _buildBaseUpdatePayload(userid);
    updateData['username'] = username;
    if (email.isNotEmpty) updateData['uemail'] = email;
    if (phone.isNotEmpty) updateData['uphoneno'] = phone;
    if (dob.isNotEmpty) updateData['udob'] = dob;
    if (_editGender != null) updateData['ugender'] = _editGender;
    if (country.isNotEmpty) updateData['ucountry'] = country;

    setStateDialog(() {
      _isSavingDialog = true;
    });

    try {
      await api.updateProfile(updateData);

      if (!mounted) return;

      // Update local state to reflect immediately in UI
      setState(() {
        _userName = username;
        if (email.isNotEmpty) _userEmail = email;
        if (phone.isNotEmpty) _userPhone = phone;
        if (country.isNotEmpty) _userAddress = country;
      });

      Navigator.of(dialogCtx).pop(); // close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setStateDialog(() {
        _isSavingDialog = false;
      });
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleBottomNavTap(int index) async {
    final role = _userRoleEnum;
    if (role == null) return;

    if (index == 4) {
      // More button - handled by SharedBottomNavigationBar to open drawer
      return;
    }

    if (index == 0) {
      // Dashboard/Home
      String route;
      switch (role) {
        case nav.UserRole.admin:
          route = '/admin';
          break;
        case nav.UserRole.moderator:
          route = '/moderator';
          break;
        case nav.UserRole.owner:
          route = '/owner';
          break;
        case nav.UserRole.customer:
          route = '/home';
          break;
      }
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(route, (route) => false);
      } else {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(route, (route) => false);
      }
      return;
    }

    if (index == 1) {
      // Properties/Cart
      if (role == nav.UserRole.customer) {
        Navigator.of(context).pushReplacementNamed('/customer-cart');
      } else if (role == nav.UserRole.owner) {
        Navigator.of(context).pushReplacementNamed('/owner-property-listing');
      } else {
        Navigator.of(context).pushReplacementNamed('/manage-services');
      }
      return;
    }

    if (index == 2) {
      if (role == nav.UserRole.customer) {
        Navigator.of(context).pushReplacementNamed('/customer-bookings');
      } else if (role == nav.UserRole.owner) {
        Navigator.of(context).pushReplacementNamed('/owner-reservation');
      } else if (role == nav.UserRole.admin) {
        Navigator.of(context).pushReplacementNamed('/admin-stock-manager');
      } else {
        Navigator.of(context).pushReplacementNamed('/moderator-stock-manager');
      }
      return;
    }

    if (index == 3) {
      // Profile - already on this page
      if (_selectedIndex != 3) {
        setState(() => _selectedIndex = 3);
      }
    }
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context); // Close drawer first
    final role = _userRoleEnum;
    if (role == null) return;

    switch (label) {
      case 'Dashboard':
        String route;
        switch (role) {
          case nav.UserRole.admin:
            route = '/admin';
            break;
          case nav.UserRole.moderator:
            route = '/moderator';
            break;
          case nav.UserRole.owner:
            route = '/owner';
            break;
          case nav.UserRole.customer:
            route = '/home';
            break;
        }
        final navigator = appNavigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil(route, (route) => false);
        } else {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(route, (route) => false);
        }
        break;
      case 'Profile':
        // Already on profile page
        break;
      case 'Properties':
    
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-property-listing');
        } else {
          Navigator.of(context).pushReplacementNamed('/manage-services');
        }
        break;
      
      case 'Bookings':
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-reservation');
        } else if (role == nav.UserRole.admin) {
          Navigator.of(context).pushReplacementNamed('/admin-stock-manager');
        } else {
          Navigator.of(context).pushReplacementNamed('/moderator-stock-manager');
        }
        break;
      case 'Rooms':
        Navigator.of(context).pushReplacementNamed('/home');
        break;
      case 'Cart':
        Navigator.of(context).pushReplacementNamed('/customer-cart');
        break;
      case 'Notifications':
        Navigator.of(context).pushReplacementNamed('/customer-notifications');
        break;
      case 'User Management':
        // Navigate to user management page with appropriate role
        final appRole = role == nav.UserRole.admin ? AppRole.admin : AppRole.moderator;
        Navigator.of(context).pushReplacementNamed('/user-management', arguments: appRole);
        break;
      case 'Customer':
        // Owner navigation to customer management
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-manage-customer');
        }
        break;
      case 'Moderator/Admin':
        // Owner navigation to moderator/admin management
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-manage-moderatoradmin');
        }
        break;
      case 'BooknPayLog':
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-book-and-pay');
        }
        break;
      case 'AuditTrails':
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-audit-trails');
        }
        break;
      case 'Cluster':
        // Owner navigation to cluster management
        if (role == nav.UserRole.owner) {
          Navigator.of(context).pushReplacementNamed('/owner-cluster');
        }
        break;
      case 'Activity Logs':
        if (role == nav.UserRole.admin) {
          Navigator.of(context).pushReplacementNamed('/admin-activity-logs');
        } else if (role == nav.UserRole.moderator) {
          Navigator.of(context).pushReplacementNamed('/moderator-activity-logs');
        }
        break;
      case 'Ledger':
        if (role == nav.UserRole.admin) {
          Navigator.of(context).pushReplacementNamed('/admin-ledger');
        } else if (role == nav.UserRole.moderator) {
          Navigator.of(context).pushReplacementNamed('/moderator-ledger');
        }
        break;
      case 'Stock Manager':
        if (role == nav.UserRole.admin) {
          Navigator.of(context).pushReplacementNamed('/admin-stock-manager');
        } else if (role == nav.UserRole.moderator) {
          Navigator.of(context).pushReplacementNamed('/moderator-stock-manager');
        }
        break;
      case 'Customer Review':
        Navigator.of(context).pushReplacementNamed('/admin-customer-reviews');
        break;
      case 'Customer Reviews':
        Navigator.of(context).pushReplacementNamed('/moderator-customer-reviews');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigating to $label', style: const TextStyle(color: Colors.white)),
            backgroundColor: _primaryBlue,
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  // Small helper to keep account rows consistent & neat
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
