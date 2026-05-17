import 'package:flutter/material.dart';
import 'ask_question_form.dart';
import '../shared/customer_layout.dart';
import 'package:flutter/services.dart';
import '../api.dart' as api;
import '../services/session.dart'; 
import '../shared/colors.dart';

// ─────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────
class _C {
  static const primary       = AdminColors.primary;
  static const primaryLight  = AdminColors.primaryLight;
  static const accent        = AdminColors.accent;
  static const accentLight   = AdminColors.accentLight;
  static const cream         = AdminColors.cream;
  static const surface       = AdminColors.surface;
  static const surfaceAlt    = Color(0xFFF0E6D8);
  static const border        = AdminColors.border;
  static const borderDark    = Color(0xFFD5B896);
  static const textPrimary   = AdminColors.textPrimary;
  static const textSecond    = AdminColors.textSecond;
  static const textMuted     = AdminColors.textMuted;
  static const highlight     = Color(0x3DC4956A);
  static const white         = Colors.white;
}

BoxDecoration _card({double radius = 18, Color? bg, bool elevated = false}) =>
    BoxDecoration(
      color: bg ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _C.border),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: _C.primary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              )
            ]
          : [
              BoxShadow(
                color: _C.primary.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
    );

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────
class FaqCategory {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const FaqCategory({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

class FaqItem {
  final String id;
  final String category;
  final String question;
  final String answer;
  final String? tip;
  final bool isList;
  final bool isPublished;
  final String? sourceRole;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.tip,
    this.isList = false,
    this.isPublished = false,
    this.sourceRole,
  });
}

// ─────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────
class CustomerFAQ extends StatefulWidget {
  const CustomerFAQ({super.key});

  @override
  State<CustomerFAQ> createState() => _CustomerFAQState();
}

class _CustomerFAQState extends State<CustomerFAQ> {
  final ScrollController _scrollController = ScrollController();

  String activeCategory = 'booking';
  String? openId;
  bool showSupportForm = false;
  List<FaqItem> publishedFaqs = [];
  bool isFaqLoading = false;

  int _unreadCount = 0;

  final Map<String, String> feedbackState = {};
  final Map<String, GlobalKey> faqKeys = {};
  final GlobalKey faqContentKey = GlobalKey();
  final GlobalKey supportFormKey = GlobalKey();

  final List<FaqCategory> faqCategories = const [
    FaqCategory(
      id: 'account',
      label: 'Account & Login',
      subtitle: 'Registration, signing in, and managing your credentials.',
      icon: Icons.person_outline_rounded,
    ),
    FaqCategory(
      id: 'browse',
      label: 'Browse & Properties',
      subtitle: 'Finding the right place to stay in Sarawak.',
      icon: Icons.explore_outlined,
    ),
    FaqCategory(
      id: 'booking',
      label: 'Booking',
      subtitle:
          'How bookings work — from adding to cart to managing your reservations.',
      icon: Icons.calendar_today_outlined,
    ),
    FaqCategory(
      id: 'payment',
      label: 'Payment',
      subtitle: 'Paying for your booking securely.',
      icon: Icons.payment_outlined,
    ),
    FaqCategory(
      id: 'notifications',
      label: 'Notifications',
      subtitle: 'Room suggestions and booking alerts via the bell icon.',
      icon: Icons.notifications_none_rounded,
    ),
    FaqCategory(
      id: 'reviews',
      label: 'Reviews',
      subtitle: 'Writing, editing, and viewing your property reviews.',
      icon: Icons.star_border_rounded,
    ),
  ];

  final List<FaqItem> defaultFaqs = const [
    FaqItem(
      id: 'acc1',
      category: 'account',
      question: 'How do I create a new account?',
      answer:
          "Go to the Login page and click Sign Up. Fill in your first name, last name, username, email address, phone number, and password, then click Sign Up to submit. Your account will be created and ready to use immediately.",
      tip:
          "💡 Make sure your email address is valid because you'll need it to receive booking confirmations and password resets.",
    ),
    FaqItem(
      id: 'acc2',
      category: 'account',
      question: 'How do I log in to my account?',
      answer:
          "Navigate to the Login page, enter your email or username and password, then click Login. You'll be redirected to the homepage upon success. You can also sign in using your Google account by clicking the Google button on the login page.",
    ),
    FaqItem(
      id: 'acc4',
      category: 'account',
      question: 'How do I reset my password if I forgot it?',
      answer:
          'On the Login page, click Forgot Password. Enter your registered email address and click Send New Password. A new temporary password will be sent to your email inbox.',
      tip:
          "⚠️ Check your spam or junk folder if you don't see the email within a few minutes.",
    ),
    FaqItem(
      id: 'brw1',
      category: 'browse',
      question: 'How do I find available properties?',
      answer:
          'There are two ways to browse properties:\n1. Go to the Homepage, locate the interactive Sarawak map, click on a region/location, and press Find Stays. Then enter your check-in and check-out dates.\n2. Go directly to the Rooms page, enter your check-in and check-out dates, and view all matching properties.',
      isList: true,
    ),
    FaqItem(
      id: 'brw4',
      category: 'browse',
      question: 'What do greyed-out dates on the calendar mean?',
      answer:
          'Greyed-out dates are blackout dates. These are periods when the property is unavailable for booking, such as maintenance, private events, or holidays. You cannot select these dates when making a booking.',
    ),
    FaqItem(
      id: 'bkg1',
      category: 'booking',
      question: 'How do I book a room that is available?',
      answer:
          '1. Select a property and open its details page.\n2. Confirm your check-in and check-out dates and check the total price.\n3. Click Book and Pay, then Add to Cart.\nYour booking will be added to your Cart with a status of Accepted.',
      isList: true,
    ),
    FaqItem(
      id: 'bkg2',
      category: 'booking',
      question: 'What happens when a room is fully booked?',
      answer:
          'If a room is fully booked for your selected dates, click Enquiry or Waitlist instead. Your booking will be added to the Cart with a Pending status and a request will be sent to the property moderator. The moderator may suggest an alternative room for you.',
    ),
    FaqItem(
      id: 'pay1',
      category: 'payment',
      question: 'How do I pay for my booking?',
      answer:
          'Go to Cart and find a reservation with Accepted status. Click Pay Now. A payment form will appear. Click Pay with PayPal to be redirected to the PayPal gateway, where you can complete the transaction securely.',
    ),
    FaqItem(
      id: 'pay3',
      category: 'payment',
      question: 'What is a checkout timer?',
      answer:
          'Once you initiate checkout, a timer starts counting down. If the timer expires before you complete payment, your booking will be automatically cancelled and removed from your cart. Make sure to complete payment before the timer runs out.',
    ),
    FaqItem(
      id: 'not2',
      category: 'notifications',
      question: 'What is a room suggestion notification?',
      answer:
          "If your booking request was for a fully booked room, the moderator may suggest an alternative available room. You'll receive a notification in your bell icon showing the suggested property's address, check-in and check-out dates, and total price.",
    ),
    FaqItem(
      id: 'rev1',
      category: 'reviews',
      question: 'How do I write a review?',
      answer:
          'You can only review a property after your check-out date. Go to Cart, then Reservations History. Find the completed booking and click Write/View Review. Fill in the form with your ratings and comments, then click Submit Review.',
    ),
  ];

  final List<String> quickPickIds = const ['brw4', 'bkg1', 'pay1'];

  String? normalizeCustomerCategory(String category) {
    final value = category.toLowerCase().trim();
    if (value == 'account') return 'account';
    if (value == 'browse') return 'browse';
    if (value == 'booking') return 'booking';
    if (value == 'payment') return 'payment';
    if (value == 'notifications') return 'notifications';
    if (value == 'reviews') return 'reviews';
    return null;
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

  Future<void> loadPublishedFaqs() async {
    try {
      setState(() => isFaqLoading = true);

      final result = await api.fetchPublishedFaqs(category: 'all', search: '');
      final backendFaqs = result['faqs'] ?? [];
      final formattedFaqs = <FaqItem>[];

      for (final item in backendFaqs) {
        final faq = Map<String, dynamic>.from(item as Map);
        final normalizedCategory =
            normalizeCustomerCategory('${faq['category'] ?? ''}');

        if (normalizedCategory == null) continue;

        formattedFaqs.add(
          FaqItem(
            id: 'published-${faq['id'] ?? faq['faqid'] ?? faq['questionid']}',
            category: normalizedCategory,
            question: '${faq['q'] ?? faq['question'] ?? ''}',
            answer: '${faq['a'] ?? faq['answer'] ?? ''}',
            sourceRole: '${faq['sourcerole'] ?? faq['sourceRole'] ?? ''}',
            isPublished: true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          publishedFaqs = formattedFaqs;
          for (final faq in faqs) {
            faqKeys.putIfAbsent(faq.id, () => GlobalKey());
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isFaqLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();

    _loadUnreadCount();

    for (final faq in faqs) {
      faqKeys[faq.id] = GlobalKey();
    }

    loadPublishedFaqs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  FaqCategory? get activeCat {
    try {
      return faqCategories.firstWhere((cat) => cat.id == activeCategory);
    } catch (_) {
      return null;
    }
  }

  List<FaqItem> get faqs {
    final existingQuestions =
        defaultFaqs.map((faq) => faq.question.toLowerCase().trim()).toSet();

    final uniquePublishedFaqs = publishedFaqs.where((faq) {
      final questionText = faq.question.toLowerCase().trim();
      return questionText.isNotEmpty && !existingQuestions.contains(questionText);
    }).toList();

    return [...uniquePublishedFaqs, ...defaultFaqs];
  }

  List<FaqItem> get filteredFaqs {
    return faqs.where((faq) => faq.category == activeCategory).toList();
  }

  List<FaqItem> get quickPicks =>
      faqs.where((faq) => quickPickIds.contains(faq.id)).toList();

  int catCount(String catId) =>
      faqs.where((faq) => faq.category == catId).length;

  void selectCategory(String catId) {
    setState(() {
      activeCategory = catId;
      openId = null;
    });

    scrollToKey(faqContentKey);
  }

  void keepScrollAfterSetState(VoidCallback update) {
    final oldOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    setState(update);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final maxOffset = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(oldOffset.clamp(0.0, maxOffset));
    });
  }

  void scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  void scrollToForm() {
    setState(() {
      showSupportForm = true;
    });

    scrollToKey(supportFormKey);
  }

  void handleQuickPick(FaqItem faq) {
    setState(() {
      activeCategory = faq.category;
      openId = faq.id;
    });

    scrollToKey(faqContentKey);
  }

  void handleFeedback(String faqId, String type) {
    setState(() {
      feedbackState[faqId] = type;
    });
  }

  TextStyle get _qStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _C.textPrimary,
        height: 1.4,
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: CustomerLayout(
        selectedIndex: 3,
        backgroundColor: _C.cream,
        appBar: null,
        body: SingleChildScrollView(
          key: const PageStorageKey<String>('customer_faq_scroll'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: Column(
            children: [
              _buildHero(),
              _buildMainContent(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationBell() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/customer-notifications')
            .then((_) => _loadUnreadCount());
      },
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

          if (_unreadCount > 0)
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
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
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
    );
  }

  // ── Hero ──────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 22,
        20,
        58,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF3D1F0A),
            _C.primary,
            _C.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -60,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.accentLight.withOpacity(0.08),
              ),
            ),
          ),

          Positioned(
            top: -4,
            right: 2,
            child: _notificationBell(),
          ),
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;

                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroBadge(),
                      const SizedBox(height: 16),
                      const Text(
                        'How can we help?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Find answers about bookings, payments, notifications, reviews, and account support.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: 32),
                        _stats(),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      content,
                      const SizedBox(height: 22),
                      _stats(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.support_agent_rounded,
            color: _C.accentLight,
            size: 15,
          ),
          SizedBox(width: 7),
          Text(
            'CUSTOMER HELP CENTER',
            style: TextStyle(
              color: _C.accentLight,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat(faqs.length.toString(), 'Answers',
              Icons.question_answer_rounded),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withOpacity(0.18),
          ),
          _stat(faqCategories.length.toString(), 'Topics',
              Icons.category_rounded),
        ],
      ),
    );
  }

  Widget _stat(String number, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _C.accentLight.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: _C.accentLight,
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Main content ──────────────────────────────
  Widget _buildMainContent() {
    return Transform.translate(
      offset: const Offset(0, -26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 760;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 248, child: _sidebar()),
                      const SizedBox(width: 24),
                      Expanded(child: _contentPanel()),
                    ],
                  );
                }

                return Column(
                  children: [
                    _sidebar(),
                    const SizedBox(height: 20),
                    _contentPanel(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 4),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TOPICS',
                  style: TextStyle(
                    color: _C.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ...faqCategories.map((cat) {
            final isActive = activeCategory == cat.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => selectCategory(cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? _C.borderDark : Colors.transparent,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: _C.primary.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _C.accent.withOpacity(0.1)
                              : _C.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          cat.icon,
                          size: 17,
                          color: isActive ? _C.accent : _C.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isActive ? _C.textPrimary : _C.textSecond,
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _C.accent.withOpacity(0.12)
                              : _C.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          catCount(cat.id).toString(),
                          style: TextStyle(
                            color: isActive ? _C.accent : _C.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Divider(color: _C.border, height: 24),
          InkWell(
            onTap: scrollToForm,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Still need help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

  Widget _contentPanel() {
    final title = activeCat?.label ?? 'FAQ';
    final desc = activeCat?.subtitle ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: faqContentKey,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: _C.primary.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (activeCat != null)
                    Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_C.accent, _C.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          Icon(activeCat!.icon, color: Colors.white, size: 22),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: const TextStyle(
                              color: _C.textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (isFaqLoading) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(
                  color: _C.accent,
                  backgroundColor: _C.surface,
                ),
              ],
            ],
          ),
        ),
        if (filteredFaqs.isEmpty)
          _emptyState()
        else
          ...filteredFaqs.map(_accordionItem),
        _supportSection(),
      ],
    );
  }

  Widget _accordionItem(FaqItem faq) {
    final isOpen = openId == faq.id;

    return Container(
      key: faqKeys[faq.id],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen ? _C.accent : _C.border,
          width: isOpen ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(isOpen ? 0.10 : 0.04),
            blurRadius: isOpen ? 20 : 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              keepScrollAfterSetState(() {
                openId = isOpen ? null : faq.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(faq.question, style: _qStyle),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isOpen ? _C.primary : _C.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isOpen ? Colors.white : _C.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _accordionBody(faq),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _accordionBody(FaqItem faq) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _C.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formatAnswer(faq.answer, faq.isList),
          if (faq.isPublished) ...[
            const SizedBox(height: 16),
            _tipBox('📌 Published by Admin', isAdmin: true),
          ],
          if (faq.tip != null) ...[
            const SizedBox(height: 16),
            _tipBox(faq.tip!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Was this helpful?',
                style: TextStyle(
                  color: _C.textSecond,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              _feedbackBtn(faq.id, 'up', '👍'),
              const SizedBox(width: 8),
              _feedbackBtn(faq.id, 'down', '👎'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipBox(String text, {bool isAdmin = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF1E6),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(left: BorderSide(color: _C.accent, width: 4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.textSecond,
          height: 1.6,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _formatAnswer(String text, bool isList) {
    if (!isList) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          text,
          style: const TextStyle(
            color: _C.textSecond,
            fontSize: 14,
            height: 1.75,
          ),
        ),
      );
    }

    final lines = text.split('\n');

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final match = RegExp(r'^(\d+)\.\s(.+)').firstMatch(line);

          if (match != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _C.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      match.group(1)!,
                      style: const TextStyle(
                        color: _C.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      match.group(2)!,
                      style: const TextStyle(
                        color: _C.textSecond,
                        fontSize: 14,
                        height: 1.75,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (line.trim().isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _feedbackBtn(String faqId, String type, String emoji) {
    final isActive = feedbackState[faqId] == type;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => handleFeedback(faqId, type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? (type == 'down' ? const Color(0xFFB14B38) : _C.primary)
              : _C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? (type == 'down' ? const Color(0xFFB14B38) : _C.primary)
                : _C.border,
          ),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _C.textMuted,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No results found',
            style: TextStyle(
              color: _C.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search term or browse a topic.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportSection() {
    return Container(
      key: supportFormKey,
      margin: const EdgeInsets.only(top: 28),
      child: showSupportForm ? _askQuestionFormBlock() : _supportCard(),
    );
  }

  Widget _supportCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D1F0A), _C.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 520;

          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SUPPORT',
                  style: TextStyle(
                    color: _C.accentLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Can't find what you're looking for?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send your question to our team. We usually respond within 24 hours.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          );

          final button = InkWell(
            onTap: scrollToForm,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, color: _C.primary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Ask a Question',
                    style: TextStyle(
                      color: _C.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );

          if (isSmall) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textBlock,
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textBlock),
              const SizedBox(width: 18),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _askQuestionFormBlock() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(color: _C.border),
              left: BorderSide(color: _C.border),
              right: BorderSide(color: _C.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: _C.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask a Question',
                      style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Please provide your question details below.',
                      style: TextStyle(
                        color: _C.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  keepScrollAfterSetState(() {
                    showSupportForm = false;
                  });
                },
                style: TextButton.styleFrom(foregroundColor: _C.textMuted),
                child: const Text(
                  'Hide Form',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        AskQuestionForm(
          role: 'Customer',
          categories: faqCategories
              .map((cat) => FAQCategory(id: cat.id, label: cat.label))
              .toList(),
          theme: 'customer',
        ),
      ],
    );
  }
}