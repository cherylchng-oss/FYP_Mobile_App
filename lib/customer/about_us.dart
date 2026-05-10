import 'package:flutter/material.dart';
import '../shared/customer_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF6B3F1A);
  static const primaryLight = Color(0xFF8B5E3C);
  static const accent = Color(0xFFBF8040);
  static const accentLight = Color(0xFFE8B97A);
  static const cream = Color(0xFFFAF6F0);
  static const surface = Color(0xFFF5EDE0);
  static const border = Color(0xFFE8D9C5);
  static const textPrimary = Color(0xFF2C1A0E);
  static const textSecond = Color(0xFF6B4C30);
  static const textMuted = Color(0xFFA07850);
  static const dark = Color(0xFF1A0E06);
  static const darkSurface = Color(0xFF2C1A0E);
}

BoxDecoration _card({double radius = 20}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _C.border),
    boxShadow: [
      BoxShadow(
        color: _C.primary.withOpacity(0.07),
        blurRadius: 16,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

Widget _sectionHeading({
  required String eyebrow,
  required String title,
  required String sub,
  bool dark = false,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 700),
    child: Column(
      children: [
        Text(
          eyebrow.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _C.accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white : _C.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white.withOpacity(0.70) : _C.textSecond,
            fontSize: 15,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}

Widget _onlineImage(
  String url, {
  double? height,
  BoxFit fit = BoxFit.cover,
  double radius = 16,
}) {
  if (url.trim().isEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height ?? 180,
        width: double.infinity,
        color: _C.darkSurface,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            color: _C.accent,
            size: 38,
          ),
        ),
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: height ?? 180,
          width: double.infinity,
          color: _C.darkSurface,
          child: const Center(
            child: CircularProgressIndicator(
              color: _C.accentLight,
              strokeWidth: 2.4,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          height: height ?? 180,
          width: double.infinity,
          color: _C.darkSurface,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              color: _C.accent,
              size: 38,
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ABOUT US PAGE
// ─────────────────────────────────────────────────────────────────────────────
class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _marqueeController = ScrollController();
  final ScrollController _filmstripController = ScrollController();
  final GlobalKey _servicesKey = GlobalKey();

  // Online demo image first. Replace later with your own image URL or asset.
  final String heroImage =
      'https://picsum.photos/seed/hello-sarawak-booking-hero/1200/1600';

  final List<Map<String, dynamic>> moods = const [
    {
      'emoji': '🌿',
      'title': 'Nature Lover',
      'message':
          'Start with rainforest views, national parks, rivers, and peaceful stays surrounded by greenery.',
    },
    {
      'emoji': '🍜',
      'title': 'Food Hunter',
      'message':
          'Begin with Sarawak laksa, continue with kolo mee, then let the local markets surprise you.',
    },
    {
      'emoji': '📸',
      'title': 'Photo Explorer',
      'message':
          'Chase sunsets, waterfront lights, culture shots, and hidden corners worth remembering.',
    },
    {
      'emoji': '🏡',
      'title': 'Chill Traveller',
      'message':
          'Pick a cozy stay, slow down, enjoy local hospitality, and let Sarawak unfold gently.',
    },
    {
      'emoji': '🧗',
      'title': 'Adventure Seeker',
      'message':
          'Go for caves, trails, boats, beaches, and the kind of stories you will tell for years.',
    },
  ];

  final List<Map<String, dynamic>> services = const [
    {
      'icon': Icons.hotel_rounded,
      'title': 'Sleep With a View',
      'text':
          'Find handpicked stays where comfort meets Sarawak nature, culture, and local warmth.',
    },
    {
      'icon': Icons.travel_explore_rounded,
      'title': 'Plan the Fun Stuff',
      'text':
          'Discover parks, caves, rivers, beaches, markets, villages, and hidden local experiences.',
    },
    {
      'icon': Icons.restaurant_rounded,
      'title': 'Eat Like a Local',
      'text':
          'Explore authentic Sarawak flavours, from laksa and kolo mee to local food adventures.',
    },
    {
      'icon': Icons.flight_takeoff_rounded,
      'title': 'Move Around Easily',
      'text':
          'Make travel smoother with better access to transport, nearby spots, and trip planning.',
    },
    {
      'icon': Icons.card_travel_rounded,
      'title': 'Ask Us Where To Go',
      'text':
          'Get recommendations based on your travel mood, whether you want chill, wild, or tasty.',
    },
    {
      'icon': Icons.groups_rounded,
      'title': 'Bring the Whole Gang',
      'text':
          'Create easier plans for families, students, friends, and community trips.',
    },
  ];

  final List<Map<String, String>> founders = const [
    {
      'name': 'The Stay Finder',
      'role': 'Finds cozy places and makes sure travellers feel welcome.',
      'tag': 'COZY BOSS',
      'img': 'https://picsum.photos/seed/founder-stay-finder/900/1200',
    },
    {
      'name': 'The Route Planner',
      'role': 'Connects stays, destinations, food stops, and little adventures.',
      'tag': 'MAP MASTER',
      'img': 'https://picsum.photos/seed/founder-route-planner/900/1200',
    },
    {
      'name': 'The Experience Maker',
      'role': 'Turns simple trips into stories filled with local flavour.',
      'tag': 'STORY MAKER',
      'img': 'https://picsum.photos/seed/founder-experience-maker/900/1200',
    },
  ];

  final List<Map<String, String>> filmstripImages = const [
    {
      'label': 'Bako National Park',
      'vibe': 'Monkey business 🐒',
      'desc':
          'A nature escape with trails, coastal views, wildlife, and a proper Borneo adventure mood.',
      'img': 'https://picsum.photos/seed/bako-national-park/900/700',
    },
    {
      'label': 'Gunung Mulu',
      'vibe': 'Cave mode ON 🦇',
      'desc':
          'A dramatic place for caves, limestone formations, rainforest scenery, and exploration.',
      'img': 'https://picsum.photos/seed/gunung-mulu/900/700',
    },
    {
      'label': 'Damai Beach',
      'vibe': 'Sunset therapy 🌅',
      'desc':
          'A relaxing coastal stop for sea breeze, mountain views, and slow travel moments.',
      'img': 'https://picsum.photos/seed/damai-beach/900/700',
    },
    {
      'label': 'Semenggoh Wildlife Centre',
      'vibe': 'Orangutan moments 🦧',
      'desc':
          'A meaningful wildlife experience where visitors can learn about orangutan conservation.',
      'img': 'https://picsum.photos/seed/semenggoh-wildlife/900/700',
    },
    {
      'label': 'Sarawak Waterfront',
      'vibe': 'Evening stroll ✨',
      'desc':
          'A lively riverside area for walks, food, views, and beautiful evening lights.',
      'img': 'https://picsum.photos/seed/sarawak-waterfront/900/700',
    },
    {
      'label': 'Local Hospitality',
      'vibe': 'Good people, good stories 🤎',
      'desc':
          'The warm side of Sarawak — friendly people, local stories, and welcoming stays.',
      'img': 'https://picsum.photos/seed/local-hospitality/900/700',
    },
  ];

  final List<String> marqueeItems = const [
    'Stay Local',
    'Eat Laksa',
    'Chase Sunsets',
    'Find Hidden Stays',
    'Explore Borneo',
    'Meet Good People',
    'Make Travel Stories',
    'Go Somewhere Green',
  ];

  final List<Map<String, String>> funFacts = const [
    {
      'emoji': '🦜',
      'title': 'Hornbill Energy',
      'text': 'Sarawak is famously known as the Land of the Hornbills.',
    },
    {
      'emoji': '🍜',
      'title': 'Laksa Fan Club',
      'text': 'Sarawak laksa has the kind of fan energy people proudly defend.',
    },
    {
      'emoji': '🌿',
      'title': 'Green Everywhere',
      'text': 'Rainforest adventures are basically part of the Sarawak personality.',
    },
    {
      'emoji': '🏡',
      'title': 'Stay With Stories',
      'text': 'Local stays often come with warmth, tips, and stories you remember.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll(_marqueeController, 10);
    _startAutoScroll(_filmstripController, 7);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _marqueeController.dispose();
    _filmstripController.dispose();
    super.dispose();
  }

  void _startAutoScroll(ScrollController controller, double speed) {
    Future.delayed(const Duration(milliseconds: 800), () async {
      while (mounted) {
        await Future.delayed(const Duration(milliseconds: 30));

        if (!mounted || !controller.hasClients) continue;

        final position = controller.position;
        final maxScroll = position.maxScrollExtent;

        if (maxScroll <= 0) continue;

        final nextOffset = controller.offset + (speed * 0.18);

        if (nextOffset >= maxScroll) {
          controller.jumpTo(0);
        } else {
          controller.jumpTo(nextOffset);
        }
      }
    });
  }

  void scrollToServices() {
    final ctx = _servicesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 3,
      backgroundColor: _C.cream,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _topShowcaseSection(),
            MoodPickerSection(moods: moods),
            _marqueeBand(),
            _servicesSection(),
            _funFactsSection(),
            _filmstripSection(),
            _foundersSection(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TOP SHOWCASE: IMAGE + CURVED CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _topShowcaseSection() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 430;

    return Container(
      color: _C.cream,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: compact ? 330 : 420,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _onlineImage(
                  heroImage,
                  radius: 0,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.04),
                        Colors.black.withOpacity(0.26),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Transform.translate(
            offset: const Offset(0, -56),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sarawak Stays &\nLocal Booking',
                          style: TextStyle(
                            color: _C.textPrimary,
                            fontSize: compact ? 26 : 30,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'A booking platform built to help travellers discover stays, culture, and local experiences in Sarawak.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: _C.textSecond,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _topInfoChip(Icons.hotel_rounded, 'Stays'),
                      _topInfoChip(Icons.explore_rounded, 'Explore'),
                      _topInfoChip(Icons.restaurant_rounded, 'Local Food'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'We are committed to offering guests the best of Sarawak, from breathtaking natural wonders to meaningful local experiences. Hello Sarawak helps users discover accommodations, explore local regions, and enjoy a smoother booking experience with a friendly local touch.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: _C.textSecond,
                      fontSize: 13.5,
                      height: 1.75,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: _filledTopButton(
                          'Explore Services',
                          Icons.arrow_downward_rounded,
                          onTap: scrollToServices,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _outlineTopButton(
                          'Pick Mood',
                          Icons.emoji_emotions_rounded,
                          onTap: () {
                            _scrollController.animateTo(
                              compact ? 640 : 760,
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _topInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _C.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filledTopButton(
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _C.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _C.accent.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineTopButton(
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _C.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MARQUEE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _marqueeBand() {
    final items = [...marqueeItems, ...marqueeItems];

    return Container(
      width: double.infinity,
      color: _C.darkSurface,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: SingleChildScrollView(
        controller: _marqueeController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    item,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.42),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 22),
                  const Text(
                    '✦',
                    style: TextStyle(color: _C.accent, fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SERVICES
  // ───────────────────────────────────────────────────────────────────────────
  Widget _servicesSection() {
    return Container(
      key: _servicesKey,
      color: _C.cream,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 0),
      child: Column(
        children: [
          _sectionHeading(
            eyebrow: 'What We Provide',
            title: 'Our Services',
            sub:
                'A simple and supportive platform for accommodation, travel discovery, and local Sarawak experiences.',
          ),
          const SizedBox(height: 44),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = 1;
              if (constraints.maxWidth > 900) {
                cols = 3;
              } else if (constraints.maxWidth > 580) {
                cols = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: services.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: cols == 1 ? 1.72 : cols == 2 ? 1.12 : 1.0,
                ),
                itemBuilder: (_, i) => _serviceCard(services[i], i),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> service, int index) {
    return _TapScale(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    service['icon'] as IconData,
                    color: _C.accent,
                    size: 26,
                  ),
                ),
                const Spacer(),
                Text(
                  '0${index + 1}',
                  style: TextStyle(
                    color: _C.border.withOpacity(0.9),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              service['title'] as String,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                service['text'] as String,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  color: _C.textSecond,
                  fontSize: 13,
                  height: 1.6,
                ),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FUN FACTS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _funFactsSection() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 72),
      child: Column(
        children: [
          _sectionHeading(
            eyebrow: 'Small Facts, Big Personality',
            title: 'Tiny Sarawak Fun Facts',
            sub:
                'A little extra flavour for travellers who like their information with some personality.',
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = 1;
              if (constraints.maxWidth > 900) {
                cols = 4;
              } else if (constraints.maxWidth > 620) {
                cols = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: funFacts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: cols == 1 ? 2.2 : 1.28,
                ),
                itemBuilder: (_, i) {
                  final fact = funFacts[i];

                  return _TapScale(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: _card(radius: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact['emoji'] ?? '✨',
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            fact['title'] ?? 'Fun Fact',
                            style: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              fact['text'] ?? '',
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                color: _C.textSecond,
                                fontSize: 12.5,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FILMSTRIP - RESTORED + SAFE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _filmstripSection() {
    final images = [...filmstripImages, ...filmstripImages];

    return Container(
      color: _C.dark,
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          _sectionHeading(
            eyebrow: 'Explore Sarawak',
            title: 'Moments Worth\nRemembering',
            sub:
                'From coastal escapes to rainforest adventures, Sarawak brings every traveller closer to culture and nature.',
            dark: true,
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 236,
            child: ListView.separated(
              controller: _filmstripController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => _filmstripCard(images[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filmstripCard(Map<String, String> item) {
    final imageUrl = item['img'] ?? '';
    final label = item['label'] ?? 'Sarawak Destination';
    final vibe = item['vibe'] ?? '';

    return GestureDetector(
      onTap: () => _showPlaceSheet(item),
      child: SizedBox(
        width: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _onlineImage(imageUrl, radius: 0),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.dark.withOpacity(0.86),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vibe.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.accent.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vibe,
                          style: const TextStyle(
                            color: _C.accentLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to peek',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  void _showPlaceSheet(Map<String, String> item) {
    final imageUrl = item['img'] ?? '';
    final label = item['label'] ?? 'Sarawak Destination';
    final vibe = item['vibe'] ?? '';
    final desc = item['desc'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: _onlineImage(imageUrl, radius: 0),
                  ),
                ),
                const SizedBox(height: 16),
                if (vibe.isNotEmpty)
                  Text(
                    vibe,
                    style: const TextStyle(
                      color: _C.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _C.textSecond,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FOUNDERS - RESTORED + SAFE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _foundersSection() {
    return Container(
      color: _C.cream,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 72),
      child: Column(
        children: [
          _sectionHeading(
            eyebrow: 'Meet The Humans',
            title: 'Our Founders',
            sub:
                'The people behind Hello Sarawak, working to create better digital tourism experiences.',
          ),
          const SizedBox(height: 44),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = 1;
              if (constraints.maxWidth > 900) {
                cols = 3;
              } else if (constraints.maxWidth > 580) {
                cols = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: founders.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 22,
                  mainAxisSpacing: 22,
                  childAspectRatio: cols == 1 ? 0.92 : 0.70,
                ),
                itemBuilder: (_, i) => _founderCard(founders[i], i),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _founderCard(Map<String, String> founder, int index) {
    final imageUrl = founder['img'] ?? '';
    final tag = founder['tag'] ?? 'TEAM';
    final name = founder['name'] ?? 'Founder';
    final role = founder['role'] ?? '';

    return _TapScale(
      child: Container(
        decoration: _card(radius: 22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _onlineImage(imageUrl, radius: 0),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _C.darkSurface.withOpacity(0.65),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Text(
                      '0${index + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    role,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      color: _C.textSecond,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Picker
// ─────────────────────────────────────────────────────────────────────────────
class MoodPickerSection extends StatefulWidget {
  const MoodPickerSection({
    super.key,
    required this.moods,
  });

  final List<Map<String, dynamic>> moods;

  @override
  State<MoodPickerSection> createState() => _MoodPickerSectionState();
}

class _MoodPickerSectionState extends State<MoodPickerSection> {
  int selectedMoodIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedMood = widget.moods[selectedMoodIndex];

    return Container(
      color: _C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
      child: Column(
        children: [
          _sectionHeading(
            eyebrow: 'Tiny Travel Personality Test',
            title: 'What’s Your Sarawak Mood Today?',
            sub:
                'Pick a mood and we will give you a small travel idea. Totally serious. Mostly.',
          ),

          const SizedBox(height: 32),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: widget.moods.asMap().entries.map((entry) {
                final index = entry.key;
                final mood = entry.value;
                final selected = selectedMoodIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => selectedMoodIndex = index);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _C.primary : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: selected ? _C.primary : _C.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: selected
                                ? _C.primary.withOpacity(0.20)
                                : Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mood['emoji'] as String,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mood['title'] as String,
                            style: TextStyle(
                              color: selected ? Colors.white : _C.textSecond,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedMood['emoji'] as String,
                  style: const TextStyle(fontSize: 38),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedMood['title'] as String,
                        style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedMood['message'] as String,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          color: _C.textSecond,
                          fontSize: 14,
                          height: 1.7,
                          fontWeight: FontWeight.w500,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// TAP SCALE MICRO-INTERACTION
// ─────────────────────────────────────────────────────────────────────────────
class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.child,
  });

  final Widget child;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}