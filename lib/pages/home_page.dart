import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/feature_card.dart';
import '../widgets/glass_card.dart';
import '../services/camera_service.dart';
import 'live_camera_page.dart';
import 'analytics_page.dart';
import 'device_setup_page.dart';
import 'safety_guide_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'help_support_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CameraService _cameraService = CameraService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Driver';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Road Safe AI',
            style: AppTextStyles.headlineMedium.copyWith(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.oceanGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),

              // Welcome Section
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<bool>(
                        stream: _cameraService.connectionStream,
                        builder: (context, snapshot) {
                          final isConnected = snapshot.data ?? false;
                          return Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? AppColors.success
                                      : AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isConnected
                                    ? 'Device Connected'
                                    : 'Device Disconnected',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Features Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  FeatureCard(
                    icon: Icons.videocam_rounded,
                    title: 'Live Camera',
                    subtitle: 'Monitor in real-time',
                    color: AppColors.primary,
                    gradientColors: AppColors.primaryGradient,
                    onTap: () {
                      if (_cameraService.isConnected) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LiveCameraPage()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DeviceSetupPage()),
                        );
                      }
                    },
                  ),
                  FeatureCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Analytics',
                    subtitle: 'View your stats',
                    color: AppColors.success,
                    gradientColors: AppColors.successGradient,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AnalyticsPage()),
                      );
                    },
                  ),
                  FeatureCard(
                    icon: Icons.router_rounded,
                    title: 'Device Setup',
                    subtitle: 'Connect ESP32-CAM',
                    color: AppColors.accent,
                    gradientColors: AppColors.accentGradient,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DeviceSetupPage()),
                      );
                    },
                  ),
                  FeatureCard(
                    icon: Icons.book_rounded,
                    title: 'Safety Guide',
                    subtitle: 'Learn best practices',
                    color: AppColors.secondary,
                    gradientColors: AppColors.secondaryGradient,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SafetyGuidePage()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.help_outline, color: Colors.white),
                      title: Text(
                        'Help & Support',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white70),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HelpSupportPage()),
                        );
                      },
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white),
                      title: Text(
                        'Sign Out',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white70),
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
