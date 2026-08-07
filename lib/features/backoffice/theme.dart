import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens of the mobile backoffice (entreprise manager).
///
/// Ported 1:1 from the CSS variables of `backoffice-mobile.html`.
class BackofficeTheme {
  BackofficeTheme._();

  // --- Palette ---
  static const Color green = Color(0xFF0F3D2E);
  static const Color greenSoft = Color(0xFFE7EFE9);
  static const Color gold = Color(0xFFE8A33D);
  static const Color goldSoft = Color(0xFFFBEDD6);
  static const Color goldDim = Color(0xFFB4740E);
  static const Color red = Color(0xFFC1443D);
  static const Color redSoft = Color(0xFFF8E4E2);
  static const Color blue = Color(0xFF3D6BE8);
  static const Color blueSoft = Color(0xFFE7EEFB);
  static const Color cream = Color(0xFFF5F1E8);
  static const Color bg = Color(0xFFF6F4EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAE5D8);
  static const Color text = Color(0xFF182620);
  static const Color muted = Color(0xFF7C8A80);
  static const Color graySoft = Color(0xFFEFEDE5);
  static const Color shell = Color(0xFFDEDBD1); // page body behind the phone
  static const Color success = Color(0xFF1E9E5A);
  static const double radius = 16;

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
}

/// Avatar initials like the design ("PM", "MA"...).
String boInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((w) => w[0]).join().toUpperCase();
}

/// Formats money the fr-FR way: 8000 → "8 000".
String boMoney(int n) {
  final s = n.toString();
  return s.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}

/// Formats a `yyyy-MM-dd` date as "04 Aug".
String boFmtDate(String isoDate) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]) ?? 1;
  final day = parts[2];
  if (month < 1 || month > 12) return isoDate;
  return '$day ${months[month - 1]}';
}
