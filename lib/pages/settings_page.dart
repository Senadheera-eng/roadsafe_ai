import 'package:flutter/material.dart';
import 'home_page.dart';
import '../widgets/glass_card.dart';

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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false, // remove all previous routes
            );
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
            const SizedBox(height: 16),

            // Help & Support
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.white),
                title: const Text("Help & Support",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Navigate to help
                },
              ),
            ),
            const SizedBox(height: 16),

            // Logout
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: () {
                  // Add logout logic
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
