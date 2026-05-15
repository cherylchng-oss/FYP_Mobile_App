import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app.dart';
import '../services/session.dart';
import '../shared/navigation_menu.dart' as nav;
import '../shared/bottom_navigation_bar.dart';
import '../shared/colors.dart';
import '../api.dart' as api;
import 'admin_notification.dart';

class AdminCustomerReviewsPage extends StatefulWidget {
  const AdminCustomerReviewsPage({super.key});

  @override
  State<AdminCustomerReviewsPage> createState() =>
      _AdminCustomerReviewsPageState();
}

class _AdminCustomerReviewsPageState extends State<AdminCustomerReviewsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  static const String _baseUrl = 'http://167.99.113.105:8080';

  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;

  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _summary = {};

  DateTime? _startDate;
  DateTime? _endDate;
  String _sortOrder = 'latest';
  int _currentPage = 1;
  static const int _reviewsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadReviews();
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

  Future<Map<String, String>> _headers() async {
    final token = await Session.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Authentication token was not found. Please log in again.');
    }

    return {
      'Content-Type': 'application/json',
      'X-Client-Type': 'mobile',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/customer-reviews'),
        headers: await _headers(),
      );

      debugPrint('REVIEWS DEBUG: status = ${response.statusCode}');
      debugPrint('REVIEWS DEBUG: body = ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : 'Failed to load reviews. Status code: ${response.statusCode}',
        );
      }

      if (decoded is Map<String, dynamic> && decoded['success'] == false) {
        throw Exception(decoded['message'] ?? 'Failed to load reviews.');
      }

      final rawReviews = decoded is Map<String, dynamic> && decoded['reviews'] is List
          ? decoded['reviews'] as List
          : <dynamic>[];

      final mappedReviews = rawReviews
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final mappedSummary =
          decoded is Map<String, dynamic> && decoded['summary'] is Map
              ? Map<String, dynamic>.from(decoded['summary'])
              : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _reviews = mappedReviews;
        _summary = mappedSummary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _replyToReview(Map<String, dynamic> review) async {
    final controller = TextEditingController(
      text: _safeText(review['owner_reply'], fallback: ''),
    );

    final reply = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                backgroundColor: const Color(0xFF80BF54),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (reply == null || reply.trim().isEmpty) return;

    try {
      final reviewId = review['reviewid'];

      final response = await http.put(
        Uri.parse('$_baseUrl/reviews/$reviewId/reply'),
        headers: await _headers(),
        body: jsonEncode({'owner_reply': reply}),
      );

      debugPrint('REPLY DEBUG: status = ${response.statusCode}');
      debugPrint('REPLY DEBUG: body = ${response.body}');

      if (response.statusCode != 200) {
        final decoded = jsonDecode(response.body);
        throw Exception(
          decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : 'Failed to submit reply.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply submitted successfully. Email notification sent.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _loadReviews();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;

    if (index == 0) {
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushNamed('/manage-services');
      return;
    }

    if (index == 2) {
      Navigator.of(context).pushNamed('/admin-stock-manager');
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushNamed('/profile');
      return;
    }
  }

  void _handleMenuSelection(String label) {
    Navigator.pop(context);

    switch (label) {
      case 'Dashboard':
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
        return;
      case 'Customer':
        Navigator.of(context).pushNamed('/admin-customers');
        return;
      case 'Moderator':
        Navigator.of(context).pushNamed('/admin-moderators');
        return;
      case 'Property Listing':
      case 'Properties':
        Navigator.of(context).pushNamed('/manage-services');
        return;
      case 'Reservation':
      case 'Bookings':
        Navigator.of(context).pushNamed('/admin-stock-manager');
        return;
      case 'Stock Manager':
        Navigator.of(context).pushNamed('/admin-stock-manager');
        return;
      case 'Activity Logs':
        Navigator.of(context).pushNamed('/admin-activity-logs');
        return;
      case 'Ledger':
        Navigator.of(context).pushNamed('/admin-ledger');
        return;
      case 'Customer Review':
        return;
      case 'User Management':
        Navigator.of(context).pushNamed('/user-management', arguments: AppRole.admin);
        return;
      case 'Profile':
        Navigator.of(context).pushNamed('/profile');
        return;
    }
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return value.toString();
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            _isLoading
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
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(color: AdminColors.textPrimary),
                ),
            const SizedBox(height: 3),
            Text(title,
                style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final totalReviews = _safeText(_summary['totalReviews'], fallback: _reviews.length.toString());
    final repliedReviews = _safeText(_summary['repliedReviews'], fallback: '0');
    final pendingReplies = _safeText(_summary['pendingReplies'], fallback: '0');
    final averageRating = _toDouble(_summary['averageRating']).toStringAsFixed(2);

    return Column(
      children: [
        Row(children: [
          _buildSummaryCard(title: 'Total Reviews', value: totalReviews, icon: Icons.reviews, color: AdminColors.primaryLight),
          const SizedBox(width: 12),
          _buildSummaryCard(title: 'Avg Rating', value: averageRating, icon: Icons.star, color: AdminColors.accent),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _buildSummaryCard(title: 'Replied', value: repliedReviews, icon: Icons.mark_email_read, color: AdminColors.success),
          const SizedBox(width: 12),
          _buildSummaryCard(title: 'Pending Reply', value: pendingReplies, icon: Icons.pending_actions, color: AdminColors.danger),
        ]),
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
            _infoRow('Review Date', _formatDate(review['reviewdate'])),
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
                    Text('Reply date: ${_formatDate(review['reply_date'])}',
                        style: AppTextStyles.caption.copyWith(color: AdminColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _replyToReview(review),
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

  // ─── Filter / Pagination ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredSorted {
    final keyword = _searchController.text.trim().toLowerCase();
    var result = _reviews.where((r) {
      final prop = (r['propertyname'] ?? r['propertyaddress'] ?? '').toString().toLowerCase();
      final customer = (r['reviewer_name'] ?? r['username'] ?? '').toString().toLowerCase();
      final matchSearch = keyword.isEmpty ||
          prop.contains(keyword) ||
          customer.contains(keyword);

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

  List<Map<String, dynamic>> get _currentPageReviews {
    final all = _filteredSorted;
    final start = (_currentPage - 1) * _reviewsPerPage;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _reviewsPerPage).clamp(0, all.length));
  }

  int get _totalPages => (_filteredSorted.length / _reviewsPerPage).ceil();

  Widget _buildFilterCard() {
    final hasFilters = _startDate != null ||
        _endDate != null ||
        _searchController.text.isNotEmpty ||
        _sortOrder != 'latest';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(14),
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
            Expanded(
                child: _buildDateField('From', _startDate,
                    (dt) => setState(() { _startDate = dt; _currentPage = 1; }))),
            const SizedBox(width: 10),
            Expanded(
                child: _buildDateField('To', _endDate,
                    (dt) => setState(() { _endDate = dt; _currentPage = 1; }))),
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
                style: TextButton.styleFrom(
                    foregroundColor: AdminColors.textMuted),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(10),
        color: AdminColors.surface,
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        const Icon(Icons.search, size: 16, color: AdminColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _searchController,
            style: AppTextStyles.bodySmall.copyWith(color: AdminColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search property name or customer name...',
              hintStyle: AppTextStyles.caption.copyWith(color: AdminColors.textMuted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty)
          GestureDetector(
            onTap: () => _searchController.clear(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.close, size: 14, color: AdminColors.textMuted),
            ),
          ),
      ]),
    );
  }

  Widget _buildDateField(
      String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
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
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(8),
              color: AdminColors.cardBg,
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
              Icon(Icons.calendar_today,
                  size: 13,
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
                color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AdminColors.border),
            borderRadius: BorderRadius.circular(8),
            color: AdminColors.cardBg,
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
            onChanged: (v) =>
                setState(() { _sortOrder = v ?? 'latest'; _currentPage = 1; }),
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
          _pageBtn(Icons.arrow_back_ios_new, _currentPage > 1,
              () => setState(() => _currentPage--)),
          const SizedBox(width: 8),
          ...List.generate(total, (i) {
            final page = i + 1;
            final show = page == 1 ||
                page == total ||
                (page >= _currentPage - 1 && page <= _currentPage + 1);
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
          _pageBtn(Icons.arrow_forward_ios, _currentPage < total,
              () => setState(() => _currentPage++)),
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
    final hasFilters = _startDate != null ||
        _endDate != null ||
        _searchController.text.isNotEmpty ||
        _sortOrder != 'latest';

    return RefreshIndicator(
      onRefresh: _loadReviews,
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
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AdminColors.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.danger.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AdminColors.danger, size: 42),
                    const SizedBox(height: 12),
                    Text('Unable to load customer reviews',
                        style: AppTextStyles.h4.copyWith(color: AdminColors.danger)),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AdminColors.danger),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadReviews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (_reviews.isEmpty)
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
                    const SizedBox(height: 40),
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
                      if (hasFilters) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _startDate = null;
                            _endDate = null;
                            _sortOrder = 'latest';
                            _currentPage = 1;
                          }),
                          child: const Text('Clear Filters'),
                        ),
                      ],
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
                ..._currentPageReviews.map(_buildReviewCard),
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
      endDrawer: MoreMenuDrawer(
        role: nav.UserRole.admin,
        onItemSelected: _handleMenuSelection,
        onLogout: _handleLogout,
        currentPageLabel: 'Customer Review',
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
