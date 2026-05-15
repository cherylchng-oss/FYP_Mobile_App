import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart' as api;
import '../app.dart';
import '../services/session.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import 'moderator_notification.dart';

// ── Typography helper (Outfit font shorthand) ──────────────────────────────────
TextStyle _mts(double size, FontWeight weight, Color color, {double? height}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color, height: height);

class ModeratorStockManagerPage extends StatefulWidget {
  const ModeratorStockManagerPage({super.key});

  @override
  State<ModeratorStockManagerPage> createState() => _ModeratorStockManagerPageState();
}

class _ModeratorStockManagerPageState extends State<ModeratorStockManagerPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _selectedSection = 'Stock Overview';

  // ── Stock Overview ──
  bool _isLoadingStock = true;
  bool _isFilteringStock = false;
  String? _stockError;
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>>? _stockFilteredProperties;

  final TextEditingController _stockSearchCtrl = TextEditingController();
  String _stockStatusFilter = 'All';
  DateTime? _stockCheckIn;
  DateTime? _stockCheckOut;

  // ── Daily Occupancy ──
  bool _isLoadingOccupancy = false;
  bool _occupancyLoaded = false;
  List<dynamic> _allReservations = [];
  List<dynamic> _filteredReservations = [];
  DateTimeRange? _dateRange;
  final TextEditingController _occupancySearchCtrl = TextEditingController();

  // ── Blackout Management ──
  bool _isLoadingBlackouts = true;
  String? _blackoutError;
  List<dynamic> _blackouts = [];
  String _blackoutFilter = 'All';
  String _blackoutRoleFilter = 'All';

  int? _userid;
  String? _usergroup;
  int _unreadCount = 0;

  // ── Summary Getters ──
  int get _totalProperties => _properties.length;
  int get _totalStock {
    int t = 0;
    for (final p in _properties) t += _toInt(p['quantity']);
    return t;
  }
  int get _lowStockCount =>
      _properties.where((p) => _toInt(p['quantity']) > 0 && _toInt(p['quantity']) <= 2).length;
  int get _outOfStockCount =>
      _properties.where((p) => _toInt(p['quantity']) <= 0).length;

  List<Map<String, dynamic>> get _displayProperties {
    final base = _stockFilteredProperties ?? _properties;
    final search = _stockSearchCtrl.text.trim().toLowerCase();
    if (search.isEmpty) return base;
    return base.where((p) {
      final name = (p['propertyaddress'] ?? '').toString().toLowerCase();
      return name.contains(search);
    }).toList();
  }

  List<dynamic> get _filteredBlackouts {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _blackouts.where((b) {
      final m = b is Map ? b : <dynamic, dynamic>{};
      final isActive = m['is_active'] == true || m['is_active'] == 1;
      final isOverridden = m['is_overridden'] == true || m['is_overridden'] == 1 ||
          (m['status'] ?? '').toString().toLowerCase() == 'overridden';
      final endDate = _parseDate(m['end_date']);
      final isExpired = endDate != null && endDate.isBefore(today);

      if (_blackoutFilter == 'Active' && !(isActive && !isExpired)) return false;
      if (_blackoutFilter == 'Overridden' && !isOverridden) return false;
      if (_blackoutFilter == 'Expired' && !isExpired) return false;
      if (_blackoutRoleFilter != 'All') {
        final role = (m['created_by_role'] ?? '').toString().toLowerCase();
        if (role != _blackoutRoleFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSession().then((_) {
      _loadStockData();
      _loadBlackouts();
    });
    _loadUnreadCount();
    _stockSearchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stockSearchCtrl.dispose();
    _occupancySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    _userid = await Session.getUserId();
    _usergroup = await Session.getUserGroup();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadCount = notifications.where((n) => !(n['isRead'] ?? false)).length;
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Image helpers
  // ─────────────────────────────────────────────
  static const String _baseUrl = 'http://167.99.113.105:8080';

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$_baseUrl${url.startsWith('/') ? '' : '/'}$url';
  }

  /// Returns a list where each entry is either:
  ///   - a String (http/https URL — use Image.network)
  ///   - a Uint8List (decoded base64 — use Image.memory)
  List<dynamic> _parseImages(dynamic raw) {
    List<dynamic> items;
    if (raw == null) return [];
    if (raw is List) {
      items = raw;
    } else if (raw is String) {
      // Try JSON array first, then comma-separated
      try {
        final decoded = jsonDecode(raw);
        items = decoded is List ? decoded : [raw];
      } catch (_) {
        items = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    } else {
      return [];
    }

    final result = <dynamic>[];
    for (final item in items) {
      final s = item?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      if (s.startsWith('http://') || s.startsWith('https://')) {
        result.add(s);
      } else if (s.startsWith('/')) {
        result.add(_resolveImageUrl(s));
      } else {
        // Assume base64
        try {
          result.add(base64Decode(s));
        } catch (_) {
          result.add(_resolveImageUrl(s));
        }
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────
  // Stock data
  // ─────────────────────────────────────────────
  Future<void> _loadStockData() async {
    setState(() { _isLoadingStock = true; _stockError = null; });
    try {
      final data = await api.fetchPropertiesListingTable();
      List<dynamic> raw = data['properties'] ?? data['data'] ?? data['result'] ?? [];
      final mapped = raw.whereType<Map>()
          .where((e) =>
              e['propertyid'] != null &&
              e['propertyid'].toString().trim().isNotEmpty &&
              (e['propertyaddress'] ?? '').toString().trim().isNotEmpty)
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            m['_preImgs'] = _parseImages(m['propertyimage']);
            return m;
          })
          .toList();
      if (!mounted) return;
      setState(() { _properties = mapped; _stockFilteredProperties = null; _isLoadingStock = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _stockError = e.toString(); _isLoadingStock = false; });
    }
  }

  // ─────────────────────────────────────────────
  // Stock filters
  // ─────────────────────────────────────────────
  Future<void> _applyStockFilters() async {
    final hasDateFilter = _stockCheckIn != null || _stockCheckOut != null;
    final hasStatusFilter = _stockStatusFilter != 'All';

    if (!hasDateFilter && !hasStatusFilter) {
      setState(() => _stockFilteredProperties = null);
      return;
    }

    if (!hasDateFilter && hasStatusFilter) {
      setState(() {
        _stockFilteredProperties = _properties.where((p) {
          final s = (p['propertystatus'] ?? '').toString().toLowerCase();
          return s == _stockStatusFilter.toLowerCase();
        }).toList();
      });
      return;
    }

    setState(() => _isFilteringStock = true);
    try {
      if (!_occupancyLoaded) {
        final res = await api.fetchReservationsForAdminModerator();
        if (!mounted) return;
        setState(() { _allReservations = res; _occupancyLoaded = true; });
      }

      final matchingAddresses = <String>{};
      for (final r in _allReservations) {
        final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        final ci = _parseDate(m['checkindate']);
        if (ci == null) continue;
        if (_stockCheckIn != null) {
          final from = DateTime(_stockCheckIn!.year, _stockCheckIn!.month, _stockCheckIn!.day);
          if (ci.isBefore(from)) continue;
        }
        if (_stockCheckOut != null) {
          final to = DateTime(_stockCheckOut!.year, _stockCheckOut!.month, _stockCheckOut!.day);
          if (ci.isAfter(to)) continue;
        }
        final addr = (m['propertyaddress'] ?? '').toString().toLowerCase();
        if (addr.isNotEmpty) matchingAddresses.add(addr);
      }

      List<Map<String, dynamic>> result = _properties.where((p) {
        final addr = (p['propertyaddress'] ?? '').toString().toLowerCase();
        return matchingAddresses.contains(addr);
      }).toList();

      if (hasStatusFilter) {
        result = result.where((p) {
          final s = (p['propertystatus'] ?? '').toString().toLowerCase();
          return s == _stockStatusFilter.toLowerCase();
        }).toList();
      }

      if (!mounted) return;
      setState(() { _stockFilteredProperties = result; _isFilteringStock = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFilteringStock = false);
    }
  }

  // ─────────────────────────────────────────────
  // Daily Occupancy
  // ─────────────────────────────────────────────
  Future<void> _loadOccupancyData() async {
    setState(() => _isLoadingOccupancy = true);
    try {
      final res = await api.fetchReservationsForAdminModerator();
      if (!mounted) return;
      setState(() {
        _allReservations = res;
        _occupancyLoaded = true;
        _isLoadingOccupancy = false;
      });
      _applyOccupancyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOccupancy = false);
    }
  }

  void _applyOccupancyFilter() {
    final search = _occupancySearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredReservations = _allReservations.where((r) {
        final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        if (_dateRange != null) {
          final ci = _parseDate(m['checkindate'] ?? m['checkInDate']);
          if (ci == null) return false;
          if (ci.isBefore(_dateRange!.start) || ci.isAfter(_dateRange!.end)) return false;
        }
        if (search.isNotEmpty) {
          final name = (m['propertyaddress'] ?? m['propertyAddress'] ?? '').toString().toLowerCase();
          if (!name.contains(search)) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AdminColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      if (_occupancyLoaded) _applyOccupancyFilter();
    }
  }

  // ─────────────────────────────────────────────
  // Blackout Dates
  // ─────────────────────────────────────────────
  Future<void> _loadBlackouts() async {
    if (_userid == null) { await _loadSession(); if (_userid == null) return; }
    setState(() { _isLoadingBlackouts = true; _blackoutError = null; });
    try {
      final list = await api.fetchBlackouts(_userid!, _usergroup ?? 'moderator');
      if (!mounted) return;
      setState(() { _blackouts = list; _isLoadingBlackouts = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _blackoutError = e.toString(); _isLoadingBlackouts = false; });
    }
  }

  Future<void> _deleteBlackout(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Blackout', style: _mts(16, FontWeight.w600, AdminColors.textPrimary)),
        content: Text('Are you sure you want to delete this blackout date?',
            style: _mts(14, FontWeight.w400, AdminColors.textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: _mts(13, FontWeight.w500, AdminColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: _mts(13, FontWeight.w600, AdminColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await api.deleteBlackout(id, _userid!, _usergroup ?? 'moderator');
      _loadBlackouts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _safeText(dynamic v, {String fallback = '-'}) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) { return v.toString(); }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try { return DateTime.parse(v.toString()); } catch (_) { return null; }
  }

  String _fmtCount(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Future<void> _pickDate(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AdminColors.primary, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { if (isCheckIn) _stockCheckIn = picked; else _stockCheckOut = picked; });
      _applyStockFilters();
    }
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
    if (index == 4) return;
    if (index == 0) { Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false); return; }
    if (index == 1) { Navigator.of(context).pushNamed('/manage-services'); return; }
    if (index == 2) { Navigator.of(context).pushNamed('/moderator-stock-manager'); return; }
    if (index == 3) { Navigator.of(context).pushNamed('/profile'); return; }
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.moderator); break;
      case 'Properties': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager': Navigator.of(context).pushNamed('/moderator-stock-manager'); break;
      case 'Activity Logs': Navigator.of(context).pushNamed('/moderator-activity-logs'); break;
      case 'Ledger': Navigator.of(context).pushNamed('/moderator-ledger'); break;
      case 'Customer Reviews': Navigator.of(context).pushNamed('/moderator-customer-reviews'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
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
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Stock Manager',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 2,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/stock_manager.png', fit: BoxFit.cover),
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
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock Manager',
                          style: _mts(24, FontWeight.w600, Colors.white, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor property stock, room\nquantity, and availability.',
                        style: _mts(13, FontWeight.w400, Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ModeratorNotifications()),
                  ).then((_) => _loadUnreadCount()),
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
                            child: Text('$_unreadCount', style: _mts(9, FontWeight.w700, Colors.white)),
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

  // ── Tab Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (Icons.inventory_2_outlined,    'Stock Overview'),
      (Icons.calendar_today_outlined, 'Daily Occupancy'),
      (Icons.block_outlined,          'Blackout Dates'),
    ];

    return Container(
      color: AdminColors.cream,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = _selectedSection == tabs[i].$2;
            return GestureDetector(
              onTap: () => setState(() => _selectedSection = tabs[i].$2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 10 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AdminColors.primary : AdminColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isActive ? AdminColors.primary : AdminColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[i].$1, size: 14,
                        color: isActive ? Colors.white : AdminColors.textMuted),
                    const SizedBox(width: 6),
                    Text(tabs[i].$2,
                        style: _mts(12,
                            isActive ? FontWeight.w600 : FontWeight.w400,
                            isActive ? Colors.white : AdminColors.textMuted)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedSection) {
      case 'Daily Occupancy': return _buildOccupancyTab();
      case 'Blackout Dates':  return _buildBlackoutTab();
      default:                return _buildStockTab();
    }
  }

  // ── Tab 1: Stock Overview ───────────────────────────────────────────────────
  Widget _buildStockTab() {
    if (_stockError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AdminColors.danger, size: 48),
            const SizedBox(height: 12),
            Text('Unable to load stock data', style: _mts(17, FontWeight.w600, AdminColors.textPrimary)),
            const SizedBox(height: 8),
            Text(_stockError!, textAlign: TextAlign.center,
                style: _mts(13, FontWeight.w400, AdminColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStockData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStockData,
      color: AdminColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 12),
          _buildStockFilterCard(),
          const SizedBox(height: 14),
          if (_isLoadingStock || _isFilteringStock)
            Column(children: List.generate(4, (_) => _buildSkeletonCard()))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Property Stock List', style: _mts(15, FontWeight.w600, AdminColors.textPrimary)),
                Text('${_displayProperties.length} properties',
                    style: _mts(13, FontWeight.w400, AdminColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            if (_properties.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, size: 56, color: AdminColors.border),
                  const SizedBox(height: 12),
                  Text('No stock records found', style: _mts(17, FontWeight.w600, AdminColors.textMuted)),
                ])),
              )
            else if (_displayProperties.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No properties match the selected filters.',
                    style: _mts(14, FontWeight.w400, AdminColors.textMuted))),
              )
            else
              ..._displayProperties.map(_buildPropertyCard),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Stats Grid ──────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _MStatData(icon: Icons.apartment_outlined,         label: 'Properties',   count: _totalProperties,  iconColor: AdminColors.primary,  iconBg: AdminColors.surface,                       accent: AdminColors.primary),
      _MStatData(icon: Icons.inventory_2_outlined,       label: 'Total Stock',  count: _totalStock,       iconColor: AdminColors.success,  iconBg: AdminColors.success.withOpacity(0.15),     accent: AdminColors.success),
      _MStatData(icon: Icons.warning_amber_outlined,     label: 'Low Stock',    count: _lowStockCount,    iconColor: AdminColors.warning,  iconBg: AdminColors.warning.withOpacity(0.15),     accent: AdminColors.warning),
      _MStatData(icon: Icons.do_not_disturb_on_outlined, label: 'Out of Stock', count: _outOfStockCount,  iconColor: AdminColors.danger,   iconBg: AdminColors.danger.withOpacity(0.12),      accent: AdminColors.danger),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: stats.map(_buildStatCard).toList(),
    );
  }

  Widget _buildStatCard(_MStatData s) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: AdminColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -10, bottom: -10,
              child: Icon(s.icon, size: 68, color: s.accent.withOpacity(0.07))),
          Positioned(left: 0, right: 0, bottom: 0,
              child: Container(height: 3,
                  decoration: BoxDecoration(
                    color: s.accent.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  ))),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: s.iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(s.icon, size: 16, color: s.iconColor),
                ),
                const SizedBox(height: 8),
                Text(s.label, style: _mts(11, FontWeight.w500, AdminColors.textMuted)),
                const SizedBox(height: 2),
                _isLoadingStock
                    ? Container(
                        height: 20,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AdminColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(_fmtCount(s.count),
                        style: _mts(20, FontWeight.w700, AdminColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stock Filter Card ───────────────────────────────────────────────────────
  Widget _buildStockFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _stockSearchCtrl,
          style: _mts(14, FontWeight.w400, AdminColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search properties...',
            hintStyle: _mts(14, FontWeight.w400, AdminColors.textMuted),
            prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
            filled: true, fillColor: AdminColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminColors.primary)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Status', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminColors.border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _stockStatusFilter,
                  isExpanded: true,
                  style: _mts(13, FontWeight.w400, AdminColors.textPrimary),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AdminColors.textMuted, size: 18),
                  items: ['All', 'Available', 'Pending', 'Booked', 'Rejected'].map((s) =>
                      DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    setState(() => _stockStatusFilter = v ?? 'All');
                    _applyStockFilters();
                  },
                ),
              ),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Check-in', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
            const SizedBox(height: 6),
            _dateBtn(_stockCheckIn, () => _pickDate(true)),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Check-out', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
            const SizedBox(height: 6),
            _dateBtn(_stockCheckOut, () => _pickDate(false)),
          ])),
        ]),
      ]),
    );
  }

  Widget _dateBtn(DateTime? date, VoidCallback onTap) {
    final label = date == null ? 'Select' : '${date.day}/${date.month}/${date.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.border)),
        child: Row(children: [
          const Icon(Icons.calendar_month_outlined, size: 14, color: AdminColors.textMuted),
          const SizedBox(width: 4),
          Expanded(child: Text(label,
              style: _mts(11, FontWeight.w400, AdminColors.textMuted),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  // ── Skeleton Card (loading placeholder) ──────────────────────────────────
  Widget _buildSkeletonCard() {
    Widget line(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            child: Container(width: 110, height: 130, color: AdminColors.surface),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(double.infinity, 14),
                  const SizedBox(height: 8),
                  line(110, 12),
                  const SizedBox(height: 14),
                  line(80, 10),
                  const SizedBox(height: 7),
                  line(100, 10),
                  const SizedBox(height: 7),
                  line(60, 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Property Card (Stock Overview) ─────────────────────────────────────────
  Widget _buildPropertyCard(Map<String, dynamic> p) {
    final name     = _safeText(p['propertyaddress'] ?? p['propertyAddress'], fallback: 'Unnamed Property');
    final owner    = _safeText(p['username'], fallback: 'Unknown');
    final status   = _safeText(p['propertystatus'], fallback: 'Unknown');
    final qty      = _toInt(p['quantity']);
    final imgs     = (p['_preImgs'] as List<dynamic>?) ?? <dynamic>[];
    final qtyColor = qty <= 0 ? AdminColors.danger : qty <= 2 ? AdminColors.warning : AdminColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(
            color: AdminColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            child: SizedBox(
              width: 110, height: 130,
              child: Stack(fit: StackFit.expand, children: [
                if (imgs.isNotEmpty && imgs.first is Uint8List)
                  Image.memory(imgs.first as Uint8List, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                else if (imgs.isNotEmpty && imgs.first is String)
                  Image.network(imgs.first as String, fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(color: AdminColors.surface,
                            child: const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryLight))));
                      },
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                else
                  _imgPlaceholder(),
                Positioned(
                  bottom: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(7)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_outlined, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('${imgs.length} Photos', style: _mts(9, FontWeight.w500, Colors.white)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(name,
                          style: _mts(13, FontWeight.w600, AdminColors.textPrimary),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _infoBox('Stock', '$qty', qtyColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _infoBox('Owner', owner, AdminColors.primaryLight)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 12, color: AdminColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(owner,
                        style: _mts(11, FontWeight.w400, AdminColors.textMuted),
                        overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.chevron_right, size: 16, color: AdminColors.primaryLight),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _mts(10, FontWeight.w600, color)),
        const SizedBox(height: 2),
        Text(value, style: _mts(12, FontWeight.w700, AdminColors.textPrimary),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    Color color;
    if (lower == 'available') color = AdminColors.success;
    else if (lower == 'pending') color = AdminColors.accent;
    else if (lower == 'unavailable' || lower == 'rejected') color = AdminColors.danger;
    else color = AdminColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(status, style: _mts(10, FontWeight.w700, color)),
      ]),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: AdminColors.surface,
    child: const Center(child: Icon(Icons.image_outlined, color: AdminColors.border, size: 28)),
  );

  // ── Room details ────────────────────────────────────────────────────────────
  Widget _buildRoomDetails(dynamic roomDetails) {
    if (roomDetails == null) {
      return Text('No room details available',
          style: _mts(12, FontWeight.w400, AdminColors.textMuted));
    }
    dynamic parsed = roomDetails;
    if (roomDetails is String) {
      try { parsed = jsonDecode(roomDetails); }
      catch (_) {
        return Text(roomDetails.trim().isEmpty ? 'No room details available' : roomDetails,
            style: _mts(12, FontWeight.w400, AdminColors.textMuted));
      }
    }
    if (parsed is! List || parsed.isEmpty) {
      return Text('No room details available',
          style: _mts(12, FontWeight.w400, AdminColors.textMuted));
    }
    return Column(
      children: parsed.map<Widget>((room) {
        if (room is! Map) return const SizedBox.shrink();
        final roomName = _safeText(
            room['roomName'] ?? room['name'] ?? room['room_type'] ?? room['roomType'],
            fallback: 'Room');
        final roomQty =
            _safeText(room['quantity'] ?? room['stock'] ?? room['roomQuantity'], fallback: '-');
        final packageName =
            _safeText(room['packageName'] ?? room['package'] ?? room['package_name'], fallback: '');
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AdminColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.bed_outlined, size: 16, color: AdminColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                packageName.isEmpty ? roomName : '$roomName • $packageName',
                style: _mts(12, FontWeight.w600, AdminColors.textPrimary),
              ),
            ),
            Text('Qty: $roomQty', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
          ]),
        );
      }).toList(),
    );
  }

  // ── Tab 2: Daily Occupancy ──────────────────────────────────────────────────
  Widget _buildOccupancyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AdminColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _dateRange != null ? AdminColors.primary : AdminColors.border),
                  boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(children: [
                  const Icon(Icons.date_range_outlined, color: AdminColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _dateRange == null
                        ? 'Select date range...'
                        : '${_formatDate(_dateRange!.start)}  →  ${_formatDate(_dateRange!.end)}',
                    style: _mts(14, FontWeight.w400,
                        _dateRange == null ? AdminColors.textMuted : AdminColors.textPrimary),
                  )),
                  if (_dateRange != null)
                    GestureDetector(
                      onTap: () {
                        setState(() { _dateRange = null; if (_occupancyLoaded) _applyOccupancyFilter(); });
                      },
                      child: const Icon(Icons.close, size: 16, color: AdminColors.textMuted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _occupancySearchCtrl,
              onChanged: (_) { if (_occupancyLoaded) _applyOccupancyFilter(); },
              style: _mts(14, FontWeight.w400, AdminColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search property name...',
                hintStyle: _mts(14, FontWeight.w400, AdminColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
                filled: true, fillColor: AdminColors.cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingOccupancy ? null : _loadOccupancyData,
                icon: _isLoadingOccupancy
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(_isLoadingOccupancy ? 'Loading...' : 'Load Reservations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: _mts(14, FontWeight.w600, Colors.white),
                ),
              ),
            ),
          ]),
        ),
        if (_occupancyLoaded)
          Expanded(
            child: _filteredReservations.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No reservations found for the selected filters.',
                        textAlign: TextAlign.center,
                        style: _mts(14, FontWeight.w400, AdminColors.textMuted)),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredReservations.length,
                    itemBuilder: (ctx, i) {
                      final r = _filteredReservations[i];
                      final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
                      return _buildReservationCard(m);
                    },
                  ),
          )
        else
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_outlined, size: 56, color: AdminColors.border),
                const SizedBox(height: 12),
                Text('Select filters and tap\n"Load Reservations"',
                    textAlign: TextAlign.center,
                    style: _mts(14, FontWeight.w400, AdminColors.textMuted, height: 1.5)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> r) {
    final resId    = _safeText(r['reservationid'], fallback: '');
    final property = _safeText(r['propertyaddress']);
    final room     = _safeText(r['roomname'], fallback: '');
    final checkIn  = _formatDate(r['checkindate']);
    final checkOut = _formatDate(r['checkoutdate']);
    final guest    = _safeText(r['customername']);
    final status   = _safeText(r['reservationstatus']);

    Color statusColor;
    final sl = status.toLowerCase();
    if (sl == 'paid') statusColor = AdminColors.success;
    else if (sl.contains('partial')) statusColor = AdminColors.warning;
    else if (sl == 'expired' || sl == 'cancelled') statusColor = AdminColors.danger;
    else statusColor = AdminColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(property,
              style: _mts(14, FontWeight.w600, AdminColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: _mts(11, FontWeight.w600, statusColor)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.person_outline, size: 13, color: AdminColors.textMuted),
          const SizedBox(width: 4),
          Expanded(child: Text(guest, style: _mts(12, FontWeight.w400, AdminColors.textMuted),
              overflow: TextOverflow.ellipsis)),
          if (resId.isNotEmpty)
            Text('#$resId', style: _mts(11, FontWeight.w500, AdminColors.textMuted)),
        ]),
        if (room.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.bed_outlined, size: 13, color: AdminColors.textMuted),
            const SizedBox(width: 4),
            Text(room, style: _mts(12, FontWeight.w400, AdminColors.textMuted)),
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.login_outlined, size: 13, color: AdminColors.primary),
          const SizedBox(width: 4),
          Text(checkIn, style: _mts(12, FontWeight.w500, AdminColors.textSecond)),
          const SizedBox(width: 16),
          const Icon(Icons.logout_outlined, size: 13, color: AdminColors.accent),
          const SizedBox(width: 4),
          Text(checkOut, style: _mts(12, FontWeight.w500, AdminColors.textSecond)),
        ]),
      ]),
    );
  }

  // ── Tab 3: Blackout Dates ───────────────────────────────────────────────────
  Widget _buildBlackoutTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Status', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Overridden', 'Expired'].map((f) {
                  final active = _blackoutFilter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _blackoutFilter = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AdminColors.primary : AdminColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? AdminColors.primary : AdminColors.border),
                      ),
                      child: Text(f, style: _mts(12,
                          active ? FontWeight.w600 : FontWeight.w400,
                          active ? Colors.white : AdminColors.textMuted)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Text('Role', style: _mts(12, FontWeight.w600, AdminColors.textSecond)),
            const SizedBox(height: 8),
            Row(
              children: ['All', 'Admin', 'Moderator'].map((f) {
                final active = _blackoutRoleFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _blackoutRoleFilter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AdminColors.accent : AdminColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AdminColors.accent : AdminColors.border),
                    ),
                    child: Text(f, style: _mts(12,
                        active ? FontWeight.w600 : FontWeight.w400,
                        active ? Colors.white : AdminColors.textMuted)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ]),
        ),
        Expanded(
          child: _isLoadingBlackouts
              ? const Center(child: CircularProgressIndicator(color: AdminColors.primary))
              : _blackoutError != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: AdminColors.danger, size: 48),
                      const SizedBox(height: 12),
                      Text('Failed to load blackouts',
                          style: _mts(16, FontWeight.w600, AdminColors.textPrimary)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadBlackouts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.primary, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ]))
                  : _filteredBlackouts.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.block_outlined, size: 56, color: AdminColors.border),
                            const SizedBox(height: 12),
                            Text('No blackout dates found',
                                style: _mts(16, FontWeight.w600, AdminColors.textMuted)),
                          ]),
                        ))
                      : RefreshIndicator(
                          onRefresh: _loadBlackouts,
                          color: AdminColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filteredBlackouts.length,
                            itemBuilder: (ctx, i) {
                              final b = _filteredBlackouts[i];
                              final m = b is Map ? Map<String, dynamic>.from(b) : <String, dynamic>{};
                              return _buildBlackoutCard(m);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildBlackoutCard(Map<String, dynamic> b) {
    final property  = _safeText(
        b['property_name'] ?? b['propertyname'] ?? b['propertyaddress'] ?? b['property']);
    final room      = _safeText(b['room_name'] ?? b['roomname'] ?? b['room'], fallback: '');
    final startDate = _formatDate(b['start_date']);
    final endDate   = _formatDate(b['end_date']);
    final reason    = _safeText(b['reason'], fallback: 'No reason provided');
    final creator   = _safeText(
        b['created_by_username'] ?? b['username'] ?? b['createdby'], fallback: 'Unknown');
    final role      = _safeText(
        b['created_by_role'] ?? b['usergroup'] ?? b['role'], fallback: '');
    final id        = _toInt(b['id']);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDt = _parseDate(b['end_date']);
    final isExpired = endDt != null && endDt.isBefore(today);
    final isOverridden = b['is_overridden'] == true || b['is_overridden'] == 1;
    final isActive = b['is_active'] == true || b['is_active'] == 1;

    final String status;
    final Color statusColor;
    if (isOverridden) {
      status = 'Overridden'; statusColor = AdminColors.success;
    } else if (isExpired) {
      status = 'Expired'; statusColor = AdminColors.textMuted;
    } else if (isActive) {
      status = 'Active'; statusColor = AdminColors.warning;
    } else {
      status = 'Inactive'; statusColor = AdminColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        title: Row(children: [
          Expanded(child: Text(property,
              style: _mts(14, FontWeight.w600, AdminColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: _mts(11, FontWeight.w600, statusColor)),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (room.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.bed_outlined, size: 13, color: AdminColors.textMuted),
                const SizedBox(width: 4),
                Text(room, style: _mts(12, FontWeight.w400, AdminColors.textMuted)),
              ]),
              const SizedBox(height: 4),
            ],
            Row(children: [
              const Icon(Icons.login_outlined, size: 13, color: AdminColors.primary),
              const SizedBox(width: 4),
              Text(startDate, style: _mts(12, FontWeight.w500, AdminColors.textSecond)),
              const SizedBox(width: 16),
              const Icon(Icons.logout_outlined, size: 13, color: AdminColors.accent),
              const SizedBox(width: 4),
              Text(endDate, style: _mts(12, FontWeight.w500, AdminColors.textSecond)),
            ]),
            const SizedBox(height: 4),
            Text(reason, style: _mts(12, FontWeight.w400, AdminColors.textMuted),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outline, size: 12, color: AdminColors.textMuted),
              const SizedBox(width: 3),
              Text(creator, style: _mts(11, FontWeight.w400, AdminColors.textMuted)),
              if (role.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AdminColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Text(role, style: _mts(10, FontWeight.w500, AdminColors.textSecond)),
                ),
              ],
            ]),
          ]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AdminColors.danger),
          onPressed: id > 0 ? () => _deleteBlackout(id) : null,
        ),
      ),
    );
  }
}

class _MStatData {
  final IconData icon;
  final String label;
  final int count;
  final Color iconColor;
  final Color iconBg;
  final Color accent;
  const _MStatData({
    required this.icon, required this.label, required this.count,
    required this.iconColor, required this.iconBg, required this.accent,
  });
}
