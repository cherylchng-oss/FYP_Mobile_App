import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api.dart' as api;
import '../shared/pre_customer_layout.dart';
import '../shared/colors.dart';

// ─────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────
class AppColors {
  static const primary = AdminColors.primary;
  static const primaryLight = AdminColors.primaryLight;
  static const accent = AdminColors.accent;
  static const accentLight = AdminColors.accentLight;
  static const cream = AdminColors.cream;
  static const surface = AdminColors.surface;
  static const border = AdminColors.border;
  static const textPrimary = AdminColors.textPrimary;
  static const textSecond = AdminColors.textSecond;
  static const textMuted = AdminColors.textMuted;
  static const cardBg = AdminColors.cardBg;
}

// ─────────────────────────────────────────────
// Property Model
// ─────────────────────────────────────────────
class Property {
  final String id;
  final String name;
  final String location;
  final String categoryName;
  final String bedrooms;
  final int guests;
  final double pricePerNight;
  final List<String> imageUrls;
  final List<Uint8List?> imageBytes;
  final List<String> amenities;
  final double rating;
  final int ratingNo;

  Property({
    required this.id,
    required this.name,
    required this.location,
    required this.categoryName,
    required this.bedrooms,
    required this.guests,
    required this.pricePerNight,
    required this.imageUrls,
    required this.imageBytes,
    required this.amenities,
    required this.rating,
    required this.ratingNo,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    final images = getSafePropertyImages(json);
    final bytes = images.map((img) => imageBytesFromSource(img)).toList();

    return Property(
      id: '${json['propertyid'] ?? json['id'] ?? ''}',
      name: '${json['propertyaddress'] ?? json['propertyname'] ?? 'Unnamed Property'}',
      location: '${json['clustername'] ?? json['nearbylocation'] ?? 'Sarawak'}',
      categoryName: '${json['categoryname'] ?? ''}',
      bedrooms: '${json['propertybedtype'] ?? ''}',
      guests: toInt(json['propertyguestpaxno'], 1),
      pricePerNight: toNumber(json['normalrate'], 0),
      imageUrls: images,
      imageBytes: bytes,
      amenities: '${json['facilities'] ?? ''}'
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(3)
          .toList(),
      rating: toNumber(
        json['rating'] ?? json['live_rating'] ?? json['averagerating'],
        0,
      ),
      ratingNo: toInt(
        json['ratingno'] ??
            json['live_ratingno'] ??
            json['reviewcount'] ??
            json['review_count'],
        0,
      ),
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

List<String> getSafePropertyImages(Map<String, dynamic> property) {
  final images = property['propertyimage'] ?? property['images'] ?? property['image'];

  if (images is List) {
    return images
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  if (images is String && images.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(images);
      if (parsed is List) {
        return parsed
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList();
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

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return null;
    }

    if (clean.startsWith('data:image')) {
      clean = clean.split(',').last;
    }

    return base64Decode(clean);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────
// Main Before Login Rooms Page
// ─────────────────────────────────────────────
class CustomerRoomsNotLogin extends StatefulWidget {
  const CustomerRoomsNotLogin({super.key});

  @override
  State<CustomerRoomsNotLogin> createState() => _CustomerRoomsNotLoginState();
}

class _CustomerRoomsNotLoginState extends State<CustomerRoomsNotLogin> {
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  String? errorMessage;

  List<Property> properties = [];

  int page = 1;
  final int itemsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final dynamic response = await api.fetchProduct();

      final rawList = response is List
          ? response
          : response is Map
              ? (response['data'] ??
                  response['properties'] ??
                  response['products'] ??
                  response['product'] ??
                  [])
              : [];

      final loaded = <Property>[];

      for (final item in rawList) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);

        final status = '${map['propertystatus'] ?? ''}'.toLowerCase().trim();
        if (status.isNotEmpty && status != 'available') continue;

        final id = '${map['propertyid'] ?? map['id'] ?? ''}';
        if (id.isEmpty) continue;

        loaded.add(Property.fromJson(map));
      }

      if (!mounted) return;

      setState(() {
        properties = loaded;
        page = 1;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load properties. Please try again.';
        isLoading = false;
      });
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: const Text(
          'Login Required',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Please login to proceed with booking.',
          style: TextStyle(
            color: AppColors.textSecond,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    pageWidgets.add(
      _pageButton(
        Icons.chevron_left_rounded,
        page > 1 ? () => handlePageChange(page - 1) : null,
      ),
    );

    if (startPage > 1) {
      pageWidgets.add(_numberButton(1));

      if (startPage > 2) {
        pageWidgets.add(_dots());
      }
    }

    for (int p = startPage; p <= endPage; p++) {
      pageWidgets.add(_numberButton(p));
    }

    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pageWidgets.add(_dots());
      }

      pageWidgets.add(_numberButton(totalPages));
    }

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
        child: Icon(
          icon,
          size: 22,
          color: onTap != null ? AppColors.primaryLight : AppColors.border,
        ),
      ),
    );
  }

  int get totalPages => (properties.length / itemsPerPage).ceil();

  List<Property> get currentProperties {
    final start = (page - 1) * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, properties.length);

    if (start >= properties.length) return [];

    return properties.sublist(start, end);
  }

  void handlePageChange(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;

    setState(() => page = newPage);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PreCustomerLayout(
      selectedIndex: 0,
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProperties,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildRoomsHeader(MediaQuery.of(context).padding.top),
            ),

            SliverToBoxAdapter(
              child: _buildHeaderSection(),
            ),

            if (isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: _skeletonGrid(),
              )
            else if (errorMessage != null)
              SliverToBoxAdapter(
                child: _errorState(),
              )
            else if (properties.isEmpty)
              SliverToBoxAdapter(
                child: _emptyState(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: _propertiesGrid(),
              ),
              SliverToBoxAdapter(
                child: _paginationControls(),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildRoomsHeader(double topPad) {
    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/customer_stay.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3D1E0C),
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                    ),
                  ),
                );
              },
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.bed_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Property Listings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse stays across Sarawak.\nLogin to book your stay.',
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

                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${properties.length} properties',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  color: AppColors.accent,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'Preview Mode',
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _propertiesGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 520;

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return PropertyCardNotLogin(
            property: currentProperties[index],
            onBookNow: _showLoginRequiredDialog,
          );
        },
        childCount: currentProperties.length,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 520 : 360,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isMobile ? 0.86 : 0.82,
      ),
    );
  }

  SliverGrid _skeletonGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 520;

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => const SkeletonPropertyCard(),
        childCount: 6,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 520 : 360,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isMobile ? 0.86 : 0.82,
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.textMuted,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadProperties,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: AppColors.textMuted,
              size: 38,
            ),
            SizedBox(height: 14),
            Text(
              'No properties found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Property Card
// ─────────────────────────────────────────────
class PropertyCardNotLogin extends StatefulWidget {
  const PropertyCardNotLogin({
    super.key,
    required this.property,
    required this.onBookNow,
  });

  final Property property;
  final VoidCallback onBookNow;

  @override
  State<PropertyCardNotLogin> createState() => _PropertyCardNotLoginState();
}

class _PropertyCardNotLoginState extends State<PropertyCardNotLogin> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final hasReviews =
        widget.property.ratingNo > 0 && widget.property.rating > 0;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: widget.property.imageUrls.isNotEmpty
                ? ImageSliderFlutter(
                    images: widget.property.imageUrls,
                    imageBytes: widget.property.imageBytes,
                    currentIndex: currentIndex,
                    onChanged: (index) {
                      setState(() => currentIndex = index);
                    },
                  )
                : _noImagePlaceholder(),
          ),

          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: hasReviews
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.property.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: widget.onBookNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Book Now',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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

  Widget _noImagePlaceholder() {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_rounded,
        color: AppColors.border,
        size: 34,
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
    required this.imageBytes,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<String> images;
  final List<Uint8List?> imageBytes;
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
          itemBuilder: (context, index) {
            return buildPropertyImage(
              imageUrl: images[index],
              imageBytes: index < imageBytes.length ? imageBytes[index] : null,
              fit: BoxFit.cover,
            );
          },
        ),

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
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.35),
                ],
              ),
            ),
          ),
        ),

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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
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
    return Image.memory(
      imageBytes,
      width: double.infinity,
      height: height,
      fit: fit,
    );
  }

  final source = imageUrl?.trim() ?? '';

  if (source.isEmpty) {
    return _imagePlaceholder(height: height);
  }

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

    if (clean.startsWith('data:image')) {
      clean = clean.split(',').last;
    }

    return Image.memory(
      base64Decode(clean),
      width: double.infinity,
      height: height,
      fit: fit,
    );
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
    child: const Icon(
      Icons.image_not_supported_rounded,
      color: AppColors.border,
      size: 32,
    ),
  );
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
          Expanded(
            flex: 6,
            child: Container(color: const Color(0xFFF0E8DE)),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(height: 16, width: double.infinity),
                  const SizedBox(height: 8),
                  _shimmerBox(height: 12, width: 140),
                  const SizedBox(height: 10),
                  _shimmerBox(height: 28, width: 180),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _shimmerBox(height: 36, width: 110),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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