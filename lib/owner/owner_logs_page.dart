import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart' as api;
import '../services/session.dart';

import '../shared/colors.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;

import 'owner_widgets.dart';

// ─── Accent colours unique to this page ──────────────────────────────────────
const _kSurface  = Color(0xFFF0EBE5);
const _kDark     = Color(0xFF2C1A0E);

class OwnerLogsPage extends StatefulWidget {
  const OwnerLogsPage({super.key});
  static const String routeName = '/owner-logs';

  @override
  State<OwnerLogsPage> createState() => _OwnerLogsPageState();
}

class _OwnerLogsPageState extends State<OwnerLogsPage> {
  int _tabIndex = 0;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Month filter — null = All Time, 'YYYY-MM' = specific month
  String? _monthFilter;

  int _currentPage = 1;
  int _totalPages  = 1;

  List<Map<String, dynamic>> _bookLogs  = [];
  List<Map<String, dynamic>> _auditLogs = [];

  // IDs of entries dismissed in this session (client-side clear)
  final Set<String> _dismissedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await Session.getUserId();
      if (userId == null) return;

      final results = await Future.wait([
        api.fetchBookAndPayLogs(userId),
        api.auditTrails(userId),
      ]);

      final bookLogsRaw  = results[0] as List<dynamic>;
      final auditLogsRaw = results[1] as List<dynamic>;

      Map<String, dynamic> mapBookLog(dynamic raw) {
        final m      = Map<String, dynamic>.from(raw as Map);
        final status = (m['status'] ?? m['type'] ?? '').toString().toLowerCase();
        String type  = 'Other';
        if (status.contains('book') || status.contains('reserv')) type = 'Booking';
        if (status.contains('pay')  || status.contains('payment')) type = 'Payment';
        if (status.contains('cancel'))                              type = 'Cancel';
        return {
          'id':     m['id']?.toString() ?? '',
          'action': m['action']      ?? m['description'] ?? m['log_action'] ?? 'Log Entry',
          'type':   type,
          'user':   m['username']    ?? m['user']        ?? m['name']       ?? 'User',
          'time':   m['created_at']  ?? m['timestamp']   ?? m['time']       ?? '',
        };
      }

      Map<String, dynamic> mapAuditLog(dynamic raw) {
        final m      = Map<String, dynamic>.from(raw as Map);
        final action = (m['action'] ?? m['description'] ?? '').toString().toLowerCase();
        String type  = 'Other';
        if (action.contains('book') || action.contains('reserv')) type = 'Booking';
        if (action.contains('pay'))                                type = 'Payment';
        if (action.contains('cancel') || action.contains('suspend')) type = 'Cancel';
        return {
          'id':     (m['audittrailid'] ?? m['id'])?.toString() ?? '',
          'action': m['action']        ?? m['description']     ?? 'Audit Entry',
          'type':   type,
          'user':   m['username']      ?? m['user']            ?? m['performed_by'] ?? 'System',
          'time':   m['created_at']    ?? m['timestamp']       ?? '',
        };
      }

      if (!mounted) return;
      setState(() {
        _bookLogs  = bookLogsRaw.map(mapBookLog).toList();
        _auditLogs = auditLogsRaw.map(mapAuditLog).toList();
        _dismissedIds.clear();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Logs load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Available months in the active tab ─────────────────────────────────────
  List<String> get _availableMonths {
    final base = _tabIndex == 0 ? _bookLogs : _auditLogs;
    final months = base
        .map((l) => _toYearMonth(l['time']?.toString() ?? ''))
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  static String _toYearMonth(String raw) {
    if (raw.isEmpty) return '';
    try {
      // handles "DD/MM/YYYY HH:MM:SS" and ISO formats
      DateTime? dt;
      if (raw.contains('/')) {
        final parts = raw.split(' ')[0].split('/');
        if (parts.length == 3) {
          dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else {
        dt = DateTime.parse(raw);
      }
      if (dt == null) return '';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String _formatMonthLabel(String ym) {
    try {
      final parts = ym.split('-');
      const names = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${names[int.parse(parts[1])]} ${parts[0]}';
    } catch (_) {
      return ym;
    }
  }

  // ── Filtered visible list ──────────────────────────────────────────────────
  List<Map<String, dynamic>> get _visibleList {
    final base = (_tabIndex == 0 ? _bookLogs : _auditLogs)
        .where((l) => !_dismissedIds.contains(l['id']))
        .toList();

    List<Map<String, dynamic>> filtered = base;
    if (_monthFilter != null) {
      filtered = base.where((l) {
        final ym = _toYearMonth(l['time']?.toString() ?? '');
        return ym == _monthFilter;
      }).toList();
    }

    if (_searchQuery.isEmpty) return filtered;
    return filtered.where((l) =>
      (l['action'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
      (l['user']   ?? '').toString().toLowerCase().contains(_searchQuery),
    ).toList();
  }

  void _onNavTap(int index) {
    if (index == 3) return;
    switch (index) {
      case 0: Navigator.of(context).pushReplacementNamed('/owner');         break;
      case 1: Navigator.of(context).pushReplacementNamed('/owner-users');   break;
      case 2: Navigator.of(context).pushReplacementNamed('/owner-cluster'); break;
      case 4: Navigator.of(context).pushNamed('/profile');                  break;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final hdrPad      = isLandscape ? 40.0 : 80.0;
    return Scaffold(
      backgroundColor: AdminColors.cream,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: OwnerHeader(
              title: 'Logs & Audit',
              subtitle: 'All platform activity',
              notifCount: 3,
              bottomPadding: hdrPad,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: OwnerHeader.spacerHeight(bottomPadding: hdrPad, context: context) - 45),
                _buildCommandCenter(isLandscape: isLandscape),
                _buildSectionHeader(),
                Expanded(
                  child: _isLoading
                      ? const OwnerLoading()
                      : _visibleList.isEmpty
                          ? const OwnerEmptyState(message: 'No log entries found.')
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(top: 4, bottom: 40),
                              itemCount: _visibleList.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _visibleList.length) {
                                  return OwnerPagination(
                                    currentPage: _currentPage,
                                    totalPages: _totalPages,
                                    onPageChanged: (p) {
                                      setState(() => _currentPage = p);
                                      _loadData();
                                    },
                                  );
                                }
                                return _buildLogCard(_visibleList[i], i);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 3,
        onTap: _onNavTap,
        role: nav.UserRole.owner,
      ),
    );
  }

  // ── Section header with count + clear button ───────────────────────────────
  Widget _buildSectionHeader() {
    final count = _visibleList.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            _tabIndex == 0 ? 'Book & Pay Logs' : 'Audit Trails',
            style: GoogleFonts.plusJakartaSans(
              color: AdminColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.primary, fontSize: 11, fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          // Clear visible entries (client-side dismissal)
          if (_visibleList.isNotEmpty)
            GestureDetector(
              onTap: _confirmClear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.danger.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 14, color: AdminColors.danger),
                    const SizedBox(width: 5),
                    Text('Clear View',
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminColors.danger, fontSize: 11, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          decoration: BoxDecoration(
            color: AdminColors.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AdminColors.danger.withOpacity(0.10), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: AdminColors.danger, size: 24),
              ),
              const SizedBox(height: 16),
              Text('Clear View',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This hides the currently visible entries from your view. The data is not deleted from the server.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AdminColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          for (final log in _visibleList) {
                            final id = log['id']?.toString() ?? '';
                            if (id.isNotEmpty) _dismissedIds.add(id);
                          }
                        });
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AdminColors.danger, borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text('Clear',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  // ── Command centre ─────────────────────────────────────────────────────────
  Widget _buildCommandCenter({bool isLandscape = false}) {
    final pad = isLandscape ? 10.0 : 16.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: _kDark.withOpacity(0.10), blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildTabToggle(),
          SizedBox(height: isLandscape ? 6 : 12),
          _buildSearchBar(),
          SizedBox(height: isLandscape ? 6 : 12),
          _buildMonthFilter(),
        ],
      ),
    );
  }

  // ── Tab toggle (Book & Pay / Audit Trails) ─────────────────────────────────
  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AdminColors.cream, borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        Expanded(child: _buildTogglePill('Book & Pay',    0)),
        Expanded(child: _buildTogglePill('Audit Trails',  1)),
      ]),
    );
  }

  Widget _buildTogglePill(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabIndex    = index;
          _currentPage = 1;
          _monthFilter = null; // reset filter when switching tabs
          const pageSize = 10;
          final list = index == 0 ? _bookLogs : _auditLogs;
          _totalPages = (list.length / pageSize).ceil().clamp(1, 999);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isActive
              ? [BoxShadow(color: _kDark.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? AdminColors.textPrimary : AdminColors.textMuted,
            fontSize: 14, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withOpacity(0.4)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.plusJakartaSans(
          color: AdminColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          hintText: 'Search logs…',
          hintStyle: GoogleFonts.plusJakartaSans(color: AdminColors.textMuted.withOpacity(0.55), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.search_rounded, color: AdminColors.textMuted.withOpacity(0.55), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: AdminColors.textMuted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  // ── Month filter ───────────────────────────────────────────────────────────
  Widget _buildMonthFilter() {
    final months = _availableMonths;
    final label  = _monthFilter == null ? 'All Time' : _formatMonthLabel(_monthFilter!);

    return GestureDetector(
      onTap: () => _showMonthPicker(months),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _monthFilter != null
              ? AdminColors.primary.withOpacity(0.08)
              : AdminColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _monthFilter != null
                ? AdminColors.primary.withOpacity(0.30)
                : AdminColors.border.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: _monthFilter != null ? AdminColors.primary : AdminColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: _monthFilter != null ? AdminColors.primary : AdminColors.textMuted,
                  fontSize: 13, fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_monthFilter != null)
              GestureDetector(
                onTap: () => setState(() => _monthFilter = null),
                child: Icon(Icons.close_rounded, size: 16, color: AdminColors.primary),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AdminColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(List<String> months) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(
        months: months,
        selected: _monthFilter,
        onSelected: (m) => setState(() {
          _monthFilter = m;
          _currentPage = 1;
        }),
      ),
    );
  }

  // ── Log card ───────────────────────────────────────────────────────────────
  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final type = (log['type'] ?? 'Other').toString();

    Color accent; IconData typeIcon;
    switch (type) {
      case 'Booking': accent = AdminColors.success; typeIcon = Icons.bookmark_added_rounded; break;
      case 'Payment': accent = AdminColors.warning;  typeIcon = Icons.payments_rounded;       break;
      case 'Cancel':  accent = AdminColors.danger;   typeIcon = Icons.cancel_rounded;          break;
      default:        accent = AdminColors.textMuted; typeIcon = Icons.edit_note_rounded;      break;
    }

    final rawTime    = log['time']?.toString() ?? '';
    final timeLabel  = _shortTime(rawTime);
    final monthLabel = _toYearMonth(rawTime);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 60).clamp(0, 360)),
      curve: Curves.easeOutQuart,
      builder: (_, v, child) =>
          Transform.translate(offset: Offset(0, 16 * (1 - v)), child: Opacity(opacity: v, child: child)),
      child: GestureDetector(
        onTap: () => _showLogDetail(log, accent, typeIcon, type),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              // ── Accent strip ───────────────────────────────────────────────
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(typeIcon, size: 18, color: accent),
                    ),
                    const SizedBox(width: 12),
                    // Body
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type badge + time
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(type,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.access_time_rounded, size: 11, color: AdminColors.textMuted.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text(timeLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AdminColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // Action text
                          Text(
                            log['action'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w700, height: 1.4, letterSpacing: -0.1,
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Footer
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 12, color: AdminColors.textMuted.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(log['user'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AdminColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (monthLabel.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kSurface, borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(_formatMonthLabel(monthLabel),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AdminColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 14, color: AdminColors.textMuted.withOpacity(0.3)),
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
        ),
      ),
    );
  }

  static String _shortTime(String raw) {
    if (raw.isEmpty) return '—';
    try {
      DateTime dt;
      if (raw.contains('/')) {
        final parts = raw.split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts.length > 1 ? parts[1].split(':') : ['0','0'];
        dt = DateTime(int.parse(dateParts[2]), int.parse(dateParts[1]), int.parse(dateParts[0]),
                      int.parse(timeParts[0]), int.parse(timeParts[1]));
      } else {
        dt = DateTime.parse(raw).toLocal();
      }
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month]}, $h:$m';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }

  // ── Detail sheet ───────────────────────────────────────────────────────────
  void _showLogDetail(Map<String, dynamic> log, Color accent, IconData typeIcon, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogDetailSheet(
        log: log, accent: accent, typeIcon: typeIcon, type: type,
      ),
    );
  }
}

// ─── Month picker sheet ───────────────────────────────────────────────────────
class _MonthPickerSheet extends StatelessWidget {
  final List<String> months;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _MonthPickerSheet({required this.months, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
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
          Center(
            child: Container(
              width: 44, height: 5,
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              decoration: BoxDecoration(color: AdminColors.border, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Filter by Month',
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
                final m   = options[i];
                final sel = m == selected;
                final lbl = m == null ? 'All Time' : _OwnerLogsPageState._formatMonthLabel(m);
                return GestureDetector(
                  onTap: () { onSelected(m); Navigator.pop(context); },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    decoration: BoxDecoration(
                      color: sel ? AdminColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: sel ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Icon(m == null ? Icons.all_inclusive_rounded : Icons.calendar_month_rounded,
                          size: 16, color: sel ? Colors.white : AdminColors.textMuted),
                        const SizedBox(width: 12),
                        Expanded(child: Text(lbl,
                          style: GoogleFonts.plusJakartaSans(
                            color: sel ? Colors.white : AdminColors.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700,
                          ),
                        )),
                        if (sel) const Icon(Icons.check_rounded, size: 16, color: Colors.white),
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

// ─── Detail bottom sheet ──────────────────────────────────────────────────────
class _LogDetailSheet extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color accent;
  final IconData typeIcon;
  final String type;

  const _LogDetailSheet({
    required this.log, required this.accent,
    required this.typeIcon, required this.type,
  });

  static Map<String, String> _parseAction(String action) {
    final result = <String, String>{};
    final patterns = <String, RegExp>{
      'Total':           RegExp(r'Total[:\s]+RM?\s*([\d,\.]+)',         caseSensitive: false),
      'Deposit Paid':    RegExp(r'Deposit\s*Paid[:\s]+RM?\s*([\d,\.]+)',caseSensitive: false),
      'Balance Paid':    RegExp(r'Balance\s*Paid[:\s]+RM?\s*([\d,\.]+)',caseSensitive: false),
      'Balance Removed': RegExp(r'Balance\s*Removed[:\s]+RM?\s*([\d,\.]+)', caseSensitive: false),
      'Balance Due':     RegExp(r'Balance\s*Due[:\s]+RM?\s*([\d,\.]+)', caseSensitive: false),
      'Refund':          RegExp(r'Refund(?:ed)?[:\s]+RM?\s*([\d,\.]+)', caseSensitive: false),
      'Room/Package':    RegExp(r'Room/Package[:\s]+([^.|]+)',           caseSensitive: false),
      'Reservation #':   RegExp(r'reservation\s*#(\d+)',                caseSensitive: false),
      'Booking Status':  RegExp(r'Booking\s*status\s*changed\s*to\s*([A-Za-z]+)', caseSensitive: false),
    };
    const monetary = ['Total','Deposit Paid','Balance Paid','Balance Removed','Balance Due','Refund'];
    for (final e in patterns.entries) {
      final match = e.value.firstMatch(action);
      if (match != null) {
        final val = match.group(1)?.trim() ?? '';
        if (val.isNotEmpty) result[e.key] = monetary.contains(e.key) ? 'RM $val' : val;
      }
    }
    return result;
  }

  static String _extractSummary(String action) {
    final firstDot  = action.indexOf('. ');
    final firstPipe = action.indexOf(' | ');
    int end = action.length;
    if (firstDot  > 0 && firstDot  < end) end = firstDot;
    if (firstPipe > 0 && firstPipe < end) end = firstPipe;
    return action.substring(0, end).trim();
  }

  static String _formatTime(String raw) {
    if (raw.isEmpty) return '—';
    try {
      DateTime dt;
      if (raw.contains('/')) {
        final parts     = raw.split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts.length > 1 ? parts[1].split(':') : ['0','0'];
        dt = DateTime(int.parse(dateParts[2]), int.parse(dateParts[1]), int.parse(dateParts[0]),
                      int.parse(timeParts[0]), int.parse(timeParts[1]));
      } else {
        dt = DateTime.parse(raw).toLocal();
      }
      const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2,'0');
      final m = dt.minute.toString().padLeft(2,'0');
      return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m';
    } catch (_) {
      return raw;
    }
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'Room/Package':   return Icons.bed_rounded;
      case 'Reservation #':  return Icons.confirmation_number_rounded;
      case 'Booking Status':
      case 'Status':         return Icons.info_outline_rounded;
      default:               return Icons.label_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final action     = log['action']?.toString() ?? '';
    final summary    = _extractSummary(action);
    final parsed     = _parseAction(action);
    const financialK = ['Total','Deposit Paid','Balance Paid','Balance Removed','Balance Due','Refund'];
    final financials = parsed.entries.where((e) => financialK.contains(e.key)).toList();
    final infoFields = parsed.entries.where((e) => !financialK.contains(e.key)).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AdminColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coloured drag strip ────────────────────────────────────────────
          Container(
            height: 4,
            margin: const EdgeInsets.only(top: 12, left: 80, right: 80, bottom: 6),
            decoration: BoxDecoration(color: accent.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 6, 20, MediaQuery.of(context).viewInsets.bottom + 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accent.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                          child: Icon(typeIcon, size: 22, color: accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(type,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: accent, fontSize: 10, fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                summary.isEmpty ? action : summary,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AdminColors.textPrimary, fontSize: 15,
                                  fontWeight: FontWeight.w800, height: 1.4, letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Financial tiles ─────────────────────────────────────────
                  if (financials.isNotEmpty) ...[
                    _SectionLabel('Payment Breakdown', Icons.payments_outlined),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: financials.map((e) {
                        final isTotal = e.key == 'Total';
                        return Container(
                          width: (MediaQuery.of(context).size.width - 60) /
                              (financials.length == 1 ? 1 : 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isTotal ? _kDark : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: isTotal ? null : Border.all(color: AdminColors.border.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isTotal ? Colors.white.withOpacity(0.6) : AdminColors.textMuted,
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(e.value,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isTotal ? Colors.white : AdminColors.textPrimary,
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Info card ───────────────────────────────────────────────
                  _SectionLabel('Details', Icons.info_outline_rounded),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminColors.border.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        ...infoFields.asMap().entries.map((entry) => Column(
                          children: [
                            _DetailRow(icon: _iconForKey(entry.value.key), label: entry.value.key, value: entry.value.value),
                            if (entry.key < infoFields.length - 1 || true)
                              Divider(height: 1, indent: 56, endIndent: 16, color: AdminColors.border.withOpacity(0.3)),
                          ],
                        )),
                        _DetailRow(icon: Icons.person_rounded, label: 'User', value: log['user']?.toString() ?? '—'),
                        Divider(height: 1, indent: 56, endIndent: 16, color: AdminColors.border.withOpacity(0.3)),
                        _DetailRow(icon: Icons.access_time_rounded, label: 'Time', value: _formatTime(log['time']?.toString() ?? '')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Full action text (expandable) ───────────────────────────
                  if (action.length > 80) ...[
                    _SectionLabel('Full Log', Icons.article_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kSurface, borderRadius: BorderRadius.circular(16),
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: action));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: Text(action,
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500, height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Long-press to copy',
                        style: GoogleFonts.plusJakartaSans(color: AdminColors.textMuted.withOpacity(0.5), fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Close ────────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDark, foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AdminColors.textMuted),
        const SizedBox(width: 6),
        Text(text,
          style: GoogleFonts.plusJakartaSans(
            color: AdminColors.textMuted, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AdminColors.cream, borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: AdminColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(value,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
