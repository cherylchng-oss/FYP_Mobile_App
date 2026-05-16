import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  static const primary      = Color(0xFF905C3E);
  static const primaryLight = Color(0xFFC09174);

  static const accent       = Color(0xFFB88746);
  static const accentLight  = Color(0xFFE6D3BE);

  static const cream        = Color(0xFFF8F5F2);
  static const cardBg       = Color(0xFFFFFFFF);
  static const surface      = Color(0xFFF1EBE6);
  static const border       = Color(0xFFE2D8D0);

  static const textPrimary  = Color(0xFF40291C);
  static const textSecond   = Color(0xFF6B4A38);
  static const textMuted    = Color(0xFF8C857F);

  static const success      = Color(0xFF2B5136);
  static const warning      = Color(0xFFE0A43A);
  
  static const danger       = Color(0xFFB83232);
  static const drawerBg     = Color(0xFF2C1A0E);

  static const secondary      = Color(0xFF8B5E3C); 
  static const secondaryLight = Color(0xFF8B5E3C);
}

class AppTextStyles {
  static TextStyle get display     => GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w600);
  static TextStyle get h1          => GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w600);
  static TextStyle get h2          => GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600);
  static TextStyle get h3          => GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500);
  static TextStyle get h4          => GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get bodyLarge   => GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w400);
  static TextStyle get bodyDefault => GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall   => GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get label       => GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get caption     => GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500);
}
