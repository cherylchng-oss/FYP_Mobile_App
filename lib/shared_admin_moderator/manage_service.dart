import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/colors.dart';
import '../app.dart';
import '../admin/admin_notification.dart';
import '../moderator/moderator_notification.dart';

TextStyle _ts(double size, FontWeight weight, Color color, {double? height}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color, height: height);

class ManageServicesPage extends StatefulWidget {
  const ManageServicesPage({super.key});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
  String? _userRole;
  int? _userid;
  bool _isLoading = true;
  int _unreadCount = 0;
  String? _errorMessage;
  final int _selectedIndex = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadData();
    _loadUnreadCount();
  }

  Future<void> _loadUserRole() async {
    final role = await Session.getUserGroup();
    final userid = await Session.getUserId();
    setState(() {
      _userRole = role;
      _userid = userid;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userid = await Session.getUserId();
    if (userid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final propertiesData = await api.fetchPropertiesListingTable();
      if (mounted) {
        setState(() {
          _properties.clear();
          List<dynamic> apiProperties = [];
          for (var key in ['properties', 'data', 'result']) {
            if (propertiesData[key] != null && propertiesData[key] is List) {
              apiProperties = List<dynamic>.from(propertiesData[key]);
              break;
            }
          }
          if (apiProperties.isEmpty) {
            propertiesData.forEach((key, value) {
              if (value is List && value.isNotEmpty) apiProperties = List<dynamic>.from(value);
            });
          }
          for (var prop in apiProperties) {
            final propertyName = prop['propertyaddress'] ?? prop['propertydescription'] ?? 'Unnamed Property';
            final propertyLocation = prop['nearbylocation'] ?? prop['propertydescription'] ?? 'Unknown Location';
            final propertyDescription = prop['propertydescription'] ?? 'No description available';
            final statusRaw = (prop['propertystatus'] ?? prop['status'] ?? 'Available').toString();
            final statusLower = statusRaw.toLowerCase();
            final creatorRole = (prop['creatorusergroup'] ?? prop['usergroup'] ?? prop['role'] ?? 'admin').toString();
            final creatorName = prop['creatorusername'] ?? prop['username'] ?? 'Unknown';
            final bool isDisabled = statusLower.contains('disable') || statusLower.contains('inactive');
            _properties.add({
              'propertyid': prop['propertyid'],
              'name': propertyName,
              'location': propertyLocation,
              'description': propertyDescription,
              'price': _parseDouble(prop['normalrate']),
              'promo': _parseDouble(prop['earlybirddiscountrate']),
              'status': statusRaw,
              'creatorRole': creatorRole,
              'creatorName': creatorName,
              'isDisabled': isDisabled,
              'categoryname': prop['categoryname'],
              'clustername': prop['clustername'],
              'quantity': prop['quantity'],
            });
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = null);
    }

    if (mounted) setState(() => _isLoading = false);
  }

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

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  nav.UserRole _getUserRoleEnum() {
    if (_userRole == null) return nav.UserRole.admin;
    final normalized = _userRole!.toLowerCase().trim();
    if (normalized == 'admin' || normalized == 'administrator') return nav.UserRole.admin;
    if (normalized == 'moderator') return nav.UserRole.moderator;
    return nav.UserRole.admin;
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      drawerEnableOpenDragGesture: false,
      endDrawer: _userRole != null
          ? MoreMenuDrawer(
              role: _getUserRoleEnum(),
              onItemSelected: _handleMenuSelection,
              onLogout: _handleLogout,
              currentPageLabel: 'Properties',
            )
          : null,
      bottomNavigationBar: _userRole != null
          ? SharedBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onTap: _handleBottomNavTap,
              scaffoldKey: _scaffoldKey,
              role: _getUserRoleEnum(),
            )
          : null,
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AdminColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(color: AdminColors.primary),
                      ),
                    )
                  else ...[
                    _buildSummaryRow(),
                    const SizedBox(height: 14),
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AdminColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_errorMessage!,
                                style: _ts(13, FontWeight.w400, AdminColors.danger))),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _loadData,
                              color: AdminColors.danger,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    if (_properties.isEmpty && _errorMessage == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AdminColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AdminColors.border),
                          boxShadow: [BoxShadow(
                              color: AdminColors.primary.withOpacity(0.05),
                              blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(children: [
                          const Icon(Icons.apartment_outlined, size: 56, color: AdminColors.border),
                          const SizedBox(height: 14),
                          Text('No properties yet',
                              style: _ts(17, FontWeight.w600, AdminColors.textSecond)),
                          const SizedBox(height: 6),
                          Text('No properties have been added yet.',
                              style: _ts(13, FontWeight.w400, AdminColors.textMuted),
                              textAlign: TextAlign.center),
                        ]),
                      )
                    else
                      ..._properties.map((p) => _buildPropertyCard(p)),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/property_listing.png', fit: BoxFit.cover),
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
            padding: EdgeInsets.fromLTRB(20, topPad + 24, 20, 36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.apartment_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Property Listings',
                          style: _ts(24, FontWeight.w600, Colors.white, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Manage and review all property\nlistings across the system.',
                        style: _ts(13, FontWeight.w400, Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final page = _getUserRoleEnum() == nav.UserRole.admin
                        ? MaterialPageRoute(builder: (_) => AdminNotifications())
                        : MaterialPageRoute(builder: (_) => ModeratorNotifications());
                    Navigator.push(context, page).then((_) => _loadUnreadCount());
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 15),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Color(0xFFE0A43A), shape: BoxShape.circle),
                            child: Text('$_unreadCount', style: _ts(9, FontWeight.w700, Colors.white)),
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

  // ── Summary Row ─────────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    final total     = _properties.length;
    final available = _properties.where((p) =>
        (p['status'] ?? '').toString().toLowerCase() == 'available').length;
    final pending   = _properties.where((p) =>
        (p['status'] ?? '').toString().toLowerCase() == 'pending').length;

    return Row(
      children: [
        _statPill(Icons.apartment_outlined,    '$total',     'Total',     AdminColors.primary),
        const SizedBox(width: 10),
        _statPill(Icons.check_circle_outline,  '$available', 'Available', AdminColors.success),
        const SizedBox(width: 10),
        _statPill(Icons.pending_outlined,      '$pending',   'Pending',   AdminColors.warning),
      ],
    );
  }

  Widget _statPill(IconData icon, String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.border),
          boxShadow: [BoxShadow(
              color: AdminColors.primary.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(count, style: _ts(15, FontWeight.w700, AdminColors.textPrimary)),
                Text(label, style: _ts(10, FontWeight.w500, AdminColors.textMuted)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Property Card ───────────────────────────────────────────────────────────
  Widget _buildPropertyCard(Map<String, dynamic> p) {
    final rawStatus       = (p['status'] ?? 'Available').toString();
    final normalizedStatus = rawStatus.toLowerCase();
    final bool isRejected  = normalizedStatus.contains('reject');
    final bool isPending   = normalizedStatus.contains('pending');
    final bool isDisabled  = normalizedStatus.contains('disable') || (p['isDisabled'] == true);

    Color statusColor;
    String statusLabel;
    if (isRejected) {
      statusColor = AdminColors.danger;
      statusLabel = 'Rejected';
    } else if (isPending) {
      statusColor = AdminColors.warning;
      statusLabel = 'Pending';
    } else if (isDisabled) {
      statusColor = AdminColors.textMuted;
      statusLabel = 'Disabled';
    } else {
      statusColor = AdminColors.success;
      statusLabel = 'Available';
    }

    final price = p['price'] as double? ?? 0.0;
    final promo = p['promo'] as double? ?? 0.0;
    final hasPromo = promo > 0 && promo < price;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: AdminColors.primary.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status chip(s)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(p['name'] ?? 'Untitled',
                      style: _ts(15, FontWeight.w600, AdminColors.textPrimary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusChip(statusLabel, statusColor),
                    if (isDisabled && !normalizedStatus.contains('disable')) ...[
                      const SizedBox(height: 4),
                      _statusChip('Disabled', AdminColors.textMuted),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Location
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AdminColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(p['location'] ?? 'Unknown',
                  style: _ts(13, FontWeight.w400, AdminColors.textSecond),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            // Category / cluster pills
            if ((p['categoryname'] ?? '').toString().isNotEmpty ||
                (p['clustername'] ?? '').toString().isNotEmpty)
              Wrap(spacing: 6, runSpacing: 4, children: [
                if ((p['categoryname'] ?? '').toString().isNotEmpty)
                  _tagChip(Icons.category_outlined, p['categoryname'].toString()),
                if ((p['clustername'] ?? '').toString().isNotEmpty)
                  _tagChip(Icons.corporate_fare_outlined, p['clustername'].toString()),
              ]),
            if ((p['categoryname'] ?? '').toString().isNotEmpty ||
                (p['clustername'] ?? '').toString().isNotEmpty)
              const SizedBox(height: 10),
            // Price
            if (hasPromo) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                Text('RM ${promo.toStringAsFixed(0)}',
                    style: _ts(18, FontWeight.w700, AdminColors.primary)),
                const SizedBox(width: 8),
                Text('RM ${price.toStringAsFixed(0)}',
                    style: _ts(13, FontWeight.w400, AdminColors.textMuted).copyWith(
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save RM ${(price - promo).toStringAsFixed(0)}',
                    style: _ts(10, FontWeight.w600, AdminColors.success),
                  ),
                ),
              ]),
              Text('/night', style: _ts(11, FontWeight.w400, AdminColors.textMuted)),
            ] else ...[
              Text('RM ${price.toStringAsFixed(0)}',
                  style: _ts(18, FontWeight.w700, AdminColors.primary)),
              Text('/night', style: _ts(11, FontWeight.w400, AdminColors.textMuted)),
            ],
            const SizedBox(height: 10),
            // Divider
            Container(height: 1, color: AdminColors.border),
            const SizedBox(height: 10),
            // Owner row + info button
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AdminColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(p['creatorName'] ?? 'Unknown',
                  style: _ts(12, FontWeight.w400, AdminColors.textMuted),
                  overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () => _showPropertyDetails(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.info_outline, size: 13, color: AdminColors.primary),
                    const SizedBox(width: 4),
                    Text('Details', style: _ts(11, FontWeight.w600, AdminColors.primary)),
                  ]),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: _ts(10, FontWeight.w700, color)),
      ]),
    );
  }

  Widget _tagChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AdminColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AdminColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: _ts(11, FontWeight.w400, AdminColors.textSecond)),
      ]),
    );
  }

  // ── Property Details Dialog ──────────────────────────────────────────────────
  void _showPropertyDetails(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AdminColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.apartment_outlined, color: AdminColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                property['name'] ?? 'Property Details',
                style: _ts(16, FontWeight.w600, AdminColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Container(height: 1, color: AdminColors.border),
              const SizedBox(height: 12),
              _buildDetailRow('Location', property['location']),
              _buildDetailRow('Status', (property['status'] ?? 'Available').toString()),
              _buildDetailRow('Category', property['categoryname']),
              _buildDetailRow('Cluster', property['clustername']),
              _buildDetailRow('Stock', property['quantity']?.toString()),
              _buildDetailRow('Price', property['price'] != null ? 'RM ${property['price']}' : null),
              _buildDetailRow('Promo Rate', property['promo'] != null && property['promo'] > 0
                  ? 'RM ${property['promo']}' : null),
              _buildDetailRow('Owner', property['creatorName']),
              _buildDetailRow('Description', property['description']),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: _ts(14, FontWeight.w600, Colors.white),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue =
        value == null || value.toString().trim().isEmpty ? '—' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: _ts(13, FontWeight.w600, AdminColors.textSecond)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(displayValue,
                style: _ts(13, FontWeight.w400, AdminColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────
  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 1) return;
    if (index == 0) {
      final route = _getUserRoleEnum() == nav.UserRole.admin ? '/admin' : '/moderator';
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(route, (route) => false);
      } else {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(route, (route) => false);
      }
      return;
    }
    if (index == 2) {
      final route = _getUserRoleEnum() == nav.UserRole.admin
          ? '/admin-stock-manager'
          : '/moderator-stock-manager';
      Navigator.of(context).pushNamed(route);
      return;
    }
    if (index == 3) { Navigator.of(context).pushNamed('/profile'); return; }
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard':
        final route = _getUserRoleEnum() == nav.UserRole.admin ? '/admin' : '/moderator';
        final navigator = appNavigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil(route, (route) => false);
        } else {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(route, (route) => false);
        }
        break;
      case 'User Management':
        final role = _getUserRoleEnum() == nav.UserRole.admin ? AppRole.admin : AppRole.moderator;
        Navigator.of(context).pushNamed('/user-management', arguments: role);
        break;
      case 'Properties': break;
      case 'Stock Manager':
        Navigator.of(context).pushNamed(
            _getUserRoleEnum() == nav.UserRole.admin ? '/admin-stock-manager' : '/moderator-stock-manager');
        break;
      case 'Activity Logs':
        Navigator.of(context).pushNamed(
            _getUserRoleEnum() == nav.UserRole.admin ? '/admin-activity-logs' : '/moderator-activity-logs');
        break;
      case 'Ledger':
        Navigator.of(context).pushNamed(
            _getUserRoleEnum() == nav.UserRole.admin ? '/admin-ledger' : '/moderator-ledger');
        break;
      case 'Customer Review':
      case 'Customer Reviews':
        Navigator.of(context).pushNamed(
            _getUserRoleEnum() == nav.UserRole.admin ? '/admin-customer-reviews' : '/moderator-customer-reviews');
        break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }
}
