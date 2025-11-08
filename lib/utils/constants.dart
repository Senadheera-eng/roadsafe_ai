import 'package:flutter/material.dart';

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
