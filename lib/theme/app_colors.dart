import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors - Road Safety Theme
  static const Color primary = Color(0xFF2E7D32); // Dark Green (Safety)
  static const Color primaryLight = Color(0xFF4CAF50); // Light Green
  static const Color primaryDark = Color(0xFF1B5E20); // Darker Green

  // Secondary Colors - Technology Theme
  static const Color secondary = Color(0xFF1565C0); // Deep Blue (Tech)
  static const Color secondaryLight = Color(0xFF42A5F5); // Light Blue
  static const Color secondaryDark = Color(0xFF0D47A1); // Navy Blue

  // Accent Colors - Warning/Alert System
  static const Color accent = Color(0xFFFF6F00); // Orange (Alert)
  static const Color accentLight = Color(0xFFFFB74D); // Light Orange
  static const Color accentDark = Color(0xFFE65100); // Dark Orange

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFF9800); // Orange
  static const Color error = Color(0xFFD32F2F); // Red
  static const Color info = Color(0xFF2196F3); // Blue

  // Background & Surface Colors
  static const Color background = Color(0xFFF8F9FA); // Light Gray
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Very Light Gray
  static const Color cardShadow = Color(0x1A000000); // 10% Black

  // Text Colors
  static const Color textPrimary = Color(0xFF212121); // Almost Black
  static const Color textSecondary = Color(0xFF757575); // Medium Gray
  static const Color textHint = Color(0xFFBDBDBD); // Light Gray
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onSurface = Color(0xFF212121);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF4CAF50),
    Color(0xFF2E7D32),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1565C0),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFFB74D),
    Color(0xFFFF6F00),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF424242),
    Color(0xFF212121),
  ];

  // Feature Specific Colors
  static const Color cameraFeed = Color(0xFF1976D2); // Blue
  static const Color analytics = Color(0xFF388E3C); // Green
  static const Color deviceSetup = Color(0xFFFF8F00); // Orange
  static const Color guidelines = Color(0xFF7B1FA2); // Purple
  static const Color alerts = Color(0xFFD32F2F); // Red

  // Shimmer Colors (for loading states)
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
