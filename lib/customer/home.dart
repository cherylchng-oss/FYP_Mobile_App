import 'package:flutter/material.dart';
import '../shared/customer_layout.dart';
import '../shared/colors.dart';
import '../api.dart' as api;
import '../services/session.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens 
// ─────────────────────────────────────────────────────────────────────────────
class HSColors {
  static const cream        = AdminColors.cream; 
  static const surface      = AdminColors.surface;
  static const surfaceAlt   = Color(0xFFF0E6D8);
  static const primary      = AdminColors.primary;
  static const primaryLight = AdminColors.primaryLight;
  static const accent       = AdminColors.accent;
  static const accentLight  = AdminColors.accentLight;
  static const border       = AdminColors.border;
  static const borderDark   = Color(0xFFD5B896);
  static const textPrimary  = AdminColors.textPrimary;
  static const textSecond   = AdminColors.textSecond;
  static const textMuted    = AdminColors.textMuted;
  static const dark         = Color(0xFF1A0E06);
  static const darkSurface  = Color(0xFF2C1A0E);
  static const gold         = Color(0xFFBF8040); 
  static const brownSoft    = Color(0xFF8B5E3C);
}

BoxDecoration _card({double radius = 20, Color? bg}) => BoxDecoration(
  color: bg ?? Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: HSColors.border),
  boxShadow: [BoxShadow(color: HSColors.primary.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 5))],
);

// ─────────────────────────────────────────────────────────────────────────────
// HomePage
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userid = await Session.getUserId();

      if (userid == null) return;

      final notifications = await api.fetchNotifications(userid);

      if (!mounted) return;

      setState(() {
        _unreadCount = notifications.where((n) {
          final isRead = n['isread'] ?? n['isRead'] ?? false;
          return isRead == false;
        }).length;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToRoomsPage() {
    Navigator.pushNamed(context, '/customer-rooms');
  }

  void _goToAboutSarawakPage() {
    Navigator.pushNamed(context, '/about-sarawak');
  }

  void _goToAboutUsPage() {
    Navigator.pushNamed(context, '/about-us');
  }

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 0,
      backgroundColor: HSColors.cream,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(children: [
        // Hero
        _HeroSection(
          onExploreStays: _goToRoomsPage,
          onDiscoverSarawak: _goToAboutSarawakPage,
          unreadCount: _unreadCount,
          onNotificationTap: () {
            Navigator.pushNamed(context, '/customer-notifications')
                .then((_) => _loadUnreadCount());
          },
        ),

        // Why choose us
        const _WhyChooseUsSection(),

        // Trip mood recommendation
        const _TripMoodSection(),

        // Curated experiences
        const _CuratedSection(),

        // Testimonials - ONLY this section animated
        const _RevealOnScroll(
          delay: Duration(milliseconds: 150),
          child: _TestimonialsSection(),
        ),

        // CTA
        _CtaSection(
          onFindStay: _goToRoomsPage,
          onAboutUs: _goToAboutUsPage,
        )
      ]),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onExploreStays,
    required this.onDiscoverSarawak,
    required this.unreadCount, 
    required this.onNotificationTap, 
  });

  final VoidCallback onExploreStays;
  final VoidCallback onDiscoverSarawak;
  final int unreadCount; 
  final VoidCallback onNotificationTap; 

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return SizedBox(
      height: h * 0.88,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        // Background
        Image.asset('assets/home.png', fit: BoxFit.cover,
          color: Colors.black.withOpacity(0.28), colorBlendMode: BlendMode.darken,
          errorBuilder: (_, __, ___) => Container(color: HSColors.dark)),
        // Bottom gradient
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [HSColors.dark, Colors.transparent, Color(0x44000000)]))),
        // Left gradient
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [HSColors.dark.withOpacity(0.55), Colors.transparent]))),

        // Notification bell
        Positioned(
          top: MediaQuery.of(context).padding.top + 18,
          right: 22,
          child: GestureDetector(
            onTap: onNotificationTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 15,
                  ),
                ),

                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0A43A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Content
        SafeArea(child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w > 768 ? 56 : 22),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: HSColors.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: HSColors.accent.withOpacity(0.40)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_rounded, color: HSColors.accentLight, size: 13),
                SizedBox(width: 7),
                Text('BORNEO, MALAYSIA', style: TextStyle(color: HSColors.accentLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              ]),
            ),
            const SizedBox(height: 22),
            // Headline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RichText(text: TextSpan(
                style: TextStyle(fontSize: w < 480 ? 36 : w < 768 ? 50 : 68, height: 1.0, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white),
                children: const [
                  TextSpan(text: 'YOUR STORY\nBEGINS IN '),
                  TextSpan(text: 'SARAWAK.', style: TextStyle(color: HSColors.accentLight, fontStyle: FontStyle.italic)),
                ],
              )),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text('Explore the land of hornbills, ancient caves, and living traditions. Find your perfect homestay today.',
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: w < 480 ? 15 : 17, height: 1.65)),
            ),
            const SizedBox(height: 32),
            // CTAs
            Wrap(spacing: 12, runSpacing: 12, children: [
              _heroCta('Explore Stays', Icons.search_rounded, filled: true, onTap: onExploreStays),
              _heroCta('Discover Sarawak', Icons.explore_rounded, filled: false, onTap: onDiscoverSarawak),
            ]),
          ]),
        )),

        // Scroll hint
        Positioned(bottom: 28, left: 0, right: 0, child: Center(child: Column(children: [
          Text('SCROLL DOWN', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const _ScrollArrow(),
        ]))),
      ]),
    );
  }

  Widget _heroCta(String label, IconData icon, {required bool filled, required VoidCallback onTap}) =>
    InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? HSColors.accent : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: Colors.white.withOpacity(0.30)),
          boxShadow: filled ? [BoxShadow(color: HSColors.accent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
}

class _ScrollArrow extends StatefulWidget {
  const _ScrollArrow();
  @override State<_ScrollArrow> createState() => _ScrollArrowState();
}
class _ScrollArrowState extends State<_ScrollArrow> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _a = Tween(begin: 0.0, end: 6.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Transform.translate(offset: Offset(0, _a.value),
      child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.45), size: 26)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WHY CHOOSE US 
// ─────────────────────────────────────────────────────────────────────────────
class _WhyChooseUsSection extends StatelessWidget {
  const _WhyChooseUsSection();

  static const features = [
    {
      'icon': 'verified',
      'title': 'Verified Stays',
      'desc': 'Every property is reviewed and verified by our local team before listing.',
    },
    {
      'icon': 'price',
      'title': 'Best Price Promise',
      'desc': 'We match any lower price you find — no hidden fees, ever.',
    },
    {
      'icon': 'local',
      'title': 'Local Experience',
      'desc': 'Connect directly with local hosts for authentic Sarawak hospitality.',
    },
    {
      'icon': 'support',
      'title': '24 / 7 Support',
      'desc': 'Our team is always here to help before, during, and after your stay.',
    },
    {
      'icon': 'flexible',
      'title': 'Flexible Booking',
      'desc': 'Easy date changes and deposit-based reservations for peace of mind.',
    },
    {
      'icon': 'safe',
      'title': 'Secure Payments',
      'desc': 'PayPal-protected transactions keep your booking safe every time.',
    },
  ];

  static const _icons = {
    'verified': Icons.verified_rounded,
    'price': Icons.price_check_rounded,
    'local': Icons.people_rounded,
    'support': Icons.support_agent_rounded,
    'flexible': Icons.date_range_rounded,
    'safe': Icons.lock_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Container(
      color: HSColors.cream,
      padding: EdgeInsets.fromLTRB(
        isWide ? 40 : 16,
        64,
        isWide ? 40 : 16,
        64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _SectionHeading(
                eyebrow: 'Why Hello Sarawak?',
                title: 'Built for travellers\nwho care',
                sub: 'We make finding and booking authentic Sarawak stays simple, safe, and memorable.',
                center: true,
              ),

              const SizedBox(height: 34),

              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  // Mobile: compact vertical cards
                  if (width < 650) {
                    return Column(
                      children: features.map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _mobileFeatureCard(f),
                        );
                      }).toList(),
                    );
                  }

                  // Tablet/Desktop: grid cards
                  final cols = width >= 1000 ? 3 : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: features.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      mainAxisExtent: cols == 3 ? 210 : 190,
                    ),
                    itemBuilder: (_, i) {
                      return _desktopFeatureCard(features[i]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileFeatureCard(Map<String, String> f) {
    final icon = _icons[f['icon']] ?? Icons.check_circle_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HSColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: HSColors.accent,
              size: 21,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['title']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HSColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  f['desc']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HSColors.textSecond,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopFeatureCard(Map<String, String> f) {
    final icon = _icons[f['icon']] ?? Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  HSColors.accent,
                  HSColors.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            f['title']!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HSColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Text(
              f['desc']!,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                color: HSColors.textSecond,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CURATED EXPERIENCES
// ─────────────────────────────────────────────────────────────────────────────
class _CuratedSection extends StatelessWidget {
  const _CuratedSection();

  static const destinations = [
    {'name': 'Bako National Park', 'tag': 'Wildlife & Rainforest', 'img': 'assets/about_bako.png'},
    {'name': 'Gunung Mulu',        'tag': 'UNESCO Heritage',       'img': 'assets/about_mulu.png'},
    {'name': 'Damai Beach',        'tag': 'Coastal Escape',        'img': 'assets/about_damai.png'},
    {'name': 'Semenggoh',          'tag': 'Orangutan Sanctuary',   'img': 'assets/about_semenggoh.png'},
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;
    final cols = w > 768 ? 2 : 1;

    return Container(
      color: HSColors.dark,
      padding: EdgeInsets.fromLTRB(isWide ? 40 : 16, 80, isWide ? 40 : 16, 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _SectionHeading(eyebrow: 'Curated Experiences', title: 'Explore the\nBest of Sarawak', dark: true)),
            if (isWide)
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: HSColors.accent.withOpacity(0.45)), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Discover more →', style: TextStyle(color: HSColors.accentLight, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: destinations.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 18, mainAxisSpacing: 18, mainAxisExtent: 280),
            itemBuilder: (_, i) {
              final d = destinations[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(d['img']!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: HSColors.darkSurface)),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [HSColors.dark.withOpacity(0.90), Colors.transparent]))),
                  Positioned(left: 22, bottom: 22, right: 22, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['tag']!.toUpperCase(), style: const TextStyle(color: HSColors.accentLight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                      const SizedBox(height: 6),
                      Text(d['name']!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ])),
                ]),
              );
            },
          ),
        ]),
      )),
    );
  }
}

class _TripMoodSection extends StatefulWidget {
  const _TripMoodSection();

  @override
  State<_TripMoodSection> createState() => _TripMoodSectionState();
}

class _TripMoodSectionState extends State<_TripMoodSection> {
  int selectedIndex = 0;

  static const moods = [
    {
      'label': 'Relaxing',
      'icon': Icons.spa_rounded,
      'destination': 'Damai Beach',
      'tag': 'Coastal Escape',
      'desc': 'Perfect for a calm getaway with sea breeze, beach views, relaxing sunsets, and a peaceful stay away from the busy city.',
      'image': 'assets/about_damai.png',
    },
    {
      'label': 'Adventure',
      'icon': Icons.hiking_rounded,
      'destination': 'Gunung Mulu',
      'tag': 'UNESCO Heritage',
      'desc': 'Perfect for travellers who enjoy caves, rainforest trails, limestone formations, and exciting nature exploration.',
      'image': 'assets/about_mulu.png',
    },
    {
      'label': 'Family',
      'icon': Icons.family_restroom_rounded,
      'destination': 'Kuching City',
      'tag': 'Easy & Comfortable',
      'desc': 'Perfect for families who want easy access to food, shopping, sightseeing spots, comfortable stays, and family-friendly attractions.',
      'image': 'assets/fam.png',
    },
    {
      'label': 'Food',
      'icon': Icons.restaurant_rounded,
      'destination': 'Kuching Food Festival',
      'tag': 'Local Food Hunt',
      'desc': 'Perfect for food lovers who want to try local favourites, street food, desserts, snacks, and different Sarawak flavours in one place.',
      'image': 'assets/foodfes.png',
    },
    {
      'label': 'Culture',
      'icon': Icons.museum_rounded,
      'destination': 'Sarawak Cultural Village',
      'tag': 'Culture & Heritage',
      'desc': 'Perfect for discovering Sarawak’s traditional houses, ethnic cultures, local performances, crafts, and heritage experiences.',
      'image': 'assets/culturevil.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedMood = moods[selectedIndex];
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        isWide ? 40 : 16,
        72,
        isWide ? 40 : 16,
        72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _SectionHeading(
                eyebrow: 'Plan By Mood',
                title: 'What kind of trip\nare you planning?',
                sub: 'Pick a travel mood and we will suggest a Sarawak destination that matches your vibe.',
                center: true,
              ).animate().fadeIn(
                    duration: 450.ms,
                  ).slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 30),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: moods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final mood = entry.value;
                    final selected = selectedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? HSColors.primary : HSColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected
                                  ? HSColors.primary
                                  : HSColors.border,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: HSColors.primary.withOpacity(0.18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mood['icon'] as IconData,
                                size: 16,
                                color: selected
                                    ? Colors.white
                                    : HSColors.accent,
                              ),

                              const SizedBox(width: 7),

                              Text(
                                mood['label'] as String,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : HSColors.textSecond,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ).animate().fadeIn(
                    delay: 100.ms,
                    duration: 450.ms,
                  ).slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 28),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _MoodRecommendationCard(
                  key: ValueKey(selectedMood['label']),
                  mood: selectedMood,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodRecommendationCard extends StatelessWidget {
  const _MoodRecommendationCard({
    super.key,
    required this.mood,
  });

  final Map<String, Object> mood;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 720;

    return Container(
      decoration: _card(radius: 28),
      clipBehavior: Clip.antiAlias,
      child: isWide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _moodImage(260),
                ),
                Expanded(
                  flex: 5,
                  child: _moodContent(context),
                ),
              ],
            )
          : Column(
              children: [
                _moodImage(210),
                _moodContent(context),
              ],
            ),
    ).animate().fadeIn(
          duration: 350.ms,
        ).slideY(
          begin: 0.05,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _moodImage(double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            mood['image'] as String,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(color: HSColors.darkSurface);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  HSColors.dark.withOpacity(0.70),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HSColors.accent.withOpacity(0.28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (mood['tag'] as String).toUpperCase(),
                style: const TextStyle(
                  color: HSColors.accentLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mood['destination'] as String,
            style: const TextStyle(
              color: HSColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            mood['desc'] as String,
            style: const TextStyle(
              color: HSColors.textSecond,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTIMONIALS
// ─────────────────────────────────────────────────────────────────────────────
class _TestimonialsSection extends StatefulWidget {
  const _TestimonialsSection();

  @override
  State<_TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<_TestimonialsSection> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  static const testimonials = [
    {
      'name': 'Sarah Jenkins',
      'location': 'UK',
      'text': 'Booking through Hello Sarawak was seamless. The homestay in Kuching gave us an incredible, authentic experience!',
    },
    {
      'name': 'Ahmad Fazil',
      'location': 'KL',
      'text': 'Easy to navigate and great selection of properties. Our stay in Mulu was simply unforgettable.',
    },
    {
      'name': 'Elena Rossi',
      'location': 'Italy',
      'text': 'Beautiful platform with amazing customer support. Our longhouse stay was beyond what we imagined.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _testimonialCard(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '★★★★★',
            style: TextStyle(
              color: HSColors.accent,
              letterSpacing: 2,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Text(
              '"${t['text']}"',
              style: const TextStyle(
                color: HSColors.textSecond,
                fontStyle: FontStyle.italic,
                height: 1.55,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: HSColors.accent,
                child: Text(
                  t['name']![0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['name']!,
                    style: const TextStyle(
                      color: HSColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    t['location']!.toUpperCase(),
                    style: const TextStyle(
                      color: HSColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
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

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Container(
      color: HSColors.cream,
      padding: EdgeInsets.fromLTRB(
        isWide ? 40 : 16,
        80,
        isWide ? 40 : 16,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _SectionHeading(
                eyebrow: 'Guest Stories',
                title: 'Loved by travellers\naround the world',
                center: true,
              ).animate().fadeIn(
                    duration: 450.ms,
                  ).slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 40),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: const [
                  _StatChip(value: '500+', label: 'Happy Guests'),
                  _StatChip(value: '12', label: 'Regions'),
                  _StatChip(value: '4.9★', label: 'Avg Rating'),
                  _StatChip(value: '3+', label: 'Years Running'),
                ],
              ).animate().fadeIn(
                    delay: 100.ms,
                    duration: 450.ms,
                  ).slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 40),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  // Mobile: swipeable testimonials
                  if (isMobile) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 215,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: testimonials.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (_, i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: _testimonialCard(testimonials[i])
                                    .animate()
                                    .fadeIn(
                                      duration: 450.ms,
                                    )
                                    .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      duration: 450.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(testimonials.length, (index) {
                            final active = _currentPage == index;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: active
                                    ? HSColors.accent
                                    : HSColors.border,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  }

                  // Tablet/Desktop: keep grid
                  final cols = constraints.maxWidth > 800 ? 3 : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: testimonials.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      mainAxisExtent: 200,
                    ),
                    itemBuilder: (_, i) {
                      return _testimonialCard(testimonials[i])
                          .animate()
                          .fadeIn(
                            delay: (i * 100).ms,
                            duration: 450.ms,
                          )
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            duration: 450.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: _card(),
    child: Column(children: [
      Text(value, style: const TextStyle(color: HSColors.primary, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(label.toUpperCase(), style: const TextStyle(color: HSColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA 
// ─────────────────────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  const _CtaSection({
    required this.onFindStay,
    required this.onAboutUs,
  });

  final VoidCallback onFindStay;
  final VoidCallback onAboutUs;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D1F0A), HSColors.primary, HSColors.primaryLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(w > 768 ? 56 : 22, 80, w > 768 ? 56 : 22, 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30)),
            child: const Text('READY TO EXPLORE?', style: TextStyle(color: HSColors.accentLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
          ),
          const SizedBox(height: 20),
          Text('Your perfect Sarawak stay\nis waiting for you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: w < 480 ? 28 : 38, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 14),
          Text('Join thousands of happy travellers who have discovered authentic Sarawak hospitality with Hello Sarawak.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 15, height: 1.65)),
          const SizedBox(height: 36),
          // CTA buttons
          Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [
            ElevatedButton.icon(
              onPressed: onFindStay,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Find a Stay', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: HSColors.accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAboutUs,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('About Us', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.40)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
          const SizedBox(height: 48),
          // Trust badges
          Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 12, children: [
            _trustBadge(Icons.verified_rounded, 'Verified Stays'),
            _trustBadge(Icons.lock_rounded, 'Secure Payments'),
            _trustBadge(Icons.support_agent_rounded, '24/7 Support'),
          ]),
        ]),
      )),
    );
  }

  Widget _trustBadge(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: HSColors.accentLight, size: 16),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}

class _RevealOnScroll extends StatefulWidget {
  const _RevealOnScroll({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        if (!_visible && info.visibleFraction > 0.18) {
          Future.delayed(widget.delay, () {
            if (mounted) {
              setState(() {
                _visible = true;
              });
            }
          });
        }
      },
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.08),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Section heading
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title, this.sub, this.center = false, this.dark = false});
  final String eyebrow, title;
  final String? sub;
  final bool center, dark;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      Text(eyebrow.toUpperCase(), textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(color: HSColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
      const SizedBox(height: 12),
      Text(title, textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(color: dark ? Colors.white : HSColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
      if (sub != null) ...[
        const SizedBox(height: 12),
        Text(sub!, textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(color: dark ? Colors.white.withOpacity(0.68) : HSColors.textSecond, fontSize: 14, height: 1.65)),
      ],
    ],
  );
}