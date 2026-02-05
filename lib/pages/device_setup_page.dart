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
import '../services/drowsiness_service.dart';
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

  @override
  void dispose() {
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // MANUAL IP ENTRY DIALOG
  // ═══════════════════════════════════════════════════════════
  void _showManualIPDialog() {
    final ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_location_alt,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Enter IP Manually')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skip WiFi configuration and connect directly using IP address.',
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
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Requirements:',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ESP32 must be connected to WiFi\n'
                      '• Your phone must be on same network\n'
                      '• You must know the ESP32\'s IP address',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'ESP32 IP Address',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router),
                  helperText: 'Example: 192.168.1.100',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final ip = ipController.text.trim();

              if (!_isValidIP(ip)) {
                _showError('Invalid IP',
                    'Please enter a valid IP address (e.g., 192.168.1.100)');
                return;
              }

              Navigator.pop(context); // Close dialog
              await _connectToManualIP(ip);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.check),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  bool _isValidIP(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  Future<void> _connectToManualIP(String ip) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing connection to $ip...';
    });

    try {
      print('🔗 Testing manual IP: $ip');

      // Test stream endpoint
      final testResponse = await http
          .get(Uri.parse('http://$ip/stream'))
          .timeout(const Duration(seconds: 5));

      if (testResponse.statusCode == 200 || testResponse.statusCode == 503) {
        print('✅ ESP32 is reachable at $ip');

        // Save IP
        await CameraService().setDiscoveredIP(ip);
        DrowsinessDetector.setESP32IP(ip);

        setState(() {
          _configuredIP = ip;
          _isLoading = false;
        });

        // Go directly to positioning
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CameraPositioningPage(deviceIP: ip),
            ),
          );
        }
      } else {
        throw Exception('Device not responding correctly');
      }
    } catch (e) {
      print('❌ Manual IP connection failed: $e');

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Connection Failed',
        'Could not connect to ESP32 at $ip\n\n'
            'Please verify:\n'
            '• ESP32 is powered on\n'
            '• ESP32 is connected to WiFi\n'
            '• Your phone is on same network\n'
            '• IP address is correct\n\n'
            'Error: $e',
      );
    }
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

        // ✅ NEW: Instead of just showing error, offer manual IP option
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Configured Device'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No previously configured ESP32 found.\n\n'
                  'You have two options:',
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
                      Text(
                        'Option 1: Configure WiFi',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. Connect to "RoadSafe-AI-Setup"\n'
                        '2. Configure your home WiFi\n'
                        '3. Position camera',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Option 2: Manual IP (Faster)',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If ESP32 is already on WiFi,\nenter IP directly and skip setup',
                        style: AppTextStyles.bodySmall,
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
                  setState(() {
                    _currentStep = 0; // Go to step 1
                  });
                },
                child: const Text('Configure WiFi'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showManualIPDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Enter IP Manually'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // ✅ NEW: Show error with manual IP option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not connect to your configured ESP32.\n\n'
                'This could mean:\n'
                '• ESP32 is powered off\n'
                '• ESP32 is not on the WiFi network\n'
                '• WiFi configuration was reset',
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
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can enter the IP manually if you know it',
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showManualIPDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Manual IP'),
            ),
          ],
        ),
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

      // Open WiFi config page IN APP
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
        // Inform drowsiness detector
        try {
          DrowsinessDetector.setESP32IP(result);
        } catch (_) {}
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

  // ============================================
  // FORGET WIFI
  // ============================================

  void _showForgetWiFiDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.warning, size: 32),
            const SizedBox(width: 12),
            const Text('Forget WiFi?'),
          ],
        ),
        content: const Text(
          'This will clear the saved WiFi configuration on ESP32.\n\n'
          'You will need to reconfigure WiFi from the beginning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forgetWiFi();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Forget WiFi'),
          ),
        ],
      ),
    );
  }

  Future<void> _forgetWiFi() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Resetting WiFi configuration...';
    });

    try {
      // Clear local cache
      await CameraService().clearCachedDevice();

      setState(() {
        _configuredIP = null;
        _currentStep = 0;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WiFi configuration cleared'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('❌ Forget WiFi error: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
            const SizedBox(width: 12),
            const Text('Setup Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ESP32-CAM is ready for monitoring.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('IP Address:'),
                      Text(
                        ip,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Optionally navigate to camera positioning
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraPositioningPage(deviceIP: ip),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Position Camera'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ERROR DIALOG
  // ============================================

  void _showError(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
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
        title: const Text('Device Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  Row(
                    children: List.generate(4, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Current step
                  if (_currentStep == 0) _buildStep1(),
                  if (_currentStep == 1) _buildStep2ConfigureWiFi(),
                  if (_currentStep == 2) _buildStep3ConnectToDevice(),
                  if (_currentStep == 3) _buildStep4Complete(),
                ],
              ),
            ),
    );
  }

  // ============================================
  // STEP WIDGETS
  // ============================================

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.power, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 1: Power On ESP32',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect your ESP32-CAM to power',
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
              const Icon(Icons.electrical_services,
                  color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Connect Power',
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
                    _buildInstruction('Connect USB cable to ESP32-CAM'),
                    _buildInstruction('Plug into 5V power source'),
                    _buildInstruction('Wait for LED indicator'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ✅ NEW: Quick access button for already configured devices
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
                  const Icon(Icons.info_outline,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Already configured your device?',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _skipToPositioning,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('WiFi Configured - Position Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        GradientButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          text: 'Next: Configure WiFi',
          icon: Icons.arrow_forward,
          gradientColors: AppColors.primaryGradient,
        ),
      ],
    );
  }

  Widget _buildStep2ConfigureWiFi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.wifi, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Step 2: Configure WiFi',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect ESP32 to your WiFi network',
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
              _buildInstruction('Your home WiFi network name (SSID)'),
              _buildInstruction('Your home WiFi password'),
              _buildInstruction('ESP32 will connect and get an IP address'),
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

        // ✅ NEW: Manual IP Button
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showManualIPDialog,
          icon: const Icon(Icons.edit_location_alt),
          label: const Text('Enter IP Manually'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
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
