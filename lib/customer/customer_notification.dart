import 'package:flutter/material.dart';
import '../api.dart' as api;
import '../services/session.dart';
import '../shared/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const primary       = AdminColors.primary;
  static const primaryLight  = AdminColors.primaryLight;
  static const accent        = AdminColors.accent;
  static const accentLight   = AdminColors.accentLight;
  static const cream         = AdminColors.cream;
  static const surface       = AdminColors.surface;
  static const surfaceAlt   = Color(0xFFF0E6D8);
  static const border        = AdminColors.border;
  static const textPrimary   = AdminColors.textPrimary;
  static const textSecond    = AdminColors.textSecond;
  static const textMuted     = AdminColors.textMuted;
  static const unreadBg     = Color(0xFFFFF8F0);
  static const unreadAccent = Color(0xFFBF8040);
  static const success       = AdminColors.success;
  static const successBg    = Color(0xFFEBF7F2);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification type
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

  final ScrollController _scrollController = ScrollController();

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

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loadUserAndNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      setState(() => currentPage = page);

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

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
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 50,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 20),
                    _buildSummaryBar(),
                    const SizedBox(height: 16),
                    _buildNotificationList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Header
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/customer_stay.png', 
              fit: BoxFit.cover,
            ),
          ),

          // Dark brown overlay
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showMarkAllRead = constraints.maxWidth > 390;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button / left icon box
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Notifications',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),

                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0A43A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$unreadCount new',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'View your latest and\nprevious notifications.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Mark all read button
                    if (showMarkAllRead)
                      InkWell(
                        onTap: handleMarkAllRead,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.done_all_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Mark all read',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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
    if (totalPages <= 1) return const SizedBox.shrink();

    final pageWidgets = <Widget>[
      _pageBtn(
        Icons.chevron_left_rounded,
        currentPage == 1 ? null : () => goToPage(currentPage - 1),
      ),
      ...getPageNumbers().map((page) {
        if (page == '...') return _pageDots();
        return _pageNumberBtn(page as int);
      }),
      _pageBtn(
        Icons.chevron_right_rounded,
        currentPage == totalPages ? null : () => goToPage(currentPage + 1),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: pageWidgets,
      ),
    );
  }

  Widget _pageNumberBtn(int page) {
    final sel = page == currentPage;

    return InkWell(
      onTap: sel ? null : () => goToPage(page),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? _C.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _C.primary : _C.border),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: sel ? Colors.white : _C.textSecond,
          ),
        ),
      ),
    );
  }

  Widget _pageDots() {
    return const SizedBox(
      width: 28,
      height: 38,
      child: Center(
        child: Text(
          '...',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _C.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _pageBtn(IconData icon, VoidCallback? onTap) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: onTap != null ? Colors.white : _C.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Icon(
        icon,
        size: 22,
        color: onTap != null ? _C.primaryLight : _C.border,
      ),
    ),
  );
}