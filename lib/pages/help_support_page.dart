import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Utility Functions ---

  // Function to simulate launching a URL (for external links like app store)
  Future<void> _launchURL(String url) async {
    // REAL CODE: if (await canLaunchUrl(Uri.parse(url))) { await launchUrl(Uri.parse(url)); }
    _showInfoSnackBar('Redirecting to external link: $url');
  }

  // CORE FIX: Function to handle opening the email client
  Future<void> _sendEmail() async {
    const email = 'roadsafeai.official@gmail.com';
    const subject = 'Support Request - RoadSafe AI App';
    const body = 'Please describe your issue below:';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject&body=$body',
    );

    // Example of real launch logic (Requires the standard import)
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showInfoSnackBar('Could not open email client.');
    }

    // Simulation (this code runs when the real launch code is commented out):
    //_showInfoSnackBar('Opening email client for: $email');
  }

  // NEW: Rating Dialog Function
  void _showRatingDialog() {
    double selectedRating = 0;

    // Determine if we are in Dark Mode currently for dialog styling
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppColors.primaryLight : AppColors.primary;
    final surfaceColor = isDarkMode ? AppColors.surfaceDark : AppColors.surface;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.star_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Rate RoadSafe AI', style: AppTextStyles.titleLarge),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Tap a star to give us your rating:',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRating = starIndex.toDouble();
                            });
                          },
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: Icon(
                              starIndex <= selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: starIndex <= selectedRating
                                  ? AppColors.warning
                                  : AppColors.textHint,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (selectedRating > 0)
                    Text(
                      selectedRating >= 4
                          ? 'Thank you for the high rating!'
                          : 'We appreciate your feedback!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Maybe Later',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: selectedRating == 0
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showInfoSnackBar(
                              'Your ${selectedRating.toInt()} star response has been recorded. Thank you!');
                        },
                  child: Text('Submit & Review',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: AppColors.purpleGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Coming Soon!',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$feature is currently under development and will be available in the next update.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.blueGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.info_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text('About RoadSafe AI', style: AppTextStyles.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'RoadSafe AI is an advanced driver drowsiness detection system that uses ESP32-CAM hardware and AI-powered analysis to keep drivers safe on the road.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 RoadSafe AI. All rights reserved.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient Background
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.greenGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),

                      // Icon Background
                      Positioned(
                        right: -60,
                        top: -60,
                        child: Icon(
                          Icons.help_rounded,
                          size: 300,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),

                      // Title
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.support_agent_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Help & Support',
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'We\'re here to help you drive safe',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Contact Support ---
                      _buildSectionTitle('Contact Support'),
                      const SizedBox(height: 12),

                      _buildContactCard(
                        icon: Icons.email_rounded,
                        title: 'Email Support',
                        subtitle: 'roadsafeai.official@gmail.com',
                        description:
                            'Get help via email - We respond within 24 hours',
                        gradient: AppColors.blueGradient,
                        onTap: _sendEmail,
                      ),

                      const SizedBox(height: 32),

                      // --- FAQ Section ---
                      _buildSectionTitle('Frequently Asked Questions'),
                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.link_rounded,
                        iconColor: AppColors.info,
                        title: 'How do I connect my ESP32-CAM?',
                        content:
                            'To connect your ESP32-CAM device:\n\n1. Navigate to the Device Setup page from the home screen\n2. Make sure your ESP32-CAM is powered on and in pairing mode\n3. Follow the step-by-step instructions to connect your device to WiFi\n4. The app will automatically detect and pair with your ESP32-CAM\n5. Once connected, you\'ll see a live camera feed\n\nIf you encounter issues, try restarting both the device and the app.',
                      ),

                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.warning_rounded,
                        iconColor: AppColors.warning,
                        title: 'What triggers a drowsiness alert?',
                        content:
                            'Our AI-powered drowsiness detection system monitors several factors:\n\n• Prolonged eye closures (more than 1 second)\n• Frequent yawning patterns\n• Head position and nodding movements\n• Eye opening percentage below threshold\n\nWhen drowsiness is detected, the system immediately:\n• Triggers a loud audio alert\n• Activates strong vibration patterns\n• Displays a visual warning on screen\n\nYou can adjust the detection sensitivity in Settings.',
                      ),

                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.speed_rounded,
                        iconColor: AppColors.success,
                        title: 'How accurate is the detection?',
                        content:
                            'Our detection system uses advanced AI trained on diverse datasets:\n\n✓ 95%+ accuracy in optimal lighting\n✓ Real-time processing (< 100ms latency)\n✓ Works in various lighting conditions\n✓ Adaptive to different facial features\n\nFor best results:\n• Position the ESP32-CAM at eye level\n• Ensure good lighting in your vehicle\n• Keep the camera lens clean\n• Mount the device securely on your dashboard',
                      ),

                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.battery_alert_rounded,
                        iconColor: AppColors.error,
                        title: 'Why is my device not connecting?',
                        content:
                            'If you\'re having connection issues, try these steps:\n\n1. Check WiFi Connection\n   • Ensure your phone is connected to WiFi\n   • Verify the ESP32-CAM is on the same network\n\n2. Restart Devices\n   • Power cycle your ESP32-CAM\n   • Close and reopen the app\n\n3. Check IP Address\n   • Verify the ESP32-CAM IP address\n   • Try manual connection from Settings\n\n4. Firewall/Router\n   • Check if your router blocks local devices\n   • Temporarily disable firewall to test\n\nIf issues persist, contact our support team.',
                      ),

                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.tips_and_updates_rounded,
                        iconColor: AppColors.accent,
                        title: 'Safety tips for long drives',
                        content:
                            'Follow these tips for safe long-distance driving:\n\n• Take breaks every 2 hours or 100 miles\n• Get at least 7-8 hours of sleep before driving\n• Stay hydrated and avoid heavy meals\n• Keep the vehicle well-ventilated\n• Share driving duties when possible\n• Don\'t rely solely on technology - listen to your body\n• If you feel drowsy, pull over safely and rest\n\nRemember: RoadSafe AI is an assistance tool, not a replacement for proper rest and alertness.',
                      ),

                      const SizedBox(height: 12),

                      _buildFAQTile(
                        icon: Icons.settings_suggest_rounded,
                        iconColor: AppColors.primary,
                        title: 'How do I adjust alert settings?',
                        content:
                            'Customize your alert preferences:\n\n1. Open the Settings page from the menu\n2. Navigate to "Alert Preferences" section\n3. Toggle options:\n   • Sound Alerts - Enable/disable audio\n   • Vibration - Control vibration intensity\n   • Detection Sensitivity - Low/Medium/High\n   • Auto-Start - Automatic detection on connect\n\nRecommended Settings:\n• High sensitivity for night driving\n• Medium for daytime\n• Enable both sound and vibration for maximum effectiveness',
                      ),

                      const SizedBox(height: 32),

                      // --- Additional Resources ---
                      _buildSectionTitle('Additional Resources'),
                      const SizedBox(height: 12),

                      // 1. Rate Our App (Calls _showRatingDialog)
                      _buildResourceCard(
                        icon: Icons.star_rounded,
                        title: 'Rate Our App',
                        subtitle: 'Share your experience with us',
                        gradient: AppColors.purpleGradient,
                        onTap: _showRatingDialog,
                      ),

                      const SizedBox(height: 12),

                      // 2. About RoadSafe AI (Calls _showAboutDialog)
                      _buildResourceCard(
                        icon: Icons.info_rounded,
                        title: 'About RoadSafe AI',
                        subtitle: 'View version and company information',
                        gradient: AppColors.blueGradient,
                        onTap: _showAboutDialog,
                      ),

                      const SizedBox(height: 12),

                      // 3. Report a Bug (Calls _showComingSoonDialog)
                      _buildResourceCard(
                        icon: Icons.bug_report_rounded,
                        title: 'Report a Bug',
                        subtitle: 'Help us improve the app',
                        gradient: AppColors.orangeGradient,
                        onTap: () {
                          _showComingSoonDialog('Bug Report');
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: gradient.first,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: gradient.first,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
