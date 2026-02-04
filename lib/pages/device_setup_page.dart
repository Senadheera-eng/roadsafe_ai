import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import '../services/camera_service.dart';
import 'camera_positioning_page.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  int _currentStep = 0;
  bool _isLoading = false;
  String _statusMessage = '';

  // ESP32 details
  final String esp32SSID = 'RoadSafe-AI-Setup';
  final String esp32SetupURL = 'http://192.168.4.1';

  // Manual IP for final connection
  final TextEditingController _manualIPController = TextEditingController();
  String? _esp32FinalIP;

  @override
  void dispose() {
    _manualIPController.dispose();
    super.dispose();
  }

  // ============================================
  // STEP 1: Open Browser for Configuration
  // ============================================

  Future<void> _openESP32Browser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening ESP32 configuration...';
    });

    try {
      // Check if connected to ESP32 WiFi
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();

      print('📱 Current WiFi: $wifiName');

      if (wifiName != null && wifiName.contains('RoadSafe')) {
        print('✅ Connected to ESP32 WiFi');
      } else {
        print('⚠️ May not be connected to ESP32 WiFi');
      }

      // Open browser to ESP32
      final url = Uri.parse(esp32SetupURL);

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Open in browser
        );

        print('✅ Opened browser to $esp32SetupURL');

        setState(() {
          _isLoading = false;
          _currentStep = 1; // Move to next step
        });

        _showConfigurationInstructions();
      } else {
        throw Exception('Cannot open browser');
      }
    } catch (e) {
      print('❌ Browser open error: $e');
      setState(() {
        _isLoading = false;
      });
      _showError(
          'Cannot Open Browser',
          'Failed to open ESP32 configuration page.\n\n'
              'Please manually open your browser and go to:\nhttp://192.168.4.1');
    }
  }

  void _showConfigurationInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Configure ESP32', style: AppTextStyles.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The ESP32 configuration page should now be open in your browser.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In the browser:',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction('1. Select your home WiFi network'),
                  _buildInstruction('2. Enter the WiFi password'),
                  _buildInstruction('3. Click "Connect to WiFi"'),
                  _buildInstruction('4. Wait for ESP32 to connect'),
                  _buildInstruction('5. Return to this app'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After ESP32 connects, remember to reconnect your phone to the same WiFi network!',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Stay on current step to allow reopening browser
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 2; // Move to search step
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('WiFi Configured'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTextStyles.bodySmall,
      ),
    );
  }

  // ============================================
  // STEP 2: Find ESP32 on Home Network
  // ============================================

  Future<void> _findESP32OnNetwork() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Searching for ESP32 on your network...';
    });

    try {
      // Get phone's current network
      final info = NetworkInfo();
      final myIP = await info.getWifiIP();

      if (myIP == null) {
        throw Exception(
            'Cannot get device IP. Make sure you\'re connected to WiFi.');
      }

      print('📱 Phone IP: $myIP');

      final parts = myIP.split('.');
      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';

      print('🔍 Scanning network: $networkBase.x');

      // IMPROVED: Extended priority IPs based on common router assignments
      final ipsToCheck = [
        // Very common router assignments
        1, // Gateway
        100, 101, 102, 103, 104, 105, // DHCP range start

        // Less common but possible
        17, 42, 50, 51, 52, 53, 54, 55,

        // Additional DHCP ranges
        150, 151, 152, 153, 154, 155,
        200, 201, 202, 203, 204, 205,

        // End of range
        250, 251, 252, 253, 254,
      ];

      // IMPROVED: Parallel scanning for faster results
      print('🔍 Starting parallel scan of ${ipsToCheck.length} IPs...');

      final futures = ipsToCheck.map((ip) async {
        final targetIP = '$networkBase.$ip';

        try {
          final response = await http
              .get(
                Uri.parse('http://$targetIP/'),
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();

            // IMPROVED: Better ESP32 detection
            if (body.contains('roadsafe') ||
                body.contains('drowsiness') ||
                body.contains('esp32-cam') ||
                body.contains('esp32cam') ||
                (body.contains('camera') && body.contains('stream')) ||
                body.contains('mjpeg')) {
              print('✅ Found ESP32 at $targetIP');
              return targetIP;
            }
          }
        } catch (e) {
          // Silently continue
        }

        return null;
      }).toList();

      // Wait for first successful result
      String? foundIP;

      for (var future in futures) {
        final ip = await future;
        if (ip != null) {
          foundIP = ip;
          break;
        }
      }

      if (foundIP != null) {
        print('✅ ESP32 found at $foundIP');

        setState(() {
          _esp32FinalIP = foundIP;
          _currentStep = 3;
          _isLoading = false;
          _statusMessage = '';
        });

        // Save to camera service
        final cameraService = CameraService();
        await cameraService.setDiscoveredIP(foundIP);

        _showSuccessAndFinish(foundIP);
        return;
      }

      // IMPROVED: If parallel scan fails, try sequential scan with more IPs
      print('⚠️ Parallel scan failed, trying sequential full scan...');

      setState(() {
        _statusMessage = 'Performing deep scan...';
      });

      for (int ip = 1; ip <= 254; ip++) {
        final targetIP = '$networkBase.$ip';

        if (ipsToCheck.contains(ip)) continue; // Already checked

        setState(() {
          _statusMessage = 'Checking $targetIP... (${ip}/254)';
        });

        try {
          final response = await http
              .get(
                Uri.parse('http://$targetIP/'),
              )
              .timeout(const Duration(milliseconds: 1500));

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();

            if (body.contains('roadsafe') ||
                body.contains('drowsiness') ||
                body.contains('esp32') ||
                (body.contains('camera') && body.contains('stream'))) {
              print('✅ Found ESP32 at $targetIP (deep scan)');

              setState(() {
                _esp32FinalIP = targetIP;
                _currentStep = 3;
                _isLoading = false;
                _statusMessage = '';
              });

              final cameraService = CameraService();
              await cameraService.setDiscoveredIP(targetIP);

              _showSuccessAndFinish(targetIP);
              return;
            }
          }
        } catch (e) {
          // Continue scanning
        }

        // Break early if taking too long
        if (ip > 200 && !mounted) break;
      }

      // Not found - show manual entry
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      print('❌ ESP32 not found after full scan');
      _showManualIPDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      _showError('Search Failed', e.toString());
    }
  }

  void _showManualIPDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ESP32 Not Found', style: AppTextStyles.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatic scan couldn\'t find the ESP32-CAM.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your ESP32 serial monitor for the IP address and enter it below:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualIPController,
              decoration: InputDecoration(
                labelText: 'ESP32 IP Address',
                hintText: 'e.g., 192.168.1.100',
                prefixIcon: const Icon(Icons.router),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_manualIPController.text.isNotEmpty) {
                _verifyManualIP(_manualIPController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyManualIP(String ip) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying $ip...';
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://$ip/'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Manual IP verified: $ip');

        setState(() {
          _esp32FinalIP = ip;
          _currentStep = 3;
          _isLoading = false;
        });

        // Save to camera service
        final cameraService = CameraService();
        await cameraService.setDiscoveredIP(ip);

        _showSuccessAndFinish(ip);
      } else {
        throw Exception('Device not responding at $ip');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      _showError('Verification Failed',
          'Cannot reach ESP32 at $ip\n\n${e.toString()}');
    }
  }

  void _showSuccessAndFinish(String ip) {
    // Save IP first
    final cameraService = CameraService();
    cameraService.setDiscoveredIP(ip);

    // Show camera positioning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text('ESP32 Found!', style: AppTextStyles.headlineMedium),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ESP32-CAM is ready at $ip',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position the camera correctly for best results',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraPositioningPage(deviceIP: ip),
                ),
              );
            },
            icon: const Icon(Icons.videocam),
            label: const Text('Position Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      [Color? color]) {
    return Row(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // UI HELPERS
  // ============================================

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.headlineSmall)),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // BUILD UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Setup', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _statusMessage,
                              style: AppTextStyles.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildCurrentStepContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildProgressDot(0, 'Connect'),
          _buildProgressLine(0),
          _buildProgressDot(1, 'Configure'),
          _buildProgressLine(1),
          _buildProgressDot(2, 'Find'),
          _buildProgressLine(2),
          _buildProgressDot(3, 'Done'),
        ],
      ),
    );
  }

  Widget _buildProgressDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surfaceVariant,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppColors.primary : AppColors.surfaceVariant,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1ConnectAndOpen();
      case 1:
        return _buildStep2WaitingForConfig();
      case 2:
        return _buildStep3FindOnNetwork();
      case 3:
        return _buildStep4Complete();
      default:
        return const SizedBox();
    }
  }

  // STEP 1: Connect and Open Browser
  Widget _buildStep1ConnectAndOpen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.wifi, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 1: Connect to ESP32',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect your phone to the ESP32 setup network, then we\'ll open the configuration page.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text('Important', style: AppTextStyles.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please disable mobile data before connecting to ESP32 WiFi.',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Instructions:', style: AppTextStyles.labelLarge),
              const SizedBox(height: 12),
              _buildNumberedInstruction(1, 'Power on your ESP32-CAM device'),
              _buildNumberedInstruction(2, 'Disable mobile data on your phone'),
              _buildNumberedInstruction(3, 'Open WiFi settings'),
              _buildNumberedInstruction(4, 'Connect to "RoadSafe-AI-Setup"'),
              _buildNumberedInstruction(5, 'Password: 12345678'),
              _buildNumberedInstruction(6, 'Return to this app'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _openESP32Browser,
          text: 'Open Configuration Page',
          icon: Icons.open_in_browser,
          gradientColors: AppColors.primaryGradient,
        ),
      ],
    );
  }

  Widget _buildNumberedInstruction(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }

  // STEP 2: Waiting for Configuration
  Widget _buildStep2WaitingForConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.settings, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 2: Configure WiFi',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Use the browser page to configure your ESP32.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.language, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Configuration page should be open in your browser',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  'http://192.168.4.1',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('In the browser:', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              _buildInstruction('✓ Select your home WiFi network'),
              _buildInstruction('✓ Enter the WiFi password'),
              _buildInstruction('✓ Click "Connect to WiFi"'),
              _buildInstruction('✓ Wait for ESP32 to connect'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: () {
            setState(() {
              _currentStep = 2;
            });
          },
          text: 'WiFi Configured - Continue',
          icon: Icons.arrow_forward,
          gradientColors: AppColors.successGradient,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openESP32Browser,
          icon: const Icon(Icons.refresh),
          label: const Text('Reopen Configuration Page'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // STEP 3: Find on Network
  Widget _buildStep3FindOnNetwork() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.search, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 3: Find ESP32',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Make sure your phone is connected to the same WiFi network as the ESP32.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _findESP32OnNetwork,
          text: 'Search for Device',
          icon: Icons.search,
          gradientColors: AppColors.primaryGradient,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _showManualIPDialog,
          icon: const Icon(Icons.edit),
          label: const Text('Enter IP Manually'),
        ),
      ],
    );
  }

  // STEP 4: Complete
  Widget _buildStep4Complete() {
    return Column(
      children: [
        const Icon(Icons.check_circle, size: 100, color: AppColors.success),
        const SizedBox(height: 24),
        Text(
          'Setup Complete!',
          style: AppTextStyles.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your ESP32-CAM is ready to use.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
