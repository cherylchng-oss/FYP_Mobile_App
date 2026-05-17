import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import 'manage_service.dart';
import '../shared/navigation_menu.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../admin/admin_notification.dart';
import '../moderator/moderator_notification.dart';

// Who is using the page right now?
enum AppRole { admin, moderator }

class AdminUserManagementPage extends StatefulWidget {
  final AppRole viewerRole;

  const AdminUserManagementPage({
    Key? key,
    required this.viewerRole,
  }) : super(key: key);

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Bottom nav selection
  int _selectedIndex = -1; // No item selected on user management page

  // Tabs
  String _selectedUserType = 'Customer'; // Customer | Moderator | Admin
  String _selectedStatus = 'All Statuses'; // All Statuses | Active | Inactive

  // Search
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Backend data (loaded from API)
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Notification badge
  int _unreadCount = 0;

  // ===== Theme =====
  Color get kBg => AdminColors.cream;
  Color get kPrimary => AdminColors.primary;
  Color get kPrimaryDeep => AdminColors.primaryLight;
  Color get kCardBg => AdminColors.cardBg;
  Color get kBorder => AdminColors.border;

  static const Color kMuted = Color(0xFF6B7280);

  UserRole get _drawerRole =>
      widget.viewerRole == AppRole.admin ? UserRole.admin : UserRole.moderator;

  List<DrawerMenuItem> get _drawerItems => drawerMenuItemsForRole(_drawerRole);

  Future<void> _loadUnreadCount() async {
    try {
      final userid = await Session.getUserId();

      if (userid == null) return;

      final notifications = await api.fetchNotifications(userid);

      if (!mounted) return;

      setState(() {
        _unreadCount = notifications.where((n) {
          final isRead = n['isread'] ?? n['isRead'] ?? false;
          return isRead == false;
        }).length;
      });
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text('Logout', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
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
        Navigator.pushNamedAndRemoveUntil(context, '/before-login', (route) => false);
      }
    }
  }

  static Color _darken(Color c, [double amount = .1]) {
    final hsl = HSLColor.fromColor(c);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  List<String> get _availableTypes {
    if (widget.viewerRole == AppRole.admin) {
      return const ['Customer', 'Moderator', 'Admin'];
    }
    // Moderator can only see Customers
    return const ['Customer'];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadUnreadCount();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('UserManagement: Loading users for role ${widget.viewerRole}');

      // Always fetch customers for current admin/moderator (backend filters "under this admin/moderator")
      final customersData = await api.fetchCustomers();
      final customers = _extractList(customersData, ['customers', 'data', 'users']);

      final List<Map<String, dynamic>> loaded = [];

      for (final raw in customers) {
        if (raw is Map<String, dynamic>) {
          loaded.add(_normalizeUser(raw, fallbackType: 'Customer'));
        }
      }

      if (widget.viewerRole == AppRole.admin) {
        // For admin viewer: also fetch moderators and administrators
        final moderatorsData = await api.fetchModerators();
        final moderators = _extractList(moderatorsData, ['moderators', 'data', 'users']);
        for (final raw in moderators) {
          if (raw is Map<String, dynamic>) {
            loaded.add(_normalizeUser(raw, fallbackType: 'Moderator'));
          }
        }

        final adminsData = await api.fetchAdministrators();
        final admins = _extractList(adminsData, ['administrators', 'admins', 'data', 'users']);
        for (final raw in admins) {
          if (raw is Map<String, dynamic>) {
            loaded.add(_normalizeUser(raw, fallbackType: 'Admin'));
          }
        }
      }

      setState(() {
        _users = loaded;
      });

      print('UserManagement: Loaded ${_users.length} users');
    } catch (e) {
      print('UserManagement: Error loading users: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Extract a list from a flexible API response using common keys.
  List<dynamic> _extractList(dynamic source, List<String> keys) {
    if (source is List) return source;
    if (source is Map<String, dynamic>) {
      for (final key in keys) {
        final value = source[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// Normalize backend user object into the shape expected by the UI.
  Map<String, dynamic> _normalizeUser(
    Map<String, dynamic> raw, {
    required String fallbackType,
  }) {
    // Try to determine role from common fields
    final dynamic groupRaw = raw['usergroup'] ?? raw['role'] ?? raw['type'];
    String type = fallbackType;
    if (groupRaw is String && groupRaw.trim().isNotEmpty) {
      final g = groupRaw.trim().toLowerCase();
      if (g.contains('admin')) {
        type = 'Admin';
      } else if (g.contains('moderator')) {
        type = 'Moderator';
      } else if (g.contains('customer')) {
        type = 'Customer';
      } else if (g.contains('owner')) {
        type = 'Owner';
      }
    }

    final uid = (raw['userid'] ?? raw['uid'] ?? raw['id'] ?? '').toString();
    final username = (raw['username'] ?? '').toString();

    // Name from firstname/lastname or "name" field
    final firstName = (raw['firstname'] ?? raw['firstName'] ?? raw['ufirstname'] ?? '').toString();
    final lastName = (raw['lastname'] ?? raw['lastName'] ?? raw['ulastname'] ?? '').toString();
    String name;
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      name = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
    } else {
      name = (raw['name'] ?? username).toString();
    }

    final email = (raw['email'] ?? raw['uemail'] ?? '').toString();
    // Check multiple field name variations for phone (backend uses 'uphoneno')
    final phone = (raw['uphoneno'] ?? raw['phone'] ?? raw['phoneNo'] ?? raw['phoneno'] ?? raw['uphone'] ?? '').toString();
    // If phone is empty or "N/A", set to empty string
    final phoneValue = phone.isEmpty || phone.toLowerCase() == 'n/a'
        ? ''
        : phone;
    final country = (raw['country'] ?? raw['countryname'] ?? raw['ucountry'] ?? '').toString();
    final cluster = (raw['cluster'] ?? raw['clustername'] ?? raw['clusterName'])?.toString();

    // Status from active/status flags (including uactivation from backend)
    String status = 'Active';
    final activeField = raw['status'] ?? raw['userStatus'] ?? raw['isActive'] ?? raw['uactivation'];
    if (activeField is bool) {
      status = activeField ? 'Active' : 'Inactive';
    } else if (activeField is String) {
      status = activeField.toLowerCase().contains('inactive') ? 'Inactive' : 'Active';
    }

    return {
      'uid': uid,
      'username': username,
      'name': name,
      'email': email,
      'status': status,
      'type': type,
      'phone': phoneValue,
      'country': country,
      if (raw['password'] != null) 'password': raw['password'].toString(),
      if (cluster != null && cluster.isNotEmpty) 'cluster': cluster,
    };
  }

  // ===== SMART SEARCH (role-aware) =====
  void _performSmartSearch(String query) {
    final q = query.trim().toLowerCase();
    _searchQuery = query;

    if (q.isEmpty) {
      setState(() {});
      return;
    }

    final match = _users.firstWhere(
      (u) => (u['username'] as String).toLowerCase().contains(q),
      orElse: () => <String, dynamic>{},
    );

    if (match.isNotEmpty) {
      final targetType = match['type'] as String;
      // only switch if the viewer can access that tab
      if (_availableTypes.contains(targetType) && targetType != _selectedUserType) {
        setState(() => _selectedUserType = targetType);
        return;
      }
    }

    setState(() {}); // refresh filter on current tab
  }

  // ===== FILTERED VIEW =====
  List<Map<String, dynamic>> get _visibleUsers {
    // Ensure current tab is valid for viewer
    if (!_availableTypes.contains(_selectedUserType)) {
      _selectedUserType = _availableTypes.first;
    }

    final list = _users.where((u) => u['type'] == _selectedUserType).where((u) {
      final s = _searchQuery.trim().toLowerCase();
      final matchesQuery = s.isEmpty ||
          (u['username'] as String).toLowerCase().contains(s) ||
          (u['name'] as String).toLowerCase().contains(s) ||
          (u['email'] as String).toLowerCase().contains(s);

      final matchesStatus = _selectedStatus == 'All Statuses' ||
          (u['status'] == 'Active' && _selectedStatus == 'Active') ||
          (u['status'] == 'Inactive' && _selectedStatus == 'Inactive');

      return matchesQuery && matchesStatus;
    }).toList();
    return list;
  }

  // ===== Header (Stock Manager style) =====
  Widget _buildHeader(double topPad) {
    return SizedBox(
      height: topPad + 110,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/user_management.png',
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
                    const Color(0xFF3D1E0C).withOpacity(0.62),
                    const Color(0xFF8B4A2F).withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: topPad + 24, left: 18, right: 18, bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.manage_accounts, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Management',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.viewerRole == AppRole.admin
                            ? 'Customers, Moderators & Admins'
                            : 'Customer Accounts',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification bell
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => widget.viewerRole == AppRole.admin
                            ? AdminNotifications()
                            : ModeratorNotifications(),
                      ),
                    ).then((_) => _loadUnreadCount());
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53E3E),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_unreadCount',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(topPad),
          _buildTypeChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              color: kPrimary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar()),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  _buildUserSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: _drawerRole,
      ),
    );
  }

  // ===== Search + Filters =====
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          // Search field — takes remaining width
          Expanded(
            flex: 3,
            child: _glass(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  Icon(Icons.search, color: kPrimaryDeep, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _performSmartSearch,
                      cursorColor: kPrimary,
                      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search users…',
                        hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _performSmartSearch('');
                      },
                      child: const Icon(Icons.close, size: 16, color: kMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Status filter — fixed compact width
          Expanded(
            flex: 2,
            child: _glass(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: kMuted),
                  style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
                  dropdownColor: Colors.white,
                  items: const [
                    DropdownMenuItem(value: 'All Statuses', child: Text('All')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v ?? 'All Statuses'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Type Chips =====
  Widget _buildTypeChips() {
    Widget chip(String label) {
      final selected = _selectedUserType == label;
      return GestureDetector(
        onTap: () => setState(() => _selectedUserType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AdminColors.primary : AdminColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? AdminColors.primary : AdminColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == 'Admin'
                    ? Icons.shield
                    : label == 'Moderator'
                        ? Icons.verified_user
                        : Icons.person,
                size: 14,
                color: selected ? Colors.white : AdminColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: selected ? Colors.white : AdminColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AdminColors.cream,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < _availableTypes.length; i++) ...[
              chip(_availableTypes[i]),
              if (i < _availableTypes.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }

  // ===== List (sliver) =====
  Widget _buildUserSliver() {
    if (_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _glass(
              radius: 20,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  Text('Failed to load users', style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Retry', style: AppTextStyles.label.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final data = _visibleUsers;
    if (data.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _glass(
              radius: 20,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 42, color: kMuted),
                  const SizedBox(height: 10),
                  Text('No users found', style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Try adjusting your filters', style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final user = data[i];
            return _glass(
              radius: 18,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatarForType(user['type']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              user['username'],
                              style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary),
                            ),
                            _statusPill(user['status']),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['name'],
                          style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user['email'],
                          style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user['type'] == 'Moderator' && user['cluster'] != null) ...[
                          const SizedBox(height: 6),
                          _tag('Cluster: ${user['cluster']}'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _refinedMenu(user),
                ],
              ),
            );
          },
          childCount: data.length,
        ),
      ),
    );
  }

  // ===== UI helpers =====
  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double radius = 16,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: kCardBg,
        border: Border.all(color: kBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _countPill(int count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count', style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statusPill(String status) {
    final bool active = status == 'Active';
    final Color bg = (active ? AdminColors.success : AdminColors.textMuted).withOpacity(0.12);
    final Color fg = active ? AdminColors.success : AdminColors.textMuted;
    final IconData icon = active ? Icons.check_circle : Icons.pause_circle_filled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(status, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: kPrimaryDeep, fontWeight: FontWeight.w600)),
    );
  }

  Widget _avatarForType(String type) {
    final Color c = type == 'Admin'
        ? kPrimaryDeep
        : type == 'Moderator'
            ? _darken(kPrimary, .05)
            : kPrimary.withOpacity(.9);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        type == 'Admin'
            ? Icons.shield
            : type == 'Moderator'
                ? Icons.verified_user
                : Icons.person,
        color: c,
        size: 26,
      ),
    );
  }

  // ===== Refined Popup Menu (role-based + viewer-aware) =====
  Widget _refinedMenu(Map<String, dynamic> user) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 8,
      onSelected: (v) async {
        switch (v) {
          case 'view':
            _showUserDetails(user);
            break;
          case 'edit':
            _showEditUser(user);
            break;
          case 'suspend':
            _suspendUser(user);
            break;
          case 'activate':
            _activateUser(user);
            break;
          case 'remove':
            _removeUser(user);
            break;
        }
      },
      itemBuilder: (_) {
        final type = user['type'] as String;        // target user
        final isActive = user['status'] == 'Active';
        final v = widget.viewerRole;                // viewer role
        final items = <PopupMenuEntry<String>>[];

        // Everyone can view visible rows
        items.add(_menuItem('view', Icons.remove_red_eye_rounded, 'View Details'));

        if (v == AppRole.moderator) {
          // Moderator viewer: can only see customers and only view
          return items;
        }

        // Admin viewer:
        if (type == 'Admin') {
          // View only for Admin targets
          return items;
        }

        if (type == 'Customer') {
          // Admin can suspend/activate customers
          if (isActive) {
            items.add(_menuItem('suspend', Icons.block_rounded, 'Suspend'));
          } else {
            items.add(_menuItem('activate', Icons.check_circle_rounded, 'Activate'));
          }
        } else if (type == 'Moderator') {
          // Admin can view, edit, and suspend/activate moderators
          items.add(_menuItem('edit', Icons.edit_rounded, 'Edit'));
          if (isActive) {
            items.add(_menuItem('suspend', Icons.block_rounded, 'Suspend'));
          } else {
            items.add(_menuItem('activate', Icons.check_circle_rounded, 'Activate'));
          }
        }
        return items;
      },
      child: _glass(
        padding: const EdgeInsets.all(8),
        radius: 12,
        child: Icon(Icons.more_horiz, color: kPrimaryDeep),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: kPrimaryDeep),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.label.copyWith(color: AdminColors.textPrimary)),
        ],
      ),
    );
  }

  // ===== Responsive View Details Dialog =====
  void _showUserDetails(Map<String, dynamic> user) {
    final type = (user['type'] as String?) ?? '—';
    final status = (user['status'] as String?) ?? '—';
    final isActive = status == 'Active';

    showDialog(
      context: context,
      builder: (_) {
        final size = MediaQuery.of(context).size;
        final double maxDialogWidth = min(size.width - 32, 720); // responsive width

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: SafeArea(
            child: SizedBox(
              width: maxDialogWidth,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ===== Header Banner =====
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kPrimary.withOpacity(.95), _darken(kPrimary, .15)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar glow
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 74,
                                    height: 74,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(.15),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      gradient: LinearGradient(
                                        colors: [Colors.white.withOpacity(.25), Colors.white.withOpacity(.12)],
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      type == 'Admin'
                                          ? Icons.shield
                                          : type == 'Moderator'
                                              ? Icons.verified_user
                                              : Icons.person,
                                      color: Colors.black87,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title + status (Wrap)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          (user['username'] as String?) ?? '—',
                                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        _bigStatusPill(isActive ? 'Active' : 'Inactive', isActive),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Role + email (Wrap)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        _roleBadge(type),
                                        if (user['email'] != null)
                                          _emailBadge(user['email'] as String),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // ===== Body Content (Responsive & Tidy) =====
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 520;
                              final List<Widget> tiles = [
                                _infoTile(Icons.badge_outlined, 'Full Name', (user['name'] as String?) ?? '—'),
                                _infoTile(Icons.tag, 'UID', (user['uid'] as String?) ?? '—'),
                                _infoTile(Icons.person_outline, 'Username', (user['username'] as String?) ?? '—'),
                                _infoTile(Icons.email_outlined, 'Email', (user['email'] as String?) ?? '—'),
                                _infoTile(Icons.phone_outlined, 'Phone',
                                  (user['phone'] != null && (user['phone'] as String).isNotEmpty)
                                    ? (user['phone'] as String)
                                    : '—'),
                                _infoTile(Icons.public, 'Country',
                                  (user['country'] != null && (user['country'] as String).isNotEmpty)
                                    ? (user['country'] as String)
                                    : '—'),
                                if (user['cluster'] != null)
                                  _infoTile(Icons.account_tree_outlined, 'Cluster', user['cluster'] as String),
                                _infoTile(
                                  Icons.layers_outlined,
                                  'User Type',
                                  type,
                                  chipify: true,
                                ),
                                _infoTile(
                                  isActive ? Icons.verified : Icons.pause_circle_filled,
                                  'Status',
                                  isActive ? 'Active' : 'Inactive',
                                  chipify: true,
                                  chipColor: isActive ? const Color(0xFFE8F1FF) : const Color(0xFFEDF2FD),
                                  chipTextColor: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF6477B9),
                                ),
                              ];

                              if (isWide) {
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: tiles
                                      .map((w) => SizedBox(
                                            width: (constraints.maxWidth - 12) / 2,
                                            child: w,
                                          ))
                                      .toList(),
                                );
                              }
                              return Column(
                                children: tiles
                                    .map((w) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: w,
                                        ))
                                    .toList(),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, kPrimary.withOpacity(.25), Colors.transparent],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                foregroundColor: kPrimaryDeep,
                              ),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text('Close', style: AppTextStyles.label.copyWith(color: kPrimaryDeep, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Width-aware email chip to prevent Wrap/Row overflows
  Widget _emailBadge(String email) {
    return LayoutBuilder(
      builder: (context, cons) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cons.maxWidth),
          child: SizedBox(
            width: cons.maxWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      email,
                      style: AppTextStyles.caption.copyWith(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== Pretty pieces used in dialog =====
  Widget _bigStatusPill(String label, bool active) {
    final Color bg = active ? const Color(0xFFBEE3F8).withOpacity(.35) : const Color(0xFFE2E8F0);
    final Color fg = Colors.white;
    final IconData icon = active ? Icons.verified : Icons.pause_circle_filled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.label.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _roleBadge(String type) {
    final IconData icon =
        type == 'Admin' ? Icons.shield : (type == 'Moderator' ? Icons.verified_user : Icons.person);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(type, style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    bool chipify = false,
    Color? chipColor,
    Color? chipTextColor,
  }) {
    final tile = _glass(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimaryDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption.copyWith(
                      color: AdminColors.textMuted,
                      letterSpacing: .2,
                    )),
                const SizedBox(height: 6),
                if (chipify)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (chipColor ?? kPrimary.withOpacity(.10)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: (chipTextColor ?? kPrimaryDeep).withOpacity(.2)),
                    ),
                    child: Text(
                      value,
                      style: AppTextStyles.label.copyWith(
                        color: chipTextColor ?? kPrimaryDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: AppTextStyles.bodyDefault.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return tile;
  }

  // ===== Edit Dialog (Admin only) =====
  void _showEditUser(Map<String, dynamic> user) {
    // Only Admin can reach here (menu guards this)
    final firstNameController = TextEditingController(
      text: (user['name'] as String).split(' ').isNotEmpty ? user['name'].split(' ').first : '',
    );
    final lastNameController = TextEditingController(
      text: (user['name'] as String).split(' ').length > 1
          ? (user['name'] as String).split(' ').skip(1).join(' ')
          : '',
    );
    final usernameController = TextEditingController(text: user['username']);
    final emailController = TextEditingController(text: user['email']);
    final passwordController = TextEditingController(text: (user['password'] ?? '') as String? ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final countryController = TextEditingController(text: user['country'] ?? '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: _glass(
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Text('Edit User', style: AppTextStyles.h2.copyWith(color: AdminColors.textPrimary)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 3, width: 64, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _input('First Name *', Icons.person_outline, firstNameController)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Last Name *', Icons.person_outline, lastNameController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _input('Username ', Icons.person, usernameController, readOnly: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Email *', Icons.email_outlined, emailController, readOnly: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  _input('Password ', Icons.lock_outline, passwordController,
                      obscure: false, readOnly: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _input('Phone No *', Icons.phone_outlined, phoneController)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Country *', Icons.public, countryController)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (firstNameController.text.isEmpty ||
                            lastNameController.text.isEmpty ||
                            usernameController.text.isEmpty ||
                            emailController.text.isEmpty ||
                            phoneController.text.isEmpty ||
                            countryController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields')),
                          );
                          return;
                        }
                        setState(() {
                          user['name'] = '${firstNameController.text} ${lastNameController.text}';
                          user['username'] = usernameController.text;
                          user['email'] = emailController.text;
                          user['phone'] = phoneController.text;
                          user['country'] = countryController.text;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User ${user['username']} has been updated.')),
                        );
                      },
                      child: Text('Submit', style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(String label, IconData icon, TextEditingController ctrl, {bool obscure = false, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(color: AdminColors.textPrimary)),
        const SizedBox(height: 6),
        _glass(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: ctrl,
            readOnly: readOnly,
            obscureText: obscure,
            cursorColor: kPrimary,
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              icon: Icon(icon, color: kPrimaryDeep),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ===== Actions =====
  void _suspendUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => _confirm(
        title: 'Suspend User',
        message: 'Suspend ${user['username']}?',
        confirmLabel: 'Suspend',
        confirmColor: kPrimaryDeep,
        onConfirm: () async {
          final uidStr = (user['uid'] ?? '').toString();
          final userid = int.tryParse(uidStr);
          if (userid == null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid user ID – cannot suspend.')),
            );
            return;
          }

          try {
            await api.suspendUser(userid);
            await _loadUsers();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User ${user['username']} has been suspended.')),
            );
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to suspend user: $e')),
            );
          }
        },
      ),
    );
  }

  void _activateUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => _confirm(
        title: 'Activate User',
        message: 'Activate ${user['username']}?',
        confirmLabel: 'Activate',
        confirmColor: kPrimaryDeep,
        onConfirm: () async {
          final uidStr = (user['uid'] ?? '').toString();
          final userid = int.tryParse(uidStr);
          if (userid == null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid user ID – cannot activate.')),
            );
            return;
          }

          try {
            await api.activateUser(userid);
            await _loadUsers();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User ${user['username']} has been activated.')),
            );
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to activate user: $e')),
            );
          }
        },
      ),
    );
  }

  void _removeUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => _confirm(
        title: 'Remove User',
        message: 'Permanently remove ${user['username']}? This cannot be undone.',
        confirmLabel: 'Remove',
        confirmColor: Colors.redAccent,
        onConfirm: () {
          setState(() => _users.remove(user));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User ${user['username']} has been removed.')),
          );
        },
      ),
    );
  }

  Widget _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: _glass(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.h3.copyWith(color: AdminColors.textPrimary)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryDeep,
                      side: BorderSide(color: kPrimaryDeep),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cancel', style: AppTextStyles.label.copyWith(color: kPrimaryDeep, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(confirmLabel, style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return MoreMenuDrawer(
      role: _drawerRole,
      onItemSelected: _handleMenuSelection,
      onLogout: _handleLogout,
      currentPageLabel: 'User Management',
    );
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    if (label == 'Dashboard') {
      final userGroup = widget.viewerRole == AppRole.admin ? 'admin' : 'moderator';
      final nav = appNavigatorKey.currentState;
      if (userGroup == 'admin') {
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('/admin', (route) => false);
        } else {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/admin', (route) => false);
        }
      } else {
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('/moderator', (route) => false);
        } else {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/moderator', (route) => false);
        }
      }
      return;
    }
    if (label == 'Profile') {
      Navigator.of(context).pushNamed('/profile');
      return;
    }
    if (label == 'PropertyListing' || label == 'Properties') {
      Navigator.of(context).pushNamed('/manage-services');
      return;
    }
    if (label == 'Reservation' || label == 'Bookings') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-stock-manager' : '/moderator-stock-manager';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'AuditTrails') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-audit-trails' : '/moderator-audit-trails';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'BooknPayLog') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-book-and-pay' : '/moderator-book-and-pay';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'Activity Logs') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-activity-logs' : '/moderator-activity-logs';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'Ledger') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-ledger' : '/moderator-ledger';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'Stock Manager') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-stock-manager' : '/moderator-stock-manager';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'Customer Review' || label == 'Customer Reviews') {
      final route = widget.viewerRole == AppRole.admin ? '/admin-customer-reviews' : '/moderator-customer-reviews';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (label == 'User Management') {
      return; // already on this page
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $label', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: kPrimary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleBottomNavTap(int index) async {
    if (index == 4) {
      // More button - handled by SharedBottomNavigationBar to open drawer
      return;
    }
    if (index == 0) {
      // Dashboard
      final userGroup = widget.viewerRole == AppRole.admin ? 'admin' : 'moderator';
      final nav = appNavigatorKey.currentState;
      if (userGroup == 'admin') {
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('/admin', (route) => false);
        } else {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/admin', (route) => false);
        }
      } else {
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('/moderator', (route) => false);
        } else {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/moderator', (route) => false);
        }
      }
      return;
    }
    if (index == 1) {
      // Properties -> Manage Services
      Navigator.of(context).pushNamed('/manage-services');
      return;
    }
    if (index == 2) {
      final route = widget.viewerRole == AppRole.admin ? '/admin-stock-manager' : '/moderator-stock-manager';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (index == 3) {
      // Profile
      Navigator.of(context).pushNamed('/profile');
      return;
    }
  }

}
