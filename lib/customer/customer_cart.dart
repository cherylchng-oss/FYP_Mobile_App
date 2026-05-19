import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session.dart';
import '../services/paypal_service.dart';
import '../shared/customer_layout.dart';
import '../api.dart' as api;

// ─────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────
class _C {
  static const primary       = Color(0xFF6B3F1A);
  static const primaryLight  = Color(0xFF8B5E3C);
  static const accent        = Color(0xFFBF8040);
  static const accentLight   = Color(0xFFE8B97A);
  static const cream         = Color(0xFFFAF6F0);
  static const surface       = Color(0xFFF5EDE0);
  static const border        = Color(0xFFE8D9C5);
  static const textPrimary   = Color(0xFF2C1A0E);
  static const textSecond    = Color(0xFF6B4C30);
  static const textMuted     = Color(0xFFA07850);
  static const success       = Color(0xFF3D7A5C);
  static const successBg     = Color(0xFFEBF7F2);
  static const successBorder = Color(0xFFB2DDD0);
  static const danger        = Color(0xFFB83232);
  static const dangerBg      = Color(0xFFFBECEC);
  static const dangerBorder  = Color(0xFFEFB8B8);
  static const warning       = Color(0xFF9A6200);
  static const warningBg     = Color(0xFFFFF8EC);
  static const warningBorder = Color(0xFFE8C56A);
  static const blue          = Color(0xFF2563EB);
  static const blueBg        = Color(0xFFEFF6FF);
  static const blueBorder    = Color(0xFFBFDBFE);
  static const starGold      = Color(0xFFD4980A);
}

BoxDecoration _card({double radius = 18, Color? bg}) => BoxDecoration(
  color: bg ?? Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _C.border),
  boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
);

// ─────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────
class CustomerCart extends StatefulWidget {
  const CustomerCart({super.key});
  @override State<CustomerCart> createState() => _CustomerCartState();
}

class _CustomerCartState extends State<CustomerCart> with SingleTickerProviderStateMixin {
  int currentPage = 1;
  String sortOrder = 'Latest';
  String filterStatus = 'All status';
  late TabController _tabController;

  bool loading = true;
  bool showPaymentModal = false;
  bool showReviewModal = false;
  bool showSupportModal = false;
  bool showCartRefreshNotice = false;
  bool isCancelProcessing = false;
  bool isFetchingSupport = false;
  bool isSubmittingReview = false;

  String toastMessage = '';
  String toastType = '';
  String cartRefreshMessage = '';
  String paymentStatus = 'idle';
  String paymentError = '';
  String? propertyOwnerPayPalId;
  String? lastPaidReservationId;

  int countdownTimer = 5;
  int paymentCountdown = 300;
  Timer? paymentTimer;
  Timer? successTimer;
  bool paymentExpired = false;

  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> userReviews = [];
  List<String> recentlyPaidReservationIds = [];

  Map<String, dynamic>? selectedReservation;
  dynamic selectedReservationId;
  String? actionToConfirm;
  Map<String, dynamic>? supportOperatorData;

  Map<String, dynamic>? reviewProperty;
  String reviewState = 'create';
  dynamic existingReviewId;
  String reviewText = '';
  String reviewError = '';
  final TextEditingController reviewController = TextEditingController();
  final FocusNode reviewFocusNode = FocusNode();
  final Map<String, int> subRatings = {
    'location': 0, 'cleanliness': 0, 'value': 0, 'facilities': 0, 'service': 0,
  };

  String userId = '';
  String usergroup = '';
  String username = '';

  static const int reservationsPerPage = 5;

  bool get isCartUserLoggedIn => userId.isNotEmpty;
  String get normalizedUserGroup => usergroup.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoredUserAndData();
  }

  @override
  void dispose() {
    paymentTimer?.cancel();
    successTimer?.cancel();
    _tabController.dispose();
    reviewController.dispose();
    reviewFocusNode.dispose();
    super.dispose();
  }

  // ── Data & Logic ─────────────────
  Future<void> _loadStoredUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionUserId = await Session.getUserId();
    final sessionUsername = await Session.getUsername();
    final sessionUserGroup = await Session.getUserGroup();

    userId = (sessionUserId ?? prefs.getString('userid') ?? prefs.getString('userId') ?? '').toString();
    usergroup = sessionUserGroup ?? prefs.getString('usergroup') ?? prefs.getString('userGroup') ?? prefs.getString('role') ?? '';
    username = sessionUsername ?? prefs.getString('username') ?? '';

    if (!isCartUserLoggedIn) { setState(() => loading = false); return; }
    await fetchCartData();
    await fetchMyReviews();
  }

  Future<void> fetchCartData() async {
    setState(() => loading = true);
    try {
      final data = await api.fetchCart();
      reservations = normalizeReservations(data);
      await expireOverdueReservations();
    } catch (e) {
      displayToast('error', 'Failed to load your reservations. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> fetchMyReviews() async {
    if (!isCartUserLoggedIn) {
      userReviews = [];
      if (mounted) setState(() {});
      return;
    }

    try {
      final propertyIds = reservations
          .map((r) => int.tryParse('${r['propertyid']}'))
          .where((id) => id != null)
          .cast<int>()
          .toSet()
          .toList();

      final allReviews = <Map<String, dynamic>>[];

      for (final propertyId in propertyIds) {
        final data = await api.fetchReviews(propertyId);
        final reviews = normalizeReviews(data);

        allReviews.addAll(
          reviews.where((r) => r['userid'].toString() == userId.toString()),
        );
      }

      userReviews = allReviews;
    } catch (_) {
      userReviews = [];
    }

    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> normalizeReservations(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['reservations'] is List) return (data['reservations'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['data'] is List) return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['rows'] is List) return (data['rows'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> normalizeReviews(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['reviews'] is List) return (data['reviews'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['data'] is List) return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['rows'] is List) return (data['rows'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  String normalizeStatus(dynamic status) => (status ?? '').toString().trim().toLowerCase();

  String toSafeIsoDate(dynamic value) {
    if (value == null) return '';

    final raw = value.toString().trim();
    if (raw.isEmpty) return '';

    final isoDateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (isoDateOnly.hasMatch(raw)) return raw;

    // DD/MM/YYYY
    final slash = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(raw);
    if (slash != null) {
      return '${slash.group(3)}-${slash.group(2)}-${slash.group(1)}';
    }

    // Datetime with timezone: convert to Malaysia/local time
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';

    final localDate = parsed.toLocal();

    return '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';
  }

  String formatSafeDate(dynamic value) {
    final iso = toSafeIsoDate(value);
    if (iso.isEmpty) return 'Invalid date';
    final parts = iso.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  bool isAutoCanceledReservation(Map<String, dynamic> r) {
    final status = normalizeStatus(r['reservationstatus']);
    if (!['accepted','pending','booking','payment pending'].contains(status)) return false;
    if (r['reservationblocktime'] == null) return false;
    final dateIso = toSafeIsoDate(r['reservationblocktime']);
    final date = DateTime.tryParse(dateIso);
    if (date == null) return false;
    return DateTime.now().isAfter(DateTime(date.year, date.month, date.day, 23, 59, 59, 999));
  }

  bool isOverduePartiallyPaid(Map<String, dynamic> r) {
    if (normalizeStatus(r['reservationstatus']) != 'partially paid') return false;
    if (r['reservationblocktime'] == null) return false;
    final dateIso = toSafeIsoDate(r['reservationblocktime']);
    final date = DateTime.tryParse(dateIso);
    if (date == null) return false;
    return DateTime.now().isAfter(DateTime(date.year, date.month, date.day, 23, 59, 59, 999));
  }

  String getEffectiveReservationStatus(Map<String, dynamic> r) {
    if (isAutoCanceledReservation(r) || isOverduePartiallyPaid(r)) return 'Expired';
    return (r['reservationstatus'] ?? 'Unknown').toString();
  }

  Future<void> expireOverdueReservations() async {
    for (final r in reservations) {
      if (isAutoCanceledReservation(r) || isOverduePartiallyPaid(r)) {
        await updateReservationStatusInBackend(r['reservationid'], 'Expired', showToast: false);
      }
    }
  }

  List<Map<String, dynamic>> get activeCartReservations => reservations.where((r) {
    final s = normalizeStatus(getEffectiveReservationStatus(r));
    return ['payment pending','pending','booking','accepted','partially paid'].contains(s);
  }).toList();

  List<Map<String, dynamic>> get historyReservationsRaw => reservations.where((r) {
    final s = normalizeStatus(getEffectiveReservationStatus(r));
    return !['payment pending','pending','booking','accepted','partially paid'].contains(s);
  }).toList();

  List<Map<String, dynamic>> get sortedReservations {
    final sorted = [...historyReservationsRaw];
    if (sortOrder == 'Latest') {
      final paidOrder = [if (lastPaidReservationId != null) lastPaidReservationId!, ...recentlyPaidReservationIds];
      sorted.sort((a, b) {
        final ai = paidOrder.indexOf(a['reservationid'].toString());
        final bi = paidOrder.indexOf(b['reservationid'].toString());
        final ar = ai != -1; final br = bi != -1;
        if (ar && !br) return -1;
        if (!ar && br) return 1;
        if (ar && br) return ai.compareTo(bi);
        return (num.tryParse(b['reservationid'].toString()) ?? 0).compareTo(num.tryParse(a['reservationid'].toString()) ?? 0);
      });
    } else if (sortOrder == 'Oldest') {
      sorted.sort((a, b) => (num.tryParse(a['reservationid'].toString()) ?? 0).compareTo(num.tryParse(b['reservationid'].toString()) ?? 0));
    } else if (sortOrder == 'Price High to Low') {
      sorted.sort((a, b) => (num.tryParse(b['totalprice'].toString()) ?? 0).compareTo(num.tryParse(a['totalprice'].toString()) ?? 0));
    } else if (sortOrder == 'Price Low to High') {
      sorted.sort((a, b) => (num.tryParse(a['totalprice'].toString()) ?? 0).compareTo(num.tryParse(b['totalprice'].toString()) ?? 0));
    }
    return sorted;
  }

  List<Map<String, dynamic>> get filteredReservations {
    if (filterStatus == 'All status') return sortedReservations;
    return sortedReservations.where((r) => normalizeStatus(getEffectiveReservationStatus(r)) == normalizeStatus(filterStatus)).toList();
  }

  List<Map<String, dynamic>> get currentReservations {
    final start = (currentPage - 1) * reservationsPerPage;
    final end = (start + reservationsPerPage).clamp(0, filteredReservations.length);
    if (start >= filteredReservations.length) return [];
    return filteredReservations.sublist(start, end);
  }

  int get totalPages => (filteredReservations.length / reservationsPerPage).ceil();

  double get finalTotalOwed => activeCartReservations.fold(0.0, (acc, r) {
    final total = double.tryParse('${r['totalprice'] ?? 0}') ?? 0;
    var deposit = double.tryParse('${r['downpaymentamount'] ?? r['downPaymentAmount'] ?? 0}') ?? 0;
    if (deposit <= 0) deposit = total * 0.10;
    final amountDue = normalizeStatus(r['reservationstatus']) == 'partially paid'
      ? (total - deposit).clamp(0.0, double.infinity).toDouble()
      : deposit;
    return acc + amountDue;
  });

  int get totalNights => activeCartReservations.fold(0, (acc, r) {
    final ciIso = toSafeIsoDate(r['checkindatetime']);
    final coIso = toSafeIsoDate(r['checkoutdatetime']);

    final ci = DateTime.tryParse(ciIso);
    final co = DateTime.tryParse(coIso);

    if (ci == null || co == null) return acc;

    final nights = co.difference(ci).inDays;
    return acc + (nights > 0 ? nights : 0);
  });

  Map<String, String> parseReservationRequest(dynamic request) {
    if (request == null || request.toString().isEmpty) return {'roomName': '', 'specialRequest': ''};
    final text = request.toString();
    if (text.contains('Room Selected:')) {
      final parts = text.split('Additional Requests:');
      return {'roomName': parts[0].replaceAll('Room Selected:', '').trim(), 'specialRequest': parts.length > 1 ? parts[1].trim() : ''};
    }
    return {'roomName': '', 'specialRequest': text};
  }

  String getFirstPropertyImage(dynamic propertyimage) {
    if (propertyimage == null) return '';
    if (propertyimage is List && propertyimage.isNotEmpty) return propertyimage.first.toString();
    if (propertyimage is String) {
      final clean = propertyimage.trim();
      if (clean.isEmpty) return '';
      try {
        final parsed = jsonDecode(clean);
        if (parsed is List && parsed.isNotEmpty) return parsed.first.toString();
      } catch (_) { return clean; }
      return clean;
    }
    return '';
  }

  ImageProvider? safeImageProvider(String imgStr) {
    if (imgStr.trim().isEmpty) return null;
    final clean = imgStr.trim();
    if (clean.startsWith('http')) return NetworkImage(clean);
    if (clean.startsWith('data:image')) return MemoryImage(base64Decode(clean.split(',').last));
    try { return MemoryImage(base64Decode(clean)); } catch (_) { return null; }
  }

  void displayToast(String type, String message) {
    if (!mounted) return;
    setState(() { toastType = type; toastMessage = message; });
    Color bgColor = _C.primaryLight;
    if (type == 'error') bgColor = _C.danger;
    else if (type == 'warning') bgColor = _C.warning;
    else if (type == 'success') bgColor = _C.success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(type == 'error' ? Icons.error_outline_rounded : type == 'success' ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> markReservationAsRecentlyUpdated(dynamic reservationId) async {
    if (reservationId == null) return;
    final id = reservationId.toString();
    lastPaidReservationId = id;
    sortOrder = 'Latest'; filterStatus = 'All status'; currentPage = 1;
    recentlyPaidReservationIds = [id, ...recentlyPaidReservationIds.where((x) => x != id)].take(10).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recentlyPaidReservationIds', jsonEncode(recentlyPaidReservationIds));
  }

  Future<void> updateReservationStatusInBackend(dynamic reservationId, String status, {bool showToast = true}) async {
    try {
      await api.updateReservationStatus(reservationId, status);
      final i = reservations.indexWhere((r) => r['reservationid'].toString() == reservationId.toString());
      if (i != -1) reservations[i]['reservationstatus'] = status;
      final n = normalizeStatus(status);
      if (['canceled','cancelled','expired','paid'].contains(n)) await markReservationAsRecentlyUpdated(reservationId);
      if (showToast && status != 'Paid' && status != 'Partially Paid') {
        final msgs = {'Canceled':'Your reservation has been canceled.','Expired':'Your reservation has expired due to non-payment.','Pending':'Please wait for the response of the operators.'};
        displayToast('success', msgs[status] ?? 'Status updated successfully.');
      }
      if (mounted) setState(() {});
    } catch (_) {
      displayToast('error', 'Failed to update reservation. Please try again.');
    } finally {
      if (mounted) setState(() => isCancelProcessing = false);
    }
  }

  Future<void> removeReservationInBackend(dynamic reservationId) async {
    try {
      await api.removeReservation(reservationId);
      reservations.removeWhere((r) => r['reservationid'].toString() == reservationId.toString());
      displayToast('success', 'Reservation removed from your list.');
      setState(() {});
    } catch (_) { displayToast('error', 'Failed to remove reservation. Please try again.'); }
  }

  Future<void> fetchPropertyOwnerPayPalId(dynamic propertyId) async {
    try {
      setState(() => paymentStatus = 'loading');
      final ownerData = await api.getPropertyOwnerPayPalId(propertyId);
      propertyOwnerPayPalId = ownerData['payPalId'];
      setState(() => paymentStatus = 'idle');
    } catch (_) {
      setState(() { paymentStatus = 'error'; paymentError = 'Failed to get payment information. Please try again.'; });
    }
  }

  void confirmAction(String action, dynamic reservationId) {
    setState(() { actionToConfirm = action; selectedReservationId = reservationId; });
    showConfirmDialog();
  }

  Future<void> executeAction() async {
    if (actionToConfirm == null || (selectedReservationId == null && actionToConfirm != 'checkout')) return;
    switch (actionToConfirm) {
      case 'pay':
        final reservation = reservations.firstWhere((r) => r['reservationid'].toString() == selectedReservationId.toString(), orElse: () => {});
        if (reservation.isEmpty) { displayToast('error', 'Reservation not found. Please refresh and try again.'); return; }
        selectedReservation = reservation;
        await fetchPropertyOwnerPayPalId(reservation['propertyid']);
        openPaymentModal();
        break;
      case 'cancel':
        setState(() => isCancelProcessing = true);
        displayToast('warning', 'Processing cancellation...');
        await updateReservationStatusInBackend(selectedReservationId, 'Canceled');
        break;
      case 'cancel_forfeit':
        setState(() => isCancelProcessing = true);
        displayToast('warning', 'Processing cancellation. Deposit will not be refunded...');
        await updateReservationStatusInBackend(selectedReservationId, 'Canceled');
        break;
      case 'remove':
        displayToast('success', 'Removing...');
        await removeReservationInBackend(selectedReservationId);
        break;
      case 'checkout':
        await handleCheckout();
        break;
    }
    actionToConfirm = null;
    selectedReservationId = null;
  }

  Future<void> handleCheckout() async {
    final bookingReservations = reservations.where((r) => normalizeStatus(r['reservationstatus']) == 'booking');
    if (bookingReservations.isEmpty) { displayToast('info', 'No bookings to checkout.'); return; }
    for (final r in bookingReservations) { await updateReservationStatusInBackend(r['reservationid'], 'Pending'); }
  }

  void openPaymentModal() {
    setState(() { showPaymentModal = true; paymentCountdown = 300; paymentExpired = false; });
    paymentTimer?.cancel();
    paymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (paymentCountdown <= 1) { timer.cancel(); paymentCountdown = 0; handlePaymentTimeout(); }
      else { setState(() => paymentCountdown--); }
    });
  }

  void handlePaymentTimeout() {
    if (!showPaymentModal || paymentStatus == 'success' || paymentExpired) return;
    paymentExpired = true;
    final isPayingBalance = normalizeStatus(selectedReservation?['reservationstatus']) == 'partially paid';
    setState(() { showPaymentModal = false; selectedReservation = null; paymentStatus = 'idle'; paymentError = ''; });
    displayToast('error', isPayingBalance ? 'Payment time expired. Please click Pay Balance again.' : 'Payment time expired. Please click Pay Deposit again.');
  }

  Future<void> handlePayPalApprove(String orderId) async {
    try {
      final details = await api.capturePayPalOrder(orderId);
      if (details['error'] != null) throw Exception(details['error']);
      paymentTimer?.cancel();
      final paidReservationId = selectedReservation?['reservationid'];
      final isPayingBalance = normalizeStatus(selectedReservation?['reservationstatus']) == 'partially paid';
      final newStatus = isPayingBalance ? 'Paid' : 'Partially Paid';
      await api.paymentSuccess(paidReservationId);
      await updateReservationStatusInBackend(paidReservationId, newStatus, showToast: false);
      await markReservationAsRecentlyUpdated(paidReservationId);
      setState(() { paymentStatus = 'success'; countdownTimer = 5; });
      successTimer?.cancel();
      successTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (countdownTimer <= 1) {
          timer.cancel();
          await fetchCartData();
          if (mounted) setState(() { showPaymentModal = false; paymentStatus = 'idle'; paymentError = ''; selectedReservation = null; });
        } else { setState(() => countdownTimer--); }
      });
    } catch (_) {
      setState(() { paymentError = 'Payment could not be processed. Please try again.'; paymentStatus = 'error'; });
    }
  }

  Future<void> startPayPalCartPayment() async {
    if (selectedReservation == null) return;

    setState(() {
      paymentStatus = 'processing';
      paymentError = '';
    });

    final reservation = selectedReservation!;
    final isPayingBalance =
        normalizeStatus(reservation['reservationstatus']) == 'partially paid';

    final totalAmount = double.tryParse('${reservation['totalprice'] ?? 0}') ?? 0;
    var depositAmount = double.tryParse(
          '${reservation['downpaymentamount'] ?? reservation['downPaymentAmount'] ?? 0}',
        ) ??
        0;

    if (depositAmount <= 0) depositAmount = totalAmount * 0.10;

    final double balanceAmount =
    (totalAmount - depositAmount).clamp(0.0, double.infinity).toDouble();

    final double amount = isPayingBalance ? balanceAmount : depositAmount;

    final result = await PayPalService.showPayPalPayment(
      context: context,
      reservationId: int.parse('${reservation['reservationid']}'),
      propertyId: int.parse('${reservation['propertyid']}'),
      amount: amount,
      currency: 'MYR',
      propertyName: '${reservation['propertyaddress'] ?? 'Property'}',
      checkIn: toSafeIsoDate(reservation['checkindatetime']),
      checkOut: toSafeIsoDate(reservation['checkoutdatetime']),
    );

    if (result == null || result['status'] != 'success') {
      setState(() {
        paymentStatus = 'idle';
        paymentError = 'Payment was cancelled. Please try again.';
      });
      return;
    }

    await handleCartPaymentSuccess();
  }

  Future<void> handleCartPaymentSuccess() async {
    try {
      paymentTimer?.cancel();

      final paidReservationId = selectedReservation?['reservationid'];
      final isPayingBalance =
          normalizeStatus(selectedReservation?['reservationstatus']) == 'partially paid';

      final newStatus = isPayingBalance ? 'Paid' : 'Partially Paid';

      if (paidReservationId == null) {
        throw Exception('Missing reservation ID');
      }

      await updateReservationStatusInBackend(
        paidReservationId,
        newStatus,
        showToast: false,
      );

      try {
        await api.paymentSuccess(paidReservationId);
      } catch (e) {
        print('paymentSuccess email skipped: $e');
      }

      await markReservationAsRecentlyUpdated(paidReservationId);

      setState(() {
        paymentStatus = 'success';
        countdownTimer = 5;
      });

      successTimer?.cancel();
      successTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (countdownTimer <= 1) {
          timer.cancel();

          if (mounted) {
            setState(() {
              showPaymentModal = false;
              paymentStatus = 'idle';
              paymentError = '';
              selectedReservation = null;
            });
          }

          try {
            await fetchCartData();
            await fetchMyReviews();
          } catch (e) {
            print('Cart refresh after payment skipped: $e');
          }
        } else {
            if (mounted) {
              setState(() => countdownTimer--);
            }
          }});
    } catch (e) {
      print('Cart payment success update failed: $e');
      setState(() {
        paymentError = 'Payment was successful, but booking update failed. Please refresh your cart.';
        paymentStatus = 'error';
      });
    }
  }

  Future<void> handleRequestRefund(Map<String, dynamic> reservation) async {
    setState(() { supportOperatorData = null; isFetchingSupport = true; showSupportModal = true; });
    try {
      final ownerId = reservation['ownerid'] ?? reservation['operatorid'] ?? reservation['creatorid'] ?? reservation['propertyownerid'] ?? reservation['property_owner_id'] ?? reservation['owner_id'];
      if (ownerId != null) {
        final ownerData = await api.fetchUserData(ownerId);
        supportOperatorData = {
          'name': '${ownerData['utitle'] ?? ''} ${ownerData['ufirstname'] ?? ''} ${ownerData['ulastname'] ?? ''}'.trim().isNotEmpty
              ? '${ownerData['utitle'] ?? ''} ${ownerData['ufirstname'] ?? ''} ${ownerData['ulastname'] ?? ''}'.trim()
              : ownerData['username'] ?? 'Property Owner',
          'email': ownerData['uemail'] ?? '',
          'phone': ownerData['uphoneno'] ?? '',
        };
      } else if (reservation['propertyid'] != null) {
        final ownerData = await api.getPropertyOwnerPayPalId(reservation['propertyid']);
        supportOperatorData = {'name': ownerData['ownerName'] ?? 'Property Owner', 'email': ownerData['ownerEmail'] ?? ownerData['payPalId'] ?? '', 'phone': ownerData['ownerPhone'] ?? ''};
      } else { throw Exception('Owner ID and property ID not found'); }
    } catch (_) {
      displayToast('error', 'Failed to retrieve operator contact info.');
      supportOperatorData = {'name': 'Property Owner', 'email': '', 'phone': ''};
    } finally { setState(() => isFetchingSupport = false); }
  }

  Future<void> openReviewModal(Map<String, dynamic> reservation) async {
    final prefs = await SharedPreferences.getInstance();
    final hasDeletedBefore = prefs.getString('deleted_review_${reservation['propertyid']}_$userId');
    reviewProperty = reservation; reviewText = ''; reviewError = ''; reviewController.text = ''; existingReviewId = null;
    subRatings.updateAll((key, value) => 0);
    if (hasDeletedBefore != null) {
      reviewState = 'deleted';
    } else {
      final existing = userReviews.where((r) => r['propertyId'].toString() == reservation['propertyid'].toString() || r['propertyid'].toString() == reservation['propertyid'].toString());
      if (existing.isNotEmpty) {
        final er = existing.first;
        existingReviewId = er['id'];
        reviewText = er['comment'] ?? '';
        reviewController.text = reviewText;
        subRatings['location'] = int.tryParse('${er['location_score'] ?? er['rating'] ?? 5}') ?? 5;
        subRatings['cleanliness'] = int.tryParse('${er['cleanliness_score'] ?? er['rating'] ?? 5}') ?? 5;
        subRatings['value'] = int.tryParse('${er['value_score'] ?? er['rating'] ?? 5}') ?? 5;
        subRatings['facilities'] = int.tryParse('${er['facilities_score'] ?? er['rating'] ?? 5}') ?? 5;
        subRatings['service'] = int.tryParse('${er['service_score'] ?? er['rating'] ?? 5}') ?? 5;
        reviewState = 'view';
      } else { reviewState = 'create'; }
    }
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: _reviewModalContent(),
      ),
    );  
  }

  Future<void> handleReviewSubmit(StateSetter modalSet) async {
    reviewText = reviewController.text;

    final allRated = subRatings.values.every((v) => v > 0);

    if (!allRated) {
      modalSet(() {
        reviewError = 'Please provide a star rating for all categories.';
      });
      return;
    }

    if (reviewText.trim().isEmpty) {
      modalSet(() {
        reviewError = 'Please write a review comment.';
      });
      return;
    }

    modalSet(() {
      reviewError = '';
      isSubmittingReview = true;
    });

    final sensitiveWords = ['badword1','badword2','scam','fraud','hate','racist','kill'];
    var safeText = reviewText;

    for (final word in sensitiveWords) {
      safeText = safeText.replaceAll(
        RegExp('\\b$word\\b', caseSensitive: false),
        '*' * word.length,
      );
    }

    final average = (
      (
        subRatings['location']! +
        subRatings['cleanliness']! +
        subRatings['value']! +
        subRatings['facilities']! +
        subRatings['service']!
      ) / 5
    ).round();

    final payload = {
      'userid': int.tryParse(userId),
      'propertyid': int.tryParse('${reviewProperty?['propertyid']}'),
      'review': safeText,
      'rating': average,
      'location_score': subRatings['location'] ?? 5,
      'cleanliness_score': subRatings['cleanliness'] ?? 5,
      'value_score': subRatings['value'] ?? 5,
      'facilities_score': subRatings['facilities'] ?? 5,
      'service_score': subRatings['service'] ?? 5,
    };

    try {
      if (reviewState == 'create') {
        await api.submitReview(payload, username);

        final localReview = {
          'userid': userId,
          'propertyid': reviewProperty?['propertyid'],
          'propertyId': reviewProperty?['propertyid'],
          'comment': safeText,
          'review': safeText,
          'rating': average,
          'location_score': subRatings['location'],
          'cleanliness_score': subRatings['cleanliness'],
          'value_score': subRatings['value'],
          'facilities_score': subRatings['facilities'],
          'service_score': subRatings['service'],
        };

        userReviews.add(localReview);

        reviewState = 'view';
        reviewController.text = safeText;
        reviewText = safeText;

        if (mounted) setState(() {});

        Navigator.pop(context);

        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            displayToast('success', 'Thank you! Your review has been submitted.');
          }
        });
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('already submitted') || msg.contains('already')) {
        await fetchMyReviews();

        final existing = userReviews.where((r) =>
          r['propertyId'].toString() == reviewProperty?['propertyid'].toString() ||
          r['propertyid'].toString() == reviewProperty?['propertyid'].toString()
        );

        if (existing.isNotEmpty) {
          final er = existing.first;

          modalSet(() {
            existingReviewId = er['id'] ?? er['reviewid'] ?? er['reviewId'];
            reviewText = er['comment'] ?? er['review'] ?? '';
            reviewController.text = reviewText;

            subRatings['location'] = int.tryParse('${er['location_score'] ?? er['rating'] ?? 5}') ?? 5;
            subRatings['cleanliness'] = int.tryParse('${er['cleanliness_score'] ?? er['rating'] ?? 5}') ?? 5;
            subRatings['value'] = int.tryParse('${er['value_score'] ?? er['rating'] ?? 5}') ?? 5;
            subRatings['facilities'] = int.tryParse('${er['facilities_score'] ?? er['rating'] ?? 5}') ?? 5;
            subRatings['service'] = int.tryParse('${er['service_score'] ?? er['rating'] ?? 5}') ?? 5;

            reviewState = 'view';
            reviewError = '';
          });

          if (mounted) setState(() {});
        } else {
          modalSet(() {
            reviewError = 'You have already submitted a review for this property.';
          });
        }

        return;
      }

      modalSet(() {
        reviewError = e.toString();
      });
    } finally {
      modalSet(() {
        isSubmittingReview = false;
      });

      if (mounted) setState(() {});
    }
  }

  Future<void> handleDeleteReview() async {
    setState(() => isSubmittingReview = true);
    try {
      await api.deleteReview(existingReviewId, username);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deleted_review_${reviewProperty?['propertyid']}_$userId', 'true');
      reviewState = 'deleted';
      displayToast('success', 'Your review has been deleted.');
      await fetchMyReviews();
    } catch (_) { displayToast('error', 'Failed to delete review.'); }
    finally { setState(() => isSubmittingReview = false); }
  }

  void goToProperty(Map<String, dynamic> reservation) {
    if (reservation['propertyid'] == null || reservation['propertyid'].toString() == 'null') {
      displayToast('error', 'This property is no longer available on the platform.'); return;
    }
    Navigator.pushNamed(context, '/product/${reservation['propertyid']}', arguments: {
      'propertyId': reservation['propertyid'],
      'propertyDetails': reservation,
      'searchDates': {'checkIn': toSafeIsoDate(reservation['checkindatetime']), 'checkOut': toSafeIsoDate(reservation['checkoutdatetime'])},
    });
  }

  // ──────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 2,
      backgroundColor: _C.cream,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: fetchCartData,
            color: _C.accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  collapsedHeight: kToolbarHeight,
                  toolbarHeight: kToolbarHeight,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: _C.primary,
                  automaticallyImplyLeading: false,
                  actions: const [SizedBox.shrink()],
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final topPadding = MediaQuery.of(context).padding.top;
                      final currentHeight = constraints.maxHeight;

                      final showExpandedHeader = currentHeight > 125;
                      final showCollapsedTitle = currentHeight <= 125;

                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Container(color: _C.primary),

                          Opacity(
                            opacity: 0.06,
                            child: CustomPaint(
                              painter: _CartBatikPatternPainter(),
                            ),
                          ),

                          if (showExpandedHeader)
                            Positioned(
                              top: topPadding + 12,
                              left: 20,
                              right: 20,
                              height: 115,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _C.accentLight.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _C.accentLight.withOpacity(0.4),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.shopping_bag_rounded,
                                          color: _C.accentLight,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Hello Sarawak',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Your Reservations',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage and track your bookings',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (showCollapsedTitle)
                            Positioned(
                              top: topPadding,
                              left: 0,
                              right: 0,
                              height: kToolbarHeight,
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_rounded,
                                      color: _C.accentLight,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Cart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
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

                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _C.cream,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (!isCartUserLoggedIn)
                          _loginRequired()
                        else ...[
                          if (activeCartReservations.isNotEmpty)
                            _summaryBanner(),
                          _tabBar(),

                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: _changeTabBySwipe,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _tabController.index == 0
                                  ? KeyedSubtree(
                                      key: const ValueKey('cart-tab'),
                                      child: _cartTabContentNoScroll(),
                                    )
                                  : KeyedSubtree(
                                      key: const ValueKey('history-tab'),
                                      child: _historyTabContentNoScroll(),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),

          if (showCartRefreshNotice) _refreshNotice(),
          if (isCancelProcessing) _cancelProcessingOverlay(),
          if (showPaymentModal && selectedReservation != null) _paymentModal(),
          if (showSupportModal) _supportModal(),
        ],
      ),
    );
  }

  // ── Summary Banner ──
  Widget _summaryBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _C.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Outstanding Balance',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _C.textPrimary,
                ),
              ),
            ],
          ),
          Divider(color: _C.border, height: 24),
          _summaryRow('Active Bookings', '${activeCartReservations.length}'),
          _summaryRow('Total Nights', '$totalNights'),
          Divider(color: _C.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Due Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                ),
              ),
              Text(
                'RM ${finalTotalOwed.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _C.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Combined amount required to confirm or complete your active bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _C.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ──
  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(13)),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _C.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_rounded, size: 16),
              const SizedBox(width: 6),
              Text('Cart (${activeCartReservations.length})'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history_rounded, size: 16),
              const SizedBox(width: 6),
              Text('History (${filteredReservations.length})'),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Cart Tab ──
  Widget _cartTabContentNoScroll() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: loading
          ? Column(children: List.generate(2, (_) => _skeletonCard()))
          : activeCartReservations.isEmpty
              ? _emptyCart()
              : Column(
                  children: activeCartReservations
                      .map((r) => _reservationCard(r, false))
                      .toList(),
                ),
    );
  }

  // ── History Tab ──
  Widget _historyTabContentNoScroll() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          _filtersCard(),
          const SizedBox(height: 16),
          if (loading)
            Column(children: List.generate(3, (_) => _skeletonCard()))
          else if (currentReservations.isNotEmpty)
            Column(
              children: currentReservations
                  .map((r) => _reservationCard(r, true))
                  .toList(),
            )
          else
            _emptyHistory(),
          if (currentReservations.isNotEmpty) _pagination(),
        ],
      ),
    );
  }

  void _changeTabBySwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // swipe left: Cart -> History
    if (velocity < -250 && _tabController.index == 0) {
      setState(() {
        _tabController.animateTo(1);
      });
    }

    // swipe right: History -> Cart
    if (velocity > 250 && _tabController.index == 1) {
      setState(() {
        _tabController.animateTo(0);
      });
    }
  }

  // ── Overflow Fix ──
  Widget _longPressPreviewText(String text) {
    OverlayEntry? overlayEntry;

    void showOverlay(BuildContext context, Offset position) {
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: position.dy - 60, // show above
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry!);
    }

    void removeOverlay() {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    return GestureDetector(
      onLongPressStart: (details) {
        showOverlay(context, details.globalPosition);
      },
      onLongPressEnd: (_) {
        removeOverlay();
      },
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: _C.textSecond,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Reservation Card ──
  Widget _reservationCard(Map<String, dynamic> reservation, bool isHistorySection) {
    final effectiveStatus = getEffectiveReservationStatus(reservation);
    final parsedRequest = parseReservationRequest(reservation['request']);
    final roomName = parsedRequest['roomName'] ?? '';
    final specialRequest = parsedRequest['specialRequest'] ?? '';
    final checkoutIso = toSafeIsoDate(reservation['checkoutdatetime']);
    final checkoutDate = DateTime.tryParse(checkoutIso);

    final isPastCheckout =
        (checkoutDate ?? DateTime.now().add(const Duration(days: 1)))
            .isBefore(DateTime.now());
    final hasReviewed = userReviews.any((r) => r['propertyId'].toString() == reservation['propertyid'].toString() || r['propertyid'].toString() == reservation['propertyid'].toString());
    final isPartiallyPaid = normalizeStatus(effectiveStatus) == 'partially paid';
    final isFullyPaid = normalizeStatus(effectiveStatus) == 'paid';
    final totalAmount = double.tryParse('${reservation['totalprice'] ?? 0}') ?? 0;
    var depositAmount = double.tryParse('${reservation['downpaymentamount'] ?? reservation['downPaymentAmount'] ?? 0}') ?? 0;
    if (depositAmount <= 0) depositAmount = totalAmount * 0.10;
    final balanceDue = (totalAmount - depositAmount).clamp(0, double.infinity);
    final firstImage = getFirstPropertyImage(reservation['propertyimage']);
    final imageProvider = firstImage.isNotEmpty ? safeImageProvider(firstImage) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final isMobile = c.maxWidth < 680;

        Widget imageWidget = GestureDetector(
          onTap: () => goToProperty(reservation),
          child: Container(
            width: isMobile ? double.infinity : 180,
            height: isMobile ? 200 : null,
            constraints: isMobile ? const BoxConstraints() : const BoxConstraints(minHeight: 160),
            decoration: BoxDecoration(
              color: _C.surface,
              image: imageProvider == null ? null : DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
            child: imageProvider == null
                ? Container(
                    alignment: Alignment.center,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.image_not_supported_rounded, color: _C.border, size: 30),
                      const SizedBox(height: 4),
                      Text('No image', style: TextStyle(color: _C.border, fontSize: 11)),
                    ]),
                  )
                : null,
          ),
        );

        Widget content = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Property name + status
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => goToProperty(reservation),
                  child: Text('${reservation['propertyaddress'] ?? ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.textPrimary, height: 1.3)),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: effectiveStatus),
            ]),

            // Room chip
            if (roomName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bed_rounded, size: 13, color: _C.accent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _longPressPreviewText(roomName),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Dates
            _infoRow(Icons.flight_land_rounded, 'Check-in', formatSafeDate(reservation['checkindatetime'])),
            const SizedBox(height: 5),
            _infoRow(Icons.flight_takeoff_rounded, 'Check-out', formatSafeDate(reservation['checkoutdatetime'])),

            // Payment deadline
            if (['payment pending','pending','booking','accepted','partially paid'].contains(normalizeStatus(effectiveStatus)) && reservation['reservationblocktime'] != null) ...[
              const SizedBox(height: 5),
              _infoRow(Icons.timer_rounded, 'Pay by', formatSafeDate(reservation['reservationblocktime']), color: _C.danger),
            ],

            // Special request
            if (specialRequest.isNotEmpty && specialRequest != 'None') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.sticky_note_2_rounded, size: 14, color: _C.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text('$specialRequest', style: const TextStyle(fontSize: 12, color: _C.textMuted, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(color: _C.border, height: 1),
            const SizedBox(height: 12),

            // Price + actions row
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isPartiallyPaid) ...[
                  Text('Total: RM ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: _C.textMuted, decoration: TextDecoration.lineThrough)),
                  Text('Deposit paid: –RM ${depositAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: _C.success, fontWeight: FontWeight.w600)),
                  const Text('Balance Due', style: TextStyle(fontSize: 11, color: _C.textMuted)),
                  Text('RM ${balanceDue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.primary)),
                ] else ...[
                  const Text('Total Amount', style: TextStyle(fontSize: 11, color: _C.textMuted)),
                  Text('RM ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.primary)),
                ],
              ])),
            ]),

            const SizedBox(height: 14),

            // Action buttons
            ..._actionButtons(reservation, effectiveStatus, isHistorySection, isPartiallyPaid, isFullyPaid, isPastCheckout, hasReviewed),
          ]),
        );

        if (isMobile) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 190, child: imageWidget), content,
          ]);
        }

        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 180, child: imageWidget),
            Expanded(child: content),
          ]),
        );
      }),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 14, color: color ?? _C.textMuted),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 13, color: color ?? _C.textMuted)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color ?? _C.textPrimary)),
    ]);
  }

  List<Widget> _actionButtons(
    Map<String, dynamic> reservation,
    String effectiveStatus,
    bool isHistorySection,
    bool isPartiallyPaid,
    bool isFullyPaid,
    bool isPastCheckout,
    bool hasReviewed,
  ) {
    final status = normalizeStatus(effectiveStatus);
    final buttons = <Widget>[];

    if (!isHistorySection && ['payment pending','pending','booking','accepted','partially paid'].contains(status)) {
      buttons.add(_actionBtn(
        icon: Icons.payment_rounded,
        label: isPartiallyPaid ? 'Pay Balance' : 'Pay Deposit',
        color: isPartiallyPaid ? _C.success : _C.primary,
        filled: true,
        onPressed: () => confirmAction('pay', reservation['reservationid']),
      ));
    }

    if (!isHistorySection && ['payment pending','pending','booking','accepted'].contains(status)) {
      buttons.add(_actionBtn(
        icon: Icons.cancel_outlined,
        label: 'Cancel Booking',
        color: _C.danger,
        onPressed: () => confirmAction('cancel', reservation['reservationid']),
      ));
    }

    if (!isHistorySection && status == 'partially paid') {
      buttons.add(_actionBtn(
        icon: Icons.money_off_rounded,
        label: 'Cancel (Lose Deposit)',
        color: _C.danger,
        onPressed: () => confirmAction('cancel_forfeit', reservation['reservationid']),
      ));
    }

    if (isHistorySection && isFullyPaid) {
      buttons.add(_actionBtn(
        icon: Icons.headset_mic_rounded,
        label: 'Contact Owner',
        color: _C.blue,
        onPressed: () => handleRequestRefund(reservation),
      ));
    }

    if (isHistorySection && (status == 'paid' || status == 'accepted')) {
      if (isPastCheckout) {
        buttons.add(_actionBtn(
          icon: Icons.star_rounded,
          label: hasReviewed ? 'View My Review' : 'Write a Review',
          color: hasReviewed ? Colors.grey : _C.starGold,
          filled: !hasReviewed,
          onPressed: () => openReviewModal(reservation),
        ));
      } else {
        buttons.add(Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: _C.textMuted),
            SizedBox(width: 6),
            Text('Review unlocks after checkout', style: TextStyle(fontSize: 12, color: _C.textMuted, fontStyle: FontStyle.italic)),
          ]),
        ));
      }
    }

    return buttons.expand((w) => [w, const SizedBox(height: 8)]).toList();
  }

  Widget _actionBtn({IconData? icon, required String label, required Color color, required VoidCallback onPressed, bool filled = false}) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: onPressed,
            )
          : OutlinedButton.icon(
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onPressed,
            ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: _C.textSecond, fontSize: 13)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: _C.textPrimary, fontSize: 13)),
    ]),
  );

  // ── Filters Card ──
  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(radius: 16),
      child: LayoutBuilder(builder: (context, c) {
        final isMobile = c.maxWidth < 580;
        final sortDrop = _dropField('Sort by', Icons.sort_rounded, sortOrder,
          ['Latest','Oldest','Price High to Low','Price Low to High'],
          (v) => setState(() => sortOrder = v!));
        final filterDrop = _dropField('Filter status', Icons.filter_alt_rounded, filterStatus,
          ['All status','Canceled','Paid','Expired'],
          (v) => setState(() { filterStatus = v!; currentPage = 1; }));
        if (isMobile) return Column(children: [sortDrop, const SizedBox(height: 12), filterDrop]);
        return Row(children: [Expanded(child: sortDrop), const SizedBox(width: 12), Expanded(child: filterDrop)]);
      }),
    );
  }

  Widget _dropField(String label, IconData icon, String value, List<String> options, ValueChanged<String?> onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: _C.accent),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.textSecond)),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
        child: DropdownButton<String>(
          value: value, isExpanded: true, underline: const SizedBox.shrink(),
          style: const TextStyle(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.textMuted),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e == 'Latest' ? 'Latest First' : e == 'Oldest' ? 'Oldest First' : e == 'All status' ? 'All Statuses' : e))).toList(),
          onChanged: onChange,
        ),
      ),
    ]);
  }

  // ── Pagination ──
  Widget _pagination() {
    if (totalPages <= 1) return const SizedBox.shrink();

    const int maxVisiblePages = 4;
    final pageWidgets = <Widget>[];

    int startPage = 1;
    int endPage = totalPages;

    if (totalPages > maxVisiblePages) {
      if (currentPage <= 3) {
        startPage = 1;
        endPage = maxVisiblePages;
      } else if (currentPage >= totalPages - 2) {
        startPage = totalPages - maxVisiblePages + 1;
        endPage = totalPages;
      } else {
        startPage = currentPage - 2;
        endPage = currentPage + 2;
      }
    }

    pageWidgets.add(
      _pageBtn(
        Icons.chevron_left_rounded,
        currentPage == 1 ? null : () => setState(() => currentPage--),
      ),
    );

    if (startPage > 1) {
      pageWidgets.add(_pageNumberBtn(1));

      if (startPage > 2) {
        pageWidgets.add(_pageDots());
      }
    }

    for (int p = startPage; p <= endPage; p++) {
      pageWidgets.add(_pageNumberBtn(p));
    }

    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pageWidgets.add(_pageDots());
      }

      pageWidgets.add(_pageNumberBtn(totalPages));
    }

    pageWidgets.add(
      _pageBtn(
        Icons.chevron_right_rounded,
        currentPage == totalPages ? null : () => setState(() => currentPage++),
      ),
    );

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
      onTap: sel ? null : () => setState(() => currentPage = page),
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
    width: 38, height: 38,
    decoration: BoxDecoration(color: onTap != null ? Colors.white : _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Icon(icon, size: 22, color: onTap != null ? _C.primaryLight : _C.border)),
  );

  // ── Empty States ──
  Widget _emptyCart() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: _card(),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle),
          child: const Icon(Icons.shopping_cart_outlined, size: 36, color: _C.textMuted)),
        const SizedBox(height: 16),
        const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPrimary)),
        const SizedBox(height: 6),
        const Text('Start exploring stays to add bookings here', style: TextStyle(color: _C.textMuted, fontSize: 13)),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          icon: const Icon(Icons.search_rounded, size: 17),
          label: const Text('Browse Properties', style: TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.pushNamed(context, '/product'),
        ),
      ]),
    );
  }

  Widget _emptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: _card(),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle),
          child: const Icon(Icons.history_rounded, size: 30, color: _C.textMuted)),
        const SizedBox(height: 14),
        const Text('No reservations found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.textPrimary)),
        const SizedBox(height: 6),
        Text(filterStatus != 'All status' ? 'No history with status "$filterStatus"' : 'You don\'t have any past reservations yet',
          textAlign: TextAlign.center, style: const TextStyle(color: _C.textMuted, fontSize: 13)),
      ]),
    );
  }

  // ── Skeleton ──
  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(width: 160, height: 160, color: _C.surface),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 16, width: double.infinity, decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 10),
            Container(height: 12, width: 140, decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(height: 12, width: 120, decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 20),
            Container(height: 36, width: double.infinity, decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12))),
          ]),
        )),
      ]),
    );
  }

  // ── Login Required ──
  Widget _loginRequired() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: _card(),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle),
          child: const Icon(Icons.lock_rounded, size: 34, color: _C.accent)),
        const SizedBox(height: 18),
        const Text('Login Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.textPrimary)),
        const SizedBox(height: 8),
        const Text('Your cart and reservation history are only available after login.', textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.pushNamed(context, '/login', arguments: {'from': '/cart'}),
          child: const Text('Login to Continue', style: TextStyle(fontWeight: FontWeight.w800)),
        )),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // CONFIRM DIALOG
  // ──────────────────────────────────────────────────────────────────
  void showConfirmDialog() {
    String title = 'Confirm Action';
    Widget content = const Text('Are you sure you want to proceed?', style: TextStyle(color: _C.textSecond));
    String buttonText = 'Confirm';
    Color buttonColor = _C.primary;
    Widget? warningBox;

    if (actionToConfirm == 'pay') { title = 'Confirm Payment'; content = const Text('Proceed to payment for this reservation?', style: TextStyle(color: _C.textSecond)); }
    else if (actionToConfirm == 'cancel') { title = 'Cancel Reservation'; content = const Text('Are you sure you want to cancel this reservation?', style: TextStyle(color: _C.textSecond)); buttonText = 'Cancel Booking'; buttonColor = _C.danger; }
    else if (actionToConfirm == 'cancel_forfeit') {
      title = 'Cancel Reservation';
      buttonText = 'Cancel'; buttonColor = _C.danger;
      warningBox = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _C.warningBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.warningBorder)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_rounded, color: _C.warning, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Your paid deposit is strictly non-refundable. This action cannot be undone.', style: TextStyle(color: _C.warning, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      );
    } else if (actionToConfirm == 'remove') { title = 'Remove Reservation'; content = const Text('Remove this reservation from your list?', style: TextStyle(color: _C.textSecond)); buttonText = 'Remove'; buttonColor = _C.danger; }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPrimary)),
            const SizedBox(height: 10),
            content,
            if (warningBox != null) ...[const SizedBox(height: 12), warningBox!],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.textSecond,
                      side: const BorderSide(color: _C.border),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await executeAction();
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        buttonText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // PAYMENT MODAL
  // ──────────────────────────────────────────────────────────────────
  Widget _paymentModal() {
    final reservation = selectedReservation!;
    final isPayingBalance = normalizeStatus(reservation['reservationstatus']) == 'partially paid';
    final totalAmount = double.tryParse('${reservation['totalprice'] ?? 0}') ?? 0;
    var depositAmount = double.tryParse('${reservation['downpaymentamount'] ?? reservation['downPaymentAmount'] ?? 0}') ?? 0;
    if (depositAmount <= 0) depositAmount = totalAmount * 0.10;
    final double balanceAmount =
    (totalAmount - depositAmount).clamp(0.0, double.infinity).toDouble();

    return _modalBackdrop(child: Container(
      width: 520,
      constraints: const BoxConstraints(maxHeight: 700),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: paymentStatus == 'success'
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 64, height: 64, decoration: BoxDecoration(color: _C.successBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 34, color: _C.success)),
                const SizedBox(height: 16),
                const Text('Payment Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.success)),
                const SizedBox(height: 8),
                Text(isPayingBalance ? 'Balance payment completed. Booking fully paid!' : 'Deposit paid successfully!', textAlign: TextAlign.center, style: const TextStyle(color: _C.textSecond)),
                const SizedBox(height: 10),
                Text('Refreshing in $countdownTimer seconds...', style: const TextStyle(fontWeight: FontWeight.w800, color: _C.textMuted)),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: countdownTimer / 5, backgroundColor: _C.border, color: _C.success)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.accent, _C.primary]), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.payment_rounded, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Complete Payment', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _C.textPrimary))),
                  InkWell(
                    onTap: () { paymentTimer?.cancel(); setState(() { showPaymentModal = false; selectedReservation = null; paymentError = ''; paymentStatus = 'idle'; }); },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close_rounded, size: 18, color: _C.textSecond)),
                  ),
                ]),
                const SizedBox(height: 18),
                _paymentCountdownBox(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
                  child: Column(children: [
                    Text('${reservation['propertyaddress'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, color: _C.textPrimary, fontSize: 14)),
                    const SizedBox(height: 12),
                    _summaryRow('Check-in', formatSafeDate(reservation['checkindatetime'])),
                    _summaryRow('Check-out', formatSafeDate(reservation['checkoutdatetime'])),
                    Divider(color: _C.border, height: 16),
                    if (!isPayingBalance) ...[
                      _summaryRow('Total Amount', 'RM ${totalAmount.toStringAsFixed(2)}'),
                      _summaryRow('Deposit Due Now', 'RM ${depositAmount.toStringAsFixed(2)}'),
                      _summaryRow('Balance Due Later', 'RM ${balanceAmount.toStringAsFixed(2)}'),
                    ] else ...[
                      _summaryRow('Total Amount', 'RM ${totalAmount.toStringAsFixed(2)}'),
                      _summaryRow('Deposit Already Paid', '–RM ${depositAmount.toStringAsFixed(2)}'),
                      _summaryRow('Balance Due Now', 'RM ${balanceAmount.toStringAsFixed(2)}'),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                if (paymentStatus == 'loading')
                  const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _C.accent))
                else if (paymentStatus == 'error')
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _C.dangerBg, borderRadius: BorderRadius.circular(12)), child: Text(paymentError.isEmpty ? 'An error occurred.' : paymentError, style: const TextStyle(color: _C.danger, fontWeight: FontWeight.w700)))
                else
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: Text(isPayingBalance ? 'Pay Balance with PayPal' : 'Pay Deposit with PayPal', style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: paymentStatus == 'processing' ? null : startPayPalCartPayment,
                  )),
                if (paymentError.isNotEmpty && paymentStatus != 'error') ...[
                  const SizedBox(height: 8),
                  Text(paymentError, style: const TextStyle(color: _C.danger, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: OutlinedButton(
                  onPressed: () => fetchPropertyOwnerPayPalId(reservation['propertyid']),
                  style: OutlinedButton.styleFrom(foregroundColor: _C.primaryLight, side: const BorderSide(color: _C.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
      ),
    ));
  }

  Widget _paymentCountdownBox() {
    final urgent = paymentCountdown <= 60;
    final warning = !urgent && paymentCountdown <= 120;
    final bg = urgent ? _C.dangerBg : warning ? _C.warningBg : _C.successBg;
    final border = urgent ? _C.dangerBorder : warning ? _C.warningBorder : _C.successBorder;
    final color = urgent ? _C.danger : warning ? _C.warning : _C.success;
    final label = urgent ? '⚠️ Time running out!' : warning ? '⏳ Almost out of time' : '⏱️ Time to complete payment';
    final mins = paymentCountdown ~/ 60;
    final secs = paymentCountdown % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        Text('${mins.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}',
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // REVIEW MODAL
  // ──────────────────────────────────────────────────────────────────
  Widget _reviewModalContent() {
    return Container(
      width: 480,
      constraints: const BoxConstraints(maxHeight: 680),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(builder: (context, modalSet) {
          if (reviewState == 'deleted') {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: _C.dangerBg, shape: BoxShape.circle),
                child: const Icon(Icons.block_rounded, color: _C.danger, size: 28)),
              const SizedBox(height: 14),
              const Text('Review Not Available', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _C.textPrimary)),
              const SizedBox(height: 8),
              const Text('You have already submitted or deleted a review for this property. Guests are limited to one review per stay.', textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
              )),
            ]);
          }

          final submitDisabled = isSubmittingReview;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reviewState == 'create' ? 'Rate Your Stay' : 'Your Review',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.textPrimary)),
                const SizedBox(height: 2),
                Text('${reviewProperty?['propertyaddress'] ?? ''}', style: const TextStyle(color: _C.textMuted, fontSize: 12)),
              ])),
              InkWell(
                onTap: isSubmittingReview
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, size: 18, color: _C.textSecond)),
              ),
            ]),
            const SizedBox(height: 18),
            ...['location','cleanliness','value','facilities','service'].map((key) {
              final labels = {'location':'Location','cleanliness':'Cleanliness','value':'Value for Money','facilities':'Facilities','service':'Service'};
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                SizedBox(width: 110, child: Text('${labels[key]}', style: const TextStyle(fontWeight: FontWeight.w700, color: _C.textSecond, fontSize: 13))),
                ...List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: reviewState == 'create' ? () => modalSet(() => subRatings[key] = star) : null,
                    child: Padding(padding: const EdgeInsets.only(right: 2),
                      child: Icon(star <= (subRatings[key] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded, color: _C.starGold, size: 26)),
                  );
                }),
              ]));
            }),
            const SizedBox(height: 10),
            TextField(
              maxLines: 4,
              readOnly: reviewState != 'create',
              enabled: true,
              controller: reviewController,
              focusNode: reviewFocusNode,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (v) {
                reviewText = v;
              },
              style: const TextStyle(color: _C.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Share details of your experience...',
                hintStyle: const TextStyle(color: _C.textMuted),
                filled: true,
                fillColor: _C.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.accent, width: 2),
                ),
              ),
            ),
            if (reviewError.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.dangerBorder),
                ),
                child: Text(
                  reviewError,
                  style: const TextStyle(
                    color: _C.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              if (reviewState == 'view') TextButton.icon(
                onPressed: isSubmittingReview ? null : handleDeleteReview,
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _C.danger),
                label: const Text('Delete', style: TextStyle(color: _C.danger, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(
                onPressed: isSubmittingReview
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                style: TextButton.styleFrom(foregroundColor: _C.textMuted),
                child: Text(reviewState == 'view' ? 'Close' : 'Cancel'),
              ),
              if (reviewState == 'create') ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: submitDisabled ? null : () => handleReviewSubmit(modalSet),
                  style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(isSubmittingReview ? 'Saving...' : 'Submit', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
          ]);
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // SUPPORT MODAL
  // ──────────────────────────────────────────────────────────────────
  Widget _supportModal() {
    return _modalBackdrop(child: Container(
      width: 420,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle),
            child: const Icon(Icons.headset_mic_rounded, color: _C.accent, size: 26)),
          const SizedBox(height: 14),
          const Text('Contact Property Owner', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _C.textPrimary)),
          const SizedBox(height: 8),
          const Text('This reservation has been paid in full. Contact the property owner directly to discuss emergencies or modifications.',
            textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
            child: isFetchingSupport
                ? const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent)),
                    SizedBox(width: 10),
                    Text('Loading contact details...', style: TextStyle(color: _C.textMuted, fontSize: 13)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Operator Contact', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _C.textPrimary)),
                    Divider(color: _C.border, height: 14),
                    _contactLine(Icons.person_rounded, supportOperatorData?['name'] ?? 'Property Owner'),
                    _contactLine(Icons.email_rounded, supportOperatorData?['email'] ?? 'Not provided'),
                    _contactLine(Icons.phone_rounded, supportOperatorData?['phone'] ?? 'Not provided'),
                  ]),
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => setState(() => showSupportModal = false),
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]),
      ),
    ));
  }

  Widget _contactLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      Icon(icon, color: _C.accent, size: 16), const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(color: _C.textSecond, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  // ──────────────────────────────────────────────────────────────────
  // OVERLAYS
  // ──────────────────────────────────────────────────────────────────
  Widget _refreshNotice() {
    return Positioned(
      top: 90, right: 16,
      child: Container(
        width: 320, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.blueBorder), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)]),
        child: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Please wait', style: TextStyle(fontWeight: FontWeight.w800, color: _C.textPrimary)),
            Text(cartRefreshMessage.isEmpty ? 'Updating your booking...' : cartRefreshMessage, style: const TextStyle(fontSize: 12, color: _C.textMuted)),
          ])),
        ]),
      ),
    );
  }

  Widget _cancelProcessingOverlay() {
    return _modalBackdrop(child: Container(
      width: 380, padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: _C.warningBg, shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_top_rounded, size: 26, color: _C.warning)),
        const SizedBox(height: 14),
        const Text('Processing Cancellation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPrimary)),
        const SizedBox(height: 8),
        const Text('Please wait while we update your reservation status.', textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted)),
        const SizedBox(height: 16),
        const LinearProgressIndicator(color: _C.accent),
      ]),
    ));
  }

  Widget _modalBackdrop({required Widget child}) => Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Material(color: Colors.transparent, child: child),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────
// Status Badge
// ──────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({this.status = 'Unknown'});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    IconData icon = Icons.info_outline_rounded;
    Color bg = const Color(0xFFF5EDE0);
    Color fg = const Color(0xFF6B4C30);
    Color border = const Color(0xFFE8D9C5);

    if (s == 'enquiry') {
      icon = Icons.chat_bubble_outline_rounded; bg = const Color(0xFFECECF5); fg = const Color(0xFF4A4A80); border = const Color(0xFFCCCCEE);
    } else if (s == 'partially paid') {
      icon = Icons.credit_card_rounded; bg = const Color(0xFFFFF8EC); fg = const Color(0xFF9A6200); border = const Color(0xFFE8C56A);
    } else if (s == 'paid' || s == 'accepted') {
      icon = Icons.check_circle_rounded; bg = const Color(0xFFEBF7F2); fg = const Color(0xFF3D7A5C); border = const Color(0xFFB2DDD0);
    } else if (s == 'pending' || s == 'booking') {
      icon = Icons.access_time_rounded; bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); border = const Color(0xFFBFDBFE);
    } else if (s == 'payment pending') {
      icon = Icons.payment_rounded; bg = const Color(0xFFFFF8EC); fg = const Color(0xFF9A6200); border = const Color(0xFFE8C56A);
    } else if (s == 'canceled' || s == 'cancelled' || s == 'expired' || s == 'rejected') {
      icon = s == 'expired' ? Icons.schedule_rounded : Icons.cancel_rounded;
      bg = const Color(0xFFFBECEC); fg = const Color(0xFFB83232); border = const Color(0xFFEFB8B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}

class _CartBatikPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const spacing = 40.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), 8, paint);
        canvas.drawCircle(Offset(x, y), 14, paint);

        final path = Path()
          ..moveTo(x - 10, y)
          ..lineTo(x, y - 10)
          ..lineTo(x + 10, y)
          ..lineTo(x, y + 10)
          ..close();

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}