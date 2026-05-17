import 'package:flutter/material.dart';
import '../shared/customer_layout.dart';
import '../api.dart' as api;
import '../services/session.dart';
import '../shared/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors AppColors from customer_rooms.dart
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
  const HomePage({super.key, this.fetchProperties});
  final Future<List<Map<String, dynamic>>> Function()? fetchProperties;

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

  void _handleHomeSearch() {
    Navigator.pushNamed(context, '/product');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 0,
      backgroundColor: HSColors.cream,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // 1. Hero
            _HeroSection(
              onExplore: _handleHomeSearch,
              unreadCount: _unreadCount,
              onNotificationTap: () {
                Navigator.pushNamed(context, '/customer-notifications')
                    .then((_) => _loadUnreadCount());
              },
            ),

            // 2. Featured destinations
            const _FeaturedDestinationsSection(),

            // 3. Why choose us
            const _WhyChooseUsSection(),

            // 4. Ad banner
            const _AdBannerSection(),

            // 5. Curated experiences
            const _CuratedSection(),

            // 6. Testimonials
            const _TestimonialsSection(),

            // Bottom spacing above bottom nav
            SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onExplore,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  final VoidCallback onExplore;
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
        Image.asset('assets/WaterFront.jpeg', fit: BoxFit.cover,
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
              _heroCta('Explore Stays', Icons.search_rounded, filled: true, onTap: onExplore),
              _heroCta('Discover Sarawak', Icons.explore_rounded, filled: false, onTap: onExplore),
            ]),
          ]),
        )),

        // Notification bell
        Positioned(
          top: MediaQuery.of(context).padding.top + 18,
          right: w > 768 ? 56 : 22,
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
// FEATURED DESTINATIONS
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedDestinationsSection extends StatelessWidget {
  const _FeaturedDestinationsSection();

  static const destinations = [
    {'name': 'Kuching City', 'tag': 'Cultural Capital', 'img': 'assets/Sarawak.png', 'props': '42 stays'},
    {'name': 'Gunung Mulu',  'tag': 'UNESCO Heritage',  'img': 'assets/Mulu.jpg',    'props': '18 stays'},
    {'name': 'Damai Beach',  'tag': 'Coastal Escape',   'img': 'assets/Damai.jpg',   'props': '27 stays'},
    {'name': 'Bako Park',    'tag': 'Nature & Wildlife','img': 'assets/Bako.jpg',    'props': '11 stays'},
    {'name': 'Semenggoh',    'tag': 'Orangutan Trail',  'img': 'assets/Semenggoh.jpg','props': '9 stays'},
    {'name': 'Sibu City',    'tag': 'Riverside Charm',  'img': 'assets/WaterFront.jpeg','props': '33 stays'},
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;
    int cols = w > 1000 ? 3 : w > 600 ? 2 : 1;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(isWide ? 40 : 16, 72, isWide ? 40 : 16, 72),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _SectionHeading(
              eyebrow: 'Explore by Destination',
              title: 'Top Places\nto Stay',
              sub: 'Handpicked destinations across the Land of Hornbills.',
            )),
            if (w > 600)
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: HSColors.border), borderRadius: BorderRadius.circular(12)),
                  child: const Text('View all →', style: TextStyle(color: HSColors.textSecond, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const SizedBox(height: 36),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: destinations.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 18, mainAxisSpacing: 18,
              mainAxisExtent: cols == 1 ? 220 : 260,
            ),
            itemBuilder: (_, i) => _DestCard(data: destinations[i]),
          ),
        ]),
      )),
    );
  }
}

class _DestCard extends StatelessWidget {
  const _DestCard({required this.data});
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(fit: StackFit.expand, children: [
      Image.asset(data['img']!, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: HSColors.darkSurface)),
      // Gradient
      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
        colors: [HSColors.dark.withOpacity(0.85), Colors.transparent, Colors.black.withOpacity(0.12)]))),
      // Content
      Positioned(left: 16, right: 16, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: HSColors.accent.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
          child: Text(data['tag']!.toUpperCase(), style: const TextStyle(color: HSColors.accentLight, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        ),
        const SizedBox(height: 6),
        Text(data['name']!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Icons.home_rounded, color: Colors.white60, size: 13), const SizedBox(width: 4),
          Text(data['props']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WHY CHOOSE US
// ─────────────────────────────────────────────────────────────────────────────
class _WhyChooseUsSection extends StatelessWidget {
  const _WhyChooseUsSection();

  static const features = [
    {'icon': 'verified',    'title': 'Verified Stays',       'desc': 'Every property is reviewed and verified by our local team before listing.'},
    {'icon': 'price',       'title': 'Best Price Promise',    'desc': 'We match any lower price you find — no hidden fees, ever.'},
    {'icon': 'local',       'title': 'Local Experience',      'desc': 'Connect directly with local hosts for authentic Sarawak hospitality.'},
    {'icon': 'support',     'title': '24 / 7 Support',       'desc': 'Our team is always here to help before, during, and after your stay.'},
    {'icon': 'flexible',    'title': 'Flexible Booking',      'desc': 'Easy date changes and deposit-based reservations for peace of mind.'},
    {'icon': 'safe',        'title': 'Secure Payments',       'desc': 'PayPal-protected transactions keep your booking safe every time.'},
  ];

  static const _icons = {
    'verified':  Icons.verified_rounded,
    'price':     Icons.price_check_rounded,
    'local':     Icons.people_rounded,
    'support':   Icons.support_agent_rounded,
    'flexible':  Icons.date_range_rounded,
    'safe':      Icons.lock_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;
    int cols = w > 1000 ? 3 : w > 600 ? 2 : 1;

    return Container(
      color: HSColors.cream,
      padding: EdgeInsets.fromLTRB(isWide ? 40 : 16, 72, isWide ? 40 : 16, 72),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(children: [
          _SectionHeading(
            eyebrow: 'Why Hello Sarawak?',
            title: 'Built for travellers\nwho care',
            sub: 'We make finding and booking authentic Sarawak stays simple, safe, and memorable.',
            center: true,
          ),
          const SizedBox(height: 44),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 18, mainAxisSpacing: 18,
              childAspectRatio: cols == 1 ? 3.2 : 1.4,
            ),
            itemBuilder: (_, i) {
              final f = features[i];
              final icon = _icons[f['icon']] ?? Icons.check_circle_rounded;
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: _card(),
                child: cols == 1
                  // Mobile: horizontal layout
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(color: HSColors.accent.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: HSColors.accent, size: 22)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f['title']!, style: const TextStyle(color: HSColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(f['desc']!, style: const TextStyle(color: HSColors.textSecond, fontSize: 13, height: 1.55)),
                      ])),
                    ])
                  // Wide: vertical layout
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [HSColors.accent, HSColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: Colors.white, size: 24)),
                      const SizedBox(height: 16),
                      Text(f['title']!, style: const TextStyle(color: HSColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Expanded(child: Text(f['desc']!, style: const TextStyle(color: HSColors.textSecond, fontSize: 13, height: 1.6), overflow: TextOverflow.visible)),
                    ]),
              );
            },
          ),
        ]),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AD BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _AdBannerSection extends StatelessWidget {
  const _AdBannerSection();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 480,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/AdBanner.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: HSColors.dark)),
        // Overlays
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xCC000000), Color(0x55000000), Colors.transparent]))),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.45), Colors.transparent]))),
        // Content
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w > 768 ? 56 : 22),
          child: Align(alignment: Alignment.centerLeft, child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: HSColors.accent), borderRadius: BorderRadius.circular(30), color: Colors.black.withOpacity(0.25)),
                child: const Text('FEATURED EVENT', style: TextStyle(color: HSColors.accentLight, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.6)),
              ),
              const SizedBox(height: 18),
              Text('Sarawak Rainforest\nWorld Music Festival',
                style: TextStyle(color: Colors.white, fontSize: w < 480 ? 30 : w < 768 ? 40 : 52, fontWeight: FontWeight.w900, height: 1.05)),
              const SizedBox(height: 14),
              Text('Experience the rhythm of the jungle. Get your early bird tickets now.',
                style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: w < 480 ? 14 : 17, height: 1.6)),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.confirmation_number_rounded, size: 17),
                label: const Text('Book Tickets', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HSColors.accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ]),
          )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CURATED EXPERIENCES
// ─────────────────────────────────────────────────────────────────────────────
class _CuratedSection extends StatelessWidget {
  const _CuratedSection();

  static const destinations = [
    {'name': 'Bako National Park', 'tag': 'Wildlife & Rainforest', 'img': 'assets/Bako.jpg'},
    {'name': 'Gunung Mulu',        'tag': 'UNESCO Heritage',       'img': 'assets/Mulu.jpg'},
    {'name': 'Damai Beach',        'tag': 'Coastal Escape',        'img': 'assets/Damai.jpg'},
    {'name': 'Semenggoh',          'tag': 'Orangutan Sanctuary',   'img': 'assets/Semenggoh.jpg'},
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

// ─────────────────────────────────────────────────────────────────────────────
// TESTIMONIALS
// ─────────────────────────────────────────────────────────────────────────────
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  static const testimonials = [
    {'name': 'Sarah Jenkins', 'location': 'UK',    'text': 'Booking through Hello Sarawak was seamless. The homestay in Kuching gave us an incredible, authentic experience!'},
    {'name': 'Ahmad Fazil',   'location': 'KL',    'text': 'Easy to navigate and great selection of properties. Our stay in Mulu was simply unforgettable.'},
    {'name': 'Elena Rossi',   'location': 'Italy', 'text': 'Beautiful platform with amazing customer support. Our longhouse stay was beyond what we imagined.'},
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Container(
      color: HSColors.cream,
      padding: EdgeInsets.fromLTRB(isWide ? 40 : 16, 80, isWide ? 40 : 16, 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(children: [
          _SectionHeading(eyebrow: 'Guest Stories', title: 'Loved by travellers\naround the world', center: true),
          const SizedBox(height: 40),
          // Stats row
          Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16, children: const [
            _StatChip(value: '500+', label: 'Happy Guests'),
            _StatChip(value: '12',   label: 'Regions'),
            _StatChip(value: '4.9★', label: 'Avg Rating'),
            _StatChip(value: '3+',   label: 'Years Running'),
          ]),
          const SizedBox(height: 40),
          // Cards
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: testimonials.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, crossAxisSpacing: 18, mainAxisSpacing: 18, mainAxisExtent: 200),
              itemBuilder: (_, i) {
                final t = testimonials[i];
                return Container(
                  padding: const EdgeInsets.all(22),
                  decoration: _card(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('★★★★★', style: TextStyle(color: HSColors.accent, letterSpacing: 2, fontSize: 13)),
                    const SizedBox(height: 12),
                    Expanded(child: Text('"${t['text']}"', style: const TextStyle(color: HSColors.textSecond, fontStyle: FontStyle.italic, height: 1.55, fontSize: 13))),
                    const SizedBox(height: 14),
                    Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: HSColors.accent,
                        child: Text(t['name']![0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['name']!, style: const TextStyle(color: HSColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(t['location']!.toUpperCase(), style: const TextStyle(color: HSColors.textMuted, fontSize: 10, letterSpacing: 1.2)),
                      ]),
                    ]),
                  ]),
                );
              },
            );
          }),
        ]),
      )),
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
// Section heading
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