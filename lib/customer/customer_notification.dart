import 'package:flutter/material.dart';
import '../api.dart' as api;
import '../services/session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens (mirrors AppColors from customer_rooms.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const primary      = Color(0xFF6B3F1A);
  static const primaryLight = Color(0xFF8B5E3C);
  static const accent       = Color(0xFFBF8040);
  static const accentLight  = Color(0xFFE8B97A);
  static const cream        = Color(0xFFFAF6F0);
  static const surface      = Color(0xFFF5EDE0);
  static const surfaceAlt   = Color(0xFFF0E6D8);
  static const border       = Color(0xFFE8D9C5);
  static const textPrimary  = Color(0xFF2C1A0E);
  static const textSecond   = Color(0xFF6B4C30);
  static const textMuted    = Color(0xFFA07850);
  static const unreadBg     = Color(0xFFFFF8F0);
  static const unreadAccent = Color(0xFFBF8040);
  static const success      = Color(0xFF3D7A5C);
  static const successBg    = Color(0xFFEBF7F2);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification type → icon + color
// ─────────────────────────────────────────────────────────────────────────────
IconData _typeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'payment reminder': return Icons.payment_rounded;
    case 'upcoming booking': return Icons.calendar_today_rounded;
    case 'booking confirmed': return Icons.check_circle_rounded;
    case 'booking cancelled': return Icons.cancel_rounded;
    default: return Icons.notifications_rounded;
  }
}

Color _typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'payment reminder': return const Color(0xFFB86A1A);
    case 'upcoming booking': return const Color(0xFF2563EB);
    case 'booking confirmed': return _C.success;
    case 'booking cancelled': return const Color(0xFFB83232);
    default: return _C.accent;
  }
}

Color _typeBg(String type) {
  switch (type.toLowerCase()) {
    case 'payment reminder': return const Color(0xFFFFF3E0);
    case 'upcoming booking': return const Color(0xFFEFF6FF);
    case 'booking confirmed': return _C.successBg;
    case 'booking cancelled': return const Color(0xFFFBECEC);
    default: return _C.surface;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> notifications = [];
  String filter = 'All';
  bool loading = true;

  int currentPage = 1;
  final int itemsPerPage = 5;

  int? userId;

  final List<String> filters = [
    'All',
    'Unread',
    'Read',
    'Payment Reminder',
    'Upcoming Booking',
  ];

  // ── Icons for filter chips ────────────────────────────────────────────────
  static const _filterIcons = {
    'All':              Icons.inbox_rounded,
    'Unread':           Icons.mark_email_unread_rounded,
    'Read':             Icons.mark_email_read_rounded,
    'Payment Reminder': Icons.payment_rounded,
    'Upcoming Booking': Icons.calendar_today_rounded,
  };

  // ── Lifecycle (unchanged) ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loadUserAndNotifications();
  }

  Future<void> loadUserAndNotifications() async {
    try {
      final storedId = await Session.getUserId();
      if (storedId != null) {
        userId = int.tryParse(storedId.toString());
        if (userId != null) {
          await loadNotifications();
        } else {
          setState(() => loading = false);
        }
      } else {
        setState(() => loading = false);
      }
    } catch (error) {
      debugPrint('Failed to load user id: $error');
      setState(() => loading = false);
    }
  }

  Future<void> loadNotifications() async {
    if (userId == null) { setState(() => loading = false); return; }
    try {
      setState(() => loading = true);
      print('Notification userId: $userId');
      try { await api.syncBookingAlertNotifications(userId!); } catch (syncError) { debugPrint('Failed to sync booking alerts: $syncError'); }
      final data = await api.fetchNotifications(userId!);
      setState(() => notifications = data);
    } catch (error) {
      debugPrint('Failed to load notifications: $error');
      setState(() => notifications = []);
    } finally {
      setState(() => loading = false);
    }
  }

  List<dynamic> get filteredNotifications {
    return notifications.where((item) {
      if (filter == 'All') return true;
      if (filter == 'Unread') return item['isread'] == false;
      if (filter == 'Read') return item['isread'] == true;
      return item['notificationtype'] == filter;
    }).toList();
  }

  int get totalPages => (filteredNotifications.length / itemsPerPage).ceil();

  List<dynamic> get paginatedNotifications {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    return filteredNotifications.sublist(
      startIndex,
      endIndex > filteredNotifications.length ? filteredNotifications.length : endIndex,
    );
  }

  void changeFilter(String selectedFilter) => setState(() { filter = selectedFilter; currentPage = 1; });

  void goToPage(int page) { if (page >= 1 && page <= totalPages) setState(() => currentPage = page); }

  Future<void> handleNotificationClick(dynamic item) async {
    try {
      if (item['isread'] == false) {
        await api.markNotificationAsRead(item['notificationid']);
        setState(() {
          notifications = notifications.map((n) {
            if (n['notificationid'] == item['notificationid']) {
              return {...n, 'isread': true, 'notificationstatus': 'Read'};
            }
            return n;
          }).toList();
        });
      }
    } catch (error) { debugPrint('Failed to open notification: $error'); }
  }

  Future<void> handleMarkAllRead() async {
    if (userId == null) return;
    try {
      await api.markAllNotificationsAsRead(userId!);
      setState(() {
        notifications = notifications.map((n) => {...n, 'isread': true, 'notificationstatus': 'Read'}).toList();
      });
    } catch (error) { debugPrint('Failed to mark all as read: $error'); }
  }

  List<dynamic> getPageNumbers() {
    if (totalPages <= 5) return List.generate(totalPages, (i) => i + 1);
    if (currentPage <= 3) return [1, 2, 3, 4, '...', totalPages];
    if (currentPage >= totalPages - 2) return [1, '...', totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    return [1, '...', currentPage - 1, currentPage, currentPage + 1, '...', totalPages];
  }

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp.toString()).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) { return timestamp.toString(); }
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp.toString()).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return formatDate(timestamp);
    } catch (_) { return formatDate(timestamp); }
  }

  int get unreadCount => notifications.where((n) => n['isread'] == false).length;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 20),
              _buildSummaryBar(),
              const SizedBox(height: 16),
              _buildNotificationList(),
            ]),
          )),
        )),
      ]),
    );
  }

  // ── Header (gradient + back arrow) ───────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D1F0A), _C.primary, _C.primaryLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Back button
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              // Title block
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
                      child: Text('$unreadCount new', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text('View your latest and previous notifications.',
                  style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12, height: 1.4)),
              ])),
              const SizedBox(width: 10),
              // Mark all read button
              if (isWide || constraints.maxWidth > 400)
                InkWell(
                  onTap: handleMarkAllRead,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.done_all_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text('Mark all read', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }

  // ── Summary bar ───────────────────────────────────────────────────────────
  Widget _buildSummaryBar() {
    final total  = filteredNotifications.length;
    final unread = filteredNotifications.where((n) => n['isread'] == false).length;
    final read   = total - unread;

    return Row(children: [
      _summaryChip(Icons.inbox_rounded, '$total Total', _C.surface, _C.textSecond, _C.border),
      const SizedBox(width: 10),
      _summaryChip(Icons.mark_email_unread_rounded, '$unread Unread', _C.unreadBg, _C.accent, _C.accent.withOpacity(0.25)),
      const SizedBox(width: 10),
      _summaryChip(Icons.check_circle_outline_rounded, '$read Read', _C.successBg, _C.success, _C.success.withOpacity(0.25)),
    ]);
  }

  Widget _summaryChip(IconData icon, String label, Color bg, Color fg, Color borderColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: fg, size: 15),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );

  // ── Filter chips ──────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: filters.map((item) {
        final isActive = filter == item;
        final icon = _filterIcons[item] ?? Icons.filter_list_rounded;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => changeFilter(item),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? _C.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _C.primary : _C.border),
                boxShadow: isActive ? [BoxShadow(color: _C.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: isActive ? Colors.white : _C.textMuted),
                const SizedBox(width: 7),
                Text(item, style: TextStyle(color: isActive ? Colors.white : _C.textSecond, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }

  // ── Notification list ─────────────────────────────────────────────────────
  Widget _buildNotificationList() {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
        child: Column(children: [
          const CircularProgressIndicator(color: _C.accent, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Loading notifications...', style: TextStyle(color: _C.textMuted, fontSize: 14)),
        ]),
      );
    }

    if (filteredNotifications.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(44),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_off_rounded, color: _C.textMuted, size: 32)),
          const SizedBox(height: 16),
          const Text('No notifications found', style: TextStyle(color: _C.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(filter == 'All' ? 'You\'re all caught up!' : 'No "$filter" notifications.',
            style: const TextStyle(color: _C.textMuted, fontSize: 13)),
        ]),
      );
    }

    return Column(children: [
      ...paginatedNotifications.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildNotificationCard(item),
      )),
      if (totalPages > 1) ...[const SizedBox(height: 8), _buildPagination()],
    ]);
  }

  // ── Notification card ─────────────────────────────────────────────────────
  Widget _buildNotificationCard(dynamic item) {
    final bool isUnread = item['isread'] == false;
    final String type   = item['notificationtype']?.toString() ?? '';
    final iconData      = _typeIcon(type);
    final iconColor     = _typeColor(type);
    final iconBg        = _typeBg(type);

    return InkWell(
      onTap: () => handleNotificationClick(item),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? _C.unreadBg : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isUnread ? _C.accent.withOpacity(0.35) : _C.border, width: isUnread ? 1.5 : 1),
          boxShadow: [BoxShadow(color: _C.primary.withOpacity(isUnread ? 0.09 : 0.05), blurRadius: isUnread ? 16 : 8, offset: const Offset(0, 4))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Type icon ────────────────────────────────────────────────────
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          // ── Content ──────────────────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(item['notificationtitle']?.toString() ?? '',
                style: TextStyle(fontSize: 15, fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700, color: _C.textPrimary, height: 1.3))),
              const SizedBox(width: 10),
              _buildStatusBadge(isUnread),
            ]),
            const SizedBox(height: 8),
            // Message
            Text(item['notificationmessage']?.toString() ?? '',
              style: const TextStyle(color: _C.textSecond, height: 1.55, fontSize: 13)),
            const SizedBox(height: 10),
            // Footer row
            Row(children: [
              // Type pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(iconData, size: 11, color: iconColor),
                  const SizedBox(width: 4),
                  Text(type, style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
              const Spacer(),
              // Timestamp
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time_rounded, size: 12, color: _C.textMuted),
                const SizedBox(width: 4),
                Text(_timeAgo(item['timestamp']), style: const TextStyle(color: _C.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildStatusBadge(bool isUnread) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: isUnread ? _C.accent.withOpacity(0.12) : _C.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isUnread ? _C.accent.withOpacity(0.35) : _C.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: isUnread ? _C.accent : _C.textMuted, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(isUnread ? 'Unread' : 'Read',
        style: TextStyle(color: isUnread ? _C.accent : _C.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );

  // ── Pagination ────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      child: Column(children: [
        // Page info
        Text('Page $currentPage of $totalPages  ·  ${filteredNotifications.length} total',
          style: const TextStyle(color: _C.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6, runSpacing: 6,
          children: [
            _paginationBtn(label: '← Prev', disabled: currentPage == 1, onTap: () => goToPage(currentPage - 1)),
            ...getPageNumbers().map((page) {
              if (page == '...') {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w800, fontSize: 16)),
                );
              }
              return _pageNumber(page as int);
            }),
            _paginationBtn(label: 'Next →', disabled: currentPage == totalPages, onTap: () => goToPage(currentPage + 1)),
          ],
        ),
      ]),
    );
  }

  Widget _paginationBtn({required String label, required bool disabled, required VoidCallback onTap}) =>
    InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: disabled ? _C.surface : _C.primary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: disabled ? _C.border : _C.primary),
        ),
        child: Text(label, style: TextStyle(color: disabled ? _C.textMuted : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );

  Widget _pageNumber(int page) {
    final isActive = currentPage == page;
    return InkWell(
      onTap: () => goToPage(page),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40, height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? _C.accent : _C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? _C.accent : _C.border),
          boxShadow: isActive ? [BoxShadow(color: _C.accent.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Text('$page', style: TextStyle(color: isActive ? Colors.white : _C.textSecond, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}