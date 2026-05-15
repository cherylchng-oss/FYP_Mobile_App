import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../services/session.dart';
import '../shared/bottom_navigation_bar.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/colors.dart';
import '../app.dart';
import '../api.dart' as api;

class ModeratorNotifications extends StatefulWidget {
  const ModeratorNotifications({super.key});

  @override
  State<ModeratorNotifications> createState() => _ModeratorNotificationsState();
}

class _ModeratorNotificationsState extends State<ModeratorNotifications> {
  String _selectedFilter = 'Unread';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<void> _notificationInit;
  bool _isLoading = true;
  List<Map<String, dynamic>> allNotifications = [];

  @override
  void initState() {
    super.initState();
    _notificationInit = NotificationService().initialize();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await api.fetchNotifications();
      setState(() {
        allNotifications = notifications.map((n) => n as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() { _isLoading = false; allNotifications = []; });
    }
  }

  List<Map<String, dynamic>> get filteredNotifications {
    if (_selectedFilter == 'All') return allNotifications;
    if (_selectedFilter == 'Unread') return allNotifications.where((n) => !(n['isRead'] ?? false)).toList();
    return allNotifications.where((n) => n['type'] == _selectedFilter).toList();
  }

  int get unreadCount => allNotifications.where((n) => !(n['isRead'] ?? false)).length;

  Future<void> _markAsRead(int id) async {
    try { await api.markNotificationAsRead(id); } catch (_) {}
    setState(() {
      final n = allNotifications.firstWhere((n) => n['id'] == id, orElse: () => {});
      if (n.isNotEmpty) n['isRead'] = true;
    });
  }

  Future<void> _markAllAsRead() async {
    try { await api.markAllNotificationsAsRead(); } catch (_) {}
    setState(() {
      for (final n in allNotifications) n['isRead'] = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('All notifications marked as read'),
            backgroundColor: AdminColors.success),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    try { await api.deleteNotification(id); } catch (_) {}
    setState(() => allNotifications.removeWhere((n) => n['id'] == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Notification deleted'),
            backgroundColor: AdminColors.danger),
      );
    }
  }

  void _pickupSuggestion(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pick Up Suggestion?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
        content: Text(
          'Are you sure you want to handle this customer request for ${notification['propertyName']}?',
          style: const TextStyle(color: AdminColors.textSecond, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => notification['canPickup'] = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Suggestion picked up successfully!'),
                    backgroundColor: AdminColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
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

  // ===== Stock Manager style header =====
  Widget _buildHeader(double topPad) {
    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/notification.png',
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
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unreadCount > 0
                            ? '$unreadCount unread message${unreadCount == 1 ? '' : 's'}.\nStay on top of your alerts.'
                            : 'All caught up!\nNo new notifications.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.72),
                          height: 1.4,
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
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: AdminColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildFilterSection()),
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: AdminColors.primary)),
                    )
                  else if (filteredNotifications.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildNotificationCard(filteredNotifications[i]),
                          childCount: filteredNotifications.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: -1,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
                color: AdminColors.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$unreadCount Unread',
                    style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text('Mark all read', style: AppTextStyles.bodySmall),
                    style: TextButton.styleFrom(foregroundColor: AdminColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Unread', 'Unread'),
                  _buildFilterChip('Bookings', 'Bookings'),
                  _buildFilterChip('Payment', 'Payment'),
                  _buildFilterChip('Cancellation', 'Cancellation'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        backgroundColor: AdminColors.surface,
        selectedColor: AdminColors.primary,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: isSelected ? Colors.white : AdminColors.textSecond,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(color: isSelected ? AdminColors.secondary : AdminColors.border),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AdminColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _deleteNotification(notification['id']),
      child: InkWell(
        onTap: () {
          if (!isRead) _markAsRead(notification['id']);
          _showNotificationDetails(notification);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isRead ? AdminColors.cardBg : AdminColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? AdminColors.border : AdminColors.primary,
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: AdminColors.primary.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNotificationIcon(notification['type'], isRead),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['title'] ?? '',
                                  style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                      color: AdminColors.primary, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['message'] ?? '',
                            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textSecond, height: 1.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.access_time, size: 13, color: AdminColors.textMuted),
                            const SizedBox(width: 4),
                            Text(notification['time'] ?? '',
                                style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                if (notification['type'] == 'broadcast_suggestion' &&
                    notification['canPickup'] == true) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pickupSuggestion(notification),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Pick Up Suggestion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type, bool isRead) {
    IconData icon;
    Color color;
    Color bgColor;
    switch (type) {
      case 'payment_received':
        icon = Icons.payment; color = AdminColors.success;
        bgColor = AdminColors.success.withOpacity(0.12); break;
      case 'room_enquiry':
        icon = Icons.help_outline; color = AdminColors.accent;
        bgColor = AdminColors.accent.withOpacity(0.12); break;
      case 'broadcast_suggestion':
        icon = Icons.campaign; color = const Color(0xFF7C3AED);
        bgColor = const Color(0xFFEDE9FE); break;
      default:
        icon = Icons.notifications; color = AdminColors.textMuted;
        bgColor = AdminColors.surface;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(isRead ? 0.6 : 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.notifications_none, size: 52, color: AdminColors.primary),
            ),
            const SizedBox(height: 24),
            Text('No Notifications',
                style: AppTextStyles.h2.copyWith(color: AdminColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'All caught up!\nWe\'ll notify you of new customer activities.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildNotificationIcon(notification['type'], false),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(notification['title'] ?? '',
                      style: AppTextStyles.h3.copyWith(color: AdminColors.textPrimary)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AdminColors.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(notification['message'] ?? '',
                style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textSecond, height: 1.6)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                children: [
                  if (notification['customerName'] != null)
                    _buildDetailItem(Icons.person, 'Customer', notification['customerName']),
                  if (notification['propertyName'] != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailItem(Icons.home, 'Property', notification['propertyName']),
                  ],
                  if (notification['amount'] != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailItem(Icons.attach_money, 'Amount',
                        'RM ${notification['amount'].toStringAsFixed(2)}'),
                  ],
                  if (notification['dates'] != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailItem(Icons.calendar_today, 'Dates', notification['dates']),
                  ],
                  if (notification['broadcastBy'] != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailItem(
                        Icons.person_outline, 'Broadcast By', notification['broadcastBy']),
                  ],
                  if (notification['details'] != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailItem(Icons.info_outline, 'Details', notification['details']),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time, size: 14, color: AdminColors.textMuted),
              const SizedBox(width: 4),
              Text(notification['time'] ?? '',
                  style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
            ]),
            const SizedBox(height: 20),
            if (notification['type'] == 'broadcast_suggestion' &&
                notification['canPickup'] == true) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickupSuggestion(notification);
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text('Pick Up Suggestion',
                      style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteNotification(notification['id']);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.danger,
                      side: const BorderSide(color: AdminColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Delete', style: AppTextStyles.label.copyWith(color: AdminColors.danger, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Close', style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminColors.accent),
        const SizedBox(width: 8),
        Text('$label: ',
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
