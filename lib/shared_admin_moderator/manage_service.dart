import 'package:flutter/material.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/colors.dart';
import '../app.dart';

class ManageServicesPage extends StatefulWidget {
  const ManageServicesPage({super.key});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
  String? _userRole;
  int? _userid;
  bool _isLoading = true;
  String? _errorMessage;
  final int _selectedIndex = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadData();
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 0,
        title: const Text('Property', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AdminColors.primary,
        centerTitle: true,
        actions: const [SizedBox.shrink()],
      ),
      endDrawer: _userRole != null
          ? MoreMenuDrawer(
              role: _getUserRoleEnum(),
              onItemSelected: _handleMenuSelection,
              onLogout: _handleLogout,
              currentPageLabel: 'Properties',
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AdminColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(_properties.length),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: CircularProgressIndicator(color: AdminColors.primary),
                    ),
                  )
                else ...[
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.danger.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AdminColors.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(color: AdminColors.danger)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadData,
                            color: AdminColors.danger,
                          ),
                        ],
                      ),
                    ),
                  if (_properties.isEmpty && _errorMessage == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: AdminColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.apartment, size: 56, color: AdminColors.border),
                          SizedBox(height: 14),
                          Text('No properties yet',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.textSecond)),
                          SizedBox(height: 6),
                          Text('No properties have been added yet.',
                              style: TextStyle(fontSize: 13, color: AdminColors.textMuted),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ..._properties.map((p) => _buildPropertyCard(p)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _userRole != null
          ? SharedBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onTap: _handleBottomNavTap,
              scaffoldKey: _scaffoldKey,
              role: _getUserRoleEnum(),
            )
          : null,
    );
  }

  Widget _buildHeaderBanner(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.apartment, color: Colors.white70, size: 32),
          const SizedBox(height: 12),
          const Text('Property Listings',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Manage and review all property listings. $count listing${count == 1 ? '' : 's'} found.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> p) {
    final rawStatus = (p['status'] ?? 'Available').toString();
    final normalizedStatus = rawStatus.toLowerCase();
    final bool isRejected = normalizedStatus.contains('reject');
    final bool isDisabled = normalizedStatus.contains('disable') || (p['isDisabled'] == true);
    final String statusLabel = isRejected ? 'Rejected' : 'Available';

    return Card(
      color: AdminColors.cardBg,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminColors.border),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p['name'] ?? 'Untitled',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? AdminColors.danger.withOpacity(0.12)
                        : AdminColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: isRejected ? AdminColors.danger : AdminColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isDisabled)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.textMuted.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Disabled',
                      style: TextStyle(
                          color: AdminColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AdminColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p['location'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 13, color: AdminColors.textSecond),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (p['promo'] != null && p['promo'] > 0 && p['promo'] < p['price']) ...[
              Text(
                'RM ${p['promo']}/night',
                style: const TextStyle(
                    color: AdminColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'RM ${p['price']}/night',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Save RM ${(p['price'] - p['promo']).toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AdminColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'RM ${p['price']}/night',
                style: const TextStyle(
                    color: AdminColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AdminColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p['creatorName'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: AdminColors.accent, size: 20),
                  onPressed: () => _showPropertyDetails(p),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'View details',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetails(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.apartment, color: AdminColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                property['name'] ?? 'Property Details',
                style: const TextStyle(
                    color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
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
              _buildDetailRow('Location', property['location']),
              _buildDetailRow('Status', (property['status'] ?? 'Available').toString()),
              _buildDetailRow('Category', property['categoryname']),
              _buildDetailRow('Cluster', property['clustername']),
              _buildDetailRow('Stock', property['quantity']?.toString()),
              _buildDetailRow(
                  'Price', property['price'] != null ? 'RM ${property['price']}' : null),
              _buildDetailRow(
                  'Promo Rate', property['promo'] != null && property['promo'] > 0
                      ? 'RM ${property['promo']}'
                      : null),
              _buildDetailRow('Owner', property['creatorName']),
              _buildDetailRow('Description', property['description']),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
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
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecond,
                    fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(displayValue,
                style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13)),
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
