import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens of the Super Admin console.
///
/// Ported 1:1 from the CSS variables of `super-admin-desktop.html`.
class SuperAdminTheme {
  SuperAdminTheme._();

  // --- Palette ---
  static const Color ink = Color(0xFF12151A);
  static const Color inkSoft = Color(0xFF1B2027);
  static const Color gold = Color(0xFFE8A33D);
  static const Color goldSoft = Color(0xFFFBEDD6);
  static const Color goldDim = Color(0xFFB4740E);
  static const Color green = Color(0xFF1E9E5A);
  static const Color greenSoft = Color(0xFFE5F5EC);
  static const Color red = Color(0xFFC1443D);
  static const Color redSoft = Color(0xFFF8E4E2);
  static const Color blue = Color(0xFF3D6BE8);
  static const Color blueSoft = Color(0xFFE7EEFB);
  static const Color cream = Color(0xFFF5F1E8);
  static const Color bg = Color(0xFFF6F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E5DE);
  static const Color text = Color(0xFF181A1D);
  static const Color muted = Color(0xFF84868C);
  static const Color rowHover = Color(0xFFFBFAF7);
  static const Color inkLine = Color(0x17F5F1E8); // cream @ ~9%

  // --- Metrics ---
  static const double sidebarWidth = 248;
  static const double sidebarWidthCollapsed = 76;
  static const double radius = 14;

  // --- Typography ---
  static TextStyle sora(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = text,
    double? height,
  }) {
    return GoogleFonts.sora(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle inter(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = text,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  // --- Surfaces ---
  static BoxDecoration card() {
    return BoxDecoration(
      color: surface,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static BoxDecoration chip(Color bgColor) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    );
  }
}

/// Utility to build avatar initials like the design ("PM", "SA"...).
String saInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final letters = parts.take(2).map((w) => w[0]).join();
  return letters.toUpperCase();
}
