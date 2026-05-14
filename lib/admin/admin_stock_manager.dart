import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../api.dart' as api;
import '../app.dart';
import '../services/session.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';

class AdminStockManagerPage extends StatefulWidget {
  const AdminStockManagerPage({super.key});

  @override
  State<AdminStockManagerPage> createState() => _AdminStockManagerPageState();
}

class _AdminStockManagerPageState extends State<AdminStockManagerPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _selectedSection = 'Stock Overview';

  bool _isLoadingStock = true;
  String? _stockError;
  List<Map<String, dynamic>> _properties = [];

  bool _isLoadingReservations = false;
  List<dynamic> _allReservations = [];
  List<dynamic> _filteredReservations = [];
  DateTimeRange? _dateRange;
  final TextEditingController _propertySearchCtrl = TextEditingController();
  bool _occupancyLoaded = false;

  bool _isLoadingBlackouts = true;
  String? _blackoutError;
  List<dynamic> _blackouts = [];
  String _blackoutFilter = 'All';
  String _blackoutRoleFilter = 'All';

  final TextEditingController _stockSearchCtrl = TextEditingController();
  String _stockStatusFilter = 'All Status';
  DateTime? _stockCheckIn;
  DateTime? _stockCheckOut;
  List<Map<String, dynamic>>? _stockFilteredProperties;

  int? _userid;
  String? _username;
  String? _usergroup;

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

  List<Map<String, dynamic>> get _displayProperties =>
      _stockFilteredProperties ?? _properties;

  @override
  void initState() {
    super.initState();
    _loadSession().then((_) {
      _loadStockData();
      _loadBlackouts();
    });
  }

  @override
  void dispose() {
    _propertySearchCtrl.dispose();
    _stockSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    _userid = await Session.getUserId();
    _username = await Session.getUsername();
    _usergroup = await Session.getUserGroup();
  }

  Future<void> _loadStockData() async {
    setState(() { _isLoadingStock = true; _stockError = null; });
    try {
      final data = await api.fetchPropertiesListingTable();
      List<dynamic> raw = data['properties'] ?? data['data'] ?? data['result'] ?? [];
      final mapped = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() { _properties = mapped; _stockFilteredProperties = null; _isLoadingStock = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _stockError = e.toString(); _isLoadingStock = false; });
    }
  }

  Future<void> _loadOccupancyData() async {
    setState(() => _isLoadingReservations = true);
    try {
      final reservations = await api.fetchReservationsForAdminModerator();
      if (!mounted) return;
      setState(() {
        _allReservations = reservations;
        _occupancyLoaded = true;
        _isLoadingReservations = false;
      });
      _applyOccupancyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReservations = false);
    }
  }

  void _applyOccupancyFilter() {
    final search = _propertySearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredReservations = _allReservations.where((r) {
        final map = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        if (_dateRange != null) {
          final checkIn = _parseDate(map['checkindate'] ?? map['checkInDate'] ?? map['check_in_date']);
          if (checkIn == null) return false;
          if (checkIn.isBefore(_dateRange!.start) || checkIn.isAfter(_dateRange!.end)) return false;
        }
        if (search.isNotEmpty) {
          final name = (map['propertyaddress'] ?? map['propertyAddress'] ?? '').toString().toLowerCase();
          if (!name.contains(search)) return false;
        }
        return true;
      }).toList();
    });
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value.toString()); } catch (_) { return null; }
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

  Future<void> _loadBlackouts() async {
    if (_userid == null) { await _loadSession(); if (_userid == null) return; }
    setState(() { _isLoadingBlackouts = true; _blackoutError = null; });
    try {
      final list = await api.fetchBlackouts(_userid!, _usergroup ?? 'admin');
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
        backgroundColor: AdminColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Blackout', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this blackout date?', style: TextStyle(color: AdminColors.textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AdminColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AdminColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await api.deleteBlackout(id, _userid!, _usergroup ?? 'admin');
      _loadBlackouts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _showCreateBlackoutDialog() async {
    final propertyOptions = _properties.map((p) {
      final id = p['propertyid'] ?? p['id'];
      final name = _safeText(p['propertyaddress'] ?? p['propertyAddress'], fallback: 'Unknown');
      return {'id': id, 'name': name};
    }).toList();

    if (propertyOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No properties found. Load stock data first.')),
      );
      return;
    }

    Map<String, dynamic>? selectedProperty = propertyOptions.first;
    String roomName = '';
    DateTime? startDate;
    DateTime? endDate;
    String reason = '';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Blackout Date',
              style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedProperty,
                    decoration: const InputDecoration(labelText: 'Property'),
                    items: propertyOptions
                        .map((p) => DropdownMenuItem(value: p, child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedProperty = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Room Name (optional)'),
                    onChanged: (v) => roomName = v,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startDate == null ? 'Start Date *' : 'Start: ${startDate!.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 14, color: AdminColors.textSecond),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18, color: AdminColors.accent),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AdminColors.primary)),
                          child: child!,
                        ),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      endDate == null ? 'End Date *' : 'End: ${endDate!.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 14, color: AdminColors.textSecond),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18, color: AdminColors.accent),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AdminColors.primary)),
                          child: child!,
                        ),
                      );
                      if (picked != null) setDialogState(() => endDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Reason (optional)'),
                    maxLines: 2,
                    onChanged: (v) => reason = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AdminColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (startDate == null || endDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select start and end dates')));
                  return;
                }
                if (endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await api.createBlackout({
                    'propertyid': selectedProperty!['id'],
                    'property_name': selectedProperty!['name'],
                    'room_name': roomName.isEmpty ? null : roomName,
                    'startDate': startDate!.toIso8601String().split('T')[0],
                    'endDate': endDate!.toIso8601String().split('T')[0],
                    'reason': reason.isEmpty ? null : reason,
                    'created_by_userid': _userid,
                    'created_by_username': _username,
                    'created_by_role': _usergroup ?? 'admin',
                  });
                  _loadBlackouts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create blackout: $e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final t = value.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) { return value.toString(); }
  }

  Color _stockLevelColor(int qty) {
    if (qty <= 0) return AdminColors.danger;
    if (qty <= 2) return AdminColors.accent;
    return AdminColors.success;
  }

  Future<void> _applyStockFilters() async {
    final search = _stockSearchCtrl.text.trim().toLowerCase();
    final hasDateFilter = _stockCheckIn != null || _stockCheckOut != null;
    final hasStatusFilter = _stockStatusFilter != 'All Status';

    if (!hasDateFilter && !hasStatusFilter && search.isEmpty) {
      setState(() => _stockFilteredProperties = null);
      return;
    }

    List<Map<String, dynamic>> result = _properties.where((p) {
      if (search.isEmpty) return true;
      final name = (p['propertyaddress'] ?? p['propertyAddress'] ?? '').toString().toLowerCase();
      return name.contains(search);
    }).toList();

    if (hasDateFilter || hasStatusFilter) {
      if (!_occupancyLoaded) {
        setState(() => _isLoadingReservations = true);
        try {
          final reservations = await api.fetchReservationsForAdminModerator();
          if (!mounted) return;
          setState(() { _allReservations = reservations; _occupancyLoaded = true; _isLoadingReservations = false; });
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoadingReservations = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load reservation data for filtering')));
          return;
        }
      }

      final matchingNames = <String>{};
      for (final r in _allReservations) {
        final rMap = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        if (hasStatusFilter) {
          final resStatus = (rMap['reservationstatus'] ?? rMap['reservationStatus'] ?? '').toString().toLowerCase();
          bool match = false;
          switch (_stockStatusFilter) {
            case 'Paid': match = resStatus == 'paid'; break;
            case 'Partially Paid': match = resStatus == 'partially paid' || resStatus == 'partially_paid'; break;
            case 'Expired': match = resStatus == 'expired'; break;
            case 'Cancelled': match = resStatus == 'cancelled' || resStatus == 'canceled'; break;
          }
          if (!match) continue;
        }
        if (hasDateFilter) {
          final checkIn = _parseDate(rMap['checkindate'] ?? rMap['checkInDate'] ?? rMap['check_in_date']);
          if (checkIn == null) continue;
          if (_stockCheckIn != null && checkIn.isBefore(DateTime(_stockCheckIn!.year, _stockCheckIn!.month, _stockCheckIn!.day))) continue;
          if (_stockCheckOut != null && checkIn.isAfter(DateTime(_stockCheckOut!.year, _stockCheckOut!.month, _stockCheckOut!.day))) continue;
        }
        final propName = (rMap['propertyaddress'] ?? rMap['propertyAddress'] ?? '').toString().toLowerCase();
        if (propName.isNotEmpty) matchingNames.add(propName);
      }

      result = result.where((p) {
        final name = (p['propertyaddress'] ?? p['propertyAddress'] ?? '').toString().toLowerCase();
        return matchingNames.contains(name);
      }).toList();
    }

    setState(() => _stockFilteredProperties = result);
  }

  Future<void> _pickStockDate({required bool isCheckIn}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isCheckIn ? _stockCheckIn : _stockCheckOut) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AdminColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) _stockCheckIn = picked;
        else _stockCheckOut = picked;
      });
    }
  }

  // ── Navigation ──
  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 2) return;
    if (index == 0) { Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false); return; }
    if (index == 1) { Navigator.of(context).pushNamed('/manage-services'); return; }
    if (index == 3) { Navigator.of(context).pushNamed('/profile'); return; }
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false); return;
      case 'Customer': Navigator.of(context).pushNamed('/admin-customers'); return;
      case 'Moderator': Navigator.of(context).pushNamed('/admin-moderators'); return;
      case 'Property Listing':
      case 'Properties': Navigator.of(context).pushNamed('/manage-services'); return;
      case 'Stock Manager': return;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.admin); return;
      case 'Activity Logs': Navigator.of(context).pushNamed('/admin-activity-logs'); return;
      case 'Ledger': Navigator.of(context).pushNamed('/admin-ledger'); return;
      case 'Customer Review': Navigator.of(context).pushNamed('/admin-customer-reviews'); return;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); return;
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Stock Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: const [SizedBox.shrink()],
      ),
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Stock Manager',
      ),
      floatingActionButton: _selectedSection == 'Blackout Dates'
          ? FloatingActionButton.extended(
              onPressed: _showCreateBlackoutDialog,
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Blackout', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 2,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.admin,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildStockHeaderBanner()),
          SliverToBoxAdapter(child: _buildSectionChips()),
        ],
        body: _selectedSection == 'Stock Overview'
            ? _buildStockTab()
            : _selectedSection == 'Daily Occupancy'
                ? _buildOccupancyTab()
                : _buildBlackoutTab(),
      ),
    );
  }

  Widget _buildStockHeaderBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.inventory_2, color: Colors.white70, size: 32),
            SizedBox(height: 12),
            Text('Stock Manager',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Monitor property stock, room quantity, and availability.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionChips() {
    const sections = ['Stock Overview', 'Daily Occupancy', 'Blackout Dates'];

    Widget chip(String label) {
      final selected = _selectedSection == label;
      final IconData icon;
      switch (label) {
        case 'Stock Overview':  icon = Icons.inventory_2;     break;
        case 'Daily Occupancy': icon = Icons.calendar_month;  break;
        default:                icon = Icons.event_busy;
      }
      return GestureDetector(
        onTap: () => setState(() => _selectedSection = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [AdminColors.primary, AdminColors.primaryLight])
                : LinearGradient(colors: [Colors.white, Colors.white.withOpacity(.9)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.transparent : AdminColors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AdminColors.primary.withOpacity(.22)
                    : Colors.black.withOpacity(.03),
                blurRadius: selected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15,
                  color: selected ? Colors.white : AdminColors.primaryLight),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AdminColors.primaryLight,
                  )),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            chip(sections[i]),
            if (i < sections.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ── Tab 1: Stock Overview ──
  Widget _buildStockTab() {
    if (_stockError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AdminColors.danger, size: 48),
              const SizedBox(height: 12),
              const Text('Unable to load stock data',
                  style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text(_stockError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AdminColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStockData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStockData,
      color: AdminColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSummary(),
          const SizedBox(height: 16),
          _buildStockFilterCard(),
          const SizedBox(height: 14),
          if (_isLoadingStock)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AdminColors.primary),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Property Stock List',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (_stockFilteredProperties != null)
                  Text('${_displayProperties.length} result(s)',
                      style: const TextStyle(fontSize: 13, color: AdminColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            if (_properties.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 56, color: AdminColors.border),
                      SizedBox(height: 12),
                      Text('No stock records found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AdminColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ),
              )
            else if (_displayProperties.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No properties match the selected filters.',
                      style: TextStyle(color: AdminColors.textMuted)),
                ),
              )
            else
              ..._displayProperties.map(_buildStockCard),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary() {
    return Column(
      children: [
        Row(
          children: [
            _buildSummaryCard(title: 'Properties', value: _totalProperties.toString(),
                icon: Icons.apartment, color: AdminColors.accent),
            const SizedBox(width: 12),
            _buildSummaryCard(title: 'Total Stock', value: _totalStock.toString(),
                icon: Icons.inventory, color: AdminColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryCard(title: 'Low Stock', value: _lowStockCount.toString(),
                icon: Icons.warning_amber, color: AdminColors.accentLight),
            const SizedBox(width: 12),
            _buildSummaryCard(title: 'Out of Stock', value: _outOfStockCount.toString(),
                icon: Icons.remove_circle_outline, color: AdminColors.danger),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
          boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            _isLoadingStock
              ? Container(
                height: 20,
                width: 60,
                decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(6),
                ),
              )
              : Text(
                value,
                style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildRoomDetails(dynamic roomDetails) {
    if (roomDetails == null) {
      return const Text('No room details available', style: TextStyle(color: AdminColors.textMuted, fontSize: 12));
    }
    dynamic parsed = roomDetails;
    if (roomDetails is String) {
      try { parsed = jsonDecode(roomDetails); }
      catch (_) {
        return Text(roomDetails.trim().isEmpty ? 'No room details available' : roomDetails,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 12));
      }
    }
    if (parsed is! List || parsed.isEmpty) {
      return const Text('No room details available', style: TextStyle(color: AdminColors.textMuted, fontSize: 12));
    }
    return Column(
      children: parsed.map<Widget>((room) {
        if (room is! Map) return const SizedBox.shrink();
        final roomName = _safeText(room['roomName'] ?? room['name'] ?? room['room_type'] ?? room['roomType'], fallback: 'Room');
        final roomQty = _safeText(room['quantity'] ?? room['stock'] ?? room['roomQuantity'], fallback: '-');
        final packageName = _safeText(room['packageName'] ?? room['package'] ?? room['package_name'], fallback: '');
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AdminColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.bed, size: 16, color: AdminColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  packageName.isEmpty ? roomName : '$roomName • $packageName',
                  style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text('Qty: $roomQty',
                  style: const TextStyle(color: AdminColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> property) {
    final propertyName = _safeText(property['propertyaddress'] ?? property['propertyAddress'], fallback: 'Unnamed Property');
    final owner = _safeText(property['username'], fallback: 'Unknown owner');
    final cluster = _safeText(property['clustername'], fallback: 'No cluster');
    final category = _safeText(property['categoryname'], fallback: 'No category');
    final status = _safeText(property['propertystatus'], fallback: 'Unknown');
    final quantity = _toInt(property['quantity']);
    final stockColor = _stockLevelColor(quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: stockColor.withOpacity(0.14),
                child: Icon(Icons.home_work, color: stockColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(propertyName,
                    style: const TextStyle(color: AdminColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _smallInfoBox(label: 'Stock', value: quantity.toString(), color: stockColor)),
              const SizedBox(width: 10),
              Expanded(child: _smallInfoBox(label: 'Owner', value: owner, color: AdminColors.primaryLight)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallInfoBox(label: 'Cluster', value: cluster, color: AdminColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: _smallInfoBox(label: 'Category', value: category, color: AdminColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Room Details',
              style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          _buildRoomDetails(property['room_details']),
        ],
      ),
    );
  }

  Widget _smallInfoBox({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStockFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _stockSearchCtrl,
            style: const TextStyle(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search properties...',
              hintStyle: const TextStyle(color: AdminColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted),
              filled: true,
              fillColor: AdminColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 12, color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _stockStatusFilter,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: AdminColors.textPrimary),
                          items: const ['All Status', 'Paid', 'Partially Paid', 'Expired', 'Cancelled']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => _stockStatusFilter = v ?? 'All Status'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildDatePickerBox(label: 'Check-in', date: _stockCheckIn, onTap: () => _pickStockDate(isCheckIn: true))),
              const SizedBox(width: 10),
              Expanded(child: _buildDatePickerBox(label: 'Check-out', date: _stockCheckOut, onTap: () => _pickStockDate(isCheckIn: false))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoadingReservations ? null : _applyStockFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoadingReservations
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerBox({required String label, required DateTime? date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null
                        ? 'mm/dd/yyyy'
                        : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}',
                    style: TextStyle(fontSize: 11, color: date == null ? AdminColors.textMuted : AdminColors.textPrimary),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 13, color: AdminColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Daily Occupancy ──
  Widget _buildOccupancyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AdminColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: AdminColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dateRange == null
                              ? 'Select date range'
                              : '${_formatDate(_dateRange!.start.toIso8601String())}  →  ${_formatDate(_dateRange!.end.toIso8601String())}',
                          style: TextStyle(
                            color: _dateRange == null ? AdminColors.textMuted : AdminColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        GestureDetector(
                          onTap: () { setState(() => _dateRange = null); if (_occupancyLoaded) _applyOccupancyFilter(); },
                          child: const Icon(Icons.clear, size: 18, color: AdminColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _propertySearchCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search property…',
                  hintStyle: const TextStyle(color: AdminColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AdminColors.accent),
                  filled: true,
                  fillColor: AdminColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.primary)),
                ),
                onChanged: (_) { if (_occupancyLoaded) _applyOccupancyFilter(); },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingReservations ? null : _loadOccupancyData,
                  icon: _isLoadingReservations
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: const Text('Load Reservations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_occupancyLoaded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${_filteredReservations.length} result(s)',
                  style: const TextStyle(color: AdminColors.textMuted, fontSize: 13)),
            ]),
          ),
        Expanded(
          child: !_occupancyLoaded
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 48, color: AdminColors.border),
                      SizedBox(height: 12),
                      Text('Press "Load Reservations" to view data',
                          style: TextStyle(color: AdminColors.textMuted)),
                    ],
                  ),
                )
              : _filteredReservations.isEmpty
                  ? const Center(child: Text('No reservations match the selected filters.',
                      style: TextStyle(color: AdminColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredReservations.length,
                      itemBuilder: (ctx, i) {
                        final r = Map<String, dynamic>.from(
                            _filteredReservations[i] is Map ? _filteredReservations[i] : {});
                        final reservationId = r['reservationid'] ?? r['reservationId'] ?? r['id'] ?? '-';
                        final property = _safeText(r['propertyaddress'] ?? r['propertyAddress'], fallback: 'Unknown Property');
                        final customer = _safeText(r['customername'] ?? r['customerName'] ?? r['username'], fallback: 'Unknown');
                        final room = _safeText(r['roomname'] ?? r['roomName'] ?? r['room_type'], fallback: '-');
                        final checkIn = _formatDate(r['checkindate'] ?? r['checkInDate'] ?? r['check_in_date']);
                        final checkOut = _formatDate(r['checkoutdate'] ?? r['checkOutDate'] ?? r['check_out_date']);
                        final statusRaw = _safeText(r['reservationstatus'] ?? r['reservationStatus'], fallback: 'Unknown');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminColors.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AdminColors.border),
                            boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('#$reservationId',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.accent)),
                                  const Spacer(),
                                  _buildStatusChip(statusRaw),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(property, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.person, size: 14, color: AdminColors.textMuted),
                                const SizedBox(width: 4),
                                Text(customer, style: const TextStyle(fontSize: 13, color: AdminColors.textSecond)),
                                const SizedBox(width: 12),
                                const Icon(Icons.bed, size: 14, color: AdminColors.textMuted),
                                const SizedBox(width: 4),
                                Text(room, style: const TextStyle(fontSize: 13, color: AdminColors.textSecond)),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.login, size: 14, color: AdminColors.success),
                                const SizedBox(width: 4),
                                Text(checkIn, style: const TextStyle(fontSize: 12, color: AdminColors.success)),
                                const SizedBox(width: 12),
                                const Icon(Icons.logout, size: 14, color: AdminColors.accent),
                                const SizedBox(width: 4),
                                Text(checkOut, style: const TextStyle(fontSize: 12, color: AdminColors.accent)),
                              ]),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Tab 3: Blackout Dates ──
  Widget _buildBlackoutTab() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final filtered = _blackouts.where((b) {
      final bMap = b is Map ? b : {};
      final isActive = bMap['is_active'] == true || bMap['is_active'] == 1;
      final isOverridden = bMap['is_overridden'] == true || bMap['is_overridden'] == 1 ||
          (bMap['status'] ?? '').toString().toLowerCase() == 'overridden';
      final endDate = _parseDate(bMap['end_date']);
      final isExpired = endDate != null && endDate.isBefore(today);

      if (_blackoutFilter == 'Active' && !(isActive && !isExpired)) return false;
      if (_blackoutFilter == 'Overridden' && !isOverridden) return false;
      if (_blackoutFilter == 'Expired' && !isExpired) return false;
      if (_blackoutRoleFilter != 'All') {
        final role = (bMap['created_by_role'] ?? '').toString().toLowerCase();
        if (role != _blackoutRoleFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Overridden', 'Expired'].map((f) {
                    final selected = _blackoutFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        onSelected: (_) => setState(() => _blackoutFilter = f),
                        selectedColor: AdminColors.primary,
                        backgroundColor: AdminColors.surface,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AdminColors.textSecond,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: selected ? AdminColors.primary : AdminColors.border),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Admin', 'Moderator'].map((r) {
                    final selected = _blackoutRoleFilter == r;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: (_) => setState(() => _blackoutRoleFilter = r),
                        selectedColor: AdminColors.accent,
                        backgroundColor: AdminColors.surface,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AdminColors.textSecond,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: selected ? AdminColors.accent : AdminColors.border),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingBlackouts)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AdminColors.primary)))
        else if (_blackoutError != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AdminColors.danger, size: 42),
                  const SizedBox(height: 8),
                  Text(_blackoutError!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AdminColors.textMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadBlackouts,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy, size: 48, color: AdminColors.border),
                  const SizedBox(height: 12),
                  Text(
                    _blackoutFilter == 'All' && _blackoutRoleFilter == 'All'
                        ? 'No blackout dates found'
                        : 'No matching blackout dates',
                    style: const TextStyle(color: AdminColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBlackouts,
              color: AdminColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final b = Map<String, dynamic>.from(filtered[i] is Map ? filtered[i] : {});
                  final id = b['id'] ?? b['blackoutid'];
                  final propertyName = _safeText(b['property_name'], fallback: 'Unknown Property');
                  final roomName = _safeText(b['room_name'], fallback: 'All Rooms');
                  final startDate = _formatDate(b['start_date']);
                  final endDate = _formatDate(b['end_date']);
                  final reason = _safeText(b['reason'], fallback: 'No reason provided');
                  final isActive = b['is_active'] == true || b['is_active'] == 1;
                  final createdBy = _safeText(b['created_by_username'], fallback: '-');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminColors.border),
                      boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(propertyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? AdminColors.success.withOpacity(0.12) : AdminColors.textMuted.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: isActive ? AdminColors.success : AdminColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (id != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AdminColors.danger, size: 20),
                                onPressed: () => _deleteBlackout(id is int ? id : int.parse(id.toString())),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.bed, size: 14, color: AdminColors.textMuted),
                          const SizedBox(width: 4),
                          Text(roomName, style: const TextStyle(fontSize: 13, color: AdminColors.textSecond)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.date_range, size: 14, color: AdminColors.accent),
                          const SizedBox(width: 4),
                          Text('$startDate → $endDate',
                              style: const TextStyle(fontSize: 12, color: AdminColors.accent)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.info_outline, size: 14, color: AdminColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(reason, style: const TextStyle(fontSize: 12, color: AdminColors.textMuted))),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.person, size: 14, color: AdminColors.textMuted),
                          const SizedBox(width: 4),
                          Text('By: $createdBy', style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
                        ]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
