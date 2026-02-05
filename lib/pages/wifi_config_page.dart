import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class WiFiConfigPage extends StatefulWidget {
  const WiFiConfigPage({super.key});

  @override
  State<WiFiConfigPage> createState() => _WiFiConfigPageState();
}

class _WiFiConfigPageState extends State<WiFiConfigPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isScanning = false;
  bool _isCheckingConnection = true;
  bool _isConnectedToESP32 = false;
  String? _currentSSID;
  String? _errorMessage;
  List<String> _availableNetworks = [];
  bool _obscurePassword = true;

  // ESP32 AP default credentials
  static const String ESP32_AP_SSID = 'Road-Safe-AI-Setup';
  static const String ESP32_AP_IP = '192.168.4.1';
  static const int ESP32_AP_PORT = 80;

  @override
  void initState() {
    super.initState();
    _checkESP32Connection();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ✅ ENHANCED: Multi-method ESP32 connection detection
  Future<void> _checkESP32Connection() async {
    setState(() {
      _isCheckingConnection = true;
      _errorMessage = null;
    });

    print('\n🔍 Checking ESP32 connection...');

    try {
      // Method 1: Check WiFi SSID
      final ssidResult = await _checkWiFiSSID();

      // Method 2: Try to ping ESP32 gateway
      final pingResult = await _pingESP32Gateway();

      // Method 3: Check WiFi gateway IP
      final gatewayResult = await _checkGatewayIP();

      final isConnected = ssidResult || pingResult || gatewayResult;

      setState(() {
        _isConnectedToESP32 = isConnected;
        _isCheckingConnection = false;
      });

      if (isConnected) {
        print('✅ Connected to ESP32 setup network');
        _scanAvailableNetworks();
      } else {
        print('❌ Not connected to ESP32 setup network');
        setState(() {
          _errorMessage =
              'Please connect to "$ESP32_AP_SSID" WiFi network first';
        });
      }
    } catch (e) {
      print('❌ Connection check error: $e');
      setState(() {
        _isCheckingConnection = false;
        _isConnectedToESP32 = false;
        _errorMessage = 'Error checking connection: $e';
      });
    }
  }

  /// ✅ Method 1: Check current WiFi SSID
  Future<bool> _checkWiFiSSID() async {
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();

      print('📡 Current WiFi SSID: $wifiName');

      if (wifiName == null) {
        print('⚠️ Cannot get WiFi SSID (null)');
        return false;
      }

      // Clean SSID (remove quotes if present)
      String cleanSSID = wifiName.replaceAll('"', '').trim();

      setState(() {
        _currentSSID = cleanSSID;
      });

      // Check if SSID matches (case-insensitive)
      final matches = cleanSSID.toLowerCase() == ESP32_AP_SSID.toLowerCase();
      print('   SSID Match: $matches ($cleanSSID vs $ESP32_AP_SSID)');

      return matches;
    } catch (e) {
      print('❌ SSID check error: $e');
      return false;
    }
  }

  /// ✅ Method 2: Ping ESP32 gateway
  Future<bool> _pingESP32Gateway() async {
    try {
      print('🔍 Attempting to ping ESP32 at $ESP32_AP_IP...');

      final response = await http
          .get(Uri.parse('http://$ESP32_AP_IP/'))
          .timeout(const Duration(seconds: 3));

      final success = response.statusCode == 200 || response.statusCode == 404;
      print(
          '   Ping result: ${success ? "✅ Success" : "❌ Failed"} (Status: ${response.statusCode})');

      return success;
    } catch (e) {
      print('   Ping result: ❌ Failed ($e)');
      return false;
    }
  }

  /// ✅ Method 3: Check gateway IP
  Future<bool> _checkGatewayIP() async {
    try {
      final info = NetworkInfo();
      final gateway = await info.getWifiGatewayIP();

      print('🌐 Gateway IP: $gateway');

      if (gateway == null) {
        return false;
      }

      // ESP32 AP mode typically uses 192.168.4.1
      final matches = gateway == ESP32_AP_IP;
      print('   Gateway Match: $matches ($gateway vs $ESP32_AP_IP)');

      return matches;
    } catch (e) {
      print('❌ Gateway check error: $e');
      return false;
    }
  }

  /// ✅ Scan for available WiFi networks via ESP32
  Future<void> _scanAvailableNetworks() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    print('\n📡 Scanning for WiFi networks via ESP32...');

    try {
      final response = await http
          .get(Uri.parse('http://$ESP32_AP_IP/scan'))
          .timeout(const Duration(seconds: 15));

      print('   Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('   Scan response: $data');

        List<String> networks = [];

        if (data is Map && data['networks'] != null) {
          networks = List<String>.from(data['networks']);
        } else if (data is List) {
          networks = List<String>.from(data);
        }

        // Remove duplicates and sort
        networks = networks.toSet().toList();
        networks.sort();

        print('✅ Found ${networks.length} networks: $networks');

        setState(() {
          _availableNetworks = networks;
          _isScanning = false;
        });
      } else {
        throw Exception('Scan failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network scan error: $e');
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to scan networks: $e';
      });
    }
  }

  /// ✅ Configure WiFi on ESP32
  Future<void> _configureWiFi() async {
    if (_ssidController.text.isEmpty) {
      _showError('Please select a WiFi network');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter WiFi password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('\n🔧 Configuring WiFi on ESP32...');
    print('   SSID: ${_ssidController.text}');
    print('   Password: ${"*" * _passwordController.text.length}');

    try {
      final response = await http
          .post(
            Uri.parse('http://$ESP32_AP_IP/configure'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'ssid': _ssidController.text,
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('   Configuration response: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ WiFi configured successfully');
        print('   Response data: $data');

        // Extract new IP address
        String? newIP;
        if (data is Map) {
          newIP = data['ip'] ?? data['new_ip'] ?? data['assigned_ip'];
        }

        setState(() {
          _isLoading = false;
        });

        _showSuccessDialog(newIP);
      } else {
        throw Exception('Configuration failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ WiFi configuration error: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Configuration failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog(String? newIP) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            SizedBox(width: 8),
            Text('WiFi Configured!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESP32 is now connected to ${_ssidController.text}',
              style: AppTextStyles.bodyLarge,
            ),
            if (newIP != null) ...[
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
                      'New IP Address:',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      newIP,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Please reconnect your phone to your regular WiFi network, then return to the app.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, newIP); // Return to setup page with IP
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure WiFi', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkESP32Connection,
            tooltip: 'Refresh Connection',
          ),
        ],
      ),
      body: _isCheckingConnection
          ? _buildCheckingState()
          : !_isConnectedToESP32
              ? _buildNotConnectedState()
              : _buildConnectedState(),
    );
  }

  Widget _buildCheckingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Checking ESP32 connection...',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 80,
              color: AppColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Connected to ESP32',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
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
                  if (_currentSSID != null) ...[
                    Text(
                      'Currently connected to:',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSSID!,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Expected network:',
                    style: AppTextStyles.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ESP32_AP_SSID,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Please follow these steps:',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              1,
              'Power on your ESP32-CAM device',
            ),
            _buildInstructionStep(
              2,
              'Open phone WiFi settings',
            ),
            _buildInstructionStep(
              3,
              'Connect to "$ESP32_AP_SSID" network',
            ),
            _buildInstructionStep(
              4,
              'Return to this app and tap "Retry"',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkESP32Connection,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                // Open WiFi settings
                print('Opening WiFi settings...');
                // Note: You'll need to add the url_launcher package
                // and implement platform-specific WiFi settings opening
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open WiFi Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: AppTextStyles.labelLarge.copyWith(
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

  Widget _buildConnectedState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to ESP32',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Network: ${_currentSSID ?? ESP32_AP_SSID}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Network selection
          Text(
            'Select WiFi Network',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the network you want your ESP32 to connect to',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // Available networks list
          if (_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_availableNetworks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No networks found',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _scanAvailableNetworks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var network in _availableNetworks)
                    ListTile(
                      leading: const Icon(Icons.wifi, color: AppColors.primary),
                      title: Text(network),
                      trailing: _ssidController.text == network
                          ? const Icon(Icons.check, color: AppColors.success)
                          : null,
                      onTap: () {
                        setState(() {
                          _ssidController.text = network;
                        });
                      },
                    ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Password input
          Text(
            'WiFi Password',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter WiFi password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Configure button
          ElevatedButton(
            onPressed: _isLoading ? null : _configureWiFi,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Configure WiFi',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
