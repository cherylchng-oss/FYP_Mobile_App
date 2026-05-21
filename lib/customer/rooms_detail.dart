import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart' as api;
import '../services/session.dart';
import '../services/paypal_service.dart';
import 'customer_rooms.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({
    super.key,
    required this.property,
    this.initialCheckIn = '',
    this.initialCheckOut = '',
    this.initialGuests = 1,
    this.filterRegion = '',
  });

  final Property property;
  final String initialCheckIn;
  final String initialCheckOut;
  final int initialGuests;
  final String filterRegion;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey roomSectionKey = GlobalKey();

  Timer? toastTimer;
  Timer? paymentTimer;

  Map<String, dynamic>? propertyDetails;
  bool loading = false;
  String? error;

  String checkIn = '';
  String checkOut = '';
  int guests = 1;
  int adults = 1;
  int children = 0;

  int totalNights = 0;
  bool showBookingForm = false;
  bool acceptedTerms = false;
  bool showPaymentSelectionPage = false;
  bool showPaymentConfirmationPage = false;

  Map<String, dynamic> bookingForm = {
    'title': 'Mr.',
    'firstName': '',
    'lastName': '',
    'email': '',
    'phoneNumber': '',
    'additionalRequests': '',
  };

  final List<String> _titleOptions = const [
    'Mr.',
    'Mrs.',
    'Ms.',
    'Miss',
    'Madam',
  ];

  String? _safeBookingTitleValue(dynamic value) {
    final title = value?.toString().trim();

    if (title == null || title.isEmpty || title == 'null') {
      return null;
    }

    if (_titleOptions.contains(title)) {
      return title;
    }

    return null;
  }

  String paymentFormError = '';
  bool showBookingBlockedModal = false;
  String blockedBookingTitle = 'Booking Window Closed';
  String blockedBookingMessage = '';
  Map<String, dynamic>? blockedBookingDetails;

  bool isFullscreen = false;
  int selectedImageIndex = 0;
  List<String> fullscreenImages = [];
  double imageZoom = 1;

  Map<String, bool> expandedRoomDesc = {};

  String toastMessage = '';
  bool showToast = false;
  String toastType = '';

  int paymentCountdown = 300;
  bool paymentExpired = false;
  dynamic currentReservationId;

  bool isDateOverlapping = false;
  bool isInstantPayment = false;
  Map<String, dynamic>? selectedReservation;
  String paymentStatus = 'idle';
  String paymentError = '';

  bool showAuthPrompt = false;
  String authPromptMode = 'deposit';

  bool isSoldOut = false;
  bool isBlackedOut = false;
  int? roomsLeft;
  Map<String, dynamic> roomAvailabilityMap = {};
  Map<String, double> roomOptionPriceMap = {};
  bool isLoadingRoomOptions = false;
  List<String> propertySoldOutDates = [];
  bool isLoadingPropertySoldOutDates = false;

  List<Map<String, dynamic>> propertyBlackouts = [];
  List<Map<String, dynamic>> nearbyWalkable = [];
  List<Map<String, dynamic>> nearbyLandmarks = [];
  bool nearbyLoading = false;
  String nearbyError = '';

  Map<String, dynamic> bookingData = {
    'checkIn': '',
    'checkOut': '',
    'adults': 1,
    'children': 0,
    'selectedRoom': null,
  };

  bool showAllFacilities = false;
  int currentSlide = 0;

  Map<String, dynamic>? breakdownData;
  bool isLoadingBreakdown = false;
  double usedBaseRate = 0;
  int priceRequestId = 0;

  double globalSstRate = 0.08;
  double globalDepositRate = 0.10;
  bool isPricingLoading = false;

  List<Map<String, dynamic>> allReviews = [];
  String reviewSort = 'latest';
  bool isEligibleToReview = false;
  String reviewState = 'loading';
  dynamic existingReviewId;
  DateTime? latestCheckout;
  String reviewText = '';
  bool isSubmittingReview = false;

  Map<String, int> subRatings = {
    'location': 0,
    'cleanliness': 0,
    'value': 0,
    'facilities': 0,
    'service': 0,
  };

  final Map<String, IconData> facilityIcons = const {
    'Wi-Fi': Icons.wifi,
    'Kitchen': Icons.restaurant,
    'Washer': Icons.local_laundry_service,
    'Dryer': Icons.dry_cleaning,
    'Air Conditioning': Icons.ac_unit,
    'Heating': Icons.air,
    'Dedicated workspace': Icons.desktop_windows,
    'TV': Icons.tv,
    'Free Parking': Icons.local_parking,
    'Swimming Pool': Icons.pool,
    'Bathtub': Icons.bathtub,
    'Shower': Icons.shower,
    'EV charger': Icons.electric_car,
    'Baby Crib': Icons.child_friendly,
    'King bed': Icons.king_bed,
    'Gym': Icons.fitness_center,
    'Breakfast': Icons.coffee,
    'Indoor fireplace': Icons.fireplace,
    'Smoking allowed': Icons.smoking_rooms,
    'No Smoking': Icons.smoke_free,
    'City View': Icons.location_city,
    'Garden': Icons.park,
    'Bicycle Rental': Icons.pedal_bike,
    'Beachfront': Icons.beach_access,
    'Waterfront': Icons.water,
    'Countryside': Icons.landscape,
    'Ski-in/ski-out': Icons.downhill_skiing,
    'Desert': Icons.terrain,
    'Security Alarm': Icons.notifications_active,
    'Fire Extinguisher': Icons.fire_extinguisher,
    'First Aid Kit': Icons.medical_services,
    'Security Camera': Icons.videocam,
    'Instant booking': Icons.flash_on,
    'Self check-in': Icons.key,
    'Pets Allowed': Icons.pets,
    'No Pets': Icons.block,
  };

  @override
  void initState() {
    super.initState();

    propertyDetails = Map<String, dynamic>.from(widget.property.raw);
    checkIn = toSafeIsoDate(widget.initialCheckIn);
    checkOut = toSafeIsoDate(widget.initialCheckOut);
    guests = math.max(1, widget.initialGuests);
    adults = guests;
    children = 0;
    roomsLeft = parseInt(propertyDetails?['quantity'] ?? propertyDetails?['propertyquantity'] ?? 1, 1);

    bookingData = {
      'checkIn': checkIn,
      'checkOut': checkOut,
      'adults': adults,
      'children': children,
      'selectedRoom': null,
    };

    fetchPricingSettings();
    fetchPropertyDetailsIfNeeded();
    loadUserData();
    loadReviewsAndEligibility();
    loadBlackouts();
    calculatePriceBreakdownOnly();
    unawaited(refreshAvailabilityInBackground());
  }

  @override
  void dispose() {
    toastTimer?.cancel();
    paymentTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  int parseInt(dynamic value, [int fallback = 0]) {
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  double parseDouble(dynamic value, [double fallback = 0]) {
    final parsed = double.tryParse('${value ?? ''}');
    return parsed != null && parsed.isFinite ? parsed : fallback;
  }

  String normalizeText(dynamic value) {
    return '${value ?? ''}'.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String getRoomAvailabilityKey(String baseName, [String packageName = '']) {
    return '${normalizeText(baseName)}__${normalizeText(packageName)}';
  }

  String get propertyAvailabilityKey => '__entire_property__';

  Future<void> refreshEntirePropertyAvailabilityOnly() async {
    final safeCheckIn = toSafeIsoDate(checkIn);
    final safeCheckOut = toSafeIsoDate(checkOut);
    final nights = calculateNights(safeCheckIn, safeCheckOut);

    if (!mounted) return;

    if (safeCheckIn.isEmpty || safeCheckOut.isEmpty || nights <= 0) {
      setState(() {
        roomsLeft = selectedRoomQuantity();
        isSoldOut = false;
        isBlackedOut = false;
        isDateOverlapping = false;
        isLoadingRoomOptions = false;
      });
      return;
    }

    setState(() {
      isLoadingRoomOptions = true;
    });

    final totalQty = selectedRoomQuantity();

    try {
      final availability = await api.fetchPropertyAvailability(
        propertyId: propertyIdInt,
        checkIn: safeCheckIn,
        checkOut: safeCheckOut,
      );

      final booked = countOverlappingPropertyBookings(
        availability['bookings'] is List ? availability['bookings'] : [],
      );

      final left = math.max(0, totalQty - booked);
      final blackedOut = isSelectedRangeBlackedOut();

      if (!mounted) return;

      setState(() {
        roomAvailabilityMap[propertyAvailabilityKey] = {
          'total': totalQty,
          'booked': booked,
          'left': left,
          'soldOut': left <= 0,
        };

        roomsLeft = blackedOut ? 0 : left;
        isBlackedOut = blackedOut;
        isDateOverlapping = left <= 0;
        isSoldOut = blackedOut || left <= 0;
        isLoadingRoomOptions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        roomsLeft = totalQty;
        isSoldOut = false;
        isDateOverlapping = false;
        isLoadingRoomOptions = false;
      });

      print('Failed to refresh entire property availability: $e');
    }
  }

  int countOverlappingPropertyBookings(List bookings) {
    final selectedStart = DateTime.tryParse(toSafeIsoDate(checkIn));
    final selectedEnd = DateTime.tryParse(toSafeIsoDate(checkOut));

    if (selectedStart == null || selectedEnd == null) return 0;

    final ids = <String>{};

    for (var i = 0; i < bookings.length; i++) {
      final item = bookings[i];
      if (item is! Map) continue;

      final booking = Map<String, dynamic>.from(item);

      if ('${booking['propertyid']}' != propertyId) continue;
      if (!shouldHoldRoomStock(booking)) continue;

      final bookedStart = DateTime.tryParse(toSafeIsoDate(booking['checkindatetime']));
      final bookedEnd = DateTime.tryParse(toSafeIsoDate(booking['checkoutdatetime']));

      if (bookedStart == null || bookedEnd == null) continue;

      final overlaps = bookedStart.isBefore(selectedEnd) && bookedEnd.isAfter(selectedStart);

      if (overlaps) {
        ids.add('${booking['reservationid'] ?? booking['id'] ?? i}');
      }
    }

    return ids.length;
  }

  bool isSelectedRoomSoldOutNow() {
    final selectedRoom = bookingData['selectedRoom'];
    if (selectedRoom is! Map) return false;

    final baseName = '${selectedRoom['baseRoomName'] ?? selectedRoom['name'] ?? ''}';
    final packageName = selectedRoom['isVariation'] == true
        ? '${selectedRoom['name'] ?? ''}'
        : '';

    final key = getRoomAvailabilityKey(baseName, packageName);
    final availability = roomAvailabilityMap[key];

    if (availability is Map) {
      final left = parseInt(availability['left'], selectedRoomQuantity());
      return availability['soldOut'] == true || left <= 0;
    }

    return isSoldOut;
  }

  int getRoomQuantity(Map<String, dynamic> room, [Map<String, dynamic>? option]) {
    final optionQty = parseInt(option?['quantity'] ?? option?['qty'], 0);
    if (optionQty > 0) return optionQty;

    final roomQty = parseInt(room['quantity'] ?? room['qty'], 0);
    if (roomQty > 0) return roomQty;

    return 1;
  }

  bool shouldHoldRoomStock(Map<String, dynamic> reservation) {
    final status = normalizeText(reservation['reservationstatus']);

    return [
      'paid',
      'partially paid',
      'payment pending',
      'pending',
      'booking',
    ].contains(status);
  }

  Map<String, String> extractBookedRoomInfo(Map<String, dynamic> booking) {
    final rawText = '${booking['request'] ?? booking['reservationrequest'] ?? booking['additionalrequests'] ?? booking['reservation_request'] ?? ''}';

    final roomMatch = RegExp(r'Room Selected:\s*([^\n\r(]+)', caseSensitive: false).firstMatch(rawText);
    final packageMatch = RegExp(r'\(Package:\s*([^)]+)\)', caseSensitive: false).firstMatch(rawText);

    return {
      'roomName': normalizeText(roomMatch?.group(1) ?? rawText),
      'packageName': normalizeText(packageMatch?.group(1) ?? ''),
      'rawText': normalizeText(rawText),
    };
  }

  bool bookingMatchesRoomAndPackage(
    Map<String, dynamic> booking,
    String baseRoomName,
    String packageName,
  ) {
    final baseName = normalizeText(baseRoomName);
    final pkgName = normalizeText(packageName);

    if (baseName.isEmpty) return false;

    final booked = extractBookedRoomInfo(booking);

    final sameRoom =
        booked['roomName'] == baseName ||
        booked['rawText']!.contains('room selected: $baseName');

    if (!sameRoom) return false;

    if (pkgName.isNotEmpty) {
      return booked['packageName'] == pkgName;
    }

    return booked['packageName']!.isEmpty;
  }

  int countUniqueMatchingBookings(
    List bookings,
    String baseRoomName,
    String packageName,
  ) {
    final ids = <String>{};

    for (var i = 0; i < bookings.length; i++) {
      final item = bookings[i];
      if (item is! Map) continue;

      final booking = Map<String, dynamic>.from(item);

      if (!shouldHoldRoomStock(booking)) continue;

      if (bookingMatchesRoomAndPackage(booking, baseRoomName, packageName)) {
        ids.add('${booking['reservationid'] ?? booking['id'] ?? '${booking['request']}-$i'}');
      }
    }

    return ids.length;
  }

  String toSafeIsoDate(dynamic value) {
    if (value == null) return '';

    final raw = value is DateTime ? value.toIso8601String() : '$value'.trim();
    if (raw.isEmpty) return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;

    final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
    if (slashMatch != null) {
      return '${slashMatch.group(3)}-${slashMatch.group(2)}-${slashMatch.group(1)}';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';

    final local = parsed.toLocal();

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String toBlackoutIsoDate(dynamic value) {
    if (value == null) return '';

    final raw = value is DateTime ? value.toIso8601String() : '$value'.trim();
    if (raw.isEmpty || raw == 'null') return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return raw;
    }

    // Convert dd/mm/yyyy to yyyy-mm-dd
    final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
    if (slashMatch != null) {
      return '${slashMatch.group(3)}-${slashMatch.group(2)}-${slashMatch.group(1)}';
    }

    // For blackout dates from DB like 2026-05-19T00:00:00.000Z,
    final isoDateMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    if (isoDateMatch != null) {
      return isoDateMatch.group(1)!;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';

    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String getLocalTodayIsoDate() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  String addDaysToIsoDate(dynamic value, [int daysToAdd = 1]) {
    final iso = toSafeIsoDate(value);
    final date = DateTime.tryParse(iso) ?? DateTime.now();
    final next = date.add(Duration(days: daysToAdd));
    return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
  }

  String normalizeDateString(dynamic value) => toSafeIsoDate(value);

  String formatDisplayDate(dynamic value) {
    final normalized = normalizeDateString(value);
    if (normalized.isEmpty) return '';
    final parts = normalized.split('-');
    if (parts.length != 3) return normalized;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String formatFriendlyDate(dynamic value) {
    final normalized = normalizeDateString(value);
    if (normalized.isEmpty) return '-';
    final date = DateTime.tryParse(normalized);
    if (date == null) return normalized;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int calculateNights(String start, String end) {
    final s = DateTime.tryParse(toSafeIsoDate(start));
    final e = DateTime.tryParse(toSafeIsoDate(end));
    if (s == null || e == null) return 0;
    final nights = e.difference(s).inDays;
    return nights > 0 ? nights : 0;
  }

  void displayToast(String type, String message, {bool isSticky = false}) {
    toastTimer?.cancel();
    setState(() {
      toastType = type;
      toastMessage = message;
      showToast = true;
    });
    if (!isSticky) {
      toastTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => showToast = false);
      });
    }
  }

  String get propertyId => '${propertyDetails?['propertyid'] ?? widget.property.id}';
  int get propertyIdInt => parseInt(propertyId, 0);
  int get maxPropertyGuests => parseInt(propertyDetails?['propertyguestpaxno'], 10);

  bool get isHotel => ['Hotel', 'Resort', 'Inn', 'Hostel'].contains(propertyDetails?['categoryname']);
  bool get isHomestay => ['Homestay', 'Lodge', 'Guesthouse', 'Apartment'].contains(propertyDetails?['categoryname']);

  String get description {
    final rawDescription = '${propertyDetails?['propertydescription'] ?? widget.property.description}';
    if (rawDescription.contains('_ROOMDATA_')) return rawDescription.split('_ROOMDATA_').first.trim();
    return rawDescription.trim();
  }

  dynamic get rawSetup {
    dynamic setup = propertyDetails?['room_details'] ?? propertyDetails?['roomsetup'] ?? '';
    final rawDescription = '${propertyDetails?['propertydescription'] ?? ''}';
    if (rawDescription.contains('_ROOMDATA_')) {
      final parts = rawDescription.split('_ROOMDATA_');
      if (parts.length > 1) setup = parts[1];
    }
    return setup;
  }

  bool get hasRealRoomInventory {
    final setup = rawSetup;

    if (setup is List && setup.isNotEmpty) return true;

    if (setup is String && setup.trim().startsWith('[')) {
      try {
        final parsed = jsonDecode(setup);
        return parsed is List && parsed.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  List<Map<String, dynamic>> get availableRooms {
    final rooms = <Map<String, dynamic>>[];
    dynamic setup = rawSetup;

    try {
      if (setup is List) {
        rooms.addAll(setup.map((item) => Map<String, dynamic>.from(item as Map)));
      } else if (setup is String && setup.trim().startsWith('[')) {
        final parsed = jsonDecode(setup);
        if (parsed is List) {
          rooms.addAll(parsed.map((item) => Map<String, dynamic>.from(item as Map)));
        }
      } else if (isHotel && '${propertyDetails?['propertybedtype'] ?? ''}'.isNotEmpty) {
        final beds = '${propertyDetails?['propertybedtype']}'.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
        int index = 0;
        for (final bed in beds) {
          rooms.add({
            'id': 'legacy-$index',
            'name': bed,
            'bedType': bed,
            'maxGuests': propertyDetails?['propertyguestpaxno'] ?? 1,
            'description': '',
            'price': propertyDetails?['normalrate'],
            'quantity': propertyDetails?['quantity'] ?? propertyDetails?['propertyquantity'] ?? 1,
            'images': [],
            'options': [],
          });
          index++;
        }
      }
    } catch (_) {}

    rooms.sort((a, b) => parseDouble(a['price']).compareTo(parseDouble(b['price'])));
    return rooms;
  }

  bool get isJsonInventory => availableRooms.isNotEmpty;

  List<String> get propertyImages {
    final images = propertyDetails?['propertyimage'];
    if (images is List) return images.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    if (images is String && images.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(images);
        if (decoded is List) return decoded.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
      } catch (_) {}
      return [images];
    }
    return widget.property.imageUrls;
  }

  List<String> get propertyFacilities {
    final raw = '${propertyDetails?['facilities'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return widget.property.amenities;
    return raw.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

  Future<void> loadReviewsAndEligibility() async {
    await loadReviews();
    await loadReviewEligibility();
  }

  Future<void> fetchPricingSettings() async {
    setState(() => isPricingLoading = true);
    try {
      final data = await api.fetchPricingSettings();
      if (!mounted) return;
      setState(() {
        globalSstRate = parseDouble(data['sstRate'] ?? data['sst_rate'], 0.08);
        globalDepositRate = parseDouble(data['depositRate'] ?? data['deposit_rate'], 0.10);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        globalSstRate = 0.08;
        globalDepositRate = 0.10;
      });
    } finally {
      if (mounted) setState(() => isPricingLoading = false);
    }
  }

  Future<void> fetchPropertyDetailsIfNeeded() async {
    final id = propertyIdInt;

    if (id <= 0) return;

    setState(() => loading = true);

    try {
      final fullProperty = await api.fetchSinglePropertyDetails(id);

      if (!mounted) return;

      setState(() {
        propertyDetails = fullProperty;

        roomsLeft = parseInt(
          fullProperty['quantity'] ?? fullProperty['propertyquantity'] ?? 1,
          1,
        );
      });
    } catch (e) {
      print('Failed to fetch full property details: $e');

      // Keep using passed-in preview data if full fetch fails.
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> loadUserData() async {
    try {
      final userId = await Session.getUserId();
      if (userId == null || '$userId'.isEmpty) return;
      final data = await api.fetchUserData(userId);
      if (!mounted) return;
      setState(() {
        bookingForm['title'] = '${data['utitle'] ?? 'Mr.'}';
        bookingForm['firstName'] = '${data['ufirstname'] ?? ''}';
        bookingForm['lastName'] = '${data['ulastname'] ?? ''}';
        bookingForm['email'] = '${data['uemail'] ?? ''}';
        bookingForm['phoneNumber'] = '${data['uphoneno'] ?? ''}';
      });
    } catch (_) {}
  }

  Future<void> loadReviews() async {
    try {
      final data = await api.fetchReviews(propertyIdInt);
      final list = data is List
          ? data
          : data is Map
              ? (data['reviews'] ?? data['data'] ?? [])
              : [];
      if (!mounted) return;
      setState(() => allReviews = List<Map<String, dynamic>>.from((list as List).map((e) => Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  Future<void> loadReviewEligibility() async {
    setState(() => reviewState = 'loading');
    try {
      final reservations = await api.fetchReservation();
      final userId = await Session.getUserId();
      final list = reservations is List ? reservations : [];
      DateTime? latest;
      bool eligible = false;
      dynamic reviewId;

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final sameProperty = '${map['propertyid']}' == propertyId;
        final sameUser = userId == null || '${map['userid']}' == '$userId';
        final status = normalizeText(map['reservationstatus']);
        final checkout = DateTime.tryParse('${map['checkoutdatetime'] ?? ''}');
        if (sameProperty && sameUser && checkout != null && checkout.isBefore(DateTime.now()) && status == 'paid') {
          eligible = true;
          if (latest == null || checkout.isAfter(latest)) latest = checkout;
        }
      }

      for (final review in allReviews) {
        if (userId != null && '${review['userid']}' == '$userId') reviewId = review['reviewid'];
      }

      if (!mounted) return;
      setState(() {
        isEligibleToReview = eligible;
        existingReviewId = reviewId;
        latestCheckout = latest;
        reviewState = eligible ? 'eligible' : 'notEligible';
      });
    } catch (_) {
      if (mounted) setState(() => reviewState = 'error');
    }
  }

  Future<void> loadBlackouts() async {
    try {
      final data = await api.fetchBlackoutDates();
      final list = data is List
          ? data
          : data is Map
              ? (data['blackouts'] ?? data['data'] ?? [])
              : [];
      if (!mounted) return;
      setState(() {
        propertyBlackouts = List<Map<String, dynamic>>.from(
          (list as List)
              .where((item) => '${(item as Map)['propertyid']}' == propertyId && item['is_active'] != false)
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
      });
    } catch (_) {}
  }

  Future<void> openBlockedDatePicker({
    required String field,
    required String minDate,
    String defaultViewDate = '',
  }) async {

    if (!mounted) return;

    DateTime viewDate = DateTime.tryParse(
          field == 'checkIn'
              ? (checkIn.isNotEmpty ? checkIn : minDate)
              : (checkOut.isNotEmpty ? checkOut : defaultViewDate.isNotEmpty ? defaultViewDate : minDate),
        ) ??
        DateTime.now();

    int viewYear = viewDate.year;
    int viewMonth = viewDate.month - 1;

    String dateStr(int day) =>
        '$viewYear-${(viewMonth + 1).toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    bool isBlackout(String date) {
      for (final blackout in propertyBlackouts) {
        final start = toBlackoutIsoDate(blackout['start_date'] ?? blackout['startDate']);
        final end = toBlackoutIsoDate(blackout['end_date'] ?? blackout['endDate'] ?? start);
        if (start.isNotEmpty && start.compareTo(date) <= 0 && end.compareTo(date) >= 0) {
          return true;
        }
      }
      return false;
    }

    bool isSoldOutDate(String date) {
      return propertySoldOutDates.any((d) => toSafeIsoDate(d) == date);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final daysInMonth = DateTime(viewYear, viewMonth + 2, 0).day;
            final firstDay = DateTime(viewYear, viewMonth + 1, 1).weekday % 7;
            const months = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];

            return Dialog(
              insetPadding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setDialogState(() {
                              if (viewMonth == 0) {
                                viewMonth = 11;
                                viewYear--;
                              } else {
                                viewMonth--;
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${months[viewMonth]} $viewYear',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setDialogState(() {
                              if (viewMonth == 11) {
                                viewMonth = 0;
                                viewYear++;
                              } else {
                                viewMonth++;
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 8),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: firstDay + daysInMonth,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemBuilder: (_, index) {
                        if (index < firstDay) return const SizedBox.shrink();

                        final day = index - firstDay + 1;
                        final date = dateStr(day);
                        final selected = field == 'checkIn' ? date == checkIn : date == checkOut;
                        final disabled = date.compareTo(minDate) < 0;
                        final blackout = isBlackout(date);
                        final soldOut = isSoldOutDate(date);
                        final blocked = disabled || blackout || soldOut;

                        return InkWell(
                          onTap: blocked
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await handleDateChange(field, date);
                              },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: soldOut
                                  ? const Color(0xFFE5E7EB)
                                  : blackout
                                      ? const Color(0xFFFEE2E2)
                                      : selected
                                          ? const Color(0xFF2563EB)
                                          : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: soldOut
                                    ? const Color(0xFFD1D5DB)
                                    : blackout
                                        ? const Color(0xFFFCA5A5)
                                        : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: soldOut
                                    ? const Color(0xFF6B7280)
                                    : blackout
                                        ? const Color(0xFFB91C1C)
                                        : selected
                                            ? Colors.white
                                            : disabled
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF111827),
                                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          _GuideBox(color: Color(0xFFE5E7EB), text: 'Sold out'),
                          SizedBox(width: 14),
                          _GuideBox(color: Color(0xFFFEE2E2), text: 'Unavailable'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> loadPropertySoldOutDates() async {
    if (propertyIdInt <= 0) return;

    if (!mounted) return;
    setState(() => isLoadingPropertySoldOutDates = true);

    try {
      final dates = await api.fetchPropertySoldOutDates(
        propertyId: propertyIdInt,
        days: 90,
      );

      if (!mounted) return;

      setState(() {
        propertySoldOutDates = dates;
      });
    } catch (e) {
      print('Failed to load sold out dates: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingPropertySoldOutDates = false);
      }
    }
  }

  bool isSelectedRangeBlackedOut() {
    if (checkIn.isEmpty || checkOut.isEmpty) return false;
    final selectedRoom = bookingData['selectedRoom'];
    final selectedRoomName = normalizeText(selectedRoom is Map ? (selectedRoom['baseRoomName'] ?? selectedRoom['name']) : '');

    for (final blackout in propertyBlackouts) {
      final start = toBlackoutIsoDate(blackout['start_date'] ?? blackout['startDate']);
      final end = toBlackoutIsoDate(blackout['end_date'] ?? blackout['endDate'] ?? start);
      final roomName = normalizeText(blackout['room_name'] ?? blackout['roomName'] ?? '');
      final wholeProperty = roomName.isEmpty || roomName == 'all rooms' || roomName == 'all room';
      final applies = wholeProperty || (selectedRoomName.isNotEmpty && roomName == selectedRoomName);
      final overlaps = !(end.compareTo(checkIn) < 0 || start.compareTo(checkOut) >= 0);
      if (applies && overlaps) return true;
    }
    return false;
  }

  double selectedBaseRate() {
    final selectedRoom = bookingData['selectedRoom'];
    if (selectedRoom is Map) return parseDouble(selectedRoom['price'], parseDouble(propertyDetails?['normalrate'], widget.property.pricePerNight));

    if (availableRooms.isNotEmpty) {
      double lowest = double.infinity;
      for (final room in availableRooms) {
        final roomPrice = parseDouble(room['price'], double.infinity);
        if (roomPrice > 0 && roomPrice < lowest) lowest = roomPrice;
        final options = room['options'];
        if (options is List) {
          for (final option in options) {
            final price = parseDouble((option as Map)['price'], double.infinity);
            if (price > 0 && price < lowest) lowest = price;
          }
        }
      }
      if (lowest != double.infinity) return lowest;
    }
    return parseDouble(propertyDetails?['normalrate'], widget.property.pricePerNight);
  }

  int selectedRoomQuantity() {
    final selectedRoom = bookingData['selectedRoom'];
    if (selectedRoom is Map) {
      final qty = parseInt(selectedRoom['quantity'] ?? selectedRoom['qty'], 0);
      if (qty > 0) return qty;
    }
    final propertyQty = parseInt(propertyDetails?['quantity'] ?? propertyDetails?['propertyquantity'], 1);
    return propertyQty <= 0 ? 1 : propertyQty;
  }

  Future<void> calculatePriceBreakdownOnly({bool showLoading = true}) async {
    final requestId = ++priceRequestId;

    final safeCheckIn = toSafeIsoDate(checkIn);
    final safeCheckOut = toSafeIsoDate(checkOut);
    final nights = calculateNights(safeCheckIn, safeCheckOut);
    final baseRate = selectedBaseRate();

    if (showLoading && mounted) {
      setState(() {
        isLoadingBreakdown = true;
      });
    }

    if (!mounted) return;

    setState(() {
      usedBaseRate = baseRate;
      totalNights = nights;
    });

    if (safeCheckIn.isEmpty || safeCheckOut.isEmpty || nights <= 0) {
      if (!mounted || requestId != priceRequestId) return;

      setState(() {
        breakdownData = null;
        isLoadingBreakdown = false;
      });

      return;
    }

    double roomTotal = baseRate * nights;

    try {
      final result = await api.calculateBookingPrice(
        safeCheckIn,
        safeCheckOut,
        baseRate,
        propertyIdInt,
      );

      roomTotal = parseDouble(
        result['totalPrice'] ??
            result['total_price'] ??
            result['total'] ??
            result['price'],
        roomTotal,
      );
    } catch (_) {
      // use fallback roomTotal
    }

    if (!mounted || requestId != priceRequestId) return;

    final sstAmount = roomTotal * globalSstRate;
    final grandTotal = roomTotal + sstAmount;

    setState(() {
      breakdownData = {
        'roomTotal': roomTotal,
        'sstAmount': sstAmount,
        'grandTotal': grandTotal,
        'averageNightlyRate': nights > 0 ? roomTotal / nights : baseRate,
      };

      isLoadingBreakdown = false;
    });
  }

  Future<void> refreshSelectedRoomAvailabilityOnly() async {
    final safeCheckIn = toSafeIsoDate(checkIn);
    final safeCheckOut = toSafeIsoDate(checkOut);
    final nights = calculateNights(safeCheckIn, safeCheckOut);

    if (!mounted) return;

    if (safeCheckIn.isEmpty || safeCheckOut.isEmpty || nights <= 0) {
      setState(() {
        isLoadingRoomOptions = false;
        roomsLeft = selectedRoomQuantity();
        isSoldOut = false;
        isBlackedOut = false;
        isDateOverlapping = false;
      });
      return;
    }

    final selectedRoom = bookingData['selectedRoom'];

    if (selectedRoom is! Map) {
      await refreshEntirePropertyAvailabilityOnly();
      return;
    }

    setState(() {
      isLoadingRoomOptions = true;
    });

    final baseName =
        '${selectedRoom['baseRoomName'] ?? selectedRoom['name'] ?? ''}';

    final packageName = selectedRoom['isVariation'] == true
        ? '${selectedRoom['name'] ?? ''}'
        : '';

    final key = getRoomAvailabilityKey(baseName, packageName);
    final totalQty = selectedRoomQuantity();

    try {
      final availability = packageName.isEmpty
          ? await api.fetchPropertyAvailability(
              propertyId: propertyIdInt,
              checkIn: safeCheckIn,
              checkOut: safeCheckOut,
              roomName: baseName,
            )
          : await api.fetchPropertyAvailability(
              propertyId: propertyIdInt,
              checkIn: safeCheckIn,
              checkOut: safeCheckOut,
              roomName: baseName,
              packageName: packageName,
            );

      final booked = countUniqueMatchingBookings(
        availability['bookings'] is List ? availability['bookings'] : [],
        baseName,
        packageName,
      );

      final left = math.max(0, totalQty - booked);
      final blackedOut = isSelectedRangeBlackedOut();

      if (!mounted) return;

      setState(() {
        roomAvailabilityMap[key] = {
          'total': totalQty,
          'booked': booked,
          'left': left,
          'soldOut': left <= 0,
        };

        roomsLeft = blackedOut ? 0 : left;
        isBlackedOut = blackedOut;
        isDateOverlapping = left <= 0;
        isSoldOut = blackedOut || left <= 0;

        isLoadingRoomOptions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingRoomOptions = false;
      });
    }
  }

  Future<void> refreshAvailabilityInBackground() async {
    if (!mounted) return;

    setState(() {
      isLoadingRoomOptions = true;
      isLoadingPropertySoldOutDates = true;
    });

    await Future.wait([
      loadPropertySoldOutDates(),
      loadRoomOptionPricesAndAvailability(),
    ]);

    if (!mounted) return;

    updateAvailabilityStatusOnly();
  }

  void updateAvailabilityStatusOnly() {
    final safeCheckIn = toSafeIsoDate(checkIn);
    final safeCheckOut = toSafeIsoDate(checkOut);
    final nights = calculateNights(safeCheckIn, safeCheckOut);

    if (safeCheckIn.isEmpty || safeCheckOut.isEmpty || nights <= 0) {
      setState(() {
        roomsLeft = selectedRoomQuantity();
        isSoldOut = false;
        isBlackedOut = false;
        isDateOverlapping = false;
      });
      return;
    }

    final blackedOut = isSelectedRangeBlackedOut();
    final selectedRoom = bookingData['selectedRoom'];

    int selectedLeft = selectedRoomQuantity();
    bool selectedSoldOut = false;

    if (selectedRoom is! Map) {
      final availability = roomAvailabilityMap[propertyAvailabilityKey];

      if (availability is Map) {
        selectedLeft = parseInt(
          availability['left'],
          selectedRoomQuantity(),
        );

        selectedSoldOut = availability['soldOut'] == true || selectedLeft <= 0;
      }
    } else {
      final baseName =
          '${selectedRoom['baseRoomName'] ?? selectedRoom['name'] ?? ''}';

      final packageName = selectedRoom['isVariation'] == true
          ? '${selectedRoom['name'] ?? ''}'
          : '';

      final key = getRoomAvailabilityKey(baseName, packageName);
      final availability = roomAvailabilityMap[key];

      if (availability is Map) {
        selectedLeft = parseInt(
          availability['left'],
          selectedRoomQuantity(),
        );

        selectedSoldOut =
            availability['soldOut'] == true || selectedLeft <= 0;
      }
    }

    setState(() {
      isBlackedOut = blackedOut;
      isDateOverlapping = selectedSoldOut;
      isSoldOut = blackedOut || selectedSoldOut;
      roomsLeft = blackedOut ? 0 : selectedLeft;
    });
  }

  Future<void> loadRoomOptionPricesAndAvailability() async {
    final safeCheckIn = toSafeIsoDate(checkIn);
    final safeCheckOut = toSafeIsoDate(checkOut);
    final nights = calculateNights(safeCheckIn, safeCheckOut);

    if (safeCheckIn.isEmpty || safeCheckOut.isEmpty || nights <= 0) {
      if (!mounted) return;
      setState(() {
        roomOptionPriceMap = {};
        roomAvailabilityMap = {};
        isLoadingRoomOptions = false;
      });
      return;
    }

    if (availableRooms.isEmpty) {
      await refreshEntirePropertyAvailabilityOnly();
      return;
    }

    setState(() => isLoadingRoomOptions = true);

    final nextPriceMap = <String, double>{};
    final nextAvailabilityMap = <String, dynamic>{};

    try {
      for (final room in availableRooms) {
        final baseName = '${room['name'] ?? ''}';
        final basePrice = parseDouble(room['price'], selectedBaseRate());
        final baseQty = getRoomQuantity(room);
        final baseKey = getRoomAvailabilityKey(baseName);

        try {
          final priceResult = await api.calculateBookingPrice(
            safeCheckIn,
            safeCheckOut,
            basePrice,
            propertyIdInt,
          );

          final total = parseDouble(
            priceResult['totalPrice'] ??
                priceResult['total_price'] ??
                priceResult['total'] ??
                priceResult['price'],
            basePrice * nights,
          );

          nextPriceMap[baseKey] = double.parse((total / nights).toStringAsFixed(2));
        } catch (_) {
          nextPriceMap[baseKey] = basePrice;
        }

        try {
          final availability = await api.fetchPropertyAvailability(
            propertyId: propertyIdInt,
            checkIn: safeCheckIn,
            checkOut: safeCheckOut,
            roomName: baseName,
          );

          final booked = countUniqueMatchingBookings(
            availability['bookings'] is List ? availability['bookings'] : [],
            baseName,
            '',
          );

          final left = math.max(0, baseQty - booked);

          nextAvailabilityMap[baseKey] = {
            'total': baseQty,
            'booked': booked,
            'left': left,
            'soldOut': left <= 0,
          };
        } catch (_) {
          nextAvailabilityMap[baseKey] = {
            'total': baseQty,
            'booked': 0,
            'left': baseQty,
            'soldOut': false,
          };
        }

        final options = room['options'];
        if (options is List) {
          for (final optionItem in options) {
            final option = Map<String, dynamic>.from(optionItem as Map);
            final packageName = '${option['name'] ?? ''}';
            final optionPrice = parseDouble(option['price'], basePrice);
            final optionQty = getRoomQuantity(room, option);
            final optionKey = getRoomAvailabilityKey(baseName, packageName);

            try {
              final priceResult = await api.calculateBookingPrice(
                safeCheckIn,
                safeCheckOut,
                optionPrice,
                propertyIdInt,
              );

              final total = parseDouble(
                priceResult['totalPrice'] ??
                    priceResult['total_price'] ??
                    priceResult['total'] ??
                    priceResult['price'],
                optionPrice * nights,
              );

              nextPriceMap[optionKey] = double.parse((total / nights).toStringAsFixed(2));
            } catch (_) {
              nextPriceMap[optionKey] = optionPrice;
            }

            try {
              final availability = await api.fetchPropertyAvailability(
                propertyId: propertyIdInt,
                checkIn: safeCheckIn,
                checkOut: safeCheckOut,
                roomName: baseName,
                packageName: packageName,
              );

              final booked = countUniqueMatchingBookings(
                availability['bookings'] is List ? availability['bookings'] : [],
                baseName,
                packageName,
              );

              final left = math.max(0, optionQty - booked);

              nextAvailabilityMap[optionKey] = {
                'total': optionQty,
                'booked': booked,
                'left': left,
                'soldOut': left <= 0,
              };
            } catch (_) {
              nextAvailabilityMap[optionKey] = {
                'total': optionQty,
                'booked': 0,
                'left': optionQty,
                'soldOut': false,
              };
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        roomOptionPriceMap = nextPriceMap;
        roomAvailabilityMap = nextAvailabilityMap;
        isLoadingRoomOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingRoomOptions = false);
    }
  }

  void selectRoom(Map<String, dynamic> room, {Map<String, dynamic>? option}) {
    final baseName = '${room['name'] ?? ''}';
    final packageName = option == null ? '' : '${option['name'] ?? ''}';
    final key = getRoomAvailabilityKey(baseName, packageName);
    final availability = roomAvailabilityMap[key];

    if (availability is Map && availability['soldOut'] == true) {
      displayToast(
        'error',
        option == null
            ? 'This room is sold out for the selected date.'
            : 'This room package is sold out for the selected date.',
      );
      return;
    }
    
    final selected = option == null
        ? {
            ...room,
            'baseRoomName': room['name'],
            'isVariation': false,
            'price': room['price'],
            'quantity': room['quantity'] ?? room['qty'] ?? 1,
          }
        : {
            ...option,
            'baseRoomName': room['name'],
            'isVariation': true,
            'bedType': room['bedType'],
            'maxGuests': room['maxGuests'],
            'quantity': option['quantity'] ?? option['qty'] ?? room['quantity'] ?? room['qty'] ?? 1,
          };

    setState(() {
      bookingData['selectedRoom'] = selected;

      roomsLeft = availability is Map
          ? parseInt(availability['left'], selectedRoomQuantity())
          : selectedRoomQuantity();

      isSoldOut = roomsLeft != null && roomsLeft! <= 0;
    });
    calculatePriceBreakdownOnly();
    unawaited(refreshSelectedRoomAvailabilityOnly());
  }

  Future<void> handleDateChange(String field, String value) async {
    setState(() {
      if (field == 'checkIn') {
        checkIn = value;
        bookingData['checkIn'] = value;

        if (checkOut.isNotEmpty && value.compareTo(checkOut) >= 0) {
          checkOut = '';
          bookingData['checkOut'] = '';
        }
      } else {
        checkOut = value;
        bookingData['checkOut'] = value;
      }

      breakdownData = null;
      roomsLeft = null;
      isSoldOut = false;
      isBlackedOut = false;
      isDateOverlapping = false;

      isLoadingBreakdown = true;
    });

    await calculatePriceBreakdownOnly();
    unawaited(loadPropertySoldOutDates());
    unawaited(refreshSelectedRoomAvailabilityOnly());
  }

  Future<void> openBookingForm({required bool instantPay}) async {
    if (isSoldOut) return;

    if (isJsonInventory && bookingData['selectedRoom'] == null) {
      displayToast('error', 'Please select a room type from the list to continue.');

      final ctx = roomSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }

      return;
    }
    
    if (checkIn.isEmpty || checkOut.isEmpty) {
      displayToast('error', 'Please select check-in and check-out dates first.');
      return;
    }

    if (isBlackedOut) {
      displayToast('error', 'Selected dates are unavailable. Please choose other dates.');
      return;
    }

    final userId = await Session.getUserId();
    if (userId == null || '$userId'.isEmpty) {
      setState(() {
        authPromptMode = instantPay ? 'instant' : 'deposit';
        showAuthPrompt = true;
      });
      return;
    }

    setState(() {
      isInstantPayment = instantPay;
      showBookingForm = true;
    });
  }

  double get roomTotal => parseDouble(breakdownData?['roomTotal'], selectedBaseRate() * totalNights);
  double get sstAmount => parseDouble(breakdownData?['sstAmount'], roomTotal * globalSstRate);
  double get finalGrandTotal => parseDouble(breakdownData?['grandTotal'], roomTotal + sstAmount);
  double get displayNightlyRate => totalNights > 0 ? roomTotal / totalNights : selectedBaseRate();
  bool get isPriceStillLoading =>
      isLoadingBreakdown || isPricingLoading;
  bool get isAvailabilityStillLoading => isLoadingRoomOptions;
  double get instantPaymentRate => parseDouble(propertyDetails?['instantpaymentrate'], 0.10);
  double get instantGrandTotal => finalGrandTotal * (1 - instantPaymentRate);
  double get depositAmount => isInstantPayment ? instantGrandTotal : finalGrandTotal * globalDepositRate;

  String reservationBlockTime() {
    final checkInDate = DateTime.tryParse(checkIn) ?? DateTime.now();
    final daysBeforePaying = parseDouble(propertyDetails?['daysbeforepaying'], 0);
    final block = checkInDate.subtract(Duration(minutes: (daysBeforePaying * 24 * 60).round()));
    return block.toIso8601String();
  }

  Future<void> submitBookingForm() async {
    if ('${bookingForm['firstName']}'.trim().isEmpty ||
        '${bookingForm['lastName']}'.trim().isEmpty ||
        '${bookingForm['email']}'.trim().isEmpty ||
        '${bookingForm['phoneNumber']}'.trim().isEmpty) {
      setState(() => paymentFormError = 'Please fill in all required guest details.');
      return;
    }

    setState(() {
      paymentFormError = '';
      paymentStatus = 'creating';
    });

    try {
      final userId = await Session.getUserId();
      final today = getLocalTodayIsoDate();

      if (isInstantPayment && checkIn == today) {
        setState(() {
          paymentStatus = 'idle';
          paymentFormError = 'Instant payment is only available from tomorrow onwards.';
        });
        return;
      }

      final selectedRoom = bookingData['selectedRoom'];
      final baseRoom = selectedRoom is Map ? '${selectedRoom['baseRoomName'] ?? selectedRoom['name'] ?? ''}' : '';
      final packageName = selectedRoom is Map && selectedRoom['isVariation'] == true ? ' (Package: ${selectedRoom['name']})' : '';
      final roomName = '$baseRoom$packageName'.trim();

      final reservationData = {
        'propertyid': propertyIdInt,
        'checkindatetime': '$checkIn 00:00:00',
        'checkoutdatetime': '$checkOut 00:00:00',
        'reservationblocktime': isInstantPayment
            ? null
            : reservationBlockTime(),
        'paymenttype': isInstantPayment ? 'instant' : 'deposit',
        'guestpaxno': guests,
        'adults': adults,
        'children': children,
        'request': roomName.isNotEmpty
            ? 'Room Selected: $roomName\n\nAdditional Requests: ${'${bookingForm['additionalRequests']}'.trim().isEmpty ? 'None' : bookingForm['additionalRequests']}'
            : '${bookingForm['additionalRequests'] ?? ''}',
        'totalprice': double.parse((isInstantPayment ? instantGrandTotal : finalGrandTotal).toStringAsFixed(2)),
        'reservationstatus': 'Payment Pending',
        'downpaymentamount': double.parse(depositAmount.toStringAsFixed(2)),
        'rctitle': bookingForm['title'],
        'rcfirstname': '${bookingForm['firstName']}'.trim(),
        'rclastname': '${bookingForm['lastName']}'.trim(),
        'rcemail': '${bookingForm['email']}'.trim(),
        'rcphoneno': '${bookingForm['phoneNumber']}'.trim(),
        'rcspecialrequests': '${bookingForm['additionalRequests']}'.trim(),
        'userid': userId,
      };

      final created = await api.createReservation(reservationData);
      final reservationId = created['reservationid'];
      currentReservationId = reservationId;
      selectedReservation = Map<String, dynamic>.from(created as Map);

      setState(() {
        showBookingForm = false;
        showPaymentConfirmationPage = true;
        acceptedTerms = false;
        paymentStatus = 'ready';
        paymentError = '';
      });
      startPaymentCountdown();
    } catch (error) {
      setState(() {
        paymentStatus = 'idle';
        paymentFormError = 'Unable to proceed with booking. The selected check-in date is too close. Please choose another date.';
      });
    }
  }

  void startPaymentCountdown() {
    paymentTimer?.cancel();
    setState(() {
      paymentCountdown = 300;
      paymentExpired = false;
    });

    paymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (paymentCountdown <= 1) {
        timer.cancel();
        paymentExpired = true;

        setState(() {
          paymentCountdown = 0;
          paymentStatus = 'expired';
          paymentError = 'Payment session expired.';
        });

        if (currentReservationId != null) {
          try {
            await api.removeReservation(currentReservationId);
          } catch (e) {
            print('Remove reservation skipped: $e');
          }
        }

        if (!mounted) return;

        setState(() {
          selectedReservation = null;
          currentReservationId = null;
        });
      } else {
        setState(() => paymentCountdown--);
      }
    }
    );
  }

  Future<void> startPayPalPayment() async {
    if (currentReservationId == null || selectedReservation == null) return;

    setState(() {
      paymentStatus = 'processing';
      paymentError = '';
    });

    try {
      final amount = isInstantPayment
          ? parseDouble(selectedReservation?['totalprice'], instantGrandTotal)
          : parseDouble(selectedReservation?['downpaymentamount'], depositAmount);

      final result = await PayPalService.showPayPalPayment(
        context: context,
        reservationId: parseInt(currentReservationId),
        propertyId: propertyIdInt,
        amount: amount,
        currency: 'MYR',
        propertyName: '${propertyDetails?['propertyaddress'] ?? widget.property.name}',
        checkIn: checkIn,
        checkOut: checkOut,
        isInstantPayment: isInstantPayment,
      );

      if (result == null || result['status'] != 'success') {
        paymentTimer?.cancel();

        try {
          await api.removeReservation(currentReservationId);
        } catch (e) {
          print('Remove reservation skipped: $e');
        }

        if (!mounted) return;

        setState(() {
          showPaymentConfirmationPage = false;
          paymentStatus = 'idle';
          paymentError = '';
          selectedReservation = null;
          currentReservationId = null;
        });

        displayToast('error', 'Payment was cancelled. Booking was not added to cart.');
        return;
      }

      paymentTimer?.cancel();

      if (!mounted) return;

      setState(() {
        showPaymentConfirmationPage = false;
        paymentStatus = 'success';
        selectedReservation = null;
        currentReservationId = null;
      });

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      displayToast(
        'success',
        isInstantPayment
            ? 'Payment successful. Booking confirmed!'
            : 'Deposit paid successfully. Booking confirmed!',
      );

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      Navigator.pushNamed(context, '/customer-cart');
    } catch (error) {
      paymentTimer?.cancel();

      try {
        await api.removeReservation(currentReservationId);
      } catch (e) {
        print('Remove reservation skipped: $e');
      }

      if (!mounted) return;

      setState(() {
        showPaymentConfirmationPage = false;
        paymentStatus = 'idle';
        paymentError = '';
        selectedReservation = null;
        currentReservationId = null;
      });

      displayToast('error', 'Payment failed. Booking was not added to cart.');
    }
  }

  Future<void> submitUserReview() async {
    if (!isEligibleToReview || isSubmittingReview) return;
    if (reviewText.trim().isEmpty || subRatings.values.any((rating) => rating <= 0)) {
      displayToast('error', 'Please complete all ratings and review text.');
      return;
    }

    setState(() => isSubmittingReview = true);
    try {
      final userId = await Session.getUserId();
      final username = await Session.getUsername();

      final average = (
        subRatings['location']! +
        subRatings['cleanliness']! +
        subRatings['value']! +
        subRatings['facilities']! +
        subRatings['service']!
      ) ~/ 5;

      await api.submitReview({
        'propertyid': propertyIdInt,
        'userid': userId,
        'rating': average,
        'review': reviewText.trim(),
        'location_rating': subRatings['location'],
        'cleanliness_rating': subRatings['cleanliness'],
        'value_rating': subRatings['value'],
        'facilities_rating': subRatings['facilities'],
        'service_rating': subRatings['service'],
      }, username ?? '');
      displayToast('success', 'Review submitted successfully.');
      setState(() {
        reviewText = '';
        subRatings = {'location': 0, 'cleanliness': 0, 'value': 0, 'facilities': 0, 'service': 0};
      });
      await loadReviews();
    } catch (error) {
      displayToast('error', 'Failed to submit review: $error');
    } finally {
      if (mounted) setState(() => isSubmittingReview = false);
    }
  }

  void openFullscreen(int index, List<String> images) {
    setState(() {
      fullscreenImages = images;
      selectedImageIndex = index;
      isFullscreen = true;
      imageZoom = 1;
    });
  }

  void closeFullscreen() {
    setState(() {
      isFullscreen = false;
      imageZoom = 1;
    });
  }

  List<Map<String, dynamic>> get sortedReviews {
    final list = [...allReviews];
    if (reviewSort == 'highest') {
      list.sort((a, b) => parseDouble(b['rating']).compareTo(parseDouble(a['rating'])));
    } else if (reviewSort == 'lowest') {
      list.sort((a, b) => parseDouble(a['rating']).compareTo(parseDouble(b['rating'])));
    } else {
      list.sort((a, b) => '${b['created_at'] ?? b['reviewdate'] ?? ''}'.compareTo('${a['created_at'] ?? a['reviewdate'] ?? ''}'));
    }
    return list;
  }

  double get averageReviewScore {
    if (allReviews.isEmpty) return 0;
    final total = allReviews.fold<double>(0, (sum, review) => sum + parseDouble(review['rating'], 5));
    return total / allReviews.length;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final isMobile = MediaQuery.of(context).size.width < 780;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _topBar()),
              SliverToBoxAdapter(child: _gallerySection(isMobile)),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 22),
                      child: _mainContent(),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
          if (showToast)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _ToastBox(type: toastType, message: toastMessage),
            ),
          if (isFullscreen) _fullscreenViewer(),
          if (showAuthPrompt) _authPromptOverlay(),
          if (showBookingForm) _bookingFormOverlay(),
          if (showPaymentSelectionPage) _paymentSelectionFullScreen(),
          if (showPaymentConfirmationPage) _paymentConfirmationFullScreen(),
        ],
      ),
      bottomNavigationBar: isMobile &&
              !showPaymentSelectionPage &&
              !showPaymentConfirmationPage &&
              !showBookingForm &&
              !showAuthPrompt &&
              !showBookingBlockedModal
          ? _mobileBookingBar()
          : null,
    );
  }

  Widget _mobileHeader({
    required String title,
    required VoidCallback onBack,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF3D1F0A),
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title == 'Property Details'
                          ? 'View stay details, rooms, reviews and facilities.'
                          : title == 'Payment Summary'
                              ? 'Review your dates, price and availability.'
                              : title == 'Booking Information'
                                  ? 'Fill in your guest details to continue.'
                                  : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12,
                        height: 1.4,
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

  Widget _topBar() {
    return _mobileHeader(
      title: 'Property Details',
      onBack: () => Navigator.pop(context),
    );
  }

  Widget _gallerySection(bool isMobile) {
    final images = propertyImages;
    if (images.isEmpty) {
      return SizedBox(height: isMobile ? 260 : 420, child: _imagePlaceholder());
    }

    if (isMobile) {
      return SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) => setState(() => currentSlide = index),
              itemBuilder: (_, index) => GestureDetector(
                onTap: () => openFullscreen(index, images),
                child: buildPropertyImage(imageUrl: images[index], fit: BoxFit.cover),
              ),
            ),
            Positioned(bottom: 14, right: 14, child: _imageCountBadge(currentSlide + 1, images.length)),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 430,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => openFullscreen(0, images),
                      child: buildPropertyImage(imageUrl: images.first, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _gallerySmall(images, 1)),
                        const SizedBox(height: 8),
                        Expanded(child: _gallerySmall(images, 2, showAllPhotos: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gallerySmall(List<String> images, int index, {bool showAllPhotos = false}) {
    if (index >= images.length) return _imagePlaceholder();
    return GestureDetector(
      onTap: () => openFullscreen(index, images),
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildPropertyImage(imageUrl: images[index], fit: BoxFit.cover),
          if (showAllPhotos)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.photo_library, color: Colors.white, size: 16), SizedBox(width: 6), Text('Show all photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageCountBadge(int current, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(20)),
      child: Text('$current / $total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  Widget _mainContent() {
    final width = MediaQuery.of(context).size.width;
    final titleSize = width < 520 ? 24.0 : 30.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${propertyDetails?['propertyaddress'] ?? widget.property.name}',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _meta(Icons.location_on_rounded, '${propertyDetails?['clustername'] ?? widget.property.clusterName}'),
                  _meta(Icons.bed_rounded, '${propertyDetails?['propertybedtype'] ?? widget.property.bedrooms}'),
                  _meta(Icons.people_rounded, '${propertyDetails?['propertyguestpaxno'] ?? widget.property.guests} Guest'),
                  _meta(Icons.person_pin_rounded, 'Hosted by ${propertyDetails?['username'] ?? 'Unknown Host'}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _aboutSection(),
        const SizedBox(height: 18),
        _checkTimeSection(),
        const SizedBox(height: 18),
        _reviewsSection(),  
        const SizedBox(height: 18),
        _locationSection(),      
        const SizedBox(height: 18),
        _facilitiesSection(),
        if (isJsonInventory) ...[
          const SizedBox(height: 18),
          _roomSelectionSection(),
        ],
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxChipWidth = screenWidth < 520 ? screenWidth - 78 : 360.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _aboutSection() {
    final text = description;
    final isExpanded = expandedRoomDesc['about'] ?? false;

    return SizedBox(
    width: double.infinity,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('About This Place'),

          Text(
            text,
            maxLines: isExpanded ? null : 5, 
            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textSecond,
            ),
          ),

          const SizedBox(height: 6),

          if (text.length > 120)
            GestureDetector(
              onTap: () {
                setState(() {
                  expandedRoomDesc['about'] = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _checkTimeSection() {
    final checkInTime = propertyDetails?['checkintime'] ?? propertyDetails?['check_in_time'] ?? propertyDetails?['propertycheckintime'] ?? '3:00 PM';
    final checkOutTime = propertyDetails?['checkouttime'] ?? propertyDetails?['check_out_time'] ?? propertyDetails?['propertycheckouttime'] ?? '12:00 PM';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Check-in / Check-out Time'),
        Row(
          children: [
            Expanded(child: _timeBox('Check-in', 'From $checkInTime')),
            const SizedBox(width: 10),
            Expanded(child: _timeBox('Check-out', 'Before $checkOutTime')),
          ],
        )
      ]),
    );
  }

  Widget _timeBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _facilitiesSection() {
    final previewList = propertyFacilities.take(6).toList(); 

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('What this place offers'),

          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 4.2,
            ),
            itemBuilder: (_, index) {
              final name = previewList[index];
              return Row(
                children: [
                  Icon(
                    facilityIcons[name] ?? Icons.check_circle_outline,
                    color: const Color(0xFFCC8C18),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if (propertyFacilities.length > 6)
            OutlinedButton(
              onPressed: _showFacilitiesBottomSheet,
              child: Text('More (${propertyFacilities.length})'),
            ),
        ],
      ),
    );
  }

  void _showFacilitiesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'What this place offers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: propertyFacilities.length,
                      separatorBuilder: (_, __) => const Divider(height: 22),
                      itemBuilder: (_, index) {
                        final name = propertyFacilities[index];

                        return Row(
                          children: [
                            Icon(
                              facilityIcons[name] ?? Icons.check_circle_outline,
                              color: const Color(0xFFCC8C18),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
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
          },
        );
      },
    );
  }

  Widget _roomSelectionSection() {
    final count = availableRooms.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: roomSectionKey,
          child: Row(
            children: [
              Expanded(child: _sectionTitle('Available Room Types')),
              Text(
                '$count ${count == 1 ? 'type' : 'types'}',
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        if (count > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swipe_rounded, size: 17, color: AppColors.accent),
                SizedBox(width: 7),
                Text(
                  'Swipe to view more',
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(
          height: 450,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) => _roomCard(availableRooms[index]),
          ),
        ),
      ],
    );
  }

  void _showRoomDescriptionBottomSheet(String title, String description) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        description,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textSecond,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final images = room['images'] is List
        ? List<String>.from((room['images'] as List).map((e) => '$e'))
        : <String>[];

    final options = room['options'] is List ? room['options'] as List : [];
    final selected = bookingData['selectedRoom'];

    final roomName = '${room['name'] ?? 'Room'}';
    final roomDesc = '${room['description'] ?? ''}';

    final standardSelected = selected is Map &&
        selected['baseRoomName'] == room['name'] &&
        selected['isVariation'] == false;

    return Container(
      width: 350,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomCardImageSlider(
            images: images.isNotEmpty ? images : propertyImages,
            height: 185,
            onImageClick: (index, imgs) => openFullscreen(index, imgs),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _miniInfo(Icons.bed, '${room['bedType'] ?? ''}'),
                      _miniInfo(Icons.person, 'Max ${room['maxGuests'] ?? maxPropertyGuests}'),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (roomDesc.trim().isNotEmpty) ...[
                    Text(
                      roomDesc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (roomDesc.length > 90)
                      TextButton(
                        onPressed: () => _showRoomDescriptionBottomSheet(roomName, roomDesc),
                        child: const Text('Read more'),
                      ),
                  ],

                  const SizedBox(height: 8),

                  _rateOption(
                    room: room,
                    title: 'Standard Rate',
                    subtitle: 'Room Only',
                    price: parseDouble(room['price'], selectedBaseRate()),
                    selected: standardSelected,
                    onTap: () => selectRoom(room),
                  ),

                  const SizedBox(height: 8),

                  ...options.map((option) {
                    final opt = Map<String, dynamic>.from(option as Map);
                    final optSelected = selected is Map &&
                        selected['baseRoomName'] == room['name'] &&
                        selected['name'] == opt['name'] &&
                        selected['isVariation'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _rateOption(
                        room: room,
                        option: opt,
                        title: '${opt['name'] ?? 'Package'}',
                        subtitle: '${opt['description'] ?? 'Includes base features'}',
                        price: parseDouble(
                          opt['price'],
                          parseDouble(room['price'], selectedBaseRate()),
                        ),
                        selected: optSelected,
                        onTap: () => selectRoom(room, option: opt),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateOption({
    required Map<String, dynamic> room,
    Map<String, dynamic>? option,
    required String title,
    required String subtitle,
    required double price,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final baseName = '${room['name'] ?? ''}';
    final packageName = option == null ? '' : '${option['name'] ?? ''}';
    final key = getRoomAvailabilityKey(baseName, packageName);

    final shownNightly = roomOptionPriceMap[key] ?? price;
    final availability = roomAvailabilityMap[key];
    final soldOut = availability is Map && availability['soldOut'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isLoadingRoomOptions
                    ? 'Checking...'
                    : 'RM ${shownNightly.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              if (soldOut) ...[
                const SizedBox(height: 4),
                const Text(
                  'Sold Out',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: soldOut
                    ? () => displayToast(
                          'error',
                          option == null
                              ? 'This room is sold out for the selected date.'
                              : 'This room package is sold out for the selected date.',
                        )
                    : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: soldOut
                      ? const Color(0xFFE5E7EB)
                      : selected
                          ? AppColors.primary
                          : AppColors.accent,
                  foregroundColor: soldOut ? const Color(0xFF6B7280) : Colors.white,
                  minimumSize: const Size(84, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  soldOut ? 'Sold Out' : selected ? '✓ Selected' : 'Select',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> openPaymentSelectionPage() async {
    if (isSoldOut || isBlackedOut) return;

    if (isJsonInventory && bookingData['selectedRoom'] == null) {
      displayToast('error', 'Please select a room type from the list to continue.');

      final ctx = roomSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() {
      showPaymentSelectionPage = true;
    });
    unawaited(calculatePriceBreakdownOnly());
    unawaited(loadBlackouts());
    unawaited(loadPropertySoldOutDates());
    unawaited(refreshSelectedRoomAvailabilityOnly());
  }

  Widget _warningBox(String text) {
    return Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDBA74))), child: Text(text, style: const TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.w800, fontSize: 12)));
  }

  Widget _blackoutDateWarningBox() {
    if (!isSelectedRangeBlackedOut()) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB923C)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚫 Selected dates include blackout dates',
            style: TextStyle(
              color: Color(0xFFC2410C),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Please choose another date range.',
            style: TextStyle(
              color: Color(0xFF9A3412),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBox() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isSoldOut ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSoldOut ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0))),
      child: Row(children: [
        Icon(isSoldOut ? Icons.error : Icons.check_circle, color: isSoldOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(bookingData['selectedRoom'] == null ? 'Total Available Rooms' : 'Room Selected', style: TextStyle(color: isSoldOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 13))),
        Text('${roomsLeft ?? 0} ${(roomsLeft ?? 0) == 1 ? 'Room' : 'Rooms'} Left', style: TextStyle(color: isSoldOut ? const Color(0xFFB91C1C) : const Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
    );
  }

  Widget _priceDetails() {
    if (isPriceStillLoading) {
      return _priceLoadingBox();
    }

    if (breakdownData == null || totalNights <= 0) {
      return const SizedBox.shrink();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Price details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      const SizedBox(height: 10),
      _priceRow('RM ${displayNightlyRate.toStringAsFixed(2)} x $totalNights night${totalNights > 1 ? 's' : ''}', 'RM ${roomTotal.toStringAsFixed(2)}'),
      _priceRow('SST (${(globalSstRate * 100).toStringAsFixed(1)}%)', 'RM ${sstAmount.toStringAsFixed(2)}'),
      const Divider(),
      _priceRow('Total (MYR)', 'RM ${finalGrandTotal.toStringAsFixed(2)}', total: true),
      if (instantPaymentRate > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFB923C))),
          child: Column(children: [
            _priceRow('Regular Total', 'RM ${finalGrandTotal.toStringAsFixed(2)}'),
            _priceRow('Instant Pay (${(instantPaymentRate * 100).toStringAsFixed(0)}% off)', 'RM ${instantGrandTotal.toStringAsFixed(2)}', total: true),
            Text('🔥 You save RM ${(finalGrandTotal - instantGrandTotal).toStringAsFixed(2)} with instant pay!', style: const TextStyle(color: Color(0xFFC2410C), fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
      ],
    ]);
  }

  Widget _priceLoadingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D9C5)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.accent,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Calculating latest price...',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Please wait while we check live rates and availability.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecond,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: total ? 16 : 13, fontWeight: total ? FontWeight.w900 : FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: total ? 18 : 13, fontWeight: FontWeight.w900, color: total ? const Color(0xFF007BFF) : const Color(0xFF555555))),
      ]),
    );
  }

  Widget _summaryBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationSection() {
    final address =
        '${propertyDetails?['nearbylocation'] ?? propertyDetails?['propertyaddress'] ?? ''}'.trim();

    final fullAddress = address.toLowerCase().contains('malaysia')
        ? address
        : '$address, Malaysia';

    final mapUrl =
        'https://www.google.com/maps?q=${Uri.encodeComponent(fullAddress)}&output=embed';

    final html = '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          html, body {
            margin: 0;
            padding: 0;
            height: 100%;
            width: 100%;
            overflow: hidden;
          }
          iframe {
            border: 0;
            width: 100%;
            height: 100%;
          }
        </style>
      </head>
      <body>
        <iframe
          src="$mapUrl"
          allowfullscreen
          loading="lazy">
        </iframe>
      </body>
    </html>
    ''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;

            if (url.startsWith('intent://') ||
                url.contains('google.com/maps') ||
                url.contains('maps.google.com')) {
              String launchableUrl = url;

              if (url.startsWith('intent://')) {
                launchableUrl = url
                    .replaceFirst('intent://', 'https://')
                    .split('#Intent')[0];
              }

              final uri = Uri.parse(launchableUrl);

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }

              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(html);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Location'),

          Text(
            address,
            style: const TextStyle(color: Color(0xFF4B5563)),
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsSection() {
    final average = averageReviewScore;
    final score = average * 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.reviews_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guest Reviews',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allReviews.length} ${allReviews.length == 1 ? 'review' : 'reviews'} from guests',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecond,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: reviewSort,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'latest', child: Text('Latest')),
                    DropdownMenuItem(value: 'highest', child: Text('Highest')),
                    DropdownMenuItem(value: 'lowest', child: Text('Lowest')),
                  ],
                  onChanged: (value) => setState(() => reviewSort = value ?? 'latest'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (allReviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_border_rounded, color: AppColors.accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No reviews yet. Be the first guest to share your experience after completing a stay.',
                      style: TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      score.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ratingText(score),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on ${allReviews.length} ${allReviews.length == 1 ? 'review' : 'reviews'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecond,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < average.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ...sortedReviews.take(5).map(_reviewTile),
          ],

          const SizedBox(height: 16),
          _reviewForm(),
        ],
      ),
    );
  }

  String ratingText(double score) {
    if (score >= 9) return 'Exceptional';
    if (score >= 8) return 'Excellent';
    if (score >= 7) return 'Very Good';
    if (score >= 6) return 'Good';
    if (score > 0) return 'Below Expectation';
    return 'No Ratings';
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final guestName = '${review['username'] ?? review['name'] ?? 'Verified Guest'}';
    final initial = guestName.trim().isNotEmpty ? guestName.trim()[0].toUpperCase() : 'G';
    final score = parseDouble(review['rating'], 5) * 2;
    final comment = '${review['review'] ?? review['comment'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surface,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Verified guest',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${score.toStringAsFixed(1)} / 10',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (comment.isNotEmpty)
            Text(
              '"$comment"',
              style: const TextStyle(
                height: 1.55,
                color: AppColors.textSecond,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

          if ('${review['owner_reply'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.accent, width: 4),
                ),
              ),
              child: Text(
                'Response from Host\n${review['owner_reply']}',
                style: const TextStyle(
                  color: AppColors.textSecond,
                  height: 1.45,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewForm() {
    if (reviewState == 'loading') return const SizedBox.shrink();

    if (!isEligibleToReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You can submit a review after completing a paid stay at this property.',
                style: TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (existingReviewId != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF7F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB2DDD0)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF3D7A5C),
              size: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You have already reviewed this property. Thank you for sharing your experience.',
                style: TextStyle(
                  color: Color(0xFF3D7A5C),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rate_review_rounded, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Write a Review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Rate your stay and help future guests make better decisions.',
            style: TextStyle(
              color: AppColors.textSecond,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          ...subRatings.keys.map((key) => _ratingRow(key)),

          const SizedBox(height: 12),

          TextField(
            maxLines: 4,
            onChanged: (value) => reviewText = value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Share details of your experience...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmittingReview ? null : submitUserReview,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(
                isSubmittingReview ? 'Submitting...' : 'Submit Review',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(String key) {
    final labels = {
      'location': 'Location',
      'cleanliness': 'Cleanliness',
      'value': 'Value',
      'facilities': 'Facilities',
      'service': 'Service',
    };

    final label = labels[key] ?? key;
    final rating = subRatings[key] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecond,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(5, (index) {
                final selected = rating >= index + 1;

                return InkWell(
                  onTap: () => setState(() => subRatings[key] = index + 1),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.accent,
                      size: 27,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBookingBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isLoadingBreakdown
                  ? 'Calculating price...'
                  : breakdownData != null
                      ? 'Total RM ${finalGrandTotal.toStringAsFixed(2)}'
                      : 'Select a room',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: ElevatedButton(
              onPressed: isBlackedOut || isSoldOut ? null : openPaymentSelectionPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isBlackedOut ? 'N/A' : isSoldOut ? 'Sold' : 'Book',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _fullscreenViewer() {
    final images = fullscreenImages.isNotEmpty ? fullscreenImages : propertyImages;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: closeFullscreen, icon: const Icon(Icons.close, color: Colors.white)),
            Expanded(child: Center(child: Text('${selectedImageIndex + 1} / ${images.length}', style: const TextStyle(color: Colors.white)))),
            IconButton(onPressed: () => setState(() => imageZoom = math.max(1, imageZoom - 0.25)), icon: const Icon(Icons.remove, color: Colors.white)),
            Text('${(imageZoom * 100).round()}%', style: const TextStyle(color: Colors.white)),
            IconButton(onPressed: () => setState(() => imageZoom = math.min(3, imageZoom + 0.25)), icon: const Icon(Icons.add, color: Colors.white)),
          ]),
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: Center(child: Transform.scale(scale: imageZoom, child: buildPropertyImage(imageUrl: images[selectedImageIndex], fit: BoxFit.contain))),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: selectedImageIndex > 0 ? () => setState(() => selectedImageIndex--) : null, icon: const Icon(Icons.arrow_back_ios, color: Colors.white)),
            IconButton(onPressed: selectedImageIndex < images.length - 1 ? () => setState(() => selectedImageIndex++) : null, icon: const Icon(Icons.arrow_forward_ios, color: Colors.white)),
          ]),
        ]),
      ),
    );
  }

  Widget _authPromptOverlay() {
    return _modalOverlay(
      child: _modalCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 44, color: Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text('Login Required', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Please login before using ${authPromptMode == 'instant' ? 'Instant Pay' : 'Book & Pay'}. If you do not have an account yet, please register first.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('Login to continue'))),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Register an account'))),
          TextButton(onPressed: () => setState(() => showAuthPrompt = false), child: const Text('Cancel')),
        ]),
      ),
    );
  }

  Widget _bookingFormOverlay() {
    return Material(
      color: AppColors.cream,
      child: Column(
        children: [
          _mobileHeader(
            title: 'Booking Information',
            onBack: () {
              setState(() {
                showBookingForm = false;
                showPaymentSelectionPage = true;
              });
            },
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).padding.bottom + 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bookingSummary(),

                        const SizedBox(height: 18),

                        const Text(
                          'Guest details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _safeBookingTitleValue(bookingForm['title']),
                          items: _titleOptions
                              .map(
                                (title) => DropdownMenuItem<String>(
                                  value: title,
                                  child: Text(title),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              bookingForm['title'] = value ?? 'Mr.';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        _input('firstName', 'First Name'),
                        _input('lastName', 'Last Name'),
                        _input(
                          'email',
                          'Email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _input(
                          'phoneNumber',
                          'Phone Number',
                          keyboardType: TextInputType.phone,
                        ),

                        TextField(
                          maxLines: 4,
                          onChanged: (value) {
                            bookingForm['additionalRequests'] = value;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Additional requests',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (paymentFormError.isNotEmpty)
                          Text(
                            paymentFormError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: paymentStatus == 'creating'
                                ? null
                                : submitBookingForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCC8C18),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              paymentStatus == 'creating'
                                  ? 'Processing...'
                                  : 'Proceed to Payment',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${propertyDetails?['propertyaddress'] ?? widget.property.name}', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('$checkIn → $checkOut • $totalNights night(s)'),
        if (bookingData['selectedRoom'] is Map) Text('Room: ${(bookingData['selectedRoom'] as Map)['baseRoomName'] ?? (bookingData['selectedRoom'] as Map)['name']}'),
        const Divider(),
        _priceRow('Room total', 'RM ${roomTotal.toStringAsFixed(2)}'),
        _priceRow('SST', 'RM ${sstAmount.toStringAsFixed(2)}'),
        if (isInstantPayment) ...[
          _priceRow(
            'Instant Pay Discount (${(instantPaymentRate * 100).toStringAsFixed(0)}% off)',
            '- RM ${(finalGrandTotal - instantGrandTotal).toStringAsFixed(2)}',
          ),
          _priceRow(
            'Total After Discount',
            'RM ${instantGrandTotal.toStringAsFixed(2)}',
            total: true,
          ),
          _priceRow(
            'Full payment due now',
            'RM ${depositAmount.toStringAsFixed(2)}',
            total: true,
          ),
        ] else ...[
          _priceRow(
            'Total',
            'RM ${finalGrandTotal.toStringAsFixed(2)}',
            total: true,
          ),
          _priceRow(
            'Deposit (${(globalDepositRate * 100).toStringAsFixed(0)}%)',
            'RM ${depositAmount.toStringAsFixed(2)}',
            total: true,
          ),
        ],
      ]),
    );
  }

  Widget _input(String key, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: '${bookingForm[key] ?? ''}')..selection = TextSelection.collapsed(offset: '${bookingForm[key] ?? ''}'.length),
        keyboardType: keyboardType,
        onChanged: (value) => bookingForm[key] = value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _paymentSelectionFullScreen() {
    final paymentBlocked =
      isSelectedRangeBlackedOut() ||
      isBlackedOut ||
      isSoldOut ||
      isSelectedRoomSoldOutNow();

    final selectedRoomSoldOut = isSelectedRoomSoldOutNow();
    final hasValidDateRange = checkIn.isNotEmpty && checkOut.isNotEmpty && totalNights > 0;
    final buttonLoading = hasValidDateRange && !paymentBlocked && isAvailabilityStillLoading;
    final disabledButtonText = !hasValidDateRange
      ? 'Select dates first'
      : selectedRoomSoldOut
          ? 'Selected room sold out'
          : isSelectedRangeBlackedOut() || isBlackedOut || isSoldOut
              ? 'Unavailable dates'
              : 'Checking availability...';

    return Material(
      color: AppColors.cream,
        child: Column(
          children: [
            _mobileHeader(
              title: 'Payment Summary',
              onBack: () {
                setState(() {
                  showPaymentSelectionPage = false;
                });
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).padding.bottom + 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPriceStillLoading) ...[
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Calculating price...',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ] else
                                Expanded(
                                  child: Text(
                                    'RM ${displayNightlyRate.toStringAsFixed(2)} / night',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => openBlockedDatePicker(
                                    field: 'checkIn',
                                    minDate: getLocalTodayIsoDate(),
                                  ),
                                  child: _summaryBox(
                                    'CHECK-IN',
                                    checkIn.isEmpty ? 'Add date' : formatDisplayDate(checkIn),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => openBlockedDatePicker(
                                    field: 'checkOut',
                                    minDate: checkIn.isEmpty ? getLocalTodayIsoDate() : addDaysToIsoDate(checkIn),
                                    defaultViewDate: checkIn.isEmpty ? '' : addDaysToIsoDate(checkIn),
                                  ),
                                  child: _summaryBox(
                                    'CHECKOUT',
                                    checkOut.isEmpty ? 'Add date' : formatDisplayDate(checkOut),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _blackoutDateWarningBox(),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Text(
                                '$totalNights ${totalNights == 1 ? 'Night' : 'Nights'}',
                                style: const TextStyle(
                                  color: AppColors.textSecond,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$guests Guest${guests > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          if (roomsLeft != null) _stockBox(),

                          const Divider(height: 32),

                          _priceDetails(),

                          const SizedBox(height: 22),

                          if (paymentBlocked) ...[
                            _warningBox(
                              isSelectedRoomSoldOutNow()
                                  ? 'Selected room is sold out. Please choose another room or date.'
                                  : 'Selected dates are unavailable. Please choose another date range.',
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Book and Pay
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: !hasValidDateRange || paymentBlocked || isPriceStillLoading || buttonLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        showPaymentSelectionPage = false;
                                      });
                                      openBookingForm(instantPay: false);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                !hasValidDateRange
                                  ? 'Select dates first'
                                  : paymentBlocked
                                      ? disabledButtonText
                                      : buttonLoading
                                          ? 'Checking availability...'
                                          : 'Book & Pay',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          // Instant Pay button
                          if (instantPaymentRate > 0) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: !hasValidDateRange || paymentBlocked || isPriceStillLoading || buttonLoading
                                    ? null
                                    : () {
                                      setState(() {
                                        showPaymentSelectionPage = false;
                                      });
                                      openBookingForm(instantPay: true);
                                    },
                                icon: const Icon(Icons.payment),
                                label: Text(
                                  !hasValidDateRange
                                    ? 'Select dates first'
                                    : paymentBlocked
                                        ? disabledButtonText
                                        : buttonLoading
                                            ? 'Checking availability...'
                                            : 'Instant Pay (${(instantPaymentRate * 100).toStringAsFixed(0)}% off)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _paymentCountdownBox() {
    final urgent = paymentCountdown <= 60;
    final warning = !urgent && paymentCountdown <= 120;

    final bg = urgent
        ? const Color(0xFFFBECEC)
        : warning
            ? const Color(0xFFFFF8EC)
            : const Color(0xFFEBF7F2);

    final border = urgent
        ? const Color(0xFFEFB8B8)
        : warning
            ? const Color(0xFFE8C56A)
            : const Color(0xFFB2DDD0);

    final color = urgent
        ? const Color(0xFFB83232)
        : warning
            ? const Color(0xFF9A6200)
            : const Color(0xFF3D7A5C);

    final mins = paymentCountdown ~/ 60;
    final secs = paymentCountdown % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              urgent ? '⚠️ Time running out!' : '⏱️ Time to complete payment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B4C30),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2C1A0E),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentConfirmationFullScreen() {
    final paymentBlocked =
        isSelectedRangeBlackedOut() ||
        isBlackedOut ||
        isSoldOut ||
        isSelectedRoomSoldOutNow();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final isSmallPhone = screenWidth < 380;

              return Container(
                width: screenWidth < 560 ? screenWidth - 32 : 520,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.88,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallPhone ? 18 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: isSmallPhone ? 40 : 44,
                            height: isSmallPhone ? 40 : 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFBF8040), Color(0xFF6B3F1A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.payment_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Complete Payment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isSmallPhone ? 17 : 19,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2C1A0E),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: paymentStatus == 'processing'
                                ? null
                                : () async {
                                    paymentTimer?.cancel();

                                    if (currentReservationId != null) {
                                      try {
                                        await api.removeReservation(currentReservationId);
                                      } catch (e) {
                                        print('Remove reservation skipped: $e');
                                      }
                                    }

                                    if (!mounted) return;

                                    setState(() {
                                      showPaymentConfirmationPage = false;
                                      paymentStatus = 'idle';
                                      paymentError = '';
                                      selectedReservation = null;
                                      currentReservationId = null;
                                    });
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EDE0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF6B4C30),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _paymentCountdownBox(),

                      const SizedBox(height: 16),

                      Container(
                        padding: EdgeInsets.all(isSmallPhone ? 14 : 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EDE0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8D9C5)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${propertyDetails?['propertyaddress'] ?? widget.property.name}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2C1A0E),
                                fontSize: isSmallPhone ? 13 : 14,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _summaryRow('Check-in', checkIn),
                            _summaryRow('Check-out', checkOut),

                            const Divider(
                              color: Color(0xFFE8D9C5),
                              height: 18,
                            ),

                            _summaryRow(
                              'Total Amount',
                              'RM ${finalGrandTotal.toStringAsFixed(2)}',
                            ),

                            if (isInstantPayment) ...[
                              _summaryRow(
                                'Instant Discount',
                                '-RM ${(finalGrandTotal - instantGrandTotal).toStringAsFixed(2)}',
                              ),
                              _summaryRow(
                                'Total Due Now',
                                'RM ${instantGrandTotal.toStringAsFixed(2)}',
                              ),
                            ] else ...[
                              _summaryRow(
                                'Deposit Due Now',
                                'RM ${depositAmount.toStringAsFixed(2)}',
                              ),
                              _summaryRow(
                                'Balance Due Later',
                                'RM ${(finalGrandTotal - depositAmount).toStringAsFixed(2)}',
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallPhone ? 12 : 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8C56A)),
                        ),
                        child: CheckboxListTile(
                          value: acceptedTerms,
                          onChanged: paymentStatus == 'processing' ||
                                  paymentStatus == 'expired'
                              ? null
                              : (value) {
                                  setState(() {
                                    acceptedTerms = value ?? false;
                                  });
                                },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            isInstantPayment
                                ? 'I understand that this instant payment is strictly non-refundable. Cancellation is only permitted in cases of unforeseen circumstances. Any refund disputes must be handled directly with the property owner.'
                                : 'I understand that this deposit is strictly non-refundable. I agree to pay the remaining balance before the payment deadline.',
                            textAlign: TextAlign.justify,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: isSmallPhone ? 12 : 13,
                              height: 1.45,
                              color: const Color(0xFF6B3F1A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      if (paymentError.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBECEC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            paymentError,
                            style: const TextStyle(
                              color: Color(0xFFB83232),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payment_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              paymentStatus == 'processing'
                                  ? 'Opening PayPal...'
                                  : paymentStatus == 'expired'
                                      ? 'Session Expired'
                                      : 'Pay with PayPal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B3F1A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: paymentBlocked ||
                                  !acceptedTerms ||
                                  paymentStatus == 'processing' ||
                                  paymentStatus == 'expired'
                              ? null
                              : startPayPalPayment,
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: paymentStatus == 'processing'
                              ? null
                              : () async {
                                  paymentTimer?.cancel();

                                  if (currentReservationId != null) {
                                    try {
                                      await api.removeReservation(currentReservationId);
                                    } catch (e) {
                                      print('Remove reservation skipped: $e');
                                    }
                                  }

                                  if (!mounted) return;

                                  setState(() {
                                    showPaymentConfirmationPage = false;
                                    paymentStatus = 'idle';
                                    paymentError = '';
                                    selectedReservation = null;
                                    currentReservationId = null;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B3F1A),
                            side: const BorderSide(color: Color(0xFFE8D9C5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel & Go Back',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _modalOverlay({required Widget child}) {
    return Container(color: Colors.black.withOpacity(0.55), alignment: Alignment.center, padding: const EdgeInsets.all(16), child: child);
  }

  Widget _modalCard({required Widget child, double maxWidth = 460}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _GuideBox extends StatelessWidget {
  const _GuideBox({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 13, height: 13, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFD1D5DB)))), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))]);
  }
}

class RoomCardImageSlider extends StatefulWidget {
  const RoomCardImageSlider({super.key, required this.images, required this.onImageClick, this.height = 200});
  final List<String> images;
  final void Function(int index, List<String> images) onImageClick;
  final double height;

  @override
  State<RoomCardImageSlider> createState() => _RoomCardImageSliderState();
}

class _RoomCardImageSliderState extends State<RoomCardImageSlider> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final displayImages = widget.images.isNotEmpty ? widget.images : [''];
    return SizedBox(
      height: widget.height,
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(onTap: () => widget.onImageClick(currentIndex, displayImages), child: buildPropertyImage(imageUrl: displayImages[currentIndex], fit: BoxFit.cover)),
        Positioned(bottom: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.zoom_in, color: Colors.white, size: 14), SizedBox(width: 4), Text('Click to view more', style: TextStyle(color: Colors.white, fontSize: 12))]))),
        if (displayImages.length > 1 && currentIndex > 0) Positioned(left: 4, top: widget.height / 2 - 12, child: _sliderButton(Icons.chevron_left, () => setState(() => currentIndex--))),
        if (displayImages.length > 1 && currentIndex < displayImages.length - 1) Positioned(right: 4, top: widget.height / 2 - 12, child: _sliderButton(Icons.chevron_right, () => setState(() => currentIndex++))),
        if (displayImages.length > 1) Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10)), child: Text('${currentIndex + 1}/${displayImages.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))),
      ]),
    );
  }

  Widget _sliderButton(IconData icon, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]), child: Icon(icon, size: 16)));
  }
}

Widget buildPropertyImage({String? imageUrl, Uint8List? imageBytes, BoxFit fit = BoxFit.cover, double? height}) {
  if (imageBytes != null) return Image.memory(imageBytes, width: double.infinity, height: height, fit: fit);
  final source = '${imageUrl ?? ''}'.trim();
  if (source.isEmpty) return _imagePlaceholder(height: height);
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(source, width: double.infinity, height: height, fit: fit, errorBuilder: (_, __, ___) => _imagePlaceholder(height: height));
  }
  try {
    final clean = source.startsWith('data:image') ? source.split(',').last : source;
    return Image.memory(base64Decode(clean), width: double.infinity, height: height, fit: fit);
  } catch (_) {
    return _imagePlaceholder(height: height);
  }
}

Widget _imagePlaceholder({double? height}) {
  return Container(height: height, width: double.infinity, color: const Color(0xFFE2E8F0), alignment: Alignment.center, child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8), size: 40));
}

class _ToastBox extends StatelessWidget {
  const _ToastBox({required this.type, required this.message});
  final String type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = type == 'error' ? const Color(0xFFDC2626) : type == 'success' ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    return Material(elevation: 8, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))));
  }
}