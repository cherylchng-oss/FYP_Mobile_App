import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  static const primary      = Color(0xFF6B3F1A);
  static const primaryLight = Color(0xFF8B5E3C);
  static const accent       = Color(0xFFBF8040);
  static const accentLight  = Color(0xFFE8B97A);
  static const secondary      = Color(0xFF82916C); // muted olive green
  static const secondaryLight = Color(0xFFA3B08F); // light olive green
  static const cream        = Color(0xFFFFFFFF);
  static const cardBg       = Color(0xFFFFFFFF);
  static const surface      = Color(0xFFFFFFFF);
  static const border       = Color(0xFFE0E0E0);
  static const textPrimary  = Color(0xFF2C1A0E);
  static const textSecond   = Color(0xFF6B4C30);
  static const textMuted    = Color(0xFFA07850);
  static const success      = Color(0xFF3D7A5C);
  static const danger       = Color(0xFFB83232);
  static const drawerBg     = Color(0xFF2C1A0E);
  static const drawerAccent = Color(0xFF8B5E3C);
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
