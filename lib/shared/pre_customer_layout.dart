import 'package:flutter/material.dart';
import 'colors.dart';

class PreCustomerLayout extends StatelessWidget {
  const PreCustomerLayout({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.backgroundColor = const Color(0xFFFAF6F0),
  });

  final Widget body;
  final int selectedIndex;
  final Color backgroundColor;

  static const primary = AdminColors.primary;
  static const accent = AdminColors.accent;
  static const cream = AdminColors.cream;
  static const border = AdminColors.border;
  static const textMuted = AdminColors.textMuted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: body,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _navItem(
                context,
                0,
                Icons.hotel_rounded,
                Icons.hotel_outlined,
                'Stay',
                '/pre-customer-rooms',
              ),
              _navItem(
                context,
                1,
                Icons.shopping_cart_rounded,
                Icons.shopping_cart_outlined,
                'Cart',
                '/pre-customer-cart',
              ),
              _navItem(
                context,
                2,
                Icons.calendar_today_rounded,
                Icons.calendar_today_outlined,
                'Bookings',
                '/pre-customer-bookings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    String route,
  ) {
    final selected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (selected) return;

          Navigator.of(context).pushReplacementNamed(route);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6B3210),
                            Color(0xFFD4952A),
                          ],
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? activeIcon : inactiveIcon,
                  color: selected ? Colors.white : textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? primary : textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}