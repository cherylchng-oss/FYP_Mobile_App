import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../api.dart' as api;
import '../services/session.dart';
import '../shared/customer_layout.dart';
import '../shared/colors.dart';

enum _CustomerProfileTab { personal, security, reviews }

enum _PasswordStrength { none, weak, medium, strong }

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSavingPersonal = false;
  bool _isSavingPassword = false;
  bool _isSavingUsername = false;
  bool _isLoadingReviews = false;
  bool _isDeletingReview = false;
  bool _isUploadingProfileImage = false;

  File? _selectedProfileImage;
  String? _errorMessage;
  int? _userid;
  String? _sessionUsername;

  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _originalUserData = {};

  _CustomerProfileTab _activeTab = _CustomerProfileTab.personal;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedTitle;
  String? _selectedGender;

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  _PasswordStrength _passwordStrength = _PasswordStrength.none;

  List<dynamic> _myReviews = [];

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  static const List<String> _countryOptions = [
    'Malaysia',
    'Singapore',
    'Brunei',
    'Indonesia',
    'Thailand',
    'Philippines',
    'Vietnam',
    'Cambodia',
    'Laos',
    'Myanmar',
    'China',
    'Hong Kong',
    'Taiwan',
    'Japan',
    'South Korea',
    'India',
    'Pakistan',
    'Bangladesh',
    'Sri Lanka',
    'Nepal',
    'Australia',
    'New Zealand',
    'United Kingdom',
    'United States',
    'Canada',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

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

    _loadInitialData();
  }

  @override
  void dispose() {
    _shakeController.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _countryController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userid = await Session.getUserId();
      final username = await Session.getUsername();

      if (userid == null) {
        throw Exception('User not logged in');
      }

      final data = await api.fetchUserData(userid);

      _userid = userid;
      _sessionUsername = username;
      _userData = Map<String, dynamic>.from(data);
      _originalUserData = Map<String, dynamic>.from(data);

      _fillControllers(_userData);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _fetchMyReviews(showError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load profile: $e';
        _isLoading = false;
      });
    }
  }

  void _fillControllers(Map<String, dynamic> data) {
    _firstNameController.text = data['ufirstname']?.toString() ?? '';
    _lastNameController.text = data['ulastname']?.toString() ?? '';
    _emailController.text = data['uemail']?.toString() ?? '';
    _phoneController.text = data['uphoneno']?.toString() ?? '';

    final dob = data['udob']?.toString() ?? '';
    _dobController.text = dob.isNotEmpty ? dob.split('T').first : '';

    _countryController.text = data['ucountry']?.toString() ?? '';
    _usernameController.text = data['username']?.toString() ?? '';

    _selectedTitle = data['utitle']?.toString();
    if (_selectedTitle != null && _selectedTitle!.trim().isEmpty) {
      _selectedTitle = null;
    }

    _selectedGender = data['ugender']?.toString();
    if (_selectedGender != null && _selectedGender!.trim().isEmpty) {
      _selectedGender = null;
    }
  }

  List<dynamic> _normalizeArray(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['reviews'] is List) return data['reviews'];
    if (data is Map && data['data'] is List) return data['data'];
    if (data is Map && data['rows'] is List) return data['rows'];
    return [];
  }

  Future<void> _fetchMyReviews({bool showError = true}) async {
    final userid = _userid;
    if (userid == null) return;

    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final username =
          _sessionUsername ?? _userData['username']?.toString() ?? '';

      final uri = Uri.parse(
        '${api.API_URL}/user-reviews/$userid?username=${Uri.encodeComponent(username)}',
      );

      final accessToken = await Session.getAccessToken();

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _myReviews = [];
          _isLoadingReviews = false;
        });
        return;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load reviews. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final reviews = _normalizeArray(decoded);

      if (!mounted) return;
      setState(() {
        _myReviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _myReviews = [];
        _isLoadingReviews = false;
      });

      if (showError) {
        _showSnack('Failed to load reviews: $e', isError: true);
      }
    }
  }

  Map<String, dynamic> _buildBasePayload() {
    final data = Map<String, dynamic>.from(_userData);

    data['userid'] = _userid;

    // NEW: Website allows customer to edit username in Security tab.
    data['username'] = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()
        : (_userData['username'] ??
            _originalUserData['username'] ??
            _sessionUsername ??
            '');

    data['ufirstname'] = _firstNameController.text.trim();
    data['ulastname'] = _lastNameController.text.trim();
    data['uemail'] = _emailController.text.trim();
    data['uphoneno'] = _phoneController.text.trim();
    data['udob'] = _dobController.text.trim();
    data['utitle'] = _selectedTitle;
    data['ugender'] = _selectedGender;
    data['ucountry'] = _countryController.text.trim();

    data.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });

    return data;
  }

  bool _isApiSuccess(dynamic response) {
    if (response == null) return true;
    if (response is Map && response['success'] == false) return false;
    return true;
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final userid = _userid;

      if (userid == null) {
        _showSnack('User not logged in.', isError: true);
        return;
      }

      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedProfileImage = File(pickedFile.path);
        _isUploadingProfileImage = true;
      });

      // THIS IS WHERE YOU PUT IT
      final result = await api.uploadAvatar(userid, pickedFile.path);

      final imageUrl = result['imageUrl'] ??
          result['data']?['uimage'] ??
          result['uimage'];

      if (imageUrl == null || imageUrl.toString().trim().isEmpty) {
        throw Exception('Upload succeeded but no image URL was returned.');
      }

      if (!mounted) return;

      setState(() {
        _userData['uimage'] = imageUrl;
        _originalUserData['uimage'] = imageUrl;
        _selectedProfileImage = null;
        _isUploadingProfileImage = false;
      });

      _showSnack('Profile picture updated successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingProfileImage = false;
      });

      _showSnack('Failed to update profile picture: $e', isError: true);
    }
  }

  ImageProvider? _profileImageProvider() {
    if (_selectedProfileImage != null) {
      return FileImage(_selectedProfileImage!);
    }

    final imageUrl = _userData['uimage'] ??
        _userData['profileImage'] ??
        _userData['profile_image'] ??
        _userData['profilepicture'];

    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
      return NetworkImage(imageUrl.toString());
    }

    return null;
  }

  bool _hasPersonalInfoChanged() {
    final originalFirstName =
        (_originalUserData['ufirstname'] ?? '').toString().trim();
    final originalLastName =
        (_originalUserData['ulastname'] ?? '').toString().trim();
    final originalEmail =
        (_originalUserData['uemail'] ?? '').toString().trim();
    final originalPhone =
        (_originalUserData['uphoneno'] ?? '').toString().trim();

    final originalDobRaw = (_originalUserData['udob'] ?? '').toString().trim();
    final originalDob =
        originalDobRaw.isNotEmpty ? originalDobRaw.split('T').first : '';

    final originalCountry =
        (_originalUserData['ucountry'] ?? '').toString().trim();
    final originalTitle =
        (_originalUserData['utitle'] ?? '').toString().trim();
    final originalGender =
        (_originalUserData['ugender'] ?? '').toString().trim();

    final currentFirstName = _firstNameController.text.trim();
    final currentLastName = _lastNameController.text.trim();
    final currentEmail = _emailController.text.trim();
    final currentPhone = _phoneController.text.trim();
    final currentDob = _dobController.text.trim();
    final currentCountry = _countryController.text.trim();
    final currentTitle = (_selectedTitle ?? '').trim();
    final currentGender = (_selectedGender ?? '').trim();

    return currentFirstName != originalFirstName ||
        currentLastName != originalLastName ||
        currentEmail != originalEmail ||
        currentPhone != originalPhone ||
        currentDob != originalDob ||
        currentCountry != originalCountry ||
        currentTitle != originalTitle ||
        currentGender != originalGender;
  }

  Future<void> _savePersonalInfo() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final dob = _dobController.text.trim();

    final nameRegex = RegExp(r'^[A-Za-z\s]+$');
    final phoneRegex = RegExp(r'^[0-9]+$');
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (firstName.isNotEmpty && !nameRegex.hasMatch(firstName)) {
      _shakeAndShow('First name should only contain letters and spaces.');
      return;
    }

    if (lastName.isNotEmpty && !nameRegex.hasMatch(lastName)) {
      _shakeAndShow('Last name should only contain letters and spaces.');
      return;
    }

    if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
      _shakeAndShow('Please enter a valid email address.');
      return;
    }

    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      _shakeAndShow('Phone number should only contain numbers.');
      return;
    }

    if (dob.isNotEmpty && DateTime.tryParse(dob) == null) {
      _shakeAndShow('Please enter a valid date of birth.');
      return;
    }

    setState(() {
      _isSavingPersonal = true;
    });

    try {
      final payload = _buildBasePayload();
      final response = await api.updateProfile(payload);

      if (!_isApiSuccess(response)) {
        throw Exception(response?['message'] ?? 'Failed to update profile');
      }

      if (!mounted) return;

      setState(() {
        _userData = Map<String, dynamic>.from(payload);
        _originalUserData = Map<String, dynamic>.from(payload);
        _isSavingPersonal = false;
      });

      _showSnack('Profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingPersonal = false;
      });
      _shakeAndShow('Failed to update profile: $e');
    }
  }

  bool _hasUsernameChanged() {
    final currentUsername = _usernameController.text.trim();
    final originalUsername =
        (_originalUserData['username'] ?? _userData['username'] ?? '')
            .toString()
            .trim();

    return currentUsername.isNotEmpty && currentUsername != originalUsername;
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    final usernameRegex = RegExp(r'^[a-zA-Z0-9]+$');

    if (username.isEmpty) {
      _shakeAndShow('Username cannot be empty.');
      return;
    }

    if (username.length < 6) {
      _shakeAndShow('Username must be at least 6 characters.');
      return;
    }

    if (!usernameRegex.hasMatch(username)) {
      _shakeAndShow('Username must only contain letters and numbers.');
      return;
    }

    if (!_hasUsernameChanged()) {
      return;
    }

    setState(() {
      _isSavingUsername = true;
    });

    try {
      final payload = _buildBasePayload();
      payload['username'] = username;

      final response = await api.updateProfile(payload);

      if (!_isApiSuccess(response)) {
        throw Exception(response?['message'] ?? 'Failed to update username');
      }

      await Session.setUsername(username);

      if (!mounted) return;

      setState(() {
        _userData['username'] = username;
        _originalUserData['username'] = username;
        _sessionUsername = username;
        _isSavingUsername = false;
      });

      _showSnack('Username updated successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingUsername = false;
      });

      _shakeAndShow('Failed to update username: $e');
    }
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');

    if (password.isEmpty) {
      _shakeAndShow('Please enter a new password.');
      return;
    }

    if (!passwordRegex.hasMatch(password)) {
      _shakeAndShow(
        'Password must be at least 8 characters and include letters and numbers.',
      );
      return;
    }

    if (password != confirmPassword) {
      _shakeAndShow('Passwords do not match.');
      return;
    }

    setState(() {
      _isSavingPassword = true;
    });

    try {
      final payload = _buildBasePayload();
      payload['password'] = password;

      final response = await api.updateProfile(payload);

      if (!_isApiSuccess(response)) {
        throw Exception(response?['message'] ?? 'Failed to update password');
      }

      if (!mounted) return;

      setState(() {
        _passwordController.clear();
        _confirmPasswordController.clear();
        _passwordStrength = _PasswordStrength.none;
        _isSavingPassword = false;
      });

      _showSnack('Password updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingPassword = false;
      });
      _shakeAndShow('Failed to update password: $e');
    }
  }

  Future<void> _deleteReview(dynamic review) async {
    final reviewId = review['id'];
    final propertyId = review['propertyId'] ?? review['propertyid'];

    if (reviewId == null) {
      _showSnack('Unable to delete this review.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text(
          'Delete Review',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'Are you sure you want to delete your review?',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeletingReview = true;
    });

    try {
      final username =
          _sessionUsername ?? _userData['username']?.toString() ?? '';

      final accessToken = await Session.getAccessToken();

      final uri = Uri.parse(
        '${api.API_URL}/reviews/$reviewId?creatorUsername=${Uri.encodeComponent(username)}',
      );

      print('CustomerProfile: Delete review URL: $uri');

      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      );

      print('CustomerProfile: Delete review status: ${response.statusCode}');
      print('CustomerProfile: Delete review body: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to delete review. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }

      if (!mounted) return;

      setState(() {
        _myReviews = _myReviews.where((r) => r['id'] != reviewId).toList();
        _isDeletingReview = false;
      });

      _showSnack('Your review has been deleted.');

      if (propertyId != null && _userid != null) {
        debugPrint('Deleted review for property $propertyId by user $_userid');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingReview = false;
      });

      _showSnack('Failed to delete review: $e', isError: true);
    }
  }

  void _discardPersonalChanges() {
    _fillControllers(_originalUserData);
    setState(() {});
  }

  Future<void> _pickDateOfBirth() async {
    DateTime initialDate = DateTime(2000, 1, 1);

    final currentDob = _dobController.text.trim();
    if (currentDob.isNotEmpty) {
      final parsedDob = DateTime.tryParse(currentDob);
      if (parsedDob != null) {
        initialDate = parsedDob;
      }
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AdminColors.primary,
              onPrimary: Colors.white,
              onSurface: AdminColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    final formattedDate =
        '${pickedDate.year.toString().padLeft(4, '0')}-'
        '${pickedDate.month.toString().padLeft(2, '0')}-'
        '${pickedDate.day.toString().padLeft(2, '0')}';

    setState(() {
      _dobController.text = formattedDate;
    });
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

  void _shakeAndShow(String message) {
    _shakeController.forward(from: 0);
    _showSnack(message, isError: true);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    final String type = isError ? 'error' : 'success';

    Color bgColor = AdminColors.primaryLight;
    if (type == 'error') {
      bgColor = AdminColors.danger;
    } else if (type == 'warning') {
      bgColor = AdminColors.warning;
    } else if (type == 'success') {
      bgColor = AdminColors.success;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                type == 'error'
                    ? Icons.error_outline_rounded
                    : type == 'success'
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
  }

  String _displayName() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();

    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;

    return 'Customer';
  }

  String _displayEmail() {
    final email = _emailController.text.trim();
    return email.isNotEmpty ? email : 'No email provided';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    final body = Column(
      children: [
        _buildProfileHeader(topPad),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AdminColors.primary,
                  ),
                )
              : RefreshIndicator(
                  color: AdminColors.primary,
                  onRefresh: _loadInitialData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: SlideTransition(
                      position: _shakeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) _buildErrorBanner(),
                          _buildTabs(),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildActiveTabContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );

    return CustomerLayout(
      selectedIndex: 3,
      backgroundColor: AdminColors.cream,
      body: body,
    );
  }

  Widget _buildProfileHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/profile.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3D1E0C).withOpacity(0.68),
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
                  child: Text(
                    'My Profile',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingProfileImage ? null : _pickAndUploadProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              backgroundImage: _profileImageProvider(),
                              child: _profileImageProvider() == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 42,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AdminColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: _isUploadingProfileImage
                                    ? const SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _displayEmail(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.76),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'customer',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(
            tab: _CustomerProfileTab.personal,
            icon: Icons.person_outline,
            label: 'Personal',
          ),
          _buildTabButton(
            tab: _CustomerProfileTab.security,
            icon: Icons.lock_outline,
            label: 'Security',
          ),
          _buildTabButton(
            tab: _CustomerProfileTab.reviews,
            icon: Icons.star_border_rounded,
            label: 'Reviews',
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required _CustomerProfileTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = tab;
          });

            if (tab == _CustomerProfileTab.reviews && _myReviews.isEmpty) {
              _fetchMyReviews();
            }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? AdminColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : AdminColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? Colors.white : AdminColors.textMuted,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case _CustomerProfileTab.personal:
        return _buildPersonalTab();
      case _CustomerProfileTab.security:
        return _buildSecurityTab();
      case _CustomerProfileTab.reviews:
        return _buildReviewsTab();
    }
  }

  Widget _buildPersonalTab() {
    return _buildCard(
      key: const ValueKey('personal'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Update your personal information.',
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'First Name',
            controller: _firstNameController,
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Last Name',
            controller: _lastNameController,
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _buildDatePickerField(
            label: 'Date of Birth',
            controller: _dobController,
            icon: Icons.cake_outlined,
            hint: 'Select date of birth',
          ),
          const SizedBox(height: 14),
          _buildCountryDropdownField(),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: 'Title',
            icon: Icons.workspace_premium_outlined,
            value: _selectedTitle,
            hint: 'Select title',
            items: const ['Mr.', 'Mrs.', 'Ms.', 'Miss', 'Madam'],
            onChanged: (value) {
              setState(() {
                _selectedTitle = value;
              });
            },
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: 'Gender',
            icon: Icons.wc_outlined,
            value: _selectedGender,
            hint: 'Select gender',
            items: const ['Male', 'Female', 'Other'],
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 22),
          Builder(
            builder: (context) {
              final hasChanges = _hasPersonalInfoChanged();

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          (!hasChanges || _isSavingPersonal) ? null : _discardPersonalChanges,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.primary,
                        disabledForegroundColor: AdminColors.textMuted,
                        side: BorderSide(
                          color: hasChanges ? AdminColors.primary : AdminColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (!hasChanges || _isSavingPersonal) ? null : _savePersonalInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        disabledBackgroundColor: AdminColors.surface,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AdminColors.textMuted,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _isSavingPersonal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    final passwordsMatch = _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;

    return _buildCard(
      key: const ValueKey('security'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.lock_outline,
            title: 'Security & Access',
            subtitle: 'Manage your username, password and two-factor authentication.',
          ),
          const SizedBox(height: 18),
          Text(
            'Username',
            style: AppTextStyles.label.copyWith(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildInputBox(
                  controller: _usernameController,
                  icon: Icons.person_outline,
                  hint: 'Username',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: (!_hasUsernameChanged() || _isSavingUsername)
                    ? null
                    : _saveUsername,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  disabledBackgroundColor: AdminColors.surface,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AdminColors.textMuted,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSavingUsername
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            'Change Password',
            style: AppTextStyles.label.copyWith(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildInputBox(
            controller: _passwordController,
            icon: Icons.lock_outline,
            hint: 'New password',
            obscureText: !_showPassword,
            onChanged: (value) {
              setState(() {
                _passwordStrength = _calculatePasswordStrength(value);
              });
            },
            suffix: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility : Icons.visibility_off,
                color: AdminColors.textMuted,
              ),
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
            ),
          ),
          _buildPasswordStrengthBar(),
          const SizedBox(height: 14),
          _buildInputBox(
            controller: _confirmPasswordController,
            icon: Icons.lock_reset_outlined,
            hint: 'Confirm password',
            obscureText: !_showConfirmPassword,
            onChanged: (_) => setState(() {}),
            suffix: IconButton(
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: AdminColors.textMuted,
              ),
              onPressed: () {
                setState(() {
                  _showConfirmPassword = !_showConfirmPassword;
                });
              },
            ),
          ),
          if (_confirmPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              passwordsMatch
                  ? '✓ Passwords match'
                  : '✗ Passwords do not match',
              style: TextStyle(
                color: passwordsMatch ? Colors.green : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingPassword ? null : _savePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _isSavingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _buildMfaCard(),
        ],
      ),
    );
  }

  Widget _buildMfaCard() {
    final enabled = _userData['mfa_enabled'] == true ||
        _userData['mfa_enabled']?.toString().toLowerCase() == 'true';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: AdminColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Two-Factor Authentication',
                      style: AppTextStyles.label.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage this setting from the website.',
                      style: AppTextStyles.caption.copyWith(
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.green.withOpacity(0.12)
                  : Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.check_circle : Icons.cancel,
                  size: 13,
                  color: enabled ? Colors.green : Colors.redAccent,
                ),
                const SizedBox(width: 5),
                Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: enabled ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return _buildCard(
      key: const ValueKey('reviews'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.star_border_rounded,
            title: 'My Reviews',
            subtitle: 'View and manage reviews you have posted.',
          ),
          const SizedBox(height: 18),
          if (_isLoadingReviews)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: CircularProgressIndicator(color: AdminColors.primary),
              ),
            )
          else if (_myReviews.isEmpty)
            _buildEmptyReviews()
          else
            Column(
              children: _myReviews.map((review) {
                return _buildReviewCard(review);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            color: AdminColors.primary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'No Reviews Yet',
            style: AppTextStyles.h4.copyWith(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have not reviewed any properties yet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AdminColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    final propertyName = review['propertyName'] ??
        review['propertyname'] ??
        review['propertyaddress'] ??
        'Unknown Property';

    final comment = review['comment'] ?? review['review'] ?? 'No comment';

    final ratingRaw = review['rating'] ?? 5;
    final rating = double.tryParse(ratingRaw.toString()) ?? 5.0;
    final agodaScore = (rating * 2).toStringAsFixed(1);

    final datePosted = review['datePosted'] ??
        review['dateposted'] ??
        review['created_at'] ??
        review['createdat'] ??
        '';

    final displayDate = datePosted.toString().isNotEmpty
        ? datePosted.toString().split('T').first
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.home_work_outlined,
                  color: AdminColors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyName.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Posted on $displayDate',
                      style: AppTextStyles.caption.copyWith(
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  agodaScore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$comment"',
            style: AppTextStyles.bodySmall.copyWith(
              color: AdminColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _scoreChip('Loc', review['location_score']),
              _scoreChip('Clean', review['cleanliness_score']),
              _scoreChip('Val', review['value_score']),
              _scoreChip('Fac', review['facilities_score']),
              _scoreChip('Svc', review['service_score']),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isDeletingReview ? null : () => _deleteReview(review),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String label, dynamic value) {
    final display = value?.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        '$label: $display',
        style: AppTextStyles.caption.copyWith(
          color: AdminColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required Key key,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AdminColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h4.copyWith(
                  color: AdminColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AdminColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        _buildInputBox(
          controller: controller,
          icon: icon,
          keyboardType: keyboardType,
          hint: hint ?? 'Enter ${label.toLowerCase()}',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: _pickDateOfBirth,
          child: AbsorbPointer(
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border),
              ),
              child: TextField(
                controller: controller,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AdminColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AdminColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: AdminColors.primary,
                  ),
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: AdminColors.textMuted,
                    size: 19,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryDropdownField() {
    final currentCountry = _countryController.text.trim();
    final validCountry =
        _countryOptions.contains(currentCountry) ? currentCountry : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country',
          style: AppTextStyles.label.copyWith(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.border),
          ),
          child: DropdownButtonFormField<String>(
            value: validCountry,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.public_outlined,
                color: AdminColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            hint: Text(
              'Select country',
              style: AppTextStyles.bodySmall.copyWith(
                color: AdminColors.textMuted,
              ),
            ),
            items: _countryOptions
                .map(
                  (country) => DropdownMenuItem<String>(
                    value: country,
                    child: Text(country),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _countryController.text = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        style: AppTextStyles.bodySmall.copyWith(
          color: AdminColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: AdminColors.textMuted,
          ),
          prefixIcon: Icon(
            icon,
            color: AdminColors.primary,
          ),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final validValue = items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.border),
          ),
          child: DropdownButtonFormField<String>(
            value: validValue,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: AdminColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            hint: Text(
              hint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AdminColors.textMuted,
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
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
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            color: Colors.orange.shade700,
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }
}