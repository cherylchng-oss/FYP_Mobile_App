import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api.dart' as api;
import 'rooms_detail.dart';
import '../shared/customer_layout.dart';

// ─────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────
class AppColors {
  static const primary      = Color(0xFF6B3F1A);
  static const primaryLight = Color(0xFF8B5E3C); 
  static const accent       = Color(0xFFBF8040); 
  static const accentLight  = Color(0xFFE8B97A);
  static const cream        = Color(0xFFFAF6F0); 
  static const cardBg       = Color(0xFFFFFFFF);
  static const surface      = Color(0xFFF5EDE0); 
  static const border       = Color(0xFFE8D9C5);
  static const textPrimary  = Color(0xFF2C1A0E); 
  static const textSecond   = Color(0xFF6B4C30); 
  static const textMuted    = Color(0xFFA07850);
  static const success      = Color(0xFF3D7A5C);
  static const danger       = Color(0xFFB83232);
  static const drawerBg     = Color(0xFF2C1A0E);
  static const drawerAccent = Color(0xFF8B5E3C);
}

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────
class BookingData {
  BookingData({
    this.checkIn = '',
    this.checkOut = '',
    this.adults = 1,
    this.children = 0,
  });

  String checkIn;
  String checkOut;
  int adults;
  int children;

  int get totalGuests => adults + children;
}

class Property {
  Property({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerNight,
    required this.guests,
    required this.bedrooms,
    required this.categoryName,
    required this.clusterName,
    required this.imageUrls,
    required this.imageBytes,
    required this.amenities,
    required this.rating,
    required this.ratingNo,
    required this.raw,
  });

  final String id;
  final String name;
  final String description;
  final double pricePerNight;
  final int guests;
  final String bedrooms;
  final String categoryName;
  final String clusterName;
  final List<String> imageUrls;
  final List<Uint8List?> imageBytes;
  final List<String> amenities;
  final double rating;
  final int ratingNo;
  final Map<String, dynamic> raw;

  factory Property.fromJson(Map<String, dynamic> json) {
    final images = getSafePropertyImages(json);
    final imageBytes = images.map((img) => imageBytesFromSource(img)).toList();

    return Property(
      id: '${json['propertyid'] ?? json['id'] ?? ''}',
      name: '${json['propertyaddress'] ?? json['propertyname'] ?? 'Unnamed Property'}',
      description: '${json['propertydescription'] ?? ''}',
      pricePerNight: toNumber(json['normalrate'], 0),
      guests: toInt(json['propertyguestpaxno'], 1),
      bedrooms: '${json['propertybedtype'] ?? ''}',
      categoryName: '${json['categoryname'] ?? ''}',
      clusterName: '${json['clustername'] ?? ''}',
      imageUrls: images,
      imageBytes: imageBytes,
      amenities: '${json['facilities'] ?? ''}'
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      rating: toNumber(json['rating'] ?? json['live_rating'] ?? json['averagerating'], 0),
      ratingNo: toInt(json['ratingno'] ?? json['live_ratingno'] ?? json['reviewcount'] ?? json['review_count'], 0),
      raw: json,
    );
  }
}

// ─────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────
double toNumber(dynamic value, [double fallback = 0]) {
  final parsed = double.tryParse('${value ?? ''}');
  return parsed != null && parsed.isFinite ? parsed : fallback;
}

int toInt(dynamic value, [int fallback = 0]) {
  final parsed = int.tryParse('${value ?? ''}');
  return parsed ?? fallback;
}

String normalizeText(dynamic value) {
  return '${value ?? ''}'.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeReservationStatus(dynamic status) {
  return '${status ?? ''}'
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

int getNights(String checkIn, String checkOut) {
  if (checkIn.isEmpty || checkOut.isEmpty) return 1;
  final start = DateTime.tryParse(checkIn);
  final end = DateTime.tryParse(checkOut);
  if (start == null || end == null) return 1;
  final diff = end.difference(start).inDays;
  return diff > 0 ? diff : 1;
}

String todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String addOneDay(String dateValue) {
  if (dateValue.isEmpty) return '';
  final date = DateTime.tryParse(dateValue);
  if (date == null) return '';
  final next = date.add(const Duration(days: 1));
  return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
}

String formatDisplayDate(String value) {
  if (value.isEmpty) return 'dd/mm/yyyy';
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

List<String> getSafePropertyImages(Map<String, dynamic> property) {
  final images = property['propertyimage'];
  if (images is List) {
    return images.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList();
  }
  if (images is String && images.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(images);
      if (parsed is List) {
        return parsed.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList();
      }
    } catch (_) {
      return [images];
    }
    return [images];
  }
  return [];
}

Uint8List? imageBytesFromSource(String source) {
  try {
    var clean = source.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) return null;
    if (clean.startsWith('data:image')) {
      clean = clean.split(',').last;
    }
    return base64Decode(clean);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> getPropertyReviewDisplay(Map<String, dynamic> property) {
  final rating = toNumber(property['rating'] ?? property['live_rating'] ?? property['averagerating'], 0);
  final ratingNo = toInt(property['ratingno'] ?? property['live_ratingno'] ?? property['reviewcount'] ?? property['review_count'], 0);

  String ratingText;
  if (rating == rating.roundToDouble()) {
    ratingText = rating.toStringAsFixed(1);
  } else {
    ratingText = rating.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  return {
    'hasReviews': ratingNo > 0 && rating > 0,
    'ratingText': ratingText,
  };
}

List<Map<String, dynamic>> parsePropertyRooms(Map<String, dynamic> prop) {
  final isHotel = ['Hotel', 'Resort', 'Inn', 'Hostel'].contains(prop['categoryname']);
  dynamic rawSetup = prop['room_details'] ?? prop['roomsetup'] ?? '';

  if (rawSetup is String && rawSetup.contains('_ROOMDATA_')) {
    rawSetup = rawSetup.split('_ROOMDATA_')[1];
  }

  final rooms = <Map<String, dynamic>>[];

  try {
    if (rawSetup is List) {
      rooms.addAll(rawSetup.map((item) => Map<String, dynamic>.from(item as Map)));
    } else if (rawSetup is String && rawSetup.trim().startsWith('[')) {
      final parsed = jsonDecode(rawSetup);
      if (parsed is List) {
        rooms.addAll(parsed.map((item) => Map<String, dynamic>.from(item as Map)));
      }
    }
  } catch (_) {}

  if (isHotel && rooms.isNotEmpty) return rooms;

  return [
    {
      'name': prop['propertybedtype'] ?? prop['propertyaddress'] ?? 'Whole Property',
      'quantity': prop['quantity'] ?? prop['propertyquantity'] ?? 1,
      'options': [],
    }
  ];
}

int getRoomQuantity(Map<String, dynamic> room, [Map<String, dynamic>? option]) {
  final optionQty = toInt(option?['quantity'] ?? option?['qty'], 0);
  if (optionQty > 0) return optionQty;
  final roomQty = toInt(room['quantity'] ?? room['qty'], 0);
  if (roomQty > 0) return roomQty;
  return 1;
}

Map<String, String> extractBookedRoomInfo(Map<String, dynamic> booking) {
  final rawText = '${booking['request'] ?? booking['reservationrequest'] ?? booking['additionalrequests'] ?? booking['reservation_request'] ?? ''}';
  final roomReg = RegExp(r'Room Selected:\s*([^\n\r(]+)', caseSensitive: false);
  final packageReg = RegExp(r'\(Package:\s*([^)]+)\)', caseSensitive: false);

  final roomMatch = roomReg.firstMatch(rawText);
  final packageMatch = packageReg.firstMatch(rawText);

  return {
    'roomName': normalizeText(roomMatch?.group(1) ?? rawText),
    'packageName': normalizeText(packageMatch?.group(1) ?? ''),
    'rawText': normalizeText(rawText),
  };
}

bool shouldHoldRoomStock(Map<String, dynamic> reservation) {
  final status = normalizeReservationStatus(reservation['reservationstatus']);
  return status == 'paid' || status == 'partially paid';
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
  final bookedRoomName = booked['roomName'] ?? '';
  final rawText = booked['rawText'] ?? '';
  final bookedPackageName = booked['packageName'] ?? '';

  final sameRoom = bookedRoomName == baseName || rawText.contains('room selected: $baseName');
  if (!sameRoom) return false;

  if (pkgName.isNotEmpty) {
    return bookedPackageName == pkgName;
  }
  return bookedPackageName.isEmpty;
}

int countUniqueMatchingBookings(
  List<dynamic> bookings,
  String baseRoomName,
  String packageName,
) {
  final ids = <String>{};
  for (var i = 0; i < bookings.length; i++) {
    final booking = Map<String, dynamic>.from(bookings[i] as Map);
    if (!shouldHoldRoomStock(booking)) continue;
    if (bookingMatchesRoomAndPackage(booking, baseRoomName, packageName)) {
      ids.add('${booking['reservationid'] ?? booking['id'] ?? '${booking['request'] ?? booking['reservationrequest'] ?? ''}-$i'}');
    }
  }
  return ids.length;
}

double getLowestPropertyRate(Map<String, dynamic> prop) {
  var lowestBaseRate = toNumber(prop['normalrate'], 0);
  final isHotel = ['Hotel', 'Resort', 'Inn', 'Hostel'].contains(prop['categoryname']);

  if (isHotel) {
    final parsedRooms = parsePropertyRooms(prop);
    if (parsedRooms.isNotEmpty) {
      var tempLowest = double.infinity;
      for (final room in parsedRooms) {
        final roomPrice = toNumber(room['price'], double.nan);
        if (roomPrice.isFinite && roomPrice > 0 && roomPrice < tempLowest) {
          tempLowest = roomPrice;
        }
        final options = room['options'];
        if (options is List) {
          for (final option in options) {
            final optionPrice = toNumber((option as Map)['price'], double.nan);
            if (optionPrice.isFinite && optionPrice > 0 && optionPrice < tempLowest) {
              tempLowest = optionPrice;
            }
          }
        }
      }
      if (tempLowest != double.infinity) {
        lowestBaseRate = tempLowest;
      }
    }
  }

  return lowestBaseRate.isFinite && lowestBaseRate > 0 ? lowestBaseRate : 0;
}

// ─────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────
class CustomerRoomsPage extends StatefulWidget {
  const CustomerRoomsPage({
    super.key,
    this.filterRegion = '',
    this.initialCheckIn = '',
    this.initialCheckOut = '',
    this.initialAdults = 1,
    this.initialChildren = 0,
  });

  final String filterRegion;
  final String initialCheckIn;
  final String initialCheckOut;
  final int initialAdults;
  final int initialChildren;

  @override
  State<CustomerRoomsPage> createState() => _CustomerRoomsPageState();
}

class _CustomerRoomsPageState extends State<CustomerRoomsPage> {
  final ScrollController _scrollController = ScrollController();

  Timer? toastTimer;

  final clusters = const [
    'Kuching', 'Miri', 'Sibu', 'Bintulu', 'Limbang', 'Sarikei', 'Sri Aman',
    'Kapit', 'Mukah', 'Betong', 'Samarahan', 'Serian', 'Lundu', 'Lawas',
    'Marudi', 'Simunjan', 'Tatau', 'Belaga', 'Debak', 'Kabong', 'Pusa',
    'Sebuyau', 'Saratok', 'Selangau', 'Tebedu',
  ];

  String selectedCluster = '';
  String propertyCategory = 'All';
  String activeTab = '';
  String sortOrder = 'none';

  BookingData bookingData = BookingData();
  Map<String, String> lastSearchDates = {'checkIn': '', 'checkOut': ''};

  bool isLoading = true;
  bool showFilters = false;
  bool hasSearchedWithDates = false;
  bool isCalculatingPrices = false;

  String toastMessage = '';
  String toastType = 'info';
  bool showToast = false;

  List<Map<String, dynamic>> fetchedProperties = [];
  List<Map<String, dynamic>> allProperties = [];

  Map<int, Map<String, dynamic>> dynamicPrices = {};
  Map<int, Map<String, dynamic>> isDateOverlapping = {};

  RangeValues priceRange = const RangeValues(0, 10000);
  List<String> selectedFacilities = [];
  List<String> selectedPropertyTypes = [];
  List<String> selectedBookingOptions = [];

  RangeValues tempPriceRange = const RangeValues(0, 10000);
  List<String> tempSelectedFacilities = [];
  List<String> tempSelectedPropertyTypes = [];
  String tempSortOrder = 'none';

  int page = 1;
  final int itemsPerPage = 8;

  @override
  void initState() {
    super.initState();

    selectedCluster = widget.filterRegion;
    bookingData = BookingData(
      checkIn: widget.initialCheckIn,
      checkOut: widget.initialCheckOut,
      adults: widget.initialAdults,
      children: widget.initialChildren,
    );
    _loadProperties();

    if (widget.filterRegion.isNotEmpty && (bookingData.checkIn.isEmpty || bookingData.checkOut.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        displayToast('info', 'Looking for stays in ${widget.filterRegion}? Pick your dates first!');
        setState(() => activeTab = 'checkin');
      });
    }
  }

  @override
  void dispose() {
    toastTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadProperties() async {
    setState(() => isLoading = true);
    try {
      final response = await api.fetchProduct();
      final array = response is List
          ? response
          : response is Map
              ? (response['data'] ?? response['properties'] ?? [])
              : [];

      fetchedProperties = List<Map<String, dynamic>>.from(
        array.map((item) => Map<String, dynamic>.from(item as Map)),
      );

      _applyDefaultFilters();

      if (bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) handleCheckAvailability();
        });
      }
    } catch (error) {
      displayToast('error', 'Failed to load properties');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyDefaultFilters() {
    if (hasSearchedWithDates) return;

    var availableOnly = fetchedProperties.where((prop) => prop['propertystatus'] == 'Available').toList();

    if (propertyCategory == 'Hotel') {
      availableOnly = availableOnly.where((p) => ['Hotel', 'Resort', 'Hostel'].contains(p['categoryname'])).toList();
    } else if (propertyCategory == 'Homestay') {
      availableOnly = availableOnly.where((p) => ['Homestay', 'Lodge', 'Guesthouse', 'Apartment'].contains(p['categoryname'])).toList();
    } else if (propertyCategory == 'Inn') {
      availableOnly = availableOnly.where((p) => p['categoryname'] == 'Inn').toList();
    }

    if (selectedCluster.isNotEmpty) {
      availableOnly = availableOnly.where((p) => p['clustername'] == selectedCluster).toList();
    }

    availableOnly.sort((a, b) => toInt(b['propertyid']).compareTo(toInt(a['propertyid'])));

    setState(() {
      allProperties = availableOnly;
      page = 1;
    });
  }

  Future<void> handleCheckAvailability([String? overrideCluster]) async {
    if (bookingData.checkIn.isEmpty || bookingData.checkOut.isEmpty) {
      displayToast('error', 'Please select Check-in and Check-out dates to see accurate prices.');
      setState(() => activeTab = 'checkin');
      return;
    }

    final targetCluster = overrideCluster ?? selectedCluster;
    final totalGuests = bookingData.totalGuests;

    try {
      var availableProperties = fetchedProperties.where((property) {
        if (property['propertystatus'] != 'Available') return false;
        final propertyPrice = toNumber(property['normalrate'], 0);
        if (propertyPrice < priceRange.start || propertyPrice > priceRange.end) return false;
        if (toInt(property['propertyguestpaxno'], 0) < totalGuests) return false;
        if (targetCluster.isNotEmpty && property['clustername'] != targetCluster) return false;
        if (selectedPropertyTypes.isNotEmpty && !selectedPropertyTypes.contains('${property['categoryname']}')) return false;
        if (propertyCategory == 'Hotel' && !['Hotel', 'Resort', 'Hostel'].contains(property['categoryname'])) return false;
        if (propertyCategory == 'Homestay' && !['Homestay', 'Lodge', 'Guesthouse', 'Apartment'].contains(property['categoryname'])) return false;
        if (propertyCategory == 'Inn' && property['categoryname'] != 'Inn') return false;
        if (selectedFacilities.isNotEmpty) {
          final propertyFacilities = '${property['facilities'] ?? ''}'
              .split(',')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList();
          for (final facility in selectedFacilities) {
            if (!propertyFacilities.contains(facility)) return false;
          }
        }
        return true;
      }).toList();

      if (sortOrder == 'asc') {
        availableProperties.sort((a, b) => toNumber(a['normalrate']).compareTo(toNumber(b['normalrate'])));
      } else if (sortOrder == 'desc') {
        availableProperties.sort((a, b) => toNumber(b['normalrate']).compareTo(toNumber(a['normalrate'])));
      } else {
        availableProperties.sort((a, b) => toInt(b['propertyid']).compareTo(toInt(a['propertyid'])));
      }

      if (bookingData.checkIn != lastSearchDates['checkIn'] || bookingData.checkOut != lastSearchDates['checkOut']) {
        dynamicPrices.clear();
        isDateOverlapping.clear();
        lastSearchDates = {'checkIn': bookingData.checkIn, 'checkOut': bookingData.checkOut};
      }

      setState(() {
        allProperties = availableProperties;
        page = 1;
        showFilters = false;
        hasSearchedWithDates = true;
        activeTab = '';
      });

      await _fetchPricesAndAvailabilityForPage();
    } catch (error) {
      displayToast('error', 'Failed to filter properties');
    }
  }

  Future<Map<String, dynamic>> checkPropertyAllRoomsSoldOut(
    Map<String, dynamic> prop,
    String checkIn,
    String checkOut,
  ) async {
    final propId = toInt(prop['propertyid'], 0);
    if (propId <= 0 || checkIn.isEmpty || checkOut.isEmpty) {
      return {'soldOut': false, 'lowStock': false, 'roomsLeft': null};
    }

    final rooms = parsePropertyRooms(prop);
    final roomChecks = <Map<String, dynamic>>[];

    for (final room in rooms) {
      final baseRoomName = '${room['name'] ?? prop['propertybedtype'] ?? 'Whole Property'}';
      final options = room['options'];

      if (options is List && options.isNotEmpty) {
        for (final option in options) {
          final opt = Map<String, dynamic>.from(option as Map);
          roomChecks.add({
            'baseRoomName': baseRoomName,
            'packageName': '${opt['name'] ?? ''}',
            'totalQty': getRoomQuantity(room, opt),
          });
        }
      } else {
        roomChecks.add({
          'baseRoomName': baseRoomName,
          'packageName': '',
          'totalQty': getRoomQuantity(room),
        });
      }
    }

    if (roomChecks.isEmpty) {
      return {'soldOut': false, 'lowStock': false, 'roomsLeft': null};
    }

    final results = <Map<String, dynamic>>[];

    for (final roomCheck in roomChecks) {
      try {
        final data = await api.fetchPropertyAvailability(
          propertyId: propId,
          checkIn: checkIn,
          checkOut: checkOut,
          roomName: '${roomCheck['baseRoomName'] ?? ''}',
          packageName: '${roomCheck['packageName'] ?? ''}',
        );

        final bookings = data is Map ? (data['bookings'] ?? []) : [];
        final bookedCount = countUniqueMatchingBookings(
          bookings is List ? bookings : [],
          '${roomCheck['baseRoomName']}',
          '${roomCheck['packageName']}',
        );

        final left = (roomCheck['totalQty'] as int) - bookedCount;
        results.add({
          ...roomCheck,
          'bookedCount': bookedCount,
          'left': left < 0 ? 0 : left,
          'soldOut': left <= 0,
        });
      } catch (_) {
        results.add({
          ...roomCheck,
          'bookedCount': 0,
          'left': roomCheck['totalQty'],
          'soldOut': false,
        });
      }
    }

    final totalRoomsLeft = results.fold<int>(0, (sum, item) => sum + toInt(item['left'], 0));
    final allSoldOut = results.every((item) => item['soldOut'] == true);

    return {
      'soldOut': allSoldOut,
      'lowStock': !allSoldOut && totalRoomsLeft == 1,
      'roomsLeft': totalRoomsLeft,
      'roomResults': results,
    };
  }

  Future<void> _fetchPricesAndAvailabilityForPage() async {
    if (!hasSearchedWithDates || currentProperties.isEmpty) return;

    final newPrices = Map<int, Map<String, dynamic>>.from(dynamicPrices);
    final newOverlaps = Map<int, Map<String, dynamic>>.from(isDateOverlapping);

    final propsToFetch = currentProperties.where((prop) {
      final id = toInt(prop['propertyid'], 0);
      return !newPrices.containsKey(id) || !newOverlaps.containsKey(id);
    }).toList();

    if (propsToFetch.isEmpty) return;

    setState(() => isCalculatingPrices = true);

    for (final prop in propsToFetch) {
      final propId = toInt(prop['propertyid'], 0);

      if (!newPrices.containsKey(propId)) {
        final lowestBaseRate = getLowestPropertyRate(prop);
        final nights = getNights(bookingData.checkIn, bookingData.checkOut);
        var averageNightly = lowestBaseRate;

        try {
          final res = await api.calculateBookingPrice(
            bookingData.checkIn,
            bookingData.checkOut,
            lowestBaseRate,
            propId,
          );

          final totalPrice = toNumber(res['totalPrice'] ?? res['total_price'] ?? res['total'] ?? res['price'], lowestBaseRate * nights);
          final totalNights = toNumber(res['totalNights'] ?? res['total_nights'] ?? res['nights'], nights.toDouble());

          averageNightly = totalNights > 0 ? totalPrice / totalNights : lowestBaseRate;
        } catch (_) {
          averageNightly = lowestBaseRate;
        }

        if (!averageNightly.isFinite || averageNightly <= 0) averageNightly = lowestBaseRate;

        newPrices[propId] = {
          'price': averageNightly,
          'originalBase': lowestBaseRate,
          'isDiscounted': averageNightly < lowestBaseRate,
          'isPeak': averageNightly > lowestBaseRate,
          'discountPercent': averageNightly < lowestBaseRate && lowestBaseRate > 0
              ? (((lowestBaseRate - averageNightly) / lowestBaseRate) * 100).round()
              : 0,
        };
      }

      if (!newOverlaps.containsKey(propId)) {
        try {
          final overlapData = await api.checkDateOverlap(
            propertyId: propId,
            checkIn: bookingData.checkIn,
            checkOut: bookingData.checkOut,
          );

          if (overlapData['isBlackout'] == true) {
            newOverlaps[propId] = {
              'soldOut': true,
              'lowStock': false,
              'roomsLeft': 0,
            };
          } else {
            final availabilityResult = await checkPropertyAllRoomsSoldOut(
              prop,
              bookingData.checkIn,
              bookingData.checkOut,
            );

            newOverlaps[propId] = {
              'soldOut': availabilityResult['soldOut'] == true,
              'lowStock': availabilityResult['lowStock'] == true,
              'roomsLeft': availabilityResult['roomsLeft'],
              'roomResults': availabilityResult['roomResults'] ?? [],
            };
          }
        } catch (_) {
          newOverlaps[propId] = {
            'soldOut': false,
            'lowStock': false,
            'roomsLeft': null,
          };
        }
      }
    }

    final unavailablePropertyIds = newOverlaps.entries
        .where((entry) => entry.value['soldOut'] == true)
        .map((entry) => '${entry.key}')
        .toSet();

    setState(() {
      allProperties = allProperties.where((property) => !unavailablePropertyIds.contains('${property['propertyid']}')).toList();
      dynamicPrices = newPrices;
      isDateOverlapping = newOverlaps;
      isCalculatingPrices = false;
    });
  }

  void resetFilters() {
    setState(() {
      tempSortOrder = 'none';
      tempPriceRange = const RangeValues(0, 10000);
      tempSelectedFacilities = [];
      tempSelectedPropertyTypes = [];

      sortOrder = 'none';
      priceRange = const RangeValues(0, 10000);
      selectedFacilities = [];
      selectedPropertyTypes = [];
      showFilters = false;
    });

    onSortOrFilterChanged();
  }

  void applyFilters() {
    setState(() {
      sortOrder = tempSortOrder;
      priceRange = tempPriceRange;
      selectedFacilities = List.from(tempSelectedFacilities);
      selectedPropertyTypes = List.from(tempSelectedPropertyTypes);
      showFilters = false;
    });

    onSortOrFilterChanged();
  }

  void handleViewDetails(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailPage(
          property: Property.fromJson(property),
          initialCheckIn: bookingData.checkIn,
          initialCheckOut: bookingData.checkOut,
          initialGuests: bookingData.totalGuests,
          filterRegion: selectedCluster,
        ),
      ),
    ).then((_) {
      if (bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
        handleCheckAvailability();
      }
    });
  }

  void clearDates() {
    setState(() {
      bookingData.checkIn = '';
      bookingData.checkOut = '';
      hasSearchedWithDates = false;
      isDateOverlapping = {};
      dynamicPrices = {};
      lastSearchDates = {'checkIn': '', 'checkOut': ''};
      activeTab = '';
    });
    _applyDefaultFilters();
    displayToast('info', 'Dates cleared. Showing all availability.');
  }

  void handleInputChange(String name, String value) {
    setState(() {
      if (name == 'checkIn') {
        bookingData.checkIn = value;
        if (bookingData.checkOut.isNotEmpty) {
          final checkInDate = DateTime.tryParse(value);
          final checkOutDate = DateTime.tryParse(bookingData.checkOut);
          if (checkInDate != null && checkOutDate != null && !checkInDate.isBefore(checkOutDate)) {
            bookingData.checkOut = '';
          }
        }
        activeTab = 'checkout';
      } else if (name == 'checkOut') {
        bookingData.checkOut = value;
        activeTab = 'guests';
      }
    });
  }

  void handlePageChange(int newPage) {
    final total = totalPages;
    if (newPage < 1 || newPage > total) return;
    setState(() => page = newPage);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
    _fetchPricesAndAvailabilityForPage();
  }

  List<Map<String, dynamic>> get safeProperties => allProperties;
  int get totalPages => (safeProperties.length / itemsPerPage).ceil();
  List<Map<String, dynamic>> get currentProperties {
    final start = (page - 1) * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, safeProperties.length);
    if (start >= safeProperties.length) return [];
    return safeProperties.sublist(start, end);
  }

  void onCategoryChanged(String type) {
    setState(() => propertyCategory = type);
    if (hasSearchedWithDates && bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
      handleCheckAvailability();
    } else {
      _applyDefaultFilters();
    }
  }

  void onClusterChanged(String cluster) {
    setState(() {
      selectedCluster = cluster;
      activeTab = '';
    });
    if (hasSearchedWithDates && bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
      handleCheckAvailability(cluster);
    } else {
      _applyDefaultFilters();
    }
  }

  void onSortOrFilterChanged() {
    if (hasSearchedWithDates && bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
      handleCheckAvailability();
    } else {
      _applyDefaultFilters();
    }
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 1,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await _loadProperties();

              if (bookingData.checkIn.isNotEmpty && bookingData.checkOut.isNotEmpty) {
                await handleCheckAvailability();
              }
            },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Hero App Bar ──
                  SliverAppBar(
                    expandedHeight: 140,
                    collapsedHeight: kToolbarHeight,
                    toolbarHeight: kToolbarHeight,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: AppColors.primary,
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
                            Container(color: AppColors.primary),

                            Opacity(
                              opacity: 0.06,
                              child: CustomPaint(painter: _BatikPatternPainter()),
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
                                            color: AppColors.accentLight.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.accentLight.withOpacity(0.4),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.home_work_rounded,
                                            color: AppColors.accentLight,
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
                                      'Find your perfect stay',
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
                                      'Discover authentic Sarawak hospitality',
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
                                        Icons.bed_rounded,
                                        color: AppColors.accentLight,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Rooms',
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

                  // ── Search Bar (floating over content) ──
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -1),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: renderSearchSection(),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: _headerSection()),

                  if (isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: _skeletonGrid(),
                    )
                  else if (!hasSearchedWithDates)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: _propertiesGrid(showDynamicPrice: false),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: _propertiesGrid(showDynamicPrice: true),
                    ),

                  SliverToBoxAdapter(child: _paginationControls()),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
            
            // Toast
            if (showToast)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: _ToastBox(type: toastType, message: toastMessage),
              ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Search Section
  // ──────────────────────────────────────────
  Widget renderSearchSection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              if (isCompact) {
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _searchItem(
                        'location',
                        'WHERE',
                        Icons.location_on_rounded,
                        selectedCluster.isEmpty ? 'Search destinations' : selectedCluster,
                      ),
                    ),
                    _searchDividerH(),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: _searchItem(
                        'checkin',
                        'CHECK IN',
                        Icons.calendar_month_rounded,
                        bookingData.checkIn.isEmpty ? 'Select date' : formatDisplayDate(bookingData.checkIn),
                      ),
                    ),
                    _searchDividerH(),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: _searchItem(
                        'checkout',
                        'CHECK OUT',
                        Icons.calendar_month_rounded,
                        bookingData.checkOut.isEmpty ? 'Select date' : formatDisplayDate(bookingData.checkOut),
                      ),
                    ),
                    _searchDividerH(),

                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _searchItem(
                              'guests',
                              'GUESTS',
                              Icons.people_rounded,
                              '${bookingData.adults} adults · ${bookingData.children} children',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _searchButton(),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _searchItem('location', 'WHERE', Icons.location_on_rounded,
                      selectedCluster.isEmpty ? 'Search destinations' : selectedCluster)),
                  _searchDividerV(),
                  Expanded(child: _searchItem('checkin', 'CHECK IN', Icons.calendar_month_rounded,
                      bookingData.checkIn.isEmpty ? 'Select date' : formatDisplayDate(bookingData.checkIn))),
                  _searchDividerV(),
                  Expanded(child: _searchItem('checkout', 'CHECK OUT', Icons.calendar_month_rounded,
                      bookingData.checkOut.isEmpty ? 'Select date' : formatDisplayDate(bookingData.checkOut))),
                  _searchDividerV(),
                  Expanded(flex: 2, child: _searchItem('guests', 'GUESTS', Icons.people_rounded,
                      '${bookingData.adults} adults · ${bookingData.children} children')),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _searchButton(),
                  ),
                ],
              );
            },
          ),
        ),
        if (activeTab.isNotEmpty) _searchDropdown(),
      ],
    );
  }

  Widget _searchItem(String tab, String label, IconData icon, String value) {
    final active = activeTab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (tab == 'checkout' && bookingData.checkIn.isEmpty) {
          displayToast('error', 'Please select check-in date first.');
          setState(() => activeTab = 'checkin');
          return;
        }
        setState(() => activeTab = active ? '' : tab);
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0)),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value.contains('Select') || value.contains('dd/') || value.contains('Search')
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: handleCheckAvailability,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.search_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _searchDividerV() => Container(width: 1, height: 32, color: AppColors.border);
  Widget _searchDividerH() => Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.border);

  Widget _searchDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        if (activeTab == 'location') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.explore_rounded, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Explore destinations',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              _clusterSelector(),
            ],
          );
        }

        if (activeTab == 'checkin') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdownHeader('Select check-in date'),
              const SizedBox(height: 12),
              CustomProductCalendar(
                value: bookingData.checkIn,
                minDate: todayIso(),
                onChange: (value) => handleInputChange('checkIn', value),
              ),
            ],
          );
        }

        if (activeTab == 'checkout') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdownHeader('Select check-out date'),
              const SizedBox(height: 12),
              CustomProductCalendar(
                value: bookingData.checkOut,
                minDate: bookingData.checkIn.isNotEmpty ? addOneDay(bookingData.checkIn) : todayIso(),
                defaultViewDate: bookingData.checkIn.isNotEmpty ? addOneDay(bookingData.checkIn) : '',
                onChange: (value) => handleInputChange('checkOut', value),
              ),
            ],
          );
        }

        return _guestSelector();
      }),
    );
  }

  Widget _dropdownHeader(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        if (bookingData.checkIn.isNotEmpty || bookingData.checkOut.isNotEmpty)
          TextButton(
            onPressed: clearDates,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Clear Dates', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _clusterSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _clusterChip('All Areas', selectedCluster.isEmpty, () => onClusterChanged('')),
        ...clusters.map((cluster) =>
            _clusterChip(cluster, selectedCluster == cluster, () => onClusterChanged(cluster))),
      ],
    );
  }

  Widget _clusterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecond,
          ),
        ),
      ),
    );
  }

  Widget _guestSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.people_rounded, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text("Who's coming?",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 16),
        _guestRow(
          title: 'Adults',
          subtitle: 'Ages 13 and above',
          value: bookingData.adults,
          onMinus: () => setState(() => bookingData.adults = bookingData.adults > 1 ? bookingData.adults - 1 : 1),
          onPlus: () => setState(() => bookingData.adults++),
        ),
        Divider(color: AppColors.border, height: 24),
        _guestRow(
          title: 'Children',
          subtitle: 'Ages 2–12',
          value: bookingData.children,
          onMinus: () => setState(() => bookingData.children = bookingData.children > 0 ? bookingData.children - 1 : 0),
          onPlus: () => setState(() => bookingData.children++),
        ),
      ],
    );
  }

  Widget _guestRow({
    required String title,
    required String subtitle,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        _counterButton(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 44,
          child: Center(
            child: Text('$value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
        ),
        _counterButton(Icons.add_rounded, onPlus),
      ],
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
          color: AppColors.surface,
        ),
        child: Icon(icon, size: 18, color: AppColors.primaryLight),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Header Section
  // ──────────────────────────────────────────
  Widget _headerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;

          final categoryRow = _categoryButtons();
          final filterBtn = _sortingFilterButton();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${safeProperties.length} properties',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (selectedCluster.isNotEmpty)
                            Text(
                              'in $selectedCluster',
                              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    filterBtn,
                  ],
                ),
                const SizedBox(height: 12),
                categoryRow,
                if (showFilters) _filtersPanel(),
              ],
            );
          }

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${safeProperties.length} properties available',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (selectedCluster.isNotEmpty)
                          Text('in $selectedCluster',
                              style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  categoryRow,
                  const SizedBox(width: 12),
                  filterBtn,
                ],
              ),
              if (showFilters) _filtersPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryButtons() {
    final types = ['All', 'Hotel', 'Homestay', 'Inn'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final selected = propertyCategory == type;
        return InkWell(
          onTap: () => onCategoryChanged(type),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]
                  : [],
            ),
            child: Text(
              type == 'All' ? 'All Types' : '${type}s',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecond,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sortingFilterButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            tempPriceRange = priceRange;
            tempSelectedFacilities = List.from(selectedFacilities);
            tempSelectedPropertyTypes = List.from(selectedPropertyTypes);
            tempSortOrder = sortOrder;
            showFilters = !showFilters;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 18, color: showFilters ? AppColors.accent : AppColors.textSecond),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: showFilters ? AppColors.accent : AppColors.textSecond,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersPanel() {
    final facilities = ['Wi-Fi', 'Kitchen', 'Washer', 'Air Conditioning', 'TV', 'Free Parking', 'Swimming Pool', 'Breakfast'];
    final propertyTypes = ['Hotel', 'Resort', 'Hostel', 'Homestay', 'Lodge', 'Guesthouse', 'Apartment', 'Inn'];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterSectionTitle('Sort by Price'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('Default', tempSortOrder == 'none', () => setState(() => tempSortOrder = 'none')),
              _filterChip('Low → High', tempSortOrder == 'asc', () => setState(() => tempSortOrder = 'asc')),
              _filterChip('High → Low', tempSortOrder == 'desc', () => setState(() => tempSortOrder = 'desc')),
            ],
          ),
          const SizedBox(height: 18),
          _filterSectionTitle('Price Range: RM ${tempPriceRange.start.round()} – RM ${tempPriceRange.end.round()}'),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.accent.withOpacity(0.15),
            ),
            child: RangeSlider(
              values: tempPriceRange,
              min: 0,
              max: 10000,
              divisions: 100,
              labels: RangeLabels(
                'RM ${tempPriceRange.start.round()}',
                'RM ${tempPriceRange.end.round()}',
              ),
              onChanged: (value) => setState(() => tempPriceRange = value),
            ),
          ),
          const SizedBox(height: 14),
          _filterSectionTitle('Facilities'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: facilities.map((f) {
            final selected = tempSelectedFacilities.contains(f);
            return _filterChip(f, selected, () {
              setState(() {
                selected ? tempSelectedFacilities.remove(f) : tempSelectedFacilities.add(f);
              });
            });
            }).toList(),
          ),
          const SizedBox(height: 14),
          _filterSectionTitle('Property Types'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: propertyTypes.map((t) {
              final selected = tempSelectedPropertyTypes.contains(t);
              return _filterChip(t, selected, () {
                setState(() {
                  selected ? tempSelectedPropertyTypes.remove(t) : tempSelectedPropertyTypes.add(t);
                });
              });
            }).toList(),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: resetFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _filterSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary));
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecond,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Grids
  // ──────────────────────────────────────────
  SliverGrid _skeletonGrid() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => const SkeletonPropertyCard(),
        childCount: 8,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: MediaQuery.of(context).size.width < 520 ? 520 : 360,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: MediaQuery.of(context).size.width < 520 ? 0.86 : 0.82,
      ),
    );
  }

  Widget _propertiesGrid({required bool showDynamicPrice}) {
    if (currentProperties.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _emptyState(),
        ),
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final property = currentProperties[index];
          return PropertyCard(
            property: property,
            showDynamicPrice: showDynamicPrice,
            pricingInfo: dynamicPrices[toInt(property['propertyid'])],
            availability: isDateOverlapping[toInt(property['propertyid'])] ??
                {'soldOut': false, 'lowStock': false, 'roomsLeft': null},
            hasSearchedWithDates: hasSearchedWithDates,
            isCalculatingPrices: isCalculatingPrices,
            onTap: () => handleViewDetails(property),
            onSelectDates: () => setState(() => activeTab = 'checkin'),
          );
        },
        childCount: currentProperties.length,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: MediaQuery.of(context).size.width < 520 ? 520 : 360,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: MediaQuery.of(context).size.width < 520 ? 0.84 : 0.78,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No properties found',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Try adjusting your filters or location to see more results.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Pagination
  // ──────────────────────────────────────────
  Widget _paginationControls() {
    if (totalPages <= 1) return const SizedBox.shrink();

    const int maxVisiblePages = 4;
    final pageWidgets = <Widget>[];

    int startPage = 1;
    int endPage = totalPages;

    if (totalPages > maxVisiblePages) {
      if (page <= 3) {
        startPage = 1;
        endPage = maxVisiblePages;
      } else if (page >= totalPages - 2) {
        startPage = totalPages - maxVisiblePages + 1;
        endPage = totalPages;
      } else {
        startPage = page - 2;
        endPage = page + 2;
      }
    }

    // LEFT BUTTON
    pageWidgets.add(
      _pageButton(
        Icons.chevron_left_rounded,
        page > 1 ? () => handlePageChange(page - 1) : null,
      ),
    );

    // FIRST PAGE + ...
    if (startPage > 1) {
      pageWidgets.add(_numberButton(1));

      if (startPage > 2) {
        pageWidgets.add(_dots());
      }
    }

    // MIDDLE PAGES
    for (int p = startPage; p <= endPage; p++) {
      pageWidgets.add(_numberButton(p));
    }

    // ... + LAST PAGE
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pageWidgets.add(_dots());
      }

      pageWidgets.add(_numberButton(totalPages));
    }

    // RIGHT BUTTON
    pageWidgets.add(
      _pageButton(
        Icons.chevron_right_rounded,
        page < totalPages ? () => handlePageChange(page + 1) : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: pageWidgets,
      ),
    );
  }

  Widget _numberButton(int pageNumber) {
    final selected = pageNumber == page;

    return InkWell(
      onTap: selected ? null : () => handlePageChange(pageNumber),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          '$pageNumber',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecond,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return const SizedBox(
      width: 24,
      height: 38,
      child: Center(
        child: Text(
          '...',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onTap) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: onTap != null ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Icon(icon,
            size: 22,
            color: onTap != null ? AppColors.primaryLight : AppColors.border),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Property Card
// ─────────────────────────────────────────────
class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.showDynamicPrice,
    required this.pricingInfo,
    required this.availability,
    required this.hasSearchedWithDates,
    required this.isCalculatingPrices,
    required this.onTap,
    required this.onSelectDates,
  });

  final Map<String, dynamic> property;
  final bool showDynamicPrice;
  final Map<String, dynamic>? pricingInfo;
  final Map<String, dynamic> availability;
  final bool hasSearchedWithDates;
  final bool isCalculatingPrices;
  final VoidCallback onTap;
  final VoidCallback onSelectDates;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = getSafePropertyImages(widget.property);
    final reviewDisplay = getPropertyReviewDisplay(widget.property);
    final isHotel = ['Hotel', 'Resort', 'Inn', 'Hostel'].contains(widget.property['categoryname']);
    final fallbackRate = getLowestPropertyRate(widget.property);
    final dynPrice = widget.pricingInfo != null ? toNumber(widget.pricingInfo!['price'], fallbackRate) : fallbackRate;
    final basePrice = widget.pricingInfo != null ? toNumber(widget.pricingInfo!['originalBase'], fallbackRate) : fallbackRate;
    final isDiscounted = widget.pricingInfo?['isDiscounted'] == true;
    final isPeak = widget.pricingInfo?['isPeak'] == true;
    final discountPercent = toInt(widget.pricingInfo?['discountPercent'], 0);
    final isSoldOut = widget.hasSearchedWithDates ? widget.availability['soldOut'] == true : false;
    final isLowStock = widget.hasSearchedWithDates ? widget.availability['lowStock'] == true : false;
    final roomsLeft = widget.availability['roomsLeft'];

    return InkWell(
      onTap: isSoldOut ? null : widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Opacity(
        opacity: isSoldOut ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
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
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image area
                  Expanded(
                    flex: 6,
                    child: images.isNotEmpty
                        ? ImageSliderFlutter(
                            images: images,
                            currentIndex: currentIndex,
                            onChanged: (i) => setState(() => currentIndex = i),
                          )
                        : _noImagePlaceholder(),
                  ),

                  // Content area
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, 
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + Rating
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${widget.property['propertyaddress'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (reviewDisplay['hasReviews'] == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${reviewDisplay['ratingText']}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('New',
                                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Location
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${widget.property['clustername'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Price section
                          if (!widget.showDynamicPrice)
                            SizedBox(
                              width: double.infinity,
                              child: InkWell(
                                onTap: widget.onSelectDates,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(color: AppColors.accent, width: 1.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Select dates to see price',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isHotel ? 'Starts from / night' : 'Per night',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 2),
                                  if (widget.isCalculatingPrices && widget.pricingInfo == null)
                                    const Text('Calculating...',
                                        style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                                  else ...[
                                    if (isDiscounted)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'RM ${basePrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.danger.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              '-$discountPercent%',
                                              style: const TextStyle(
                                                  color: AppColors.danger,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (isPeak)
                                      const Text('📈 High demand',
                                          style: TextStyle(
                                              color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                                    Text(
                                      dynPrice > 0 ? 'RM ${dynPrice.toStringAsFixed(2)}' : 'Select dates',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary),
                                    ),
                                    if (roomsLeft != null && !isSoldOut)
                                      Text(
                                        '$roomsLeft ${roomsLeft == 1 ? 'room' : 'rooms'} left',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isLowStock ? AppColors.danger : AppColors.success,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                  ),
                ],
              ),

              // Badges
              if (isDiscounted && !isSoldOut)
                _badge('Limited Offer', AppColors.danger, left: 10, top: 10),
              if (isPeak && !isSoldOut)
                _badge('High Demand', AppColors.accent, left: 10, top: 10),
              if (isLowStock && !isSoldOut)
                _badge('🔥 1 room left', AppColors.danger, right: 10, top: 10),

              // Sold out overlay
              if (isSoldOut)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Sold Out',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noImagePlaceholder() {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_rounded, color: AppColors.border, size: 32),
          const SizedBox(height: 6),
          Text('No image', style: TextStyle(color: AppColors.border, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {double? left, double? right, double top = 10}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6)],
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Image Slider
// ─────────────────────────────────────────────
class ImageSliderFlutter extends StatelessWidget {
  const ImageSliderFlutter({
    super.key,
    required this.images,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<String> images;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (context, index) => buildPropertyImage(imageUrl: images[index], fit: BoxFit.cover),
        ),
        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
              ),
            ),
          ),
        ),
        // Page counter
        if (images.length > 1)
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${currentIndex + 1} / ${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

Widget buildPropertyImage({
  String? imageUrl,
  Uint8List? imageBytes,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageBytes != null) {
    return Image.memory(imageBytes, width: double.infinity, height: height, fit: fit);
  }

  final source = imageUrl?.trim() ?? '';
  if (source.isEmpty) return _imagePlaceholder(height: height);

  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(
      source,
      width: double.infinity,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _imagePlaceholder(height: height),
    );
  }

  try {
    var clean = source;
    if (clean.startsWith('data:image')) clean = clean.split(',').last;
    return Image.memory(base64Decode(clean), width: double.infinity, height: height, fit: fit);
  } catch (_) {
    return _imagePlaceholder(height: height);
  }
}

Widget _imagePlaceholder({double? height}) {
  return Container(
    height: height,
    width: double.infinity,
    color: AppColors.surface,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_rounded, color: AppColors.border, size: 32),
  );
}

// ─────────────────────────────────────────────
// Calendar
// ─────────────────────────────────────────────
class CustomProductCalendar extends StatefulWidget {
  const CustomProductCalendar({
    super.key,
    required this.value,
    required this.onChange,
    required this.minDate,
    this.defaultViewDate = '',
  });

  final String value;
  final ValueChanged<String> onChange;
  final String minDate;
  final String defaultViewDate;

  @override
  State<CustomProductCalendar> createState() => _CustomProductCalendarState();
}

class _CustomProductCalendarState extends State<CustomProductCalendar> {
  late int viewYear;
  late int viewMonth;

  final monthNames = const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final dayNames = const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void initState() {
    super.initState();
    final initial = getInitialDate();
    viewYear = initial.year;
    viewMonth = initial.month - 1;
  }

  @override
  void didUpdateWidget(covariant CustomProductCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.defaultViewDate != widget.defaultViewDate ||
        oldWidget.minDate != widget.minDate) {
      final date = getInitialDate();
      viewYear = date.year;
      viewMonth = date.month - 1;
    }
  }

  DateTime getInitialDate() {
    final dateToUse = widget.value.isNotEmpty
        ? widget.value
        : widget.defaultViewDate.isNotEmpty
            ? widget.defaultViewDate
            : widget.minDate;
    final date = DateTime.tryParse(dateToUse);
    return date ?? DateTime.now();
  }

  String formatDate(int year, int month, int day) {
    return '$year-${(month + 1).toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> getCalendarDays() {
    final firstDay = DateTime(viewYear, viewMonth + 1, 1).weekday % 7;
    final daysInMonth = DateTime(viewYear, viewMonth + 2, 0).day;
    final prevMonthDays = DateTime(viewYear, viewMonth + 1, 0).day;
    final days = <Map<String, dynamic>>[];

    for (int i = firstDay - 1; i >= 0; i--) {
      days.add({'day': prevMonthDays - i, 'type': 'prev'});
    }
    for (int day = 1; day <= daysInMonth; day++) {
      days.add({'day': day, 'type': 'current', 'date': formatDate(viewYear, viewMonth, day)});
    }
    final nextDaysNeeded = 42 - days.length;
    for (int day = 1; day <= nextDaysNeeded; day++) {
      days.add({'day': day, 'type': 'next'});
    }
    return days;
  }

  void goPrevMonth() {
    setState(() {
      if (viewMonth == 0) { viewMonth = 11; viewYear--; } else { viewMonth--; }
    });
  }

  void goNextMonth() {
    setState(() {
      if (viewMonth == 11) { viewMonth = 0; viewYear++; } else { viewMonth++; }
    });
  }

  bool isDisabled(String? dateValue) {
    if (dateValue == null || dateValue.isEmpty || widget.minDate.isEmpty) return false;
    final currentDate = DateTime.tryParse(dateValue);
    final minimumDate = DateTime.tryParse(widget.minDate);
    if (currentDate == null || minimumDate == null) return false;
    return currentDate.isBefore(minimumDate);
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = getCalendarDays();

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month nav
          Row(
            children: [
              _calNavBtn(Icons.chevron_left_rounded, goPrevMonth),
              Expanded(
                child: Center(
                  child: Text(
                    '${monthNames[viewMonth]} $viewYear',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 15),
                  ),
                ),
              ),
              _calNavBtn(Icons.chevron_right_rounded, goNextMonth),
            ],
          ),
          const SizedBox(height: 8),
          // Day headers
          Row(
            children: dayNames
                .map((day) => Expanded(
                      child: Center(
                        child: Text(day,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final item = calendarDays[index];
              final disabled = item['type'] != 'current' || isDisabled(item['date']);
              final selected = item['date'] == widget.value;

              return InkWell(
                onTap: disabled ? null : () => widget.onChange(item['date']),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item['day']}',
                    style: TextStyle(
                      color: disabled
                          ? AppColors.border
                          : selected
                              ? Colors.white
                              : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _calNavBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryLight),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Skeleton Card
// ─────────────────────────────────────────────
class SkeletonPropertyCard extends StatelessWidget {
  const SkeletonPropertyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(flex: 6, child: _shimmer()),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(height: 16, width: double.infinity),
                  const SizedBox(height: 8),
                  _shimmerBox(height: 12, width: 120),
                  const Spacer(),
                  Align(alignment: Alignment.centerRight, child: _shimmerBox(height: 32, width: 130)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer() => Container(color: const Color(0xFFF0E8DE));

  Widget _shimmerBox({double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8DE),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Toast
// ─────────────────────────────────────────────
class _ToastBox extends StatelessWidget {
  const _ToastBox({required this.type, required this.message});

  final String type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isError = type == 'error';
    final isSuccess = type == 'success';

    final color = isError
        ? AppColors.danger
        : isSuccess
            ? AppColors.success
            : AppColors.primaryLight;

    final icon = isError
        ? Icons.error_outline_rounded
        : isSuccess
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      shadowColor: color.withOpacity(0.3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Decorative Batik Pattern Painter
// ─────────────────────────────────────────────
class _BatikPatternPainter extends CustomPainter {
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