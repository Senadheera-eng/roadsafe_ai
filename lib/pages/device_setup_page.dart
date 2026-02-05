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
import 'wifi_config_page.dart';

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
  bool _connectionTested = false;

  @override
  void initState() {
    super.initState();
    _checkExistingConfiguration();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ============================================
  // CHECK FOR EXISTING CONFIGURATION
  // ============================================

  Future<void> _checkExistingConfiguration() async {
    final cachedIP = await CameraService().getCachedDeviceIP();

    if (cachedIP != null) {
      print('📦 Found existing configuration: $cachedIP');

      // Show option to skip to positioning or reconfigure
      if (mounted) {
        _showExistingConfigDialog(cachedIP);
      }
    }
  }

  void _showExistingConfigDialog(String cachedIP) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: 8),
            const Expanded(child: Text('Existing Configuration')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESP32-CAM is already configured.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.router, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Text('Last IP:', style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cachedIP,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to use this configuration or set up a new one?',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start fresh setup
              setState(() {
                _currentStep = 0;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
            ),
            child: const Text('New Setup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _skipToPositioning();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use Existing'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SKIP TO POSITIONING (WiFi Already Configured)
  // ============================================

  Future<void> _skipToPositioning() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking for ESP32...';
    });

    try {
      final cachedIP = await CameraService().getCachedDeviceIP();

      if (cachedIP != null) {
        print('📦 Found cached IP: $cachedIP');

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
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CameraPositioningPage(deviceIP: cachedIP),
              ),
            );
          }
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

      _showConnectionFailedOptions(e.toString());
    }
  }

  void _showConnectionFailedOptions(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Connection Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not connect to your ESP32.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This could mean:',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint('ESP32 is powered off'),
                  _buildBulletPoint('ESP32 is not on the WiFi network'),
                  _buildBulletPoint('Your phone is on a different network'),
                  _buildBulletPoint('WiFi configuration was reset'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 0;
              });
            },
            child: const Text('New Setup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _skipToPositioning();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
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

        // Show warning but allow to continue
        if (mounted) {
          _showWiFiConnectionWarning();
        }

        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Open WiFi config page IN APP
      if (mounted) {
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
            _connectionTested = false;
            _currentStep = 2; // Move to connection test step
          });

          // Save IP to camera service
          await CameraService().setDiscoveredIP(result);
        } else {
          print('⚠️ WiFi configuration cancelled or failed');
        }
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

  void _showWiFiConnectionWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Not Connected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your phone doesn\'t appear to be connected to the ESP32 setup network.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please connect to:',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Network: $esp32SSID',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Password: 12345678',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After connecting, return to this app and try again.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to open WiFi settings
              final uri = Uri.parse('app-settings:');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Open WiFi Settings'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STEP 2: Test Connection to Device
  // ============================================

  Future<void> _testConnection() async {
    if (_configuredIP == null) {
      _showError('No IP Address',
          'ESP32 IP address not found. Please configure WiFi first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing connection to ESP32...';
      _connectionTested = false;
    });

    try {
      print('\n🧪 TESTING CONNECTION TO ESP32-CAM');
      print('========================================');
      print('Target IP: $_configuredIP');

      // Test 1: Basic HTTP request
      print('\n🧪 Test 1: Basic HTTP connectivity...');
      final response = await http.get(
        Uri.parse('http://$_configuredIP/'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      print('   ✅ HTTP connectivity OK');

      // Test 2: Stream endpoint
      print('\n🧪 Test 2: Stream endpoint check...');
      final streamResponse = await http
          .head(
            Uri.parse('http://$_configuredIP/stream'),
          )
          .timeout(const Duration(seconds: 3));

      if (streamResponse.statusCode != 200) {
        print('   ⚠️ Stream endpoint returned ${streamResponse.statusCode}');
      } else {
        print('   ✅ Stream endpoint OK');
      }

      // Test 3: Status endpoint
      print('\n🧪 Test 3: Status endpoint check...');
      try {
        final statusResponse = await http
            .get(
              Uri.parse('http://$_configuredIP/status'),
            )
            .timeout(const Duration(seconds: 3));

        if (statusResponse.statusCode == 200) {
          final statusData = json.decode(statusResponse.body);
          print('   ✅ Status endpoint OK');
          print('   📊 Status: ${statusData['status']}');
          print('   📡 WiFi: ${statusData['wifi_ssid']}');
          print('   📶 RSSI: ${statusData['rssi']}');
        }
      } catch (e) {
        print('   ⚠️ Status endpoint unavailable: $e');
      }

      print('\n✅ ALL TESTS PASSED!');
      print('========================================\n');

      setState(() {
        _isLoading = false;
        _connectionTested = true;
        _statusMessage = 'Connection test successful!';
      });

      _showSnackBar('✓ Connection test passed!', AppColors.success);
    } catch (e) {
      print('\n❌ CONNECTION TEST FAILED');
      print('========================================');
      print('Error: $e');
      print('========================================\n');

      setState(() {
        _isLoading = false;
        _connectionTested = false;
      });

      _showConnectionTestFailedDialog();
    }
  }

  void _showConnectionTestFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Connection Test Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cannot connect to ESP32 at $_configuredIP',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Common causes:',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep('1',
                        'Your phone is still connected to "RoadSafe-AI-Setup" WiFi'),
                    _buildInstructionStep('2',
                        'Your phone needs to connect to the same WiFi as ESP32'),
                    _buildInstructionStep('3',
                        'ESP32 is still connecting to WiFi (wait 30 seconds)'),
                    _buildInstructionStep(
                        '4', 'ESP32 failed to connect to WiFi'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What should you do?',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Open your phone\'s WiFi settings\n'
                '2. Disconnect from "RoadSafe-AI-Setup"\n'
                '3. Connect to your home WiFi network\n'
                '4. Return to this app and test again',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 1; // Go back to WiFi config
                _configuredIP = null;
              });
            },
            child: const Text('Reconfigure WiFi'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open WiFi settings
              final uri = Uri.parse('app-settings:');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Open WiFi Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STEP 3: Complete Setup
  // ============================================

  Future<void> _completeSetup() async {
    if (_configuredIP == null) {
      _showError('No IP Address', 'Please complete WiFi configuration first.');
      return;
    }

    if (!_connectionTested) {
      _showError('Connection Not Tested', 'Please test the connection first.');
      return;
    }

    // Connection already tested, proceed to positioning
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraPositioningPage(deviceIP: _configuredIP!),
        ),
      );
    }
  }

  // ============================================
  // FORGET WIFI (IMPROVED - NO NETWORK DEPENDENCY)
  // ============================================

  void _showForgetWiFiDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppColors.warning),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Forget WiFi Network'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will reset your ESP32-CAM to setup mode.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Two methods available:',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '📡 Method 1: Software Reset',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sends WiFi reset command to ESP32 (requires connection)',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '🔌 Method 2: Hardware Reset',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manually power cycle ESP32 while pressing reset button',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'After reset, ESP32 will create "RoadSafe-AI-Setup" WiFi network again.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetMethodChoice();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Choose Method'),
          ),
        ],
      ),
    );
  }

  void _showResetMethodChoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choose Reset Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Method 1: Software Reset
            Card(
              elevation: 0,
              color: AppColors.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _attemptSoftwareReset();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Software Reset',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send reset command via app',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Method 2: Hardware Reset
            Card(
              elevation: 0,
              color: AppColors.warning.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showHardwareResetInstructions();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.power_settings_new,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hardware Reset',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manual button press method',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attemptSoftwareReset() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending reset command to ESP32...';
    });

    try {
      print('\n🔄 ATTEMPTING SOFTWARE RESET');
      print('========================================');

      final cachedIP = await CameraService().getCachedDeviceIP();

      if (cachedIP == null) {
        throw Exception('No cached IP available');
      }

      print('Target IP: $cachedIP');

      final response = await http.post(
        Uri.parse('http://$cachedIP/reset'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Reset command sent successfully');

        // Clear local cache
        await CameraService().clearCachedDevice();

        setState(() {
          _isLoading = false;
          _configuredIP = null;
          _connectionTested = false;
          _currentStep = 0;
        });

        _showSuccessDialog(
          'WiFi Reset Successful',
          'ESP32 has been reset. It will restart in setup mode.\n\n'
              'Connect to "RoadSafe-AI-Setup" WiFi and configure again.',
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }

      print('========================================\n');
    } catch (e) {
      print('❌ Software reset failed: $e');
      print('========================================\n');

      setState(() {
        _isLoading = false;
      });

      // If software reset fails, offer hardware reset
      _showError(
        'Software Reset Failed',
        'Cannot connect to ESP32 to send reset command.\n\n'
            'This is normal if ESP32 is unreachable.\n\n'
            'Try Hardware Reset instead.',
        showHardwareResetOption: true,
      );
    }
  }

  void _showHardwareResetInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.build, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Hardware Reset'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Follow these steps carefully:',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildNumberedStep('1',
                  'Locate the RESET button on ESP32-CAM board (small button near antenna)'),
              _buildNumberedStep('2', 'Press and HOLD the reset button'),
              _buildNumberedStep(
                  '3', 'While holding reset, disconnect power from ESP32'),
              _buildNumberedStep('4', 'Keep holding reset, reconnect power'),
              _buildNumberedStep('5', 'Hold for 3 more seconds, then release'),
              _buildNumberedStep('6', 'ESP32 will restart in setup mode'),
              _buildNumberedStep(
                  '7', 'Look for "RoadSafe-AI-Setup" WiFi network'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After reset, the app cache will be cleared automatically.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Clear local cache
              await CameraService().clearCachedDevice();

              if (mounted) {
                Navigator.pop(context);

                setState(() {
                  _configuredIP = null;
                  _connectionTested = false;
                  _currentStep = 0;
                });

                _showSnackBar(
                  'App cache cleared. Ready for new setup.',
                  AppColors.success,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Did The Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // UI HELPERS
  // ============================================

  void _showError(String title, String message,
      {bool showHardwareResetOption = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTextStyles.bodyMedium),
            if (showHardwareResetOption) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showHardwareResetInstructions();
                  },
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Try Hardware Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }

  // ============================================
  // BUILD METHOD
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildCurrentStep(),
            ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Welcome();
      case 1:
        return _buildStep1ConfigureWiFi();
      case 2:
        return _buildStep2TestConnection();
      case 3:
        return _buildStep3Complete();
      default:
        return _buildStep0Welcome();
    }
  }

  // STEP 0: Welcome
  Widget _buildStep0Welcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.power, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 1: Power On Device',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect your ESP32-CAM to power and look for the "RoadSafe-AI-Setup" WiFi network.',
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
              const Icon(Icons.wifi, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Connect to WiFi',
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
                        Text('Network:', style: AppTextStyles.labelMedium),
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
                  'After connecting, return to this app and press Continue',
                  style: AppTextStyles.bodySmall,
                ),
              ),
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
          gradientColors: AppColors.primaryGradient,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _skipToPositioning,
          icon: const Icon(Icons.skip_next),
          label: const Text('WiFi Already Configured'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // STEP 1: Configure WiFi
  Widget _buildStep1ConfigureWiFi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.language, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 2: Configure WiFi',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect your ESP32 to your home WiFi network',
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

  // STEP 2: Test Connection
  Widget _buildStep2TestConnection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _connectionTested ? Icons.check_circle : Icons.link,
          size: 80,
          color: _connectionTested ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Step 3: Test Connection',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _connectionTested
              ? 'Connection successful!'
              : 'WiFi configured. Now test the connection.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _connectionTested
                  ? AppColors.successGradient
                  : AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                _connectionTested ? Icons.check_circle : Icons.wifi_find,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _connectionTested ? 'ESP32 Connected' : 'Ready to Test',
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
                              color: _connectionTested
                                  ? AppColors.success
                                  : AppColors.primary,
                            )),
                      ],
                    ),
                    if (_connectionTested) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status:', style: AppTextStyles.labelMedium),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Online',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_connectionTested) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Make sure your phone is connected to the same WiFi network as ESP32',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (!_connectionTested)
          GradientButton(
            onPressed: _testConnection,
            text: 'Test Connection',
            icon: Icons.play_arrow,
            gradientColors: AppColors.primaryGradient,
          )
        else
          GradientButton(
            onPressed: _completeSetup,
            text: 'Continue to Setup',
            icon: Icons.arrow_forward,
            gradientColors: AppColors.successGradient,
          ),
        const SizedBox(height: 32),
        // Forget WiFi Section
        const Divider(),
        const SizedBox(height: 16),
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

  // STEP 3: Complete
  Widget _buildStep3Complete() {
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
