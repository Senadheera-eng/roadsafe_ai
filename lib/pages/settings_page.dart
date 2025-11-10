import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import '../widgets/glass_card.dart';
import 'help_support_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Toggle states
  bool _alertsEnabled = true;
  bool _notificationsEnabled = false;
  bool _darkModeEnabled = false;

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

  // --- Account Management Methods ---

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 165, 207, 243), Color(0xFF00f2fe)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 80),

            // Alerts Toggle
            GlassCard(
              child: SwitchListTile(
                activeColor: Colors.cyanAccent,
                secondary:
                    const Icon(Icons.notifications_active, color: Colors.white),
                title: const Text("Drowsiness Alerts",
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text("Enable/disable alerts",
                    style: TextStyle(color: Colors.white70)),
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
                secondary: const Icon(Icons.notifications, color: Colors.white),
                title: const Text("Push Notifications",
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text("Daily/weekly safety reports",
                    style: TextStyle(color: Colors.white70)),
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
                secondary: const Icon(Icons.dark_mode, color: Colors.white),
                title: const Text("Dark Mode",
                    style: TextStyle(color: Colors.white)),
                value: _darkModeEnabled,
                onChanged: (val) {
                  setState(() {
                    _darkModeEnabled = val;
                  });
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
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Change Username
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white),
                title: const Text("Change Username",
                    style: TextStyle(color: Colors.white)),
                onTap: _changeUsername,
              ),
            ),
            const SizedBox(height: 16),

            // Change Password (Now handles re-authentication)
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.white),
                title: const Text("Change Password",
                    style: TextStyle(color: Colors.white)),
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
