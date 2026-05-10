import 'package:flutter/material.dart';
import '../shared/customer_layout.dart';

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF6B3F1A);
  static const primaryDark = Color(0xFF2C1A0E);
  static const accent = Color(0xFFBF8040);
  static const accentLight = Color(0xFFE8B97A);
}

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class SarawakImage {
  final String url;
  final String title;
  final String caption;

  const SarawakImage({
    required this.url,
    required this.title,
    required this.caption,
  });
}

class SarawakSection {
  final String title;
  final String subtitle;
  final String description;
  final List<SarawakImage> images;

  const SarawakSection({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.images,
  });
}

// ─────────────────────────────────────────────
// ABOUT SARAWAK PAGE
// ─────────────────────────────────────────────
class AboutSarawakPage extends StatefulWidget {
  const AboutSarawakPage({super.key});

  @override
  State<AboutSarawakPage> createState() => _AboutSarawakPageState();
}

class _AboutSarawakPageState extends State<AboutSarawakPage> {
  // Demo online images first.
  // Later, replace only the image URLs with your real Sarawak images.
  final List<SarawakSection> sections = const [
    SarawakSection(
      title: 'About Sarawak',
      subtitle: 'Land of the Hornbills',
      description:
          'Sarawak is Malaysia’s largest state, located on the island of Borneo. It is known for its rainforest, rivers, caves, culture, wildlife, and warm hospitality.',
      images: [
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-about-1/1200/1800',
          title: 'A brand new journey',
          caption: 'Discover the beauty, culture, and nature of Sarawak.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-about-2/1200/1800',
          title: 'Borneo beauty',
          caption: 'A destination filled with rainforest, rivers, and stories.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-about-3/1200/1800',
          title: 'Authentic escape',
          caption: 'Experience Sarawak through people, places, and heritage.',
        ),
      ],
    ),
    SarawakSection(
      title: 'Cultural Diversity',
      subtitle: 'Traditions, people, and heritage',
      description:
          'Sarawak is home to many ethnic groups including Iban, Bidayuh, Orang Ulu, Malay, Melanau, and Chinese communities. Each group contributes to Sarawak’s rich cultural identity.',
      images: [
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-culture-1/1200/1800',
          title: 'Living traditions',
          caption: 'Explore customs, festivals, crafts, and traditional lifestyles.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-culture-2/1200/1800',
          title: 'Local communities',
          caption: 'Discover the people and heritage that shape Sarawak.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-culture-3/1200/1800',
          title: 'Cultural colours',
          caption: 'A beautiful mix of language, food, music, and celebration.',
        ),
      ],
    ),
    SarawakSection(
      title: 'Natural Wonders',
      subtitle: 'Rainforest, caves, rivers, and parks',
      description:
          'Sarawak offers unforgettable natural attractions, from tropical rainforests and national parks to limestone caves, beaches, rivers, and mountain landscapes.',
      images: [
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-nature-1/1200/1800',
          title: 'Rainforest adventure',
          caption: 'Walk through lush greenery and peaceful natural scenery.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-nature-2/1200/1800',
          title: 'Hidden wonders',
          caption: 'Explore caves, trails, rivers, and breathtaking landscapes.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-nature-3/1200/1800',
          title: 'Nature escape',
          caption: 'Reconnect with nature in Sarawak’s beautiful environment.',
        ),
      ],
    ),
    SarawakSection(
      title: 'Wildlife Encounters',
      subtitle: 'Unique animals and ecosystems',
      description:
          'Sarawak is home to fascinating wildlife such as orangutans, hornbills, proboscis monkeys, and many other species living in forests, rivers, and protected areas.',
      images: [
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-wildlife-1/1200/1800',
          title: 'Wildlife moments',
          caption: 'Observe unique animals and learn about conservation.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-wildlife-2/1200/1800',
          title: 'Nature habitat',
          caption: 'Discover ecosystems filled with life and biodiversity.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-wildlife-3/1200/1800',
          title: 'Borneo wildlife',
          caption: 'A meaningful journey for nature and animal lovers.',
        ),
      ],
    ),
    SarawakSection(
      title: 'Culinary Delights',
      subtitle: 'Local flavours and food culture',
      description:
          'Sarawak’s food reflects its multicultural identity. Visitors can enjoy Sarawak laksa, kolo mee, traditional delicacies, local markets, and many unique flavours.',
      images: [
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-food-1/1200/1800',
          title: 'Local favourites',
          caption: 'Taste dishes that represent Sarawak’s culture and warmth.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-food-2/1200/1800',
          title: 'Food adventure',
          caption: 'Explore markets, local stalls, and traditional recipes.',
        ),
        SarawakImage(
          url: 'https://picsum.photos/seed/sarawak-food-3/1200/1800',
          title: 'Flavours of home',
          caption: 'Every dish tells a story of community and heritage.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 3,
      backgroundColor: _C.primaryDark,

      // Removed the top brown heading/app bar.
      // If your CustomerLayout does not accept null, use the alternative below:
      // appBar: const PreferredSize(
      //   preferredSize: Size.zero,
      //   child: SizedBox.shrink(),
      // ),
      appBar: null,

      body: LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          padding: EdgeInsets.zero,
          physics: const PageScrollPhysics(),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            return SizedBox(
              height: constraints.maxHeight,
              child: _FullScreenSarawakSection(
                section: sections[index],
                isLastSection: index == sections.length - 1, // NEW
              ),
            );
          },
        );
      },
    ),
    );
  }
}

// ─────────────────────────────────────────────
// FULL SCREEN SECTION
// ─────────────────────────────────────────────
class _FullScreenSarawakSection extends StatefulWidget {
  const _FullScreenSarawakSection({
    required this.section,
    required this.isLastSection, // NEW
  });

  final SarawakSection section;
  final bool isLastSection; // NEW

  @override
  State<_FullScreenSarawakSection> createState() =>
      _FullScreenSarawakSectionState();
}

class _FullScreenSarawakSectionState extends State<_FullScreenSarawakSection> {
  int selectedImageIndex = 0;

  SarawakImage get selectedImage {
    return widget.section.images[selectedImageIndex];
  }

  void changeImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallPhone = size.height < 720;
    final isWide = size.width > 700;

    final horizontalPadding = isWide ? size.width * 0.12 : 24.0;
    final titleSize = isWide ? 48.0 : isSmallPhone ? 30.0 : 38.0;
    final imageCardHeight = isSmallPhone ? 76.0 : 92.0;

    return Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background image
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: _BackgroundImage(
              key: ValueKey(selectedImage.url),
              url: selectedImage.url,
            ),
          ),

          // Main dark gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.42),
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.82),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),

          // Brown brand glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _C.primary.withOpacity(0.32),
                    Colors.transparent,
                    _C.primaryDark.withOpacity(0.62),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                34,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main title on image
                  Text(
                    widget.section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.section.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.86),
                      fontSize: isWide ? 18 : 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),

                  const Spacer(),

                  // Selected image wording
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(selectedImage.title),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedImage.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWide ? 32 : 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedImage.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.86),
                            fontSize: isWide ? 16 : 13,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Floating picture cards
                  SizedBox(
                    height: imageCardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.section.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final image = widget.section.images[index];
                        final selected = selectedImageIndex == index;

                        return _FloatingImageCard(
                          image: image,
                          selected: selected,
                          height: imageCardHeight,
                          onTap: () => changeImage(index),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Description
                  _DescriptionGlassCard(
                    description: widget.section.description,
                    isWide: isWide,
                  ),

                  const SizedBox(height: 12),

                  if (!widget.isLastSection)
                  Center(
                    child: Text(
                      'Swipe up to explore more',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }
}

// ─────────────────────────────────────────────
// BACKGROUND IMAGE
// ─────────────────────────────────────────────
class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({
    super.key,
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          color: _C.primaryDark,
          child: const Center(
            child: CircularProgressIndicator(
              color: _C.accentLight,
              strokeWidth: 2.5,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          color: _C.primaryDark,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              color: _C.accentLight,
              size: 38,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// FLOATING IMAGE CARD
// ─────────────────────────────────────────────
class _FloatingImageCard extends StatelessWidget {
  const _FloatingImageCard({
    required this.image,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final SarawakImage image;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.72;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _C.accentLight : Colors.white.withOpacity(0.55),
            width: selected ? 2.2 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? _C.accentLight.withOpacity(0.35)
                  : Colors.black.withOpacity(0.30),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image.url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  return Container(
                    color: _C.primaryDark,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: _C.accentLight,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: _C.primaryDark,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: _C.accentLight,
                    ),
                  );
                },
              ),

              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.55),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DESCRIPTION CARD
// ─────────────────────────────────────────────
class _DescriptionGlassCard extends StatefulWidget {
  const _DescriptionGlassCard({
    required this.description,
    required this.isWide,
  });

  final String description;
  final bool isWide;

  @override
  State<_DescriptionGlassCard> createState() => _DescriptionGlassCardState();
}

class _DescriptionGlassCardState extends State<_DescriptionGlassCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 230),
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: widget.isWide ? 720 : double.infinity,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Text(
              widget.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.justify, // NEW
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
            secondChild: Text(
              widget.description,
              textAlign: TextAlign.justify, // NEW
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 8),

          GestureDetector(
            onTap: () {
              setState(() => expanded = !expanded);
            },
            child: Text(
              expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: _C.accentLight,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}