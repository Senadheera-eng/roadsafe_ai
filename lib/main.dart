import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart'; // Import the new AppTheme
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // This code must be executed to initialize Firebase services.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization error: $e");
    // You might want to display an error screen here in a production app.
  }

  runApp(const RoadSafeAIApp());
}

class RoadSafeAIApp extends StatelessWidget {
  const RoadSafeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppThemeWrapper(); // Use the new wrapper
  }
}

// NEW: Wrapper to manage theme changes
class AppThemeWrapper extends StatelessWidget {
  const AppThemeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the themeModeNotifier and rebuild the MaterialApp when it changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          title: 'Road Safe AI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme, // Define dark theme
          themeMode: currentThemeMode, // Use the current mode from notifier
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: Assuming FirebaseAuth.instance is accessible
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        // Assuming LoginPage is defined elsewhere
        // return const LoginPage();
        // Fallback for demo environment if LoginPage is missing
        return const HomePage();
      },
    );
  }
}
