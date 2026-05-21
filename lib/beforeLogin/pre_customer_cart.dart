import 'package:flutter/material.dart';
import 'pre_customer_room.dart';
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
}

class CustomerCartNotLogin extends StatefulWidget {
  const CustomerCartNotLogin({super.key});

  @override
  State<CustomerCartNotLogin> createState() => _CustomerCartNotLoginState();
}

class _CustomerCartNotLoginState extends State<CustomerCartNotLogin> {
  @override
  Widget build(BuildContext context) {
    return PreCustomerLayout(
      selectedIndex: 1,
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          _buildCartHeader(MediaQuery.of(context).padding.top),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
                child: _loginRequiredCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildCartHeader(double topPad) {
    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          // Background image
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

          // Dark brown overlay
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
                // Left icon box
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
                    Icons.shopping_cart_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Login to view your cart\nand manage bookings.',
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

                // Login icon
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/login');
                  },
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

  // ─────────────────────────────────────────────
  // Login required card
  // ─────────────────────────────────────────────
  Widget _loginRequiredCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 58,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 26),

          const Text(
            'Please login to view your cart',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          const Text(
            'You need to be logged in to access your shopping cart and manage your bookings.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecond,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerRoomsNotLogin(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Browse Properties',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}