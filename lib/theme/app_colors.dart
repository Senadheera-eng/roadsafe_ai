import 'package:flutter/material.dart';

class AppColors {
  // Modern Vibrant Primary Colors - Electric Blue Theme
  static const Color primary = Color(0xFF0066FF); // Electric Blue
  static const Color primaryLight = Color(0xFF3385FF); // Light Electric Blue
  static const Color primaryDark = Color(0xFF0052CC); // Dark Electric Blue

  // Secondary Colors - Purple Theme
  static const Color secondary = Color(0xFF8B5CF6); // Vibrant Purple
  static const Color secondaryLight = Color(0xFFA78BFA); // Light Purple
  static const Color secondaryDark = Color(0xFF7C3AED); // Dark Purple

  // Accent Colors - Gradient Orange to Pink
  static const Color accent = Color(0xFFFF6B35); // Vibrant Orange
  static const Color accentLight = Color(0xFFFF8A65); // Light Orange
  static const Color accentDark = Color(0xFFE8581C); // Dark Orange

  // Additional Vibrant Colors
  static const Color tertiary = Color(0xFFE91E63); // Hot Pink
  static const Color quaternary = Color(0xFF00BCD4); // Cyan

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Background & Surface Colors
  static const Color background = Color(0xFFF8FAFC); // Very Light Blue Gray
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Light Blue Gray
  static const Color cardShadow = Color(0x1A000000); // 10% Black

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Dark Slate
  static const Color textSecondary = Color(0xFF64748B); // Slate Gray
  static const Color textHint = Color(0xFFCBD5E1); // Light Slate
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onSurface = Color(0xFF0F172A);

  // Modern Gradient Combinations
  static const List<Color> primaryGradient = [
    Color(0xFF0066FF), // Electric Blue
    Color(0xFF8B5CF6), // Purple
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF8B5CF6), // Purple
    Color(0xFFE91E63), // Hot Pink
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFF6B35), // Orange
    Color(0xFFE91E63), // Hot Pink
  ];

  static const List<Color> successGradient = [
    Color(0xFF10B981), // Emerald
    Color(0xFF059669), // Dark Emerald
  ];

  // ADDED: Gradient for Info/Blue actions (Fixes the error)
  static const List<Color> infoGradient = [
    Color(0xFF3B82F6), // Info Blue
    Color(0xFF00BCD4), // Cyan (Quaternary)
  ];

  static const List<Color> darkGradient = [
    Color(0xFF1E293B), // Dark Slate
    Color(0xFF334155), // Slate
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B35), // Orange
    Color(0xFFE91E63), // Hot Pink
    Color(0xFF8B5CF6), // Purple
  ];

  static const List<Color> oceanGradient = [
    Color(0xFF0066FF), // Electric Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF10B981), // Emerald
  ];

  // Feature Specific Colors
  static const Color cameraFeed = Color(0xFF0066FF); // Electric Blue
  static const Color analytics = Color(0xFF10B981); // Emerald Green
  static const Color deviceSetup = Color(0xFFFF6B35); // Vibrant Orange
  static const Color guidelines = Color(0xFF8B5CF6); // Purple
  static const Color alerts = Color(0xFFEF4444); // Red

  // Glass Effect Colors
  static const Color glassSurface = Color(0x80FFFFFF); // 50% White
  static const Color glassBorder = Color(0x40FFFFFF); // 25% White

  // Shimmer Colors (for loading states)
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
}
