import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
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
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),

            Text(
              'We are here to help you drive safe.',
              style: AppTextStyles.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // FAQ Section
            Text(
              'Frequently Asked Questions (FAQ)',
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildFAQTile(
              title: 'How do I connect my ESP32 CAM?',
              content:
                  'Go to the Device Setup page and follow the step-by-step instructions to connect your module to the local Wi-Fi and pair it with the app.',
            ),
            _buildFAQTile(
              title: 'What causes a Drowsiness Alert?',
              content:
                  'Alerts are triggered by a combination of factors, including prolonged eye closures, excessive yawning, and head position changes detected by the AI model on the ESP32 CAM.',
            ),
            _buildFAQTile(
              title: 'How accurate is the detection?',
              content:
                  'The AI model is trained on diverse datasets and provides high accuracy. Ensure the ESP32 CAM is positioned correctly on the dashboard for the best results.',
            ),
            const SizedBox(height: 24),

            // Contact Section
            Text(
              'Contact Support',
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.email_rounded, color: Colors.white),
                title: const Text('Email Support',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('support@roadsafeai.com',
                    style: TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () {
                  // TODO: Implement email intent
                },
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.call_rounded, color: Colors.white),
                title: const Text('Emergency Line',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('+1 (800) 555-SAFE (Placeholder)',
                    style: TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () {
                  // TODO: Implement phone call intent
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTile({required String title, required String content}) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
