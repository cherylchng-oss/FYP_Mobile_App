import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import 'admin_notification.dart';

class AdminAuditTrails extends StatefulWidget {
  const AdminAuditTrails({super.key});

  @override
  State<AdminAuditTrails> createState() => _AdminAuditTrailsState();
}

class _AdminAuditTrailsState extends State<AdminAuditTrails> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  String _selectedActionType = 'All Actions';
  int _currentPage = 1;
  final int _pageSize = 5;
  bool _isLoading = true;
  int _unreadCount = 0;

  List<Map<String, dynamic>> allTrails = [];

  List<Map<String, dynamic>> get _filteredTrails {
    final query = _searchController.text.trim().toLowerCase();
    return allTrails.where((trail) {
      final byType = _selectedActionType == 'All Actions' ||
          trail['actionType'] == _selectedActionType;
      if (!byType) return false;
      if (query.isEmpty) return true;
      final text = [
        trail['entityType'],
        trail['entityId'].toString(),
        trail['action'],
        trail['actionType'],
        trail['actionedBy'],
        trail['timestamp'],
        trail['creatorId'].toString(),
        trail['httpMethod'],
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _searchController.addListener(() => setState(() => _currentPage = 1));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userid = await Session.getUserId();
      if (userid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final auditData = await api.auditTrails(userid);
      if (mounted) {
        final Set<int> userIdsToFetch = {};
        final List<Map<String, dynamic>> tempTrails = [];

        if (auditData is List) {
          for (var log in auditData) {
            final actionedBy = log['username'] ?? log['actionedBy'] ?? log['actionedby'];
            final creatorId = log['userid'] ?? log['creatorid'] ?? 0;
            if (actionedBy is num) {
              userIdsToFetch.add(actionedBy.toInt());
            } else if (actionedBy == null || actionedBy.toString().isEmpty || actionedBy == 'Unknown') {
              if (creatorId is num && creatorId > 0) {
                userIdsToFetch.add(creatorId.toInt());
              }
            }
            tempTrails.add({
              'creatorId': creatorId,
              'entityType': log['entitytype'] ?? log['entityType'] ?? '',
              'entityId': log['entityid'] ?? log['entityId'] ?? 0,
              'action': log['action'] ?? '',
              'actionType': log['actiontype'] ?? log['actionType'] ?? '',
              'actionedBy': actionedBy,
              'actionedById': actionedBy is num ? actionedBy.toInt() : (creatorId is num ? creatorId.toInt() : null),
              'timestamp': log['timestamp'] ?? '',
              'httpMethod': log['actiontype'] ?? log['actionType'] ?? 'POST',
            });
          }
        }

        final Map<int, String> userIdToUsername = {};
        if (userIdsToFetch.isNotEmpty) {
          final futures = userIdsToFetch.map((uid) async {
            try {
              final userData = await api.fetchUserData(uid);
              return MapEntry(uid, userData['username']?.toString() ?? 'Unknown');
            } catch (_) {
              return MapEntry(uid, 'Unknown');
            }
          });
          final results = await Future.wait(futures);
          for (var entry in results) {
            userIdToUsername[entry.key] = entry.value;
          }
        }

        setState(() {
          allTrails.clear();
          for (var trail in tempTrails) {
            final actionedById = trail['actionedById'] as int?;
            if (actionedById != null && userIdToUsername.containsKey(actionedById)) {
              trail['actionedBy'] = userIdToUsername[actionedById]!;
            } else if (trail['actionedBy'] is num) {
              trail['actionedBy'] = 'User ${trail['actionedBy']}';
            } else if (trail['actionedBy'] == null || trail['actionedBy'].toString().isEmpty) {
              trail['actionedBy'] = 'Unknown';
            }
            trail.remove('actionedById');
            allTrails.add(trail);
          }
          allTrails = allTrails.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _actionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'create': return AdminColors.success;
      case 'update': return AdminColors.accent;
      case 'delete': return AdminColors.danger;
      case 'assign':
      case 'request':
      case 'register': return AdminColors.primaryLight;
      case 'login':
      case 'logout': return AdminColors.textMuted;
      default: return AdminColors.textMuted;
    }
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    else if (index == 1) Navigator.of(context).pushNamed('/manage-services');
    else if (index == 2) Navigator.of(context).pushNamed('/admin-stock-manager');
    else if (index == 3) Navigator.of(context).pushNamed('/profile');
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'AuditTrails': break;
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.admin); break;
      case 'Properties':
      case 'PropertyListing': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager':
      case 'Reservation':
      case 'Bookings': Navigator.of(context).pushNamed('/admin-stock-manager'); break;
      case 'BooknPayLog': Navigator.of(context).pushNamed('/admin-book-and-pay'); break;
      case 'Activity Logs': Navigator.of(context).pushNamed('/admin-activity-logs'); break;
      case 'Ledger': Navigator.of(context).pushNamed('/admin-ledger'); break;
      case 'Customer Review': Navigator.of(context).pushNamed('/admin-customer-reviews'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final allFiltered = _filteredTrails;
    final totalItems = allFiltered.length;
    final totalPages = ((totalItems + _pageSize - 1) ~/ _pageSize).clamp(1, 999999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : allFiltered.sublist(startIndex, endIndex);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'AuditTrails',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.admin,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AdminColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audit Records',
                        style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('View administrator system actions and changes.',
                        style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                    const SizedBox(height: 16),
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildFilterCard(),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: CircularProgressIndicator(color: AdminColors.primary),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Text('Records',
                              style: AppTextStyles.label.copyWith(color: AdminColors.textPrimary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('$totalItems found',
                                style: AppTextStyles.caption.copyWith(color: AdminColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTrailList(pageItems, totalItems, totalPages, currentPage),
                    ],
                  ],
                ),
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
            child: Image.asset('assets/audit_trails.png', fit: BoxFit.cover),
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
                  child: const Icon(Icons.history_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audit Trails',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 24, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'Track administrator system\nactions and changes.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.72), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AdminNotifications()),
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
                            child: Text('$_unreadCount',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: AdminColors.primary,
      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search audit trails...',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
        filled: true,
        fillColor: AdminColors.cardBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text('Filter by Action Type',
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AdminColors.surface,
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _selectedActionType,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AdminColors.cardBg,
              icon: const Icon(Icons.keyboard_arrow_down, color: AdminColors.textMuted),
              items: const [
                'All Actions', 'Create', 'Update', 'Delete',
                'Assign', 'Request', 'Register', 'Login', 'Logout',
              ]
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AdminColors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedActionType = value;
                  _currentPage = 1;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailList(
    List<Map<String, dynamic>> trails,
    int totalItems,
    int totalPages,
    int currentPage,
  ) {
    if (totalItems == 0) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 56, color: AdminColors.border),
            const SizedBox(height: 14),
            Text('No records found',
                style: AppTextStyles.h4.copyWith(color: AdminColors.textSecond)),
            const SizedBox(height: 6),
            Text('Try changing the filter or search keyword.',
                style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trails.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildTrailCard(trails[index]),
        ),
        const SizedBox(height: 12),
        _buildPagination(totalPages, currentPage),
      ],
    );
  }

  Widget _buildTrailCard(Map<String, dynamic> trail) {
    final typeColor = _actionTypeColor(trail['actionType'] ?? '');
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
              color: AdminColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.history_outlined, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trail['actionedBy'] ?? '',
                    style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                const SizedBox(height: 3),
                Text(trail['action'] ?? '',
                    style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textSecond)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AdminColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(trail['timestamp'] ?? '',
                          style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(trail['actionType'] ?? '',
                    style: AppTextStyles.caption.copyWith(
                        color: typeColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              PopupMenuButton<String>(
                color: AdminColors.cardBg,
                icon: const Icon(Icons.more_horiz, color: AdminColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'view') _showTrailDetailsDialog(trail);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, size: 18, color: AdminColors.textMuted),
                        const SizedBox(width: 8),
                        Text('View Details',
                            style: AppTextStyles.label.copyWith(
                                color: AdminColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, int currentPage) {
    if (totalPages <= 1) return const SizedBox.shrink();

    List<int> pages;
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      final set = <int>{1, totalPages, currentPage - 1, currentPage, currentPage + 1};
      set.removeWhere((p) => p < 1 || p > totalPages);
      pages = set.toList()..sort();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1 ? () => setState(() => _currentPage = currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left, color: AdminColors.primary),
        ),
        ..._buildPageButtons(pages, currentPage),
        IconButton(
          onPressed: currentPage < totalPages ? () => setState(() => _currentPage = currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right, color: AdminColors.primary),
        ),
      ],
    );
  }

  List<Widget> _buildPageButtons(List<int> pages, int currentPage) {
    final List<Widget> widgets = [];
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (i > 0 && page != pages[i - 1] + 1) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
        ));
      }
      final isSelected = page == currentPage;
      widgets.add(
        GestureDetector(
          onTap: () => setState(() => _currentPage = page),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AdminColors.primary : AdminColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? AdminColors.primary : AdminColors.border),
            ),
            child: Text(
              '$page',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AdminColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _showTrailDetailsDialog(Map<String, dynamic> trail) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AdminColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audit Trail Details',
                      style: AppTextStyles.h4.copyWith(
                          color: AdminColors.textPrimary, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AdminColors.border),
              const SizedBox(height: 8),
              _buildDetailField('Creator ID', trail['creatorId'].toString()),
              _buildDetailField('Actioned By', trail['actionedBy']),
              _buildDetailField('Entity ID', trail['entityId'].toString()),
              _buildDetailField('Entity Type', trail['entityType']),
              _buildDetailField('Timestamp', trail['timestamp']),
              _buildDetailField('Action', trail['action']),
              _buildDetailField('Action Type', trail['httpMethod']),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Close',
                      style: AppTextStyles.label.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value,
              style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary)),
        ],
      ),
    );
  }
}
