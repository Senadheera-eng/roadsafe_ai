import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../services/camera_service.dart';

class WiFiConfigPage extends StatefulWidget {
  final String esp32IP; // e.g., "192.168.4.1" for AP mode

  const WiFiConfigPage({super.key, required this.esp32IP});

  @override
  State<WiFiConfigPage> createState() => _WiFiConfigPageState();
}

class _WiFiConfigPageState extends State<WiFiConfigPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _passwordController = TextEditingController();

  bool _isScanning = true;
  bool _isConnecting = false;
  bool _obscurePassword = true;
  List<WiFiNetwork> _networks = [];
  String? _selectedSSID;
  String _statusMessage = '';
  bool _connectionSuccess = false;

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

    _animationController.forward();
    _scanNetworks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // NETWORK SCANNING
  // ═══════════════════════════════════════════════════════════
  Future<void> _scanNetworks() async {
    setState(() {
      _isScanning = true;
      _networks.clear();
      _statusMessage = '';
    });

    try {
      print('📡 Scanning WiFi networks from ESP32...');
      print('   Target: http://${widget.esp32IP}/scan');

      final response =
          await http.get(Uri.parse('http://${widget.esp32IP}/scan')).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'ESP32 did not respond to scan request.\n'
            'Make sure you\'re connected to "RoadSafe-AI-Setup" WiFi.',
          );
        },
      );

      print('📡 Scan response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 Scan data: $data');

        List<WiFiNetwork> networkList = [];

        // Handle different response formats
        if (data is Map && data.containsKey('networks')) {
          final List networks = data['networks'];
          networkList = networks.map((n) => WiFiNetwork.fromJson(n)).toList();
        } else if (data is List) {
          networkList = data.map((n) => WiFiNetwork.fromJson(n)).toList();
        }

        setState(() {
          _networks = networkList
            ..sort((a, b) => b.rssi.compareTo(a.rssi)); // Sort by signal
          _isScanning = false;
        });

        print('✅ Found ${_networks.length} networks');
      } else {
        throw Exception('Scan failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network scan error: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Failed to scan networks';
      });

      _showErrorDialog(
        'Scan Failed',
        'Could not scan WiFi networks from ESP32.\n\n'
            'Error: $e\n\n'
            'Troubleshooting:\n'
            '• Make sure ESP32 is powered on\n'
            '• Verify you\'re connected to "RoadSafe-AI-Setup"\n'
            '• Check ESP32 AP mode is active\n'
            '• Try restarting ESP32',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // WIFI CONNECTION WITH IMPROVED ERROR HANDLING
  // ═══════════════════════════════════════════════════════════
  Future<void> _connectToWiFi() async {
    if (_selectedSSID == null || _passwordController.text.isEmpty) {
      _showSnackBar(
          'Please select a network and enter password', AppColors.warning);
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Sending credentials to ESP32...';
      _connectionSuccess = false;
    });

    try {
      print('');
      print('═══════════════════════════════════════════════════════');
      print('🔐 CONNECTING ESP32 TO WIFI');
      print('═══════════════════════════════════════════════════════');
      print('   Network: $_selectedSSID');
      print('   ESP32 IP: ${widget.esp32IP}');
      print('');

      // ─────────────────────────────────────────────────────────
      // Phase 1: Test connectivity first
      // ─────────────────────────────────────────────────────────
      print('📡 Phase 1: Testing ESP32 connectivity...');

      try {
        final pingResponse = await http
            .get(Uri.parse('http://${widget.esp32IP}/'))
            .timeout(const Duration(seconds: 3));

        print('   Ping response: ${pingResponse.statusCode}');
      } catch (pingError) {
        print('   ⚠️ Ping failed: $pingError');
        throw TimeoutException(
          'Cannot reach ESP32 at ${widget.esp32IP}\n\n'
          'Please verify:\n'
          '• ESP32 is powered on\n'
          '• Phone is connected to "RoadSafe-AI-Setup"\n'
          '• ESP32 AP mode is active\n\n'
          'You can also use "Skip WiFi Config" and enter IP manually.',
        );
      }

      // ─────────────────────────────────────────────────────────
      // Phase 2: Send credentials to ESP32
      // ─────────────────────────────────────────────────────────
      print('');
      print('📤 Phase 2: Sending WiFi credentials...');

      setState(() {
        _statusMessage = 'Configuring ESP32...';
      });

      final response = await http
          .post(
        Uri.parse('http://${widget.esp32IP}/connect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ssid': _selectedSSID,
          'password': _passwordController.text,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'ESP32 did not respond to connection request.\n\n'
            'Possible causes:\n'
            '• ESP32 firmware missing /connect endpoint\n'
            '• ESP32 restarted during connection\n'
            '• Network interference\n\n'
            'Try using "Skip WiFi Config" to enter IP manually.',
          );
        },
      );

      print('📥 ESP32 response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      // ✅ Accept 200 or 202 response codes
      if (response.statusCode == 200 || response.statusCode == 202) {
        print('✅ ESP32 accepted credentials');

        // ─────────────────────────────────────────────────────────
        // Phase 3: ESP32 is connecting (wait period)
        // ─────────────────────────────────────────────────────────
        print('');
        print('⏳ Phase 3: Waiting for ESP32 to connect...');

        setState(() {
          _statusMessage =
              'ESP32 is connecting to $_selectedSSID...\n\nThis may take 10-15 seconds';
        });

        // Give ESP32 time to connect and get DHCP IP
        for (int i = 10; i > 0; i--) {
          if (!mounted) return;
          setState(() {
            _statusMessage =
                'ESP32 is connecting to $_selectedSSID...\n\nWaiting: $i seconds';
          });
          await Future.delayed(const Duration(seconds: 1));
        }

        // ─────────────────────────────────────────────────────────
        // Phase 4: Try to retrieve IP address
        // ─────────────────────────────────────────────────────────
        print('');
        print('🔍 Phase 4: Attempting to retrieve ESP32 IP...');

        String? esp32NewIP;

        // Try getting IP from status endpoint
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            setState(() {
              _statusMessage = 'Retrieving IP address... (attempt $attempt/3)';
            });

            print(
                '   Attempt $attempt: Querying http://${widget.esp32IP}/status');

            final statusResponse = await http
                .get(Uri.parse('http://${widget.esp32IP}/status'))
                .timeout(const Duration(seconds: 3));

            if (statusResponse.statusCode == 200) {
              final statusData = json.decode(statusResponse.body);
              print('   Status data: $statusData');

              // Try different JSON field names
              esp32NewIP = statusData['ip']?.toString() ??
                  statusData['local_ip']?.toString() ??
                  statusData['station_ip']?.toString() ??
                  statusData['ipAddress']?.toString();

              if (esp32NewIP != null &&
                  esp32NewIP.isNotEmpty &&
                  esp32NewIP != '0.0.0.0' &&
                  esp32NewIP != '192.168.4.1') {
                print('✅ Retrieved IP: $esp32NewIP');
                break;
              }
            }
          } catch (e) {
            print('   ⚠️ Attempt $attempt failed: $e');
          }

          if (attempt < 3) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }

        setState(() {
          _isConnecting = false;
        });

        // ─────────────────────────────────────────────────────────
        // Phase 5: Show appropriate dialog
        // ─────────────────────────────────────────────────────────
        print('');
        if (esp32NewIP != null &&
            esp32NewIP.isNotEmpty &&
            esp32NewIP != '0.0.0.0') {
          print('✅ SUCCESS: ESP32 connected with IP: $esp32NewIP');
          if (mounted) {
            _showSuccessDialogWithIP(esp32NewIP);
          }
        } else {
          print('⚠️ Could not retrieve IP automatically');
          if (mounted) {
            _showManualNetworkSwitchDialog();
          }
        }
      } else {
        throw Exception(
            'ESP32 rejected connection (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('');
      print('❌ WiFi connection error: $e');
      print('');

      setState(() {
        _statusMessage = 'Connection failed';
        _connectionSuccess = false;
        _isConnecting = false;
      });

      if (e is TimeoutException) {
        _showErrorDialog('Connection Timeout', e.message ?? e.toString());
      } else {
        _showErrorDialog(
          'Connection Failed',
          'Could not configure WiFi.\n\n'
              'Error: $e\n\n'
              'You can skip WiFi configuration and enter the IP address manually.',
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SUCCESS DIALOG - IP Retrieved
  // ═══════════════════════════════════════════════════════════
  void _showSuccessDialogWithIP(String esp32IP) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('WiFi Configured!')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.successGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'ESP32 Connected Successfully',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
                              Text('Network:',
                                  style: AppTextStyles.labelMedium),
                              Text(
                                _selectedSSID ?? 'Unknown',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('IP Address:',
                                  style: AppTextStyles.labelMedium),
                              Text(
                                esp32IP,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
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
              ),
              const SizedBox(height: 20),
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
                        Expanded(
                          child: Text(
                            'Important: Switch your phone\'s WiFi',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To continue, you must connect your phone to the same WiFi network: "$_selectedSSID"',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Next Steps:',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('1', 'Go to your phone\'s WiFi settings'),
              _buildInstructionStep('2', 'Disconnect from "RoadSafe-AI-Setup"'),
              _buildInstructionStep('3', 'Connect to "$_selectedSSID"'),
              _buildInstructionStep(
                  '4', 'Return here and tap "I\'m Connected"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to setup without IP
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _verifyAndProceed(esp32IP),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.check),
            label: const Text('I\'m Connected'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MANUAL NETWORK SWITCH DIALOG (No IP Retrieved)
  // ═══════════════════════════════════════════════════════════
  void _showManualNetworkSwitchDialog() {
    final ipController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi_find,
                  color: AppColors.warning, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Find ESP32 IP')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ESP32 successfully joined "$_selectedSSID"',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                        const Icon(Icons.info_outline,
                            color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Could not retrieve IP automatically',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please find the ESP32\'s IP address manually and enter it below.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Steps:',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('1', 'Disconnect from "RoadSafe-AI-Setup"'),
              _buildInstructionStep('2', 'Connect to "$_selectedSSID"'),
              _buildInstructionStep('3', 'Find ESP32 IP address:'),
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4, bottom: 12),
                child: Text(
                  '• Check your router\'s admin page\n'
                  '• Use a network scanner app\n'
                  '• Check ESP32 Serial Monitor',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: 'ESP32 IP Address *',
                  hintText: '192.168.1.100',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.router),
                  helperText: 'Format: xxx.xxx.xxx.xxx',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final ip = ipController.text.trim();
              if (_isValidIP(ip)) {
                Navigator.pop(context);
                _verifyAndProceed(ip);
              } else {
                _showSnackBar(
                    'Please enter a valid IP address', AppColors.error);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.check),
            label: const Text('Verify IP'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VERIFY CONNECTION AND PROCEED
  // ═══════════════════════════════════════════════════════════
  Future<void> _verifyAndProceed(String ip) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Verifying connection to $ip...';
    });

    try {
      print('🔗 Testing connection to ESP32 at $ip...');

      final testResponse = await http
          .get(Uri.parse('http://$ip/stream'))
          .timeout(const Duration(seconds: 5));

      // 200 = streaming, 503 = not streaming but device exists
      if (testResponse.statusCode == 200 || testResponse.statusCode == 503) {
        print('✅ ESP32 is reachable at $ip');

        setState(() {
          _isConnecting = false;
          _connectionSuccess = true;
        });

        _showSnackBar('✓ WiFi configured successfully!', AppColors.success);

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, ip); // Return IP to device_setup_page
        }
      } else {
        throw Exception('Unexpected response: ${testResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Connection verification failed: $e');

      setState(() {
        _isConnecting = false;
      });

      _showErrorDialog(
        'Cannot Reach ESP32',
        'Could not connect to ESP32 at $ip\n\n'
            'Please verify:\n'
            '• Both devices are on "$_selectedSSID"\n'
            '• IP address is correct\n'
            '• ESP32 is powered on\n\n'
            'Error: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SKIP WIFI CONFIG - MANUAL IP ENTRY
  // ═══════════════════════════════════════════════════════════
  void _showManualIPDialog() {
    final ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter IP Manually'),
        content: Column(
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
                    '• ESP32 must already be connected to WiFi\n'
                    '• Your phone must be on the same network\n'
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final ip = ipController.text.trim();
              if (_isValidIP(ip)) {
                Navigator.pop(context); // Close dialog
                _verifyAndProceed(ip);
              } else {
                _showSnackBar(
                    'Please enter a valid IP address', AppColors.error);
              }
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

  // ═══════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════

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

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: AppTextStyles.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: AppTextStyles.bodyMedium),
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
                        'Try using "Skip WiFi Config" to enter IP manually',
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualIPDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Enter IP Manually'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 200,
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
              actions: [
                // ✅ SKIP WIFI CONFIG BUTTON
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _showManualIPDialog,
                    icon: const Icon(Icons.edit_location_alt,
                        color: Colors.white, size: 20),
                    label: Text(
                      'Manual IP',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.primaryGradient,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.wifi_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'WiFi Configuration',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect ESP32 to your network',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Message
                    if (_statusMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _connectionSuccess
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _connectionSuccess
                                ? AppColors.success
                                : AppColors.info,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionSuccess
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: _connectionSuccess
                                  ? AppColors.success
                                  : AppColors.info,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Loading State
                    if (_isScanning)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Scanning WiFi networks...'),
                          ],
                        ),
                      ),

                    // Networks List
                    if (!_isScanning && _networks.isNotEmpty) ...[
                      Text(
                        'Available Networks',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _networks.length,
                        itemBuilder: (context, index) {
                          final network = _networks[index];
                          final isSelected = network.ssid == _selectedSSID;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSSID = network.ssid;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.1)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      network.getSignalIcon(),
                                      color: isSelected
                                          ? AppColors.primary
                                          : network.getSignalColor(),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          network.ssid,
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              network.encryption == 'Open'
                                                  ? Icons.lock_open_rounded
                                                  : Icons.lock_rounded,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${network.rssi} dBm • ${network.encryption}',
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Password Input
                      if (_selectedSSID != null) ...[
                        Text(
                          'WiFi Password',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        GlassCard(
                          padding: const EdgeInsets.all(4),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter WiFi password',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Connect Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectToWiFi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.wifi_rounded),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Connect to WiFi',
                                        style:
                                            AppTextStyles.titleMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],

                    // Rescan Button
                    if (!_isScanning && _networks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _scanNetworks,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Rescan Networks'),
                        ),
                      ),
                    ],

                    // Empty state or error
                    if (!_isScanning && _networks.isEmpty) ...[
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No networks found'),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure ESP32 is powered on and\nyou\'re connected to "RoadSafe-AI-Setup"',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _scanNetworks,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Scan'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _showManualIPDialog,
                              child: const Text('Skip and Enter IP Manually'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WiFi Network Model
// ═══════════════════════════════════════════════════════════
class WiFiNetwork {
  final String ssid;
  final int rssi;
  final String encryption;

  WiFiNetwork({
    required this.ssid,
    required this.rssi,
    required this.encryption,
  });

  factory WiFiNetwork.fromJson(Map<String, dynamic> json) {
    return WiFiNetwork(
      ssid: json['ssid'] ?? json['SSID'] ?? 'Unknown',
      rssi: json['rssi'] ?? json['RSSI'] ?? -100,
      encryption: json['encryption'] ?? json['auth'] ?? 'Unknown',
    );
  }

  IconData getSignalIcon() {
    if (rssi >= -50) return Icons.signal_wifi_4_bar;
    if (rssi >= -60) return Icons.signal_wifi_4_bar;
    if (rssi >= -70) return Icons.network_wifi_3_bar;
    if (rssi >= -80) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color getSignalColor() {
    if (rssi >= -50) return AppColors.success;
    if (rssi >= -60) return AppColors.success;
    if (rssi >= -70) return AppColors.warning;
    if (rssi >= -80) return AppColors.error;
    return AppColors.error;
  }

  String getSignalStrength() {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    if (rssi >= -80) return 'Weak';
    return 'Very Weak';
  }
}
