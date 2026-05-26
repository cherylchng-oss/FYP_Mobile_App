import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../api.dart' as api;
import '../services/session.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});
  static const String routeName = '/owner';

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  bool _isLoading = true;

  // ── Non-finance counts ──────────────────────────────────────────────────────
  int _totalUsers        = 0;
  int _totalProperties   = 0;
  int _totalReservations = 0;
  double _guestRating    = 0.0;
  int _totalClusters     = 0;

  // ── Finance all-time totals ─────────────────────────────────────────────────
  double _allRevenue        = 0.0;
  double _allNetEarnings    = 0.0;
  double _allDepositPaid    = 0.0;
  double _allPendingBalance = 0.0;

  // ── Monthly breakdown ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _monthlyData = [];

  // ── Selected period: null = All Time, 'YYYY-MM' = specific month ────────────
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ── Derived values for the selected period ─────────────────────────────────
  double get _displayRevenue =>
      _selectedMonth == null ? _allRevenue : _monthField(_selectedMonth!, 'monthlyrevenue');

  double get _displayNetEarnings =>
      _selectedMonth == null ? _allNetEarnings : _monthField(_selectedMonth!, 'monthlyearning');

  double get _displayDepositPaid =>
      _selectedMonth == null ? _allDepositPaid : _monthField(_selectedMonth!, 'monthlydeposit');

  double get _displayPendingBalance =>
      _selectedMonth == null ? _allPendingBalance : _monthField(_selectedMonth!, 'monthlyexpectedbalance');

  double _monthField(String month, String field) {
    final row = _monthlyData.firstWhere(
      (m) => (m['month'] ?? '') == month,
      orElse: () => <String, dynamic>{},
    );
    return (row[field] as num?)?.toDouble() ?? 0.0;
  }

  List<String> get _availableMonths {
    final now = DateTime.now();
    // Build "YYYY-MM" ceiling so future months are never shown
    final currentYM =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final months = _monthlyData
        .map((m) => (m['month'] ?? '').toString())
        .where((m) => m.isNotEmpty && m.compareTo(currentYM) <= 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  static String _formatMonth(String ym) {
    try {
      final parts = ym.split('-');
      if (parts.length != 2) return ym;
      const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${names[int.parse(parts[1])]} ${parts[0]}';
    } catch (_) {
      return ym;
    }
  }

  /// Format a currency amount with thousands separator: 87894.50 → "RM 87,894.50"
  static String _fmtRM(double v) {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    return 'RM ${fmt.format(v)}';
  }

  /// Format an integer with thousands separator: 12345 → "12,345"
  static String _fmtInt(int v) {
    return NumberFormat('#,##0', 'en_US').format(v);
  }

  // ── Time-aware greeting ───────────────────────────────────────────────────
  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning, Owner';
    if (h < 17) return 'Good afternoon, Owner';
    return 'Good evening, Owner';
  }

  // ── Load ────────────────────────────────────────────────────────────────────
  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final userId = await Session.getUserId();
      if (userId == null) return;

      // Website Total Users = customers + moderators + administrators
      final results = await Future.wait([
        api.fetchCustomers(),                    // [0] — customers list
        api.fetchPropertiesListingTable(),        // [1]
        api.fetchReservation(),                  // [2]
        api.fetchClusters(),                     // [3]
        api.fetchFinanceLedgerCard(userId),       // [4] — finance + monthly data
        api.fetchFinanceReviewChart(userId),      // [5] — overallRating
        api.fetchModerators(),                   // [6] — for user count
        api.fetchAdministrators(),               // [7] — for user count
      ]);

      final customersData    = results[0] as Map<String, dynamic>;
      final propertiesData   = results[1] as Map<String, dynamic>;
      final reservations     = results[2] as List<dynamic>;
      final clustersData     = results[3] as Map<String, dynamic>;
      final financeData      = results[4] as Map<String, dynamic>;
      final reviewData       = results[5] as Map<String, dynamic>;
      final moderatorsData   = results[6] as Map<String, dynamic>;
      final adminData        = results[7] as Map<String, dynamic>;

      if (!mounted) return;

      // ── User count: customers + moderators + administrators ────────────────
      int _countList(Map<String, dynamic> data, List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is List) return v.length;
        }
        return 0;
      }

      final customerCount   = _countList(customersData,  ['customers',     'data']);
      final moderatorCount  = _countList(moderatorsData,  ['moderators',    'data']);
      final adminCount      = _countList(adminData,       ['administrators','data']);

      // ── Finance ────────────────────────────────────────────────────────────
      final summary    = (financeData['summary']    as Map<String, dynamic>?) ?? {};
      final rawMonthly = (financeData['monthlyData'] as List<dynamic>?) ?? [];
      final monthly    = rawMonthly
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Cap at the current calendar month so future reservations
      // (e.g. Sep 2026 check-ins already in the DB) never become the default.
      final _now = DateTime.now();
      final _currentYM =
          '${_now.year}-${_now.month.toString().padLeft(2, '0')}';

      String? defaultMonth;
      if (monthly.isNotEmpty) {
        final sorted = monthly
            .map((m) => m['month'].toString())
            .where((m) => m.isNotEmpty && m.compareTo(_currentYM) <= 0)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        defaultMonth = sorted.isNotEmpty ? sorted.first : null;
      }

      // ── Rating from review-chart ───────────────────────────────────────────
      final reviewSummary = (reviewData['summary'] as Map<String, dynamic>?) ?? {};
      final overallRating = (reviewSummary['overallRating'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _totalUsers        = customerCount + moderatorCount + adminCount;
        _totalProperties   = ((propertiesData['properties'] as List?) ?? []).length;
        _totalReservations = reservations.length;
        _totalClusters     = ((clustersData['clusters']     as List?) ?? []).length;
        _guestRating       = overallRating;

        _allRevenue        = (summary['totalRevenue']         as num?)?.toDouble() ?? 0.0;
        _allNetEarnings    = (summary['totalOperatorEarning'] as num?)?.toDouble() ?? 0.0;
        _allDepositPaid    = (summary['totalDepositPaid']     as num?)?.toDouble() ?? 0.0;
        _allPendingBalance = (summary['totalExpectedBalance'] as num?)?.toDouble() ?? 0.0;

        _monthlyData   = monthly;
        _selectedMonth = defaultMonth;
        _isLoading     = false;
      });
    } catch (e) {
      print('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (index == 0) return;
    switch (index) {
      case 1: Navigator.of(context).pushReplacementNamed('/owner-users');   break;
      case 2: Navigator.of(context).pushReplacementNamed('/owner-cluster'); break;
      case 3: Navigator.of(context).pushReplacementNamed('/owner-logs');    break;
      case 4: Navigator.of(context).pushNamed('/profile');                  break;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: OwnerHeader(
              greeting: _greeting(),
              title: 'Owner Panel',
              notifCount: 3,
              bottomPadding: 80.0,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Builder(
                  builder: (ctx) => SizedBox(
                    height: OwnerHeader.spacerHeight(bottomPadding: 80, context: ctx) - 45,
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const OwnerSkeletonDashboard()
                      : RefreshIndicator(
                          onRefresh: _loadDashboard,
                          color: AdminColors.success,
                          backgroundColor: Colors.white,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 60),
                            children: [
                              _buildRevenueCard(),
                              const OwnerSectionHeader(title: 'Overview'),
                              _buildStatsGrid(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 0,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  // ── Revenue card ────────────────────────────────────────────────────────────
  Widget _buildRevenueCard() {
    final periodLabel = _selectedMonth == null ? 'All Time' : _formatMonth(_selectedMonth!);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (_, v, child) =>
          Transform.translate(offset: Offset(0, 28 * (1 - v)), child: Opacity(opacity: v, child: child)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: AdminColors.drawerBg.withOpacity(0.14), blurRadius: 40, offset: const Offset(0, 20), spreadRadius: -4),
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + period picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BOOKING REVENUE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2,
                  ),
                ),
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminColors.cream, borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(periodLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.textMuted, size: 15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Animated amount — re-animates when month changes
            TweenAnimationBuilder<double>(
              key: ValueKey(_selectedMonth),
              tween: Tween(begin: 0.0, end: _displayRevenue),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutExpo,
              builder: (_, value, __) => Text(
                _fmtRM(value),
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary,
                  fontSize: MediaQuery.of(context).size.width < 380 ? 30 : 36,
                  fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sub-stats chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _SubStatChip('Net Earnings',      _fmtRM(_displayNetEarnings),    AdminColors.success),
                  const SizedBox(width: 8),
                  _SubStatChip('Deposit Collected', _fmtRM(_displayDepositPaid),    AdminColors.warning),
                  const SizedBox(width: 8),
                  _SubStatChip('Pending Balance',   _fmtRM(_displayPendingBalance), AdminColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month picker sheet ──────────────────────────────────────────────────────
  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(
        months: _availableMonths,
        selectedMonth: _selectedMonth,
        onSelected: (m) => setState(() => _selectedMonth = m),
      ),
    );
  }

  // ── Stats grid ──────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _StatData('TOTAL USERS',   _fmtInt(_totalUsers),        Icons.people_outline_rounded,          false),
      _StatData('PROPERTIES',    _fmtInt(_totalProperties),   Icons.apartment_outlined,              true),
      _StatData('RESERVATIONS',  _fmtInt(_totalReservations), Icons.calendar_today_outlined,         false),
      _StatData('GUEST RATING',
          _guestRating > 0 ? '${_guestRating.toStringAsFixed(2)}/5' : '—',
                                                               Icons.star_outline_rounded,            true),
      _StatData('NET EARNINGS',  _fmtRM(_displayNetEarnings), Icons.account_balance_wallet_outlined, false),
      _StatData('CLUSTERS',      _fmtInt(_totalClusters),     Icons.location_city_outlined,          true),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final gridWidth  = constraints.maxWidth - 40;
      final cardWidth  = (gridWidth - 16) / 2;
      final cardHeight = cardWidth.clamp(155.0, 210.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: stats.length,
          itemBuilder: (_, i) => _buildStatCard(stats[i], i),
        ),
      );
    });
  }

  Widget _buildStatCard(_StatData stat, int index) {
    final baseColor = stat.isSuccess ? AdminColors.success : AdminColors.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + (index * 90)),
      curve: Curves.easeOutQuart,
      builder: (_, val, child) =>
          Transform.translate(offset: Offset(0, 18 * (1 - val)), child: Opacity(opacity: val, child: child)),
      child: BouncyInteractiveCard(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: baseColor.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -2),
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -14, bottom: -14,
                  child: Icon(stat.icon, size: 88, color: AdminColors.textMuted.withOpacity(0.07)),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: baseColor.withOpacity(0.09), shape: BoxShape.circle),
                        child: Icon(stat.icon, color: baseColor, size: 20),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stat.label,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.textMuted, fontSize: 9,
                              fontWeight: FontWeight.w700, letterSpacing: 0.7,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // FittedBox scales down long values like "RM 79,700.00" instead of clipping
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(stat.value,
                              style: GoogleFonts.plusJakartaSans(
                                color: AdminColors.textPrimary, fontSize: 28,
                                fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [baseColor.withOpacity(0.25), baseColor],
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-stat chip (inside revenue card) ─────────────────────────────────────
class _SubStatChip extends StatelessWidget {
  final String label;
  final String formattedValue; // pre-formatted, e.g. "RM 1,234.56"
  final Color color;

  const _SubStatChip(this.label, this.formattedValue, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(formattedValue,
            style: GoogleFonts.plusJakartaSans(
              color: color, fontSize: 13, fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month picker bottom sheet ────────────────────────────────────────────────
class _MonthPickerSheet extends StatelessWidget {
  final List<String> months;
  final String? selectedMonth;
  final ValueChanged<String?> onSelected;

  const _MonthPickerSheet({
    required this.months,
    required this.selectedMonth,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // null = All Time option at the top
    final options = <String?>[null, ...months];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: const BoxDecoration(
        color: AdminColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44, height: 5,
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              decoration: BoxDecoration(
                color: AdminColors.border, borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Period',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final month      = options[i];
                final isSelected = month == selectedMonth;
                final label      = month == null
                    ? 'All Time'
                    : _OwnerDashboardState._formatMonth(month);

                return GestureDetector(
                  onTap: () {
                    onSelected(month);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [] : [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          month == null ? Icons.all_inclusive_rounded : Icons.calendar_month_rounded,
                          size: 18,
                          color: isSelected ? Colors.white : AdminColors.textMuted,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(label,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected ? Colors.white : AdminColors.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data holder ─────────────────────────────────────────────────────────────
class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final bool isSuccess;

  const _StatData(this.label, this.value, this.icon, this.isSuccess);
}