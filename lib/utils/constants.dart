import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF42A5F5);
  static const Color accent = Color(0xFF0D47A1);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF212121);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class AppStrings {
  static const String appName = 'Road Safe AI';
  static const String appDescription = 'Driver Drowsiness Detection System';
  static const String loginTitle = 'Welcome Back';
  static const String registerTitle = 'Create Account';
  static const String forgotPassword = 'Forgot Password?';
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = "Already have an account? ";
  static const String signUp = 'Sign Up';
  static const String login = 'Login';
  static const String createAccount = 'Create Account';

  // Validation messages
  static const String emailRequired = 'Please enter your email';
  static const String emailInvalid = 'Please enter a valid email';
  static const String passwordRequired = 'Please enter your password';
  static const String passwordWeak = 'Password must be at least 6 characters';
  static const String nameRequired = 'Please enter your name';

  // Success messages
  static const String loginSuccess = 'Login successful!';
  static const String registerSuccess = 'Account created successfully!';

  // Feature titles
  static const String liveCamera = 'Live Camera';
  static const String analytics = 'Analytics';
  static const String deviceSetup = 'Device Setup';
  static const String guidelines = 'Guidelines';
}

class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const double iconSize = 24.0;
  static const double largeIconSize = 48.0;
}
