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
import 'wifi_config_page.dart'; // IMPORTANT: Add this import

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
  final String esp32SetupIP = '192.168.4.1';

  // Configured IP from WiFi setup
  String? _configuredIP;

  @override
  void dispose() {
    _manualIPController.dispose();
    super.dispose();
  }

  // Controller for manual IP entry
  final TextEditingController _manualIPController = TextEditingController();

  // ============================================
  // SKIP TO POSITIONING (WiFi Already Configured)
  // ============================================

  Future<void> _skipToPositioning() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking for ESP32...';
    });

    try {
      // Try to get cached/last known IP
      final cachedIP = await CameraService().getCachedDeviceIP();

      if (cachedIP != null) {
        print('📦 Found cached IP: $cachedIP');

        // Try to connect to cached IP
        setState(() {
          _statusMessage = 'Connecting to $cachedIP...';
        });

        final device = ESP32Device(
          ipAddress: cachedIP,
          deviceName: 'RoadSafe AI - ESP32-CAM',
          isConnected: false,
        );

        final success = await CameraService().connectToDevice(device);

        setState(() {
          _isLoading = false;
        });

        if (success) {
          // Go directly to camera positioning
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CameraPositioningPage(deviceIP: cachedIP),
            ),
          );
        } else {
          throw Exception('Cannot connect to $cachedIP');
        }
      } else {
        setState(() {
          _isLoading = false;
        });

        _showError(
          'No Configured Device',
          'No previously configured ESP32 found.\n\n'
              'Please complete the WiFi configuration first:\n'
              '1. Connect to "RoadSafe-AI-Setup"\n'
              '2. Configure your home WiFi\n'
              '3. Then you can use this shortcut',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showError(
        'Connection Failed',
        'Could not connect to your configured ESP32.\n\n'
            'This could mean:\n'
            '• ESP32 is powered off\n'
            '• ESP32 is not on the WiFi network\n'
            '• WiFi configuration was reset\n\n'
            'Please complete the setup process.',
      );
    }
  }

  // ============================================
  // STEP 1: Configure WiFi IN APP
  // ============================================

  Future<void> _openWiFiConfig() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening WiFi configuration...';
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

      setState(() {
        _isLoading = false;
      });

      // Open WiFi config page IN APP (not browser!)
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => WiFiConfigPage(esp32IP: esp32SetupIP),
        ),
      );

      // If WiFi was configured successfully, result contains the IP
      if (result != null && result.isNotEmpty) {
        print('✅ WiFi configured! ESP32 IP: $result');

        setState(() {
          _configuredIP = result;
          _currentStep = 2; // Skip to "Connect" step
        });

        // Save IP to camera service
        await CameraService().setDiscoveredIP(result);
      } else {
        print('⚠️ WiFi configuration cancelled or failed');
      }
    } catch (e) {
      print('❌ WiFi config error: $e');
      setState(() {
        _isLoading = false;
      });
      _showError(
          'Configuration Error',
          'Failed to open WiFi configuration.\n\n'
              'Please make sure you\'re connected to "$esp32SSID" WiFi network.');
    }
  }

  // ============================================
  // STEP 2: Connect to Device (Direct IP)
  // ============================================

  Future<void> _connectToDevice() async {
    if (_configuredIP == null) {
      _showError('No IP Address',
          'ESP32 IP address not found. Please configure WiFi first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ESP32 at $_configuredIP...';
    });

    try {
      print('\n🔗 Connecting to ESP32-CAM at $_configuredIP...');

      final device = ESP32Device(
        ipAddress: _configuredIP!,
        deviceName: 'RoadSafe AI - ESP32-CAM',
        isConnected: false,
      );

      final success = await CameraService().connectToDevice(device);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        print('✅ Connected successfully!');
        setState(() {
          _currentStep = 3; // Move to complete step
        });
        _showSuccessAndFinish(_configuredIP!);
      } else {
        throw Exception('Connection failed');
      }
    } catch (e) {
      print('❌ Connection error: $e');
      setState(() {
        _isLoading = false;
      });
      _showError(
        'Connection Failed',
        'Cannot connect to ESP32 at $_configuredIP\n\n'
            'Please make sure:\n'
            '• ESP32 is powered on\n'
            '• Your phone is connected to the same WiFi network\n'
            '• ESP32 successfully connected to WiFi\n\n'
            'Error: $e',
      );
    }
  }

  // Connect using a manually entered IP address
  Future<void> _connectToManualIP() async {
    final manualIP = _manualIPController.text.trim();
    if (manualIP.isEmpty) {
      _showError('No IP Entered', 'Please enter the device IP address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ESP32 at $manualIP...';
    });

    try {
      final device = ESP32Device(
        ipAddress: manualIP,
        deviceName: 'RoadSafe AI - ESP32-CAM',
        isConnected: false,
      );

      final success = await CameraService().connectToDevice(device);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        setState(() {
          _configuredIP = manualIP;
          _currentStep = 3;
        });
        _showSuccessAndFinish(manualIP);
      } else {
        throw Exception('Connection failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Connection Failed',
          'Cannot connect to ESP32 at $manualIP\n\nError: $e');
    }
  }

  // ============================================
  // FORGET WIFI (Using Stored IP - No Search!)
  // ============================================

  void _showForgetWiFiDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Forget WiFi Network',
                style: AppTextStyles.headlineSmall,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will reset your ESP32-CAM to setup mode.',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
                  Row(
                    children: [
                      const Icon(Icons.info, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Text('What will happen:',
                          style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ESP32 will forget saved WiFi\n'
                    '• Device will restart in AP mode\n'
                    '• You can reconnect to "RoadSafe-AI-Setup"\n'
                    '• Configure new WiFi network',
                    style: AppTextStyles.bodySmall,
                  ),
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
                      'This will disconnect your current session',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _performWiFiReset();
            },
            icon: const Icon(Icons.wifi_off),
            label: const Text('Reset WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performWiFiReset() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Resetting ESP32 WiFi...';
    });

    try {
      final cameraService = CameraService();
      bool success = false;

      // Try to get the stored/configured IP
      String? targetIP =
          _configuredIP ?? cameraService.connectedDevice?.ipAddress;

      if (targetIP != null) {
        print('🔄 Attempting reset at known IP: $targetIP');

        setState(() {
          _statusMessage = 'Sending reset to $targetIP...';
        });

        try {
          final response = await http.post(
            Uri.parse('http://$targetIP/reset'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            print('✅ Reset successful at $targetIP');
            success = true;
          }
        } catch (e) {
          print('⚠️ Reset failed at $targetIP: $e');
        }
      }

      // Fallback: Try AP mode IP
      if (!success) {
        print('🔄 Trying ESP32 AP mode (192.168.4.1)...');
        setState(() {
          _statusMessage = 'Trying AP mode (192.168.4.1)...';
        });

        try {
          final response = await http.post(
            Uri.parse('http://192.168.4.1/reset'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            print('✅ Reset via AP mode successful');
            success = true;
          }
        } catch (e) {
          print('❌ AP mode reset failed: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (success) {
        _showResetSuccessDialog();
      } else {
        _showError(
          'Reset Failed',
          'Could not reset ESP32 WiFi settings.\n\n'
              'Please try:\n'
              '1. Make sure ESP32 is powered on\n'
              '2. Connect your phone to the same WiFi network\n'
              '3. Try again, or manually restart the ESP32 device',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      _showError('Reset Error', e.toString());
    }
  }

  void _showResetSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 8),
            const Text('WiFi Reset Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESP32 has been reset to setup mode.',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Next steps:', style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. ESP32 is now in AP mode\n'
                    '2. Connect to "RoadSafe-AI-Setup"\n'
                    '3. Configure WiFi in the app\n'
                    '4. Connect to your configured device',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _currentStep = 0; // Go back to step 1
                _configuredIP = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Over'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SUCCESS DIALOG
  // ============================================

  void _showSuccessAndFinish(String ip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child:
                  Text('ESP32 Connected!', style: AppTextStyles.headlineMedium),
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

  // ============================================
  // HELPER METHODS
  // ============================================

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.headlineSmall),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
  // UI BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Device Setup', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Progress Indicator
                _buildProgressIndicator(),
                const SizedBox(height: 32),

                // Current Step Content
                if (_currentStep == 0) _buildStep1ConnectToAP(),
                if (_currentStep == 1) _buildStep2ConfigureWiFi(),
                if (_currentStep == 2) _buildStep3ConnectToDevice(),
                if (_currentStep == 3) _buildStep4Complete(),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Progress Indicator
  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildStepCircle(1, 'Connect', _currentStep >= 0),
        _buildProgressLine(_currentStep >= 1),
        _buildStepCircle(2, 'Configure', _currentStep >= 1),
        _buildProgressLine(_currentStep >= 2),
        _buildStepCircle(3, 'Setup', _currentStep >= 2),
        _buildProgressLine(_currentStep >= 3),
        _buildStepCircle(4, 'Done', _currentStep >= 3),
      ],
    );
  }

  Widget _buildStepCircle(int number, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: active
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$number',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? AppColors.primary : Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? AppColors.primary : Colors.grey[300],
        margin: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  // STEP 1: Connect to AP
  Widget _buildStep1ConnectToAP() {
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
          'Connect your phone to the ESP32 WiFi network',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
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
              const Icon(Icons.router, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'ESP32 WiFi Network',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SSID:', style: AppTextStyles.labelMedium),
                        Text(esp32SSID,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            )),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Password:', style: AppTextStyles.labelMedium),
                        Text('12345678',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
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
              const SizedBox(height: 8),
              _buildNumberedInstruction(1, 'Open WiFi settings on your phone'),
              _buildNumberedInstruction(2, 'Look for "$esp32SSID" network'),
              _buildNumberedInstruction(3, 'Connect using password: 12345678'),
              _buildNumberedInstruction(4, 'Return to this app'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          text: 'Connected - Continue',
          icon: Icons.arrow_forward,
          gradientColors: AppColors.successGradient,
        ),
        const SizedBox(height: 16),

        // NEW: WiFi Already Configured Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WiFi Already Configured?',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'If you\'ve already configured WiFi before, skip setup and go directly to camera positioning.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToConfiguredStep,
                  icon: const Icon(Icons.videocam),
                  label: const Text('WiFi Configured - Position Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _goToConfiguredStep() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking for configured device...';
    });

    try {
      final cachedIP = await CameraService().getCachedDeviceIP();

      setState(() {
        _configuredIP = cachedIP;
        _currentStep = 2; // Show Connect/Reset step so user sees IP and reset
        _isLoading = false;
        _statusMessage = '';
      });

      // Optionally try a quick connect in background (do not auto-navigate)
      Future(() async {
        try {
          final success = await CameraService().quickConnect();
          if (success && mounted) {
            // keep user on the Connect screen — they can press Connect
            setState(() async {
              _configuredIP = await CameraService().getCachedDeviceIP();
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      // Still show the connect step so user can attempt reset or manual connect
      setState(() {
        _currentStep = 2;
      });
    }
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

  // STEP 2: Configure WiFi (IN APP!)
  Widget _buildStep2ConfigureWiFi() {
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
          'Configure your home WiFi network for the ESP32',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
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
                'WiFi Configuration',
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
                child: Text(
                  'You will configure your home WiFi in the next screen',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
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
              Text('You will need:', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              _buildInstruction('✓ Your home WiFi network name (SSID)'),
              _buildInstruction('✓ Your home WiFi password'),
              _buildInstruction('✓ ESP32 will connect and get an IP address'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _openWiFiConfig,
          text: 'Configure WiFi',
          icon: Icons.settings,
          gradientColors: AppColors.primaryGradient,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = 0;
            });
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // STEP 3: Connect to Device (Direct IP - No Scanning!)
  Widget _buildStep3ConnectToDevice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.link, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        Text(
          'Step 3: Connect to Device',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'WiFi configured successfully!',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.successGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'ESP32 Connected to WiFi',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('IP Address:', style: AppTextStyles.labelMedium),
                        Text(_configuredIP ?? 'Unknown',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            )),
                      ],
                    ),
                  ],
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
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Make sure your phone is connected to the same WiFi network',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _connectToDevice,
          text: 'Connect to Device',
          icon: Icons.link,
          gradientColors: AppColors.successGradient,
        ),
        const SizedBox(height: 32),
        // Forget WiFi Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Need to reconfigure WiFi?',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'If you need to connect ESP32 to a different WiFi network, reset it to setup mode.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showForgetWiFiDialog,
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('Forget WiFi Network'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
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
