import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import '../widgets/glass_card.dart';
import 'help_support_page.dart';
import '../theme/app_theme.dart'; // Import AppTheme to access the notifier
import '../theme/app_colors.dart'; // Import AppColors for dynamic background

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Toggle states
  bool _alertsEnabled = true;
  bool _notificationsEnabled = false;
  // Initialize dark mode state based on current global value
  bool _darkModeEnabled = AppTheme.themeModeNotifier.value == ThemeMode.dark;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize username controller with current display name if available
    _usernameController.text =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Account Management Methods (Same as previous version) ---

  Future<void> _changeUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'New Username'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(_usernameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != user.displayName) {
      try {
        await user.updateDisplayName(result);
        setState(() {
          // Force a state update to refresh any UI elements using the display name
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating username: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Step 1: Show a complex dialog to gather both current and new passwords
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        final currentPasswordController = TextEditingController();
        final newPasswordController = TextEditingController();

        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                    labelText: 'New Password (min 6 chars)'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'current': currentPasswordController.text,
                  'new': newPasswordController.text,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final currentPassword = result['current']!;
    final newPassword = result['new']!;

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password must be at least 6 characters long.')),
      );
      return;
    }

    try {
      // Step 2: Re-authenticate the user with their current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, // Assuming email is the identifier
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Step 3: Change the password if re-authentication succeeds
      await user.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );

      // Sign out the user after a successful password change for security
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message =
            'The current password you entered is incorrect. Please try again.';
      } else if (e.code == 'user-not-found') {
        message = 'User not found. Please log out and log back in.';
      } else {
        message = 'Error updating password: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  // --- UI Build Method ---

  @override
  Widget build(BuildContext context) {
    // Determine if we are in Dark Mode currently
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // AppBar items now dynamically change color based on the theme
      appBar: AppBar(
        title: Text("Settings",
            style: TextStyle(
                color: isDarkMode ? AppColors.textPrimaryDark : Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDarkMode ? AppColors.textPrimaryDark : Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        // Conditional background: Gradient in Light mode, solid color in Dark mode
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? null // No gradient in dark mode, rely on scaffold background (AppColors.backgroundDark)
              : const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 165, 207, 243),
                    Color(0xFF00f2fe)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDarkMode ? AppColors.backgroundDark : null,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 80),

            // Alerts Toggle
            GlassCard(
              child: SwitchListTile(
                activeColor: Colors.cyanAccent,
                secondary: Icon(Icons.notifications_active,
                    color:
                        isDarkMode ? AppColors.textPrimaryDark : Colors.white),
                title: Text("Drowsiness Alerts",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : Colors.white)),
                subtitle: Text("Enable/disable alerts",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : Colors.white70)),
                value: _alertsEnabled,
                onChanged: (val) {
                  setState(() {
                    _alertsEnabled = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Notifications Toggle
            GlassCard(
              child: SwitchListTile(
                activeColor: Colors.cyanAccent,
                secondary: Icon(Icons.notifications,
                    color:
                        isDarkMode ? AppColors.textPrimaryDark : Colors.white),
                title: Text("Push Notifications",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : Colors.white)),
                subtitle: Text("Daily/weekly safety reports",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : Colors.white70)),
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Dark Mode Toggle
            GlassCard(
              child: SwitchListTile(
                activeColor: Colors.cyanAccent,
                secondary: Icon(Icons.dark_mode,
                    color:
                        isDarkMode ? AppColors.textPrimaryDark : Colors.white),
                title: Text("Dark Mode",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : Colors.white)),
                value: _darkModeEnabled,
                onChanged: (val) {
                  setState(() {
                    _darkModeEnabled = val;
                  });
                  // ** CORE DARK MODE LOGIC **
                  AppTheme.themeModeNotifier.value =
                      val ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
            const SizedBox(height: 32),

            // --- ACCOUNT MANAGEMENT SECTION ---
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                "Account",
                style: TextStyle(
                  color: isDarkMode
                      ? AppColors.textPrimaryDark.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Change Username
            GlassCard(
              child: ListTile(
                leading: Icon(Icons.person_outline,
                    color:
                        isDarkMode ? AppColors.textPrimaryDark : Colors.white),
                title: Text("Change Username",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : Colors.white)),
                onTap: _changeUsername,
              ),
            ),
            const SizedBox(height: 16),

            // Change Password (Now handles re-authentication)
            GlassCard(
              child: ListTile(
                leading: Icon(Icons.lock_outline,
                    color:
                        isDarkMode ? AppColors.textPrimaryDark : Colors.white),
                title: Text("Change Password",
                    style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : Colors.white)),
                onTap: _changePassword,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
