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
  final TextEditingController _manualIPController = TextEditingController();

  bool _isScanning = true;
  bool _isConnecting = false;
  bool _obscurePassword = true;
  bool _showManualIPEntry = false;
  List<WiFiNetwork> _networks = [];
  String? _selectedSSID;
  String _statusMessage = '';
  bool _connectionSuccess = false;
  String? _detectedIP;

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
    _manualIPController.dispose();
    super.dispose();
  }

  Future<void> _scanNetworks() async {
    setState(() {
      _isScanning = true;
      _networks.clear();
      _statusMessage = 'Scanning for WiFi networks...';
    });

    try {
      print('📡 Scanning WiFi networks from ${widget.esp32IP}...');

      final response = await http
          .get(Uri.parse('http://${widget.esp32IP}/scan'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List networks = data['networks'];

        print('✅ Found ${networks.length} networks');

        setState(() {
          _networks = networks.map((n) => WiFiNetwork.fromJson(n)).toList()
            ..sort(
                (a, b) => b.rssi.compareTo(a.rssi)); // Sort by signal strength
          _isScanning = false;
          _statusMessage = 'Found ${networks.length} networks';
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network scan failed: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Failed to scan networks: $e';
      });
      _showSnackBar('Network scan failed', AppColors.error);
    }
  }

  Future<void> _connectToWiFi() async {
    if (_selectedSSID == null || _passwordController.text.isEmpty) {
      _showSnackBar(
          'Please select a network and enter password', AppColors.warning);
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Sending WiFi credentials to ESP32...';
      _connectionSuccess = false;
      _detectedIP = null;
    });

    try {
      print('\n========================================');
      print('🔌 CONNECTING TO WIFI');
      print('========================================');
      print('Target ESP32: ${widget.esp32IP}');
      print('SSID: $_selectedSSID');
      print(
          'Password: ${_passwordController.text.replaceAll(RegExp(r'.'), '*')}');

      // STEP 1: Send credentials to ESP32
      print('\n📤 Step 1: Sending credentials to ESP32...');

      final response = await http
          .post(
            Uri.parse('http://${widget.esp32IP}/connect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'ssid': _selectedSSID,
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      // STEP 2: Parse response
      String? newIp;
      bool esp32Connected = false;

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          if (data is Map) {
            esp32Connected = data['success'] == true;

            if (data['ip'] != null && data['ip'].toString().isNotEmpty) {
              newIp = data['ip'].toString();
              print('✅ ESP32 reported IP: $newIp');
            }
          }
        } catch (e) {
          print('⚠️ Failed to parse JSON response: $e');
          // ESP32 might have sent HTML or rebooted
        }
      }

      // STEP 3: Handle different scenarios
      if (esp32Connected && newIp != null && newIp.isNotEmpty) {
        // ✅ BEST CASE: ESP32 connected AND reported IP
        print('✅ SUCCESS: ESP32 connected and reported IP!');

        setState(() {
          _detectedIP = newIp;
          _statusMessage = 'ESP32 connected! New IP: $newIp';
          _connectionSuccess = true;
        });

        _showSuccessDialog(newIp);
        return;
      }

      // STEP 4: ESP32 connected but didn't report IP (or rebooted)
      print('\n⚠️ ESP32 may be connected but IP not received');
      print('   This usually means ESP32 rebooted after connecting');

      setState(() {
        _statusMessage =
            'ESP32 is connecting to WiFi...\nSearching for device...';
      });

      // Wait a bit for ESP32 to finish connecting and boot up
      print('⏳ Waiting 8 seconds for ESP32 to connect and boot...');
      await Future.delayed(const Duration(seconds: 8));

      // STEP 5: Try to discover device via UDP
      print('\n🔍 Step 2: Searching for ESP32 via UDP discovery...');

      setState(() {
        _statusMessage = 'Searching for device on your WiFi network...';
      });

      final devices = await CameraService().scanForDevices();

      if (devices.isNotEmpty) {
        newIp = devices.first.ipAddress;
        print('✅ FOUND ESP32 at: $newIp');

        setState(() {
          _detectedIP = newIp;
          _statusMessage = 'Found device at $newIp!';
          _connectionSuccess = true;
        });

        _showSuccessDialog(newIp!);
        return;
      }

      // STEP 6: UDP discovery failed - show instructions
      print('❌ Could not find ESP32 automatically');
      print('   This usually means:');
      print('   1. Phone still connected to RoadSafe-AI-Setup WiFi');
      print('   2. Phone needs to switch to home WiFi');
      print('   3. ESP32 is on home WiFi but phone is not');

      setState(() {
        _statusMessage = 'ESP32 configured but cannot find it on network';
        _connectionSuccess = false;
      });

      _showNetworkSwitchInstructions();
    } catch (e) {
      print('❌ Connection error: $e');
      setState(() {
        _statusMessage = 'Error: $e';
        _connectionSuccess = false;
      });
      _showSnackBar('Connection error: $e', AppColors.error);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showSuccessDialog(String ip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('WiFi Configured!'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESP32 successfully connected to your WiFi network.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text('Network:', style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedSSID ?? 'Unknown',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.router,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text('IP Address:', style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ip,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
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
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.info, size: 20),
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
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, ip); // Return IP to device setup page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showNetworkSwitchInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_find,
                  color: AppColors.warning, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Switch WiFi Network'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESP32 has connected to your WiFi, but we cannot detect it automatically.',
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
                      'Follow these steps:',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                        '1', 'Open your phone\'s WiFi settings'),
                    _buildInstructionStep(
                        '2', 'Disconnect from "RoadSafe-AI-Setup"'),
                    _buildInstructionStep('3', 'Connect to "$_selectedSSID"'),
                    _buildInstructionStep(
                        '4', 'Return to this app and enter IP manually'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'If you know the ESP32\'s IP address, you can enter it manually below.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _showManualIPEntry = true;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Enter IP Manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _retryDiscovery();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Retry Discovery'),
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
            decoration: BoxDecoration(
              color: AppColors.warning,
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
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryDiscovery() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Searching for ESP32...';
    });

    try {
      print('🔍 Retrying UDP discovery...');
      final devices = await CameraService().scanForDevices();

      if (devices.isNotEmpty) {
        final newIp = devices.first.ipAddress;
        print('✅ Found ESP32 at: $newIp');

        setState(() {
          _detectedIP = newIp;
          _statusMessage = 'Found device at $newIp!';
          _connectionSuccess = true;
          _isConnecting = false;
        });

        _showSuccessDialog(newIp);
      } else {
        throw Exception('Device not found');
      }
    } catch (e) {
      print('❌ Retry failed: $e');
      setState(() {
        _isConnecting = false;
      });
      _showSnackBar('Device not found. Try manual IP entry.', AppColors.error);
      setState(() {
        _showManualIPEntry = true;
      });
    }
  }

  void _submitManualIP() {
    final manualIP = _manualIPController.text.trim();

    if (manualIP.isEmpty) {
      _showSnackBar('Please enter an IP address', AppColors.warning);
      return;
    }

    // Basic IP validation
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(manualIP)) {
      _showSnackBar('Invalid IP address format', AppColors.error);
      return;
    }

    print('✅ Manual IP entered: $manualIP');

    setState(() {
      _detectedIP = manualIP;
      _connectionSuccess = true;
    });

    _showSuccessDialog(manualIP);
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
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.primaryGradient,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.wifi_rounded,
                              color: Colors.white, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'WiFi Configuration',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect ESP32 to your network',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: _connectionSuccess
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _connectionSuccess
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.info.withOpacity(0.3),
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

                    // Manual IP Entry Section
                    if (_showManualIPEntry) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.edit,
                                    color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Manual IP Entry',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter the IP address of your ESP32-CAM device',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _manualIPController,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                hintText: 'e.g., 192.168.1.100',
                                prefixIcon: const Icon(Icons.router),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitManualIP,
                                icon: const Icon(Icons.check),
                                label: const Text('Use This IP'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                    ],

                    // Network List Title
                    Text(
                      'Available Networks',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Loading or Networks List
                    if (_isScanning)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Scanning for WiFi networks...',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_networks.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'No networks found',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _scanNetworks,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _networks.length,
                        itemBuilder: (context, index) {
                          final network = _networks[index];
                          final isSelected = _selectedSSID == network.ssid;

                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.zero,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSSID = network.ssid;
                                  _showManualIPEntry =
                                      false; // Hide manual entry when selecting network
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
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
                                                  color:
                                                      AppColors.textSecondary,
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
                                      style: AppTextStyles.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    // Rescan Button
                    if (!_isScanning) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _scanNetworks,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Rescan Networks'),
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

// WiFi Network Model
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
      ssid: json['ssid'],
      rssi: json['rssi'],
      encryption: json['encryption'],
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
