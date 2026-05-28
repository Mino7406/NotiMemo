import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const bgLight = Color(0xFFF5F6FF);
  static const bgDark = Color(0xFF0B0C14);

  // Surfaces / Cards
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF161721);
  static const elevatedDark = Color(0xFF1E1F2E);

  // Borders
  static const borderLight = Color(0xFFEAECF5);
  static const borderDark = Color(0xFF252638);

  // Brand gradient
  static const gradStart = Color(0xFF526AE4);
  static const gradEnd = Color(0xFFA459E7);

  // Status
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradStart, gradEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
