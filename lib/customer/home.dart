import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/map.dart';
import '../shared/customer_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.fetchProperties});

  final Future<List<Map<String, dynamic>>> Function()? fetchProperties;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  final List<String> clusters = const [
    'Kuching',
    'Miri',
    'Sibu',
    'Bintulu',
    'Limbang',
    'Sarikei',
    'Sri Aman',
    'Kapit',
    'Mukah',
    'Betong',
    'Samarahan',
    'Serian',
    'Lundu',
    'Lawas',
    'Marudi',
    'Simunjan',
    'Tatau',
    'Belaga',
    'Debak',
    'Kabong',
    'Pusa',
    'Sebuyau',
    'Saratok',
    'Selangau',
    'Tebedu',
  ];

  String selectedCluster = '';
  DateTime? checkIn;
  DateTime? checkOut;
  int adults = 1;
  int children = 0;
  String? activeTab;

  late Future<List<Map<String, dynamic>>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    _propertiesFuture = widget.fetchProperties?.call() ?? Future.value([]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd/mm/yyyy';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _selectCheckIn(DateTime date) {
    setState(() {
      checkIn = date;
      if (checkOut != null && !checkOut!.isAfter(date)) checkOut = null;
      activeTab = 'checkout';
    });
  }

  void _selectCheckOut(DateTime date) {
    setState(() {
      checkOut = date;
      activeTab = 'guests';
    });
  }

  void _clearDates() {
    setState(() {
      checkIn = null;
      checkOut = null;
      activeTab = null;
    });
  }

  void _handleHomeSearch() {
    Navigator.pushNamed(
      context,
      '/product',
      arguments: {
        'filterRegion': selectedCluster,
        'searchDates': {
          'checkIn': checkIn?.toIso8601String(),
          'checkOut': checkOut?.toIso8601String(),
          'adults': adults,
          'children': children,
        },
      },
    );
  }

  void _handleViewDetails(Map<String, dynamic> property) {
    Navigator.pushNamed(
      context,
      '/product/${property['propertyid']}',
      arguments: {
        'propertyDetails': property,
        'searchDates': {
          'checkIn': checkIn?.toIso8601String(),
          'checkOut': checkOut?.toIso8601String(),
          'adults': adults,
          'children': children,
        },
        'filterRegion': selectedCluster.isNotEmpty ? selectedCluster : property['clustername'] ?? '',
      },
    );
  }

  List<Map<String, dynamic>> _featuredProperties(List<Map<String, dynamic>> data) {
    final available = data
        .where((p) => (p['propertystatus'] ?? '').toString() == 'Available')
        .toList();

    available.sort((a, b) {
      final ratingA = double.tryParse('${a['rating'] ?? 0}') ?? 0;
      final ratingB = double.tryParse('${b['rating'] ?? 0}') ?? 0;
      if (ratingB.compareTo(ratingA) != 0) return ratingB.compareTo(ratingA);
      final idA = int.tryParse('${a['propertyid'] ?? 0}') ?? 0;
      final idB = int.tryParse('${b['propertyid'] ?? 0}') ?? 0;
      return idB.compareTo(idA);
    });

    return available.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      selectedIndex: 0,
      backgroundColor: HSColors.darkBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const _NavbarPlaceholder(),
                _HeroSection(
                  onFindStay: () {
                    _scrollController.animateTo(
                      MediaQuery.of(context).size.height - 20,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: HSColors.cream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(48)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x731A140F),
                        blurRadius: 70,
                        offset: Offset(0, -30),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MapSearchSection(
                        clusters: clusters,
                        selectedCluster: selectedCluster,
                        checkInText: _formatDate(checkIn),
                        checkOutText: _formatDate(checkOut),
                        adults: adults,
                        children: children,
                        activeTab: activeTab,
                        onTabChanged: (tab) => setState(() => activeTab = activeTab == tab ? null : tab),
                        onSearch: _handleHomeSearch,
                        panel: _buildPanel(),

                        onRegionSelected: (regionName) {
                          setState(() {
                            selectedCluster = regionName;
                            activeTab = null;
                          });
                        },
                      ),
                      const _AdBannerSection(),
                      _AvailablePropertiesSection(
                        propertiesFuture: _propertiesFuture,
                        featuredBuilder: _featuredProperties,
                        onViewAll: _handleHomeSearch,
                        onViewDetails: _handleViewDetails,
                      ),
                      const _CuratedSection(),
                      const _TestimonialsSection(),
                      const _AppPromoSection(),
                      const _FooterPlaceholder(),
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

  Widget? _buildPanel() {
    switch (activeTab) {
      case 'location':
        return _SearchPanel(
          title: 'Popular destinations',
          child: _ClusterSelector(
            clusters: clusters,
            selectedCluster: selectedCluster,
            onSelected: (value) {
              setState(() {
                selectedCluster = value;
                activeTab = null;
              });
            },
          ),
        );
      case 'checkin':
        return _SearchPanel(
          title: 'Select check-in date',
          action: (checkIn != null || checkOut != null)
              ? TextButton(
                  onPressed: _clearDates,
                  child: const Text('Clear Dates', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                )
              : null,
          child: HomeCalendar(
            value: checkIn,
            minDate: DateTime.now(),
            onChange: _selectCheckIn,
          ),
        );
      case 'checkout':
        return _SearchPanel(
          title: 'Select check-out date',
          action: (checkIn != null || checkOut != null)
              ? TextButton(
                  onPressed: _clearDates,
                  child: const Text('Clear Dates', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                )
              : null,
          child: HomeCalendar(
            value: checkOut,
            disabled: checkIn == null,
            minDate: checkIn?.add(const Duration(days: 1)) ?? DateTime.now(),
            onChange: _selectCheckOut,
          ),
        );
      case 'guests':
        return _SearchPanel(
          title: "Who's coming?",
          child: Column(
            children: [
              _GuestCounter(
                title: 'Adults',
                subtitle: 'Ages 13+',
                value: adults,
                min: 1,
                onChanged: (value) => setState(() => adults = value),
              ),
              const Divider(color: HSColors.border),
              _GuestCounter(
                title: 'Children',
                subtitle: 'Ages 2-12',
                value: children,
                min: 0,
                onChanged: (value) => setState(() => children = value),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }
}

class HSColors {
  static const cream = Color(0xFFF5F0E8);
  static const light = Color(0xFFF8F4EF);
  static const brownDark = Color(0xFF2C2016);
  static const brown = Color(0xFF493829);
  static const brownSoft = Color(0xFF7A6555);
  static const gold = Color(0xFFC4956A);
  static const goldDark = Color(0xFFA9774D);
  static const border = Color(0xFFE8E1D9);
  static const darkBg = Color(0xFF1A140F);
}

class _NavbarPlaceholder extends StatelessWidget {
  const _NavbarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0,
      color: HSColors.darkBg,
    );
  }
}

class _FooterPlaceholder extends StatelessWidget {
  const _FooterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: HSColors.darkBg,
      padding: const EdgeInsets.all(28),
      child: const Text(
        'Footer',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onFindStay});

  final VoidCallback onFindStay;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/WaterFront.jpeg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.3),
            colorBlendMode: BlendMode.darken,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [HSColors.darkBg, Colors.transparent, Color(0x66000000)],
              ),
            ),
          ),
          Positioned(
            left: width > 768 ? 64 : 24,
            right: width > 768 ? 64 : 24,
            bottom: width > 768 ? 96 : 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 30, end: 0),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: 1 - value / 30,
                child: Transform.translate(offset: Offset(0, value), child: child),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: width < 480 ? 32 : width < 768 ? 46 : 72,
                        height: 0.98,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.2,
                        color: Colors.white,
                      ),
                      children: const [
                        TextSpan(text: 'YOUR STORY BEGINS IN '),
                        TextSpan(
                          text: 'SARAWAK.',
                          style: TextStyle(
                            color: HSColors.gold,
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 500,
                    child: Text(
                      'Explore the land of hornbills, ancient caves, and living traditions. Find your perfect homestay today.',
                      style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 30),
                  OutlinedButton(
                    onPressed: onFindStay,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Find a Stay', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSearchSection extends StatelessWidget {
  const _MapSearchSection({
    required this.clusters,
    required this.selectedCluster,
    required this.checkInText,
    required this.checkOutText,
    required this.adults,
    required this.children,
    required this.activeTab,
    required this.onTabChanged,
    required this.onRegionSelected,
    required this.onSearch,
    required this.panel,
  });

  final List<String> clusters;
  final String selectedCluster;
  final String checkInText;
  final String checkOutText;
  final int adults;
  final int children;
  final String? activeTab;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<String> onRegionSelected;
  final VoidCallback onSearch;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width <= 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isSmall ? 16 : 24, isSmall ? 42 : 118, isSmall ? 16 : 24, 50),
      child: Column(
        children: [
          _SearchBar(
            selectedCluster: selectedCluster,
            checkInText: checkInText,
            checkOutText: checkOutText,
            adults: adults,
            children: children,
            activeTab: activeTab,
            onTabChanged: onTabChanged,
            onSearch: onSearch,
            panel: panel,
          ),
          const SizedBox(height: 48),
          const _SectionHeader(
            pill: 'Explore by Region',
            title: 'Find your perfect stay',
            center: true,
          ),
          const SizedBox(height: 28),
          SarawakMapSection(
            onRegionSelected: onRegionSelected,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.selectedCluster,
    required this.checkInText,
    required this.checkOutText,
    required this.adults,
    required this.children,
    required this.activeTab,
    required this.onTabChanged,
    required this.onSearch,
    required this.panel,
  });

  final String selectedCluster;
  final String checkInText;
  final String checkOutText;
  final int adults;
  final int children;
  final String? activeTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onSearch;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width <= 900;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1260),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 18 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(isSmall ? 30 : 999),
              border: Border.all(color: HSColors.border),
              boxShadow: const [BoxShadow(color: Color(0x29493829), blurRadius: 48, offset: Offset(0, 20))],
            ),
            child: isSmall
                ? Column(
                    children: _fields(isSmall) + [const SizedBox(height: 12), _searchButton(isSmall)],
                  )
                : Row(
                    children: [Expanded(child: Row(children: _fields(isSmall))), const SizedBox(width: 14), _searchButton(isSmall)],
                  ),
          ),
          if (panel != null)
            Positioned(
              top: isSmall ? 360 : 96,
              left: isSmall ? 0 : null,
              right: isSmall ? 0 : 80,
              child: Center(child: panel!),
            ),
        ],
      ),
    );
  }

  List<Widget> _fields(bool isSmall) {
    return [
      _SearchField(
        label: 'Where',
        value: selectedCluster.isEmpty ? 'Search destinations' : selectedCluster,
        icon: Icons.location_on_rounded,
        active: activeTab == 'location',
        onTap: () => onTabChanged('location'),
        isSmall: isSmall,
      ),
      _SearchField(
        label: 'Check in',
        value: checkInText,
        icon: Icons.calendar_month_outlined,
        active: activeTab == 'checkin',
        onTap: () => onTabChanged('checkin'),
        isSmall: isSmall,
      ),
      _SearchField(
        label: 'Check out',
        value: checkOutText,
        icon: Icons.calendar_month_outlined,
        active: activeTab == 'checkout',
        onTap: () => onTabChanged('checkout'),
        isSmall: isSmall,
      ),
      _SearchField(
        label: 'Who',
        value: '$adults adults, $children children',
        icon: Icons.people_alt_rounded,
        active: activeTab == 'guests',
        onTap: () => onTabChanged('guests'),
        isSmall: isSmall,
      ),
    ];
  }

  Widget _searchButton(bool isSmall) {
    return SizedBox(
      width: isSmall ? double.infinity : 70,
      height: isSmall ? 56 : 70,
      child: ElevatedButton(
        onPressed: onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: HSColors.gold,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmall ? 18 : 999)),
          elevation: 8,
        ),
        child: const Icon(Icons.search_rounded, size: 26),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.label,
    required this.value,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.isSmall,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isSmall ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: isSmall ? null : 58,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: active ? HSColors.light : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: isSmall ? const Border(bottom: BorderSide(color: HSColors.border)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: HSColors.brownSoft,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(icon, color: HSColors.brown, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: HSColors.brownDark, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: math.min(MediaQuery.of(context).size.width * 0.9, 430),
        constraints: const BoxConstraints(maxHeight: 430),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: HSColors.border),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x2E493829), blurRadius: 45, offset: Offset(0, 18))],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        color: HSColors.brown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterSelector extends StatelessWidget {
  const _ClusterSelector({required this.clusters, required this.selectedCluster, required this.onSelected});

  final List<String> clusters;
  final String selectedCluster;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final allItems = ['All Areas', ...clusters];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allItems.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisExtent: 46,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = allItems[index];
        final value = item == 'All Areas' ? '' : item;
        final selected = selectedCluster == value;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelected(value),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF7ED) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? HSColors.gold : const Color(0xFFE2E8F0), width: selected ? 2 : 1),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: selected ? HSColors.gold : const Color(0xFF4A5568),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuestCounter extends StatelessWidget {
  const _GuestCounter({required this.title, required this.subtitle, required this.value, required this.min, required this.onChanged});

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: HSColors.brown, fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: HSColors.brownSoft, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              _RoundCounterButton(icon: Icons.remove, onTap: () => onChanged(math.max(min, value - 1))),
              SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
              _RoundCounterButton(icon: Icons.add, onTap: () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundCounterButton extends StatelessWidget {
  const _RoundCounterButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: HSColors.gold),
        ),
        child: Icon(icon, color: HSColors.gold, size: 18),
      ),
    );
  }
}

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key, required this.value, required this.minDate, required this.onChange, this.disabled = false});

  final DateTime? value;
  final DateTime minDate;
  final ValueChanged<DateTime> onChange;
  final bool disabled;

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  late int viewYear;
  late int viewMonth;

  @override
  void initState() {
    super.initState();
    final initial = widget.value ?? widget.minDate;
    viewYear = initial.year;
    viewMonth = initial.month;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
  int _firstWeekdayIndex(int year, int month) => DateTime(year, month, 1).weekday % 7;

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    final first = _firstWeekdayIndex(viewYear, viewMonth);
    final totalDays = _daysInMonth(viewYear, viewMonth);
    final today = _dateOnly(DateTime.now());
    final minDate = _dateOnly(widget.minDate);

    return Opacity(
      opacity: widget.disabled ? 0.55 : 1,
      child: IgnorePointer(
        ignoring: widget.disabled,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CalendarNavButton(
                  icon: Icons.chevron_left,
                  onTap: () {
                    setState(() {
                      if (viewMonth == 1) {
                        viewMonth = 12;
                        viewYear--;
                      } else {
                        viewMonth--;
                      }
                    });
                  },
                ),
                Text('${months[viewMonth - 1]} $viewYear', style: const TextStyle(color: HSColors.brownDark, fontWeight: FontWeight.w800)),
                _CalendarNavButton(
                  icon: Icons.chevron_right,
                  onTap: () {
                    setState(() {
                      if (viewMonth == 12) {
                        viewMonth = 1;
                        viewYear++;
                      } else {
                        viewMonth++;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              childAspectRatio: 1.25,
              children: [
                for (final day in days)
                  Center(child: Text(day, style: const TextStyle(color: Color(0xFF9A8B7D), fontSize: 10, fontWeight: FontWeight.w800))),
                for (int i = 0; i < first; i++) const SizedBox.shrink(),
                for (int day = 1; day <= totalDays; day++)
                  _CalendarDayButton(
                    day: day,
                    disabled: DateTime(viewYear, viewMonth, day).isBefore(minDate),
                    selected: widget.value != null && _isSameDate(widget.value!, DateTime(viewYear, viewMonth, day)),
                    today: _isSameDate(today, DateTime(viewYear, viewMonth, day)),
                    onTap: () => widget.onChange(DateTime(viewYear, viewMonth, day)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: HSColors.cream, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: HSColors.brown),
      ),
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({required this.day, required this.disabled, required this.selected, required this.today, required this.onTap});

  final int day;
  final bool disabled;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = HSColors.brownDark;
    if (selected) {
      bg = HSColors.gold;
      fg = Colors.white;
    } else if (today) {
      bg = HSColors.light;
      fg = HSColors.gold;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            '$day',
            style: TextStyle(
              color: disabled ? Colors.grey.shade300 : fg,
              fontSize: 12,
              fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.pill, required this.title, this.subtitle, this.center = false});

  final String pill;
  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            border: Border.all(color: HSColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            pill.toUpperCase(),
            style: const TextStyle(color: HSColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontFamily: 'Georgia',
            color: HSColors.brown,
            fontSize: 42,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle!, style: const TextStyle(color: HSColors.brownSoft, fontSize: 17)),
        ],
      ],
    );
  }
}

class _SarawakMapPlaceholder extends StatelessWidget {
  const _SarawakMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1120, minHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HSColors.border),
      ),
      child: const Center(
        child: Text(
          'Sarawak Map Component Here',
          style: TextStyle(color: HSColors.brownSoft, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AdBannerSection extends StatelessWidget {
  const _AdBannerSection();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/AdBanner.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xCC000000), Color(0x66000000), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 768 ? 64 : 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: HSColors.gold), borderRadius: BorderRadius.circular(999), color: Colors.black26),
                      child: const Text('FEATURED EVENT', style: TextStyle(color: HSColors.gold, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Sarawak Rainforest World Music Festival',
                      style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 54, fontWeight: FontWeight.w800, height: 1.05),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Experience the rhythm of the jungle. Get your early bird tickets now.',
                      style: TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: const StadiumBorder()),
                      child: const Text('Book Tickets', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailablePropertiesSection extends StatelessWidget {
  const _AvailablePropertiesSection({required this.propertiesFuture, required this.featuredBuilder, required this.onViewAll, required this.onViewDetails});

  final Future<List<Map<String, dynamic>>> propertiesFuture;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) featuredBuilder;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String, dynamic>> onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(child: _SectionHeader(pill: '', title: 'Available Properties', subtitle: 'Highly rated stays across Sarawak.')),
                  if (MediaQuery.of(context).size.width > 768)
                    OutlinedButton(
                      onPressed: onViewAll,
                      style: OutlinedButton.styleFrom(foregroundColor: HSColors.gold, side: const BorderSide(color: HSColors.gold), shape: const StadiumBorder()),
                      child: const Text('View All →'),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: propertiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const _PropertyGridSkeleton();
                  final featured = featuredBuilder(snapshot.data ?? []);
                  if (featured.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(color: HSColors.light, borderRadius: BorderRadius.circular(20), border: Border.all(color: HSColors.border)),
                      child: const Text('No available properties found.', textAlign: TextAlign.center, style: TextStyle(color: HSColors.brownSoft, fontWeight: FontWeight.w600)),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 620 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: featured.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          mainAxisExtent: 390,
                        ),
                        itemBuilder: (context, index) => _PropertyCard(property: featured[index], onTap: () => onViewDetails(featured[index])),
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

class _PropertyGridSkeleton extends StatelessWidget {
  const _PropertyGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 620 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 360),
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: HSColors.border)),
            child: Column(children: [Container(height: 220, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))))]),
          ),
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.onTap});

  final Map<String, dynamic> property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageList = property['propertyimage'];
    final firstImage = imageList is List && imageList.isNotEmpty ? '${imageList.first}' : null;
    final rating = double.tryParse('${property['rating'] ?? ''}');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: HSColors.border), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: firstImage == null
                    ? Container(color: Colors.grey.shade100, child: const Center(child: Text('No images available', style: TextStyle(color: Colors.grey))))
                    : Image.network(firstImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Center(child: Text('Image unavailable')))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${property['propertyaddress'] ?? 'Unnamed Property'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HSColors.brownDark, fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      if (rating != null) ...[
                        Text(rating.toStringAsFixed(rating % 1 == 0 ? 1 : 2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''), style: const TextStyle(fontWeight: FontWeight.w800, color: HSColors.brown)),
                        const Icon(Icons.star_rounded, size: 18, color: HSColors.gold),
                      ] else
                        const Text('No reviews', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${property['clustername'] ?? 'Sarawak'}', style: const TextStyle(color: HSColors.brownSoft)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(foregroundColor: HSColors.gold, side: const BorderSide(color: HSColors.gold), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Select dates for price', style: TextStyle(fontWeight: FontWeight.w800)),
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

class _CuratedSection extends StatelessWidget {
  const _CuratedSection();

  @override
  Widget build(BuildContext context) {
    const destinations = [
      {'name': 'Bako National Park', 'tag': 'Wildlife & Rainforest', 'img': 'assets/Bako.jpg'},
      {'name': 'Gunung Mulu', 'tag': 'UNESCO Heritage', 'img': 'assets/Mulu.jpg'},
      {'name': 'Damai Beach', 'tag': 'Coastal Escape', 'img': 'assets/Damai.jpg'},
      {'name': 'Semenggoh', 'tag': 'Orangutan Sanctuary', 'img': 'assets/Semenggoh.jpg'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 110),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [HSColors.brownDark, Color(0xFF1F1711)]),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 32,
                runSpacing: 24,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const Text('Curated\nExperiences.', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 64, fontWeight: FontWeight.w800, height: 0.95)),
                  OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(foregroundColor: HSColors.gold, side: const BorderSide(color: HSColors.gold), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)), child: const Text('Discover Attractions →')),
                ],
              ),
              const SizedBox(height: 52),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 768 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: destinations.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 22, mainAxisSpacing: 22, mainAxisExtent: 280),
                    itemBuilder: (context, index) => _CuratedCard(data: destinations[index]),
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

class _CuratedCard extends StatelessWidget {
  const _CuratedCard({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(data['img']!, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xE62C2016), Colors.transparent]),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 26,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['tag']!.toUpperCase(), style: const TextStyle(color: HSColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                const SizedBox(height: 8),
                Text(data['name']!, style: const TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  @override
  Widget build(BuildContext context) {
    const testimonials = [
      {'name': 'Sarah Jenkins', 'location': 'UK', 'text': 'Booking through CAMS was seamless. The homestay in Kuching gave us an incredible, authentic Sarawak experience!'},
      {'name': 'Ahmad Fazil', 'location': 'KL', 'text': 'The interactive map made planning our road trip so easy. Highly recommend the properties in Mulu.'},
      {'name': 'Elena Rossi', 'location': 'Italy', 'text': 'Beautiful platform with amazing customer support. Our stay at the longhouse was unforgettable.'},
    ];

    return Container(
      width: double.infinity,
      color: HSColors.cream,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionHeader(pill: 'Community & Trust', title: 'Stories from our guests', center: true),
              const SizedBox(height: 44),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: const [
                  StatItem(end: 500, label: 'Happy Guests', suffix: '+'),
                  StatItem(end: 12, label: 'Regions Covered'),
                  StatItem(end: 4.9, label: 'Avg Rating', suffix: '★', isFloat: true),
                  StatItem(end: 3, label: 'Years Running', suffix: '+'),
                ],
              ),
              const SizedBox(height: 52),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: testimonials.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: _TestimonialCard(data: t),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatItem extends StatefulWidget {
  const StatItem({super.key, required this.end, required this.label, this.suffix = '', this.isFloat = false});

  final double end;
  final String label;
  final String suffix;
  final bool isFloat;

  @override
  State<StatItem> createState() => _StatItemState();
}

class _StatItemState extends State<StatItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HSColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A493829), blurRadius: 30, offset: Offset(0, 8))],
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = widget.end * _animation.value;
          return Column(
            children: [
              Text(
                '${widget.isFloat ? value.toStringAsFixed(1) : value.round()}${widget.suffix}',
                style: const TextStyle(fontFamily: 'Georgia', color: HSColors.brown, fontSize: 42, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: HSColors.brownSoft, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: HSColors.border), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('★★★★★', style: TextStyle(color: HSColors.gold, letterSpacing: 2)),
          const SizedBox(height: 16),
          Text('"${data['text']}"', style: const TextStyle(color: HSColors.brown, fontStyle: FontStyle.italic, height: 1.5)),
          const SizedBox(height: 24),
          Row(
            children: [
              AvatarCircle(name: data['name']!),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name']!, style: const TextStyle(color: HSColors.brownDark, fontWeight: FontWeight.w800)),
                  Text(data['location']!.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.4)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.src});

  final String name;
  final String? src;

  @override
  Widget build(BuildContext context) {
    if (src != null && src!.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(src!));
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: HSColors.gold,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _AppPromoSection extends StatelessWidget {
  const _AppPromoSection();

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      color: const Color(0xFF251D16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 90),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Flex(
            direction: isSmall ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: isSmall ? 0 : 1,
                child: Column(
                  crossAxisAlignment: isSmall ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    const Text('Sarawak,\nin your pocket.', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 58, height: 1.05, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 22),
                    const Text('Manage your homestay bookings, receive instant notifications, and chat with property owners directly from your pocket.', style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.55)),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.shop_rounded),
                      label: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GET IT ON', style: TextStyle(fontSize: 10, color: Colors.white70)),
                          Text('Google Play', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: HSColors.brownDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 60, height: 42),
              Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: 260,
                  height: 550,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(42), border: Border.all(color: const Color(0xFF333333), width: 4), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 60, offset: Offset(0, 30))]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset('assets/AppScreenshot.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: HSColors.cream, child: const Center(child: Text('App Screenshot', style: TextStyle(color: HSColors.brown, fontWeight: FontWeight.w800))))),
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
