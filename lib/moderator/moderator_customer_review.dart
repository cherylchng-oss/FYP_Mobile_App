import 'package:flutter/material.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../services/session.dart';
import '../api.dart' as api;
import '../app.dart';
import 'moderator_notification.dart';

class ModeratorCustomerReview extends StatefulWidget {
  const ModeratorCustomerReview({super.key});

  @override
  State<ModeratorCustomerReview> createState() => _ModeratorCustomerReviewState();
}

class _ModeratorCustomerReviewState extends State<ModeratorCustomerReview> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allReviews = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _unreadCount = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  String _sortOrder = 'latest';
  int _currentPage = 1;
  static const int _reviewsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
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

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final userid = await Session.getUserId();
      if (userid == null) return;
      final data = await api.fetchOwnerReviews(userid);
      if (mounted) setState(() => _allReviews = data);
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReply(int reviewId, String text) async {
    if (text.isEmpty) {
      _showSnack('Reply cannot be empty.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final ok = await api.replyToReview(reviewId, text);
      if (ok) {
        _showSnack('Reply submitted successfully. Email notification sent.');
        await _fetchReviews();
      } else {
        _showSnack('Failed to save reply.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _replyToReview(Map<String, dynamic> review) async {
    final controller = TextEditingController(
      text: review['owner_reply'] as String? ?? '',
    );
    final reviewId = _getId(review['reviewid']);
    final hasReply = (review['owner_reply'] as String?)?.isNotEmpty == true;

    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Review'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Write your reply here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(hasReply ? 'Update Reply' : 'Submit'),
          ),
        ],
      ),
    );

    if (reply == null || reply.trim().isEmpty) return;
    await _submitReply(reviewId, reply);
  }

  Future<void> _deleteReply(int reviewId) async {
    final confirmed = await _confirmDialog('Delete Reply', 'Remove your reply from this review?');
    if (!confirmed) return;
    final ok = await api.replyToReview(reviewId, null);
    if (ok) {
      _showSnack('Reply deleted.');
      await _fetchReviews();
    } else {
      _showSnack('Failed to delete reply.', isError: true);
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    final confirmed = await _confirmDialog(
      'Delete Review',
      'Are you sure you want to permanently delete this customer review?',
    );
    if (!confirmed) return;
    final ok = await api.deleteReview(reviewId);
    if (ok) {
      _showSnack('Review deleted.');
      await _fetchReviews();
    } else {
      _showSnack('Failed to delete review.', isError: true);
    }
  }

  List<dynamic> get _filteredSorted {
    final keyword = _searchController.text.trim().toLowerCase();
    var result = _allReviews.where((r) {
      final prop = (r['propertyname'] ?? r['propertyaddress'] ?? '').toString().toLowerCase();
      final customer = (r['reviewer_name'] ?? r['username'] ?? '').toString().toLowerCase();
      final matchSearch = keyword.isEmpty || prop.contains(keyword) || customer.contains(keyword);

      bool matchDate = true;
      if (_startDate != null || _endDate != null) {
        DateTime? rd;
        try {
          final parsed = DateTime.parse(r['reviewdate']?.toString() ?? '');
          rd = DateTime(parsed.year, parsed.month, parsed.day);
        } catch (_) {}
        if (rd != null) {
          if (_startDate != null && _endDate != null) {
            matchDate = !rd.isBefore(_startDate!) && !rd.isAfter(_endDate!);
          } else if (_startDate != null) {
            matchDate = !rd.isBefore(_startDate!);
          } else if (_endDate != null) {
            matchDate = !rd.isAfter(_endDate!);
          }
        }
      }
      return matchSearch && matchDate;
    }).toList();

    result.sort((a, b) {
      DateTime da, db;
      try { da = DateTime.parse(a['reviewdate']?.toString() ?? ''); } catch (_) { da = DateTime(2000); }
      try { db = DateTime.parse(b['reviewdate']?.toString() ?? ''); } catch (_) { db = DateTime(2000); }
      return _sortOrder == 'oldest' ? da.compareTo(db) : db.compareTo(da);
    });
    return result;
  }

  List<dynamic> get _currentPageReviews {
    final all = _filteredSorted;
    final start = (_currentPage - 1) * _reviewsPerPage;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _reviewsPerPage).clamp(0, all.length));
  }

  int get _totalPages => (_filteredSorted.length / _reviewsPerPage).ceil();

  double _toDouble(dynamic v, [double fb = 0.0]) {
    if (v == null) return fb;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  int _getId(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AdminColors.danger : AdminColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<bool> _confirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(title, style: const TextStyle(color: AdminColors.textPrimary)),
        content: Text(content, style: const TextStyle(color: AdminColors.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false);
    else if (index == 1) Navigator.of(context).pushNamed('/manage-services');
    else if (index == 2) Navigator.of(context).pushNamed('/moderator-stock-manager');
    else if (index == 3) Navigator.of(context).pushNamed('/profile');
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);
    switch (label) {
      case 'Customer Reviews': break;
      case 'Dashboard': Navigator.of(context).pushNamedAndRemoveUntil('/moderator', (route) => false); break;
      case 'User Management': Navigator.of(context).pushNamed('/user-management', arguments: AppRole.moderator); break;
      case 'Properties':
      case 'PropertyListing': Navigator.of(context).pushNamed('/manage-services'); break;
      case 'Stock Manager':
      case 'Reservation':
      case 'Bookings': Navigator.of(context).pushNamed('/moderator-stock-manager'); break;
      case 'Activity Logs': Navigator.of(context).pushNamed('/moderator-activity-logs'); break;
      case 'Ledger': Navigator.of(context).pushNamed('/moderator-ledger'); break;
      case 'Profile': Navigator.of(context).pushNamed('/profile'); break;
    }
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double topPad) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/customer_review.png', fit: BoxFit.cover),
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
                  child: const Icon(Icons.rate_review_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Reviews',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 24, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        'View customer feedback, ratings,\nreplies, and email notifications.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.72), height: 1.4),
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
          Positioned(
            right: -10, bottom: -10,
            child: Icon(icon, size: 68, color: color.withOpacity(0.07)),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: AppTextStyles.caption.copyWith(
                        color: AdminColors.textMuted, fontWeight: FontWeight.w500, fontSize: 11)),
                const SizedBox(height: 2),
                _isLoading
                    ? Container(
                        height: 20, width: 60,
                        decoration: BoxDecoration(
                          color: AdminColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyDefault.copyWith(
                            color: AdminColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final total = _allReviews.length;
    final replied = _allReviews.where((r) => (r['owner_reply'] as String?)?.isNotEmpty == true).length;
    final pending = total - replied;
    final avgRating = total == 0
        ? 0.0
        : _allReviews.fold<double>(0.0, (sum, r) => sum + _toDouble(r['rating'])) / total;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _buildSummaryCard(title: 'Total Reviews', value: total.toString(),             icon: Icons.reviews,         color: AdminColors.primaryLight),
        _buildSummaryCard(title: 'Avg Rating',    value: avgRating.toStringAsFixed(2), icon: Icons.star,            color: AdminColors.accent),
        _buildSummaryCard(title: 'Replied',       value: replied.toString(),           icon: Icons.mark_email_read, color: AdminColors.success),
        _buildSummaryCard(title: 'Pending Reply', value: pending.toString(),           icon: Icons.pending_actions, color: AdminColors.danger),
      ],
    );
  }

  Widget _ratingStars(double rating) {
    final rounded = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rounded ? Icons.star : Icons.star_border,
          size: 18,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }

  Widget _buildScoreRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (_toDouble(value) / 5).clamp(0, 1),
              backgroundColor: AdminColors.border,
              color: AdminColors.accent,
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(_toDouble(value).toStringAsFixed(1),
              style: AppTextStyles.caption.copyWith(
                  color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 105,
              child: Text(label,
                  style: AppTextStyles.caption.copyWith(
                      color: AdminColors.textSecond, fontWeight: FontWeight.w600))),
          Expanded(
              child: Text(value,
                  style: AppTextStyles.caption.copyWith(
                      color: AdminColors.textPrimary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewer = _safeText(review['reviewer_name'] ?? review['username'], fallback: 'Customer');
    final property = _safeText(review['propertyname'] ?? review['propertyaddress'], fallback: 'Unnamed Property');
    final owner = _safeText(review['owner_username'], fallback: 'Owner');
    final cluster = _safeText(review['clustername'], fallback: 'No cluster');
    final comment = _safeText(review['review'], fallback: 'No review text');
    final reply = _safeText(review['owner_reply'], fallback: '');
    final rating = _toDouble(review['rating']);
    final hasReply = reply.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_outline, color: AdminColors.accent, size: 20),
          ),
          title: Text(property,
              style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ratingStars(rating),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasReply ? AdminColors.success.withOpacity(0.12) : AdminColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasReply ? 'Replied' : 'Pending Reply',
                    style: AppTextStyles.caption.copyWith(
                      color: hasReply ? AdminColors.success : AdminColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            _infoRow('Reviewer', reviewer),
            _infoRow('Property Owner', owner),
            _infoRow('Cluster', cluster),
            _infoRow('Review Date', _formatDate(review['reviewdate']?.toString())),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Customer Review',
                  style: AppTextStyles.label.copyWith(
                      color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(comment,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AdminColors.textSecond, height: 1.4)),
            ),
            const SizedBox(height: 12),
            _buildScoreRow('Location', review['location_score']),
            _buildScoreRow('Cleanliness', review['cleanliness_score']),
            _buildScoreRow('Value', review['value_score']),
            _buildScoreRow('Facilities', review['facilities_score']),
            _buildScoreRow('Service', review['service_score']),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AdminColors.surface, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reply / Email Notification',
                      style: AppTextStyles.label.copyWith(
                          color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    hasReply ? reply : 'No reply yet. Submit a reply to notify the customer by email.',
                    style: AppTextStyles.caption.copyWith(
                        color: AdminColors.textSecond, height: 1.4),
                  ),
                  if (hasReply) ...[
                    const SizedBox(height: 6),
                    Text('Reply date: ${_formatDate(review['reply_date']?.toString())}',
                        style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _replyToReview(review),
                icon: const Icon(Icons.reply),
                label: Text(hasReply ? 'Update Reply' : 'Reply to Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final hasFilters = _startDate != null ||
        _endDate != null ||
        _searchController.text.isNotEmpty ||
        _sortOrder != 'latest';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(children: [
            const Icon(Icons.filter_list, size: 16, color: AdminColors.accent),
            const SizedBox(width: 6),
            Text('Filter Reviews',
                style: AppTextStyles.label.copyWith(
                    color: AdminColors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _buildSearchField(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildDateField('From', _startDate, (dt) => setState(() { _startDate = dt; _currentPage = 1; }))),
            const SizedBox(width: 10),
            Expanded(child: _buildDateField('To', _endDate, (dt) => setState(() { _endDate = dt; _currentPage = 1; }))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildSortDropdown()),
            if (hasFilters) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () => setState(() {
                  _searchController.clear();
                  _startDate = null;
                  _endDate = null;
                  _sortOrder = 'latest';
                  _currentPage = 1;
                }),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: AdminColors.textMuted),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search property name or customer name...',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 18),
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary)),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(10),
              color: AdminColors.surface,
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  value == null
                      ? 'mm/dd/yyyy'
                      : '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}',
                  style: AppTextStyles.caption.copyWith(
                      color: value == null ? AdminColors.textMuted : AdminColors.textPrimary),
                ),
              ),
              Icon(Icons.calendar_today, size: 13,
                  color: value == null ? AdminColors.textMuted : AdminColors.accent),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sort',
            style: AppTextStyles.caption.copyWith(
                color: AdminColors.textSecond, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AdminColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AdminColors.surface,
          ),
          child: DropdownButton<String>(
            value: _sortOrder,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AdminColors.cardBg,
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Latest First')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
            ],
            onChanged: (v) => setState(() { _sortOrder = v ?? 'latest'; _currentPage = 1; }),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    final total = _totalPages;
    if (total <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageBtn(Icons.arrow_back_ios_new, _currentPage > 1, () => setState(() => _currentPage--)),
          const SizedBox(width: 8),
          ...List.generate(total, (i) {
            final page = i + 1;
            final show = page == 1 || page == total || (page >= _currentPage - 1 && page <= _currentPage + 1);
            if (!show) return const SizedBox.shrink();
            final active = page == _currentPage;
            return GestureDetector(
              onTap: () => setState(() => _currentPage = page),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? AdminColors.primary : AdminColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? AdminColors.primary : AdminColors.border),
                ),
                alignment: Alignment.center,
                child: Text('$page',
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AdminColors.textMuted)),
              ),
            );
          }),
          const SizedBox(width: 8),
          _pageBtn(Icons.arrow_forward_ios, _currentPage < total, () => setState(() => _currentPage++)),
        ],
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AdminColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 12, color: enabled ? AdminColors.primary : AdminColors.border),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filteredSorted;

    return RefreshIndicator(
      onRefresh: _fetchReviews,
      color: AdminColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary',
                style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Overview of customer feedback and ratings.',
                style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
            const SizedBox(height: 14),
            _buildSummaryGrid(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AdminColors.primary),
                ),
              )
            else if (_allReviews.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AdminColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 52, color: AdminColors.border),
                    const SizedBox(height: 12),
                    Text('No customer reviews found',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Reviews for properties you manage will appear here.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textMuted)),
                  ],
                ),
              )
            else ...[
              _buildFilterCard(),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off, size: 44, color: AdminColors.border),
                      const SizedBox(height: 10),
                      Text('No reviews match your filters',
                          style: AppTextStyles.label.copyWith(
                              color: AdminColors.textSecond, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _startDate = null;
                          _endDate = null;
                          _sortOrder = 'latest';
                          _currentPage = 1;
                        }),
                        child: const Text('Clear Filters', style: TextStyle(color: AdminColors.primary)),
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Showing ${(_currentPage - 1) * _reviewsPerPage + 1}–'
                    '${((_currentPage - 1) * _reviewsPerPage + _currentPageReviews.length)} '
                    'of ${filtered.length} reviews',
                    style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted),
                  ),
                ),
                ..._currentPageReviews.map((r) => _buildReviewCard(r as Map<String, dynamic>)),
                _buildPagination(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.cream,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.moderator,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Customer Reviews',
      ),
      bottomNavigationBar: SharedBottomNavigationBar(
        selectedIndex: 4,
        onTap: _handleBottomNavTap,
        scaffoldKey: _scaffoldKey,
        role: nav.UserRole.moderator,
      ),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
