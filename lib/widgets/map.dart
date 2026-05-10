import 'package:flutter/material.dart';

class SarawakMapSection extends StatefulWidget {
  const SarawakMapSection({
    super.key,
    this.onRegionSelected,
  });

  final ValueChanged<String>? onRegionSelected;

  @override
  State<SarawakMapSection> createState() => _SarawakMapSectionState();
}

class _SarawakMapSectionState extends State<SarawakMapSection> {
  late SarawakRegion selectedRegion;

  final SarawakRegion defaultRegion = const SarawakRegion(
    name: 'Welcome to Sarawak',
    description:
        'Welcome to Sarawak, a land of diverse cultures, breathtaking landscapes, and rich history. Explore the map to discover more about each region.',
    image: 'assets/WaterFront.jpeg',
    x: 0,
    y: 0,
    isDefault: true,
  );

  final List<SarawakRegion> regions = const [
    SarawakRegion(
      name: 'Kuching',
      description:
          'Kuching, the vibrant capital of Sarawak, is a unique blend of culture, history and nature. Explore its scenic waterfront, rich heritage, and delicious cuisine.',
      image: 'assets/Cat City.webp',
      x: 70,
      y: 680,
    ),
    SarawakRegion(
      name: 'Serian',
      description:
          'Serian is a peaceful town in Sarawak, offering a glimpse into rural Borneo life, lush landscapes, and traditional markets.',
      image: 'assets/Serian.webp',
      x: 220,
      y: 820,
    ),
    SarawakRegion(
      name: 'Samarahan',
      description:
          'Samarahan blends modern development with traditional charm. It is known for educational institutions and vibrant markets.',
      image: 'assets/Samarahan.jpg',
      x: 280,
      y: 760,
    ),
    SarawakRegion(
      name: 'Sri Aman',
      description:
          'Sri Aman is a peaceful town by the Batang Lupar River, known for its natural beauty and the Pesta Benak festival.',
      image: 'assets/Sri Aman.jpg',
      x: 380,
      y: 760,
    ),
    SarawakRegion(
      name: 'Betong',
      description:
          'Betong is a peaceful town known for natural beauty and rich cultural heritage.',
      image: 'assets/Betong.jpg',
      x: 370,
      y: 675,
    ),
    SarawakRegion(
      name: 'Sarikei',
      description:
          'Sarikei, often known as the Town of Fruits, is renowned for agriculture and vibrant fruit markets.',
      image: 'assets/Sarikei.jpg',
      x: 450,
      y: 625,
    ),
    SarawakRegion(
      name: 'Sibu',
      description:
          'Sibu is located along the Rajang River and is known for riverside charm, vibrant markets, local food, and cultural heritage.',
      image: 'assets/Sibu.jpg',
      x: 500,
      y: 540,
    ),
    SarawakRegion(
      name: 'Mukah',
      description:
          'Mukah is the cultural heartland of the Melanau people, known for sago production and traditional Melanau villages.',
      image: 'assets/Mukah.jpg',
      x: 500,
      y: 440,
    ),
    SarawakRegion(
      name: 'Bintulu',
      description:
          'Bintulu is a bustling coastal town known for energy industries, Similajau National Park, markets, and local cuisine.',
      image: 'assets/Bintulu.webp',
      x: 750,
      y: 420,
    ),
    SarawakRegion(
      name: 'Kapit',
      description:
          'Kapit is a hidden gem deep in Sarawak, accessible by the mighty Rajang River.',
      image: 'assets/Kapit.jpg',
      x: 850,
      y: 625,
    ),
    SarawakRegion(
      name: 'Miri',
      description:
          'Miri is a vibrant resort city and gateway to breathtaking national parks and cultural experiences.',
      image: 'assets/Miri.jpg',
      x: 1050,
      y: 285,
    ),
    SarawakRegion(
      name: 'Limbang',
      description:
          'Limbang is nestled between Brunei territories and is known for its unique location and cultural diversity.',
      image: 'assets/Limbang.jpg',
      x: 1150,
      y: 120,
    ),
  ];

  @override
  void initState() {
    super.initState();
    selectedRegion = defaultRegion;
  }

  void selectRegion(SarawakRegion region) {
    setState(() => selectedRegion = region);
    widget.onRegionSelected?.call(region.name);
  }

  void goToRooms() {
    if (selectedRegion.isDefault) return;

    Navigator.pushNamed(
      context,
      '/customer-rooms',
      arguments: {
        'filterRegion': selectedRegion.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 768;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 10 : 22,
            isMobile ? 20 : 0,
            isMobile ? 10 : 22,
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: isMobile ? 0 : 44,
                    child: _MapPanel(
                      regions: regions,
                      selectedRegion: selectedRegion,
                      onSelected: selectRegion,
                    ),
                  ),
                  SizedBox(width: isMobile ? 0 : 34, height: isMobile ? 24 : 0),
                  Expanded(
                    flex: isMobile ? 0 : 44,
                    child: _InfoCard(
                      region: selectedRegion,
                      onPressed: goToRooms,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.regions,
    required this.selectedRegion,
    required this.onSelected,
  });

  final List<SarawakRegion> regions;
  final SarawakRegion selectedRegion;
  final ValueChanged<SarawakRegion> onSelected;

  static const double viewBoxWidth = 1320;
  static const double viewBoxHeight = 870;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

        final mapWidth = isMobile
            ? screenWidth - 32
            : constraints.maxWidth.clamp(520.0, 900.0);

        final mapHeight = mapWidth * (viewBoxHeight / viewBoxWidth);

        return Center(
          child: SizedBox(
            width: mapWidth,
            height: mapHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  'assets/sarawak_map.png',
                  width: mapWidth,
                  height: mapHeight,
                  fit: BoxFit.contain,
                ),

                ...regions.map((region) {
                  final left = region.x / viewBoxWidth * mapWidth;
                  final top = region.y / viewBoxHeight * mapHeight;
                  final isActive = selectedRegion.name == region.name;

                  return Positioned(
                    left: left - 10,
                    top: top - 10,
                    child: GestureDetector(
                      onTap: () => onSelected(region),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isActive ? 24 : 18,
                        height: isActive ? 24 : 18,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF493829)
                              : const Color(0xFFC4956A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF493829),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SarawakMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F0E8)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = const Color(0xFF493829)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.55, size.width * 0.43, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.20, size.width * 0.78, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.92, size.height * 0.03, size.width * 0.98, size.height * 0.10)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.45, size.width * 0.62, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.92, size.width * 0.05, size.height * 0.78)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.region,
    required this.onPressed,
  });

  final SarawakRegion region;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final imageHeight = width < 480 ? 190.0 : width < 768 ? 230.0 : 260.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(region.name),
        width: double.infinity,
        padding: EdgeInsets.all(width < 480 ? 12 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                region.image,
                width: double.infinity,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: imageHeight,
                    width: double.infinity,
                    color: const Color(0xFFF5F0E8),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFC4956A),
                      size: 42,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              region.name,
              style: TextStyle(
                fontSize: width < 480 ? 20 : width < 768 ? 24 : 29,
                color: const Color(0xFF493829),
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              region.description,
              style: TextStyle(
                fontSize: width < 480 ? 13 : width < 768 ? 14 : 16,
                color: const Color(0xFF7A6555),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: width < 480 ? double.infinity : null,
              child: OutlinedButton(
                onPressed: region.isDefault ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: region.isDefault
                      ? const Color(0xFFC4956A)
                      : const Color(0xFF493829),
                  side: BorderSide(
                    color: region.isDefault
                        ? const Color(0xFFC4956A)
                        : const Color(0xFF493829),
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  region.isDefault
                      ? 'Hover Over Map'
                      : 'Find Stays in ${region.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SarawakRegion {
  final String name;
  final String description;
  final String image;
  final double x;
  final double y;
  final bool isDefault;

  const SarawakRegion({
    required this.name,
    required this.description,
    required this.image,
    required this.x,
    required this.y,
    this.isDefault = false,
  });
}