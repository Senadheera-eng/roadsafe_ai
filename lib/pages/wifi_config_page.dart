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

  Future<void> _scanNetworks() async {
    setState(() {
      _isScanning = true;
      _networks.clear();
      _statusMessage = '';
    });

    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📡 Scan attempt $attempt/$maxRetries...');

        final response = await http
            .get(Uri.parse('http://${widget.esp32IP}/scan'))
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List networks = data['networks'] ?? [];

          if (networks.isNotEmpty) {
            setState(() {
              _networks = networks.map((n) => WiFiNetwork.fromJson(n)).toList()
                ..sort((a, b) => b.rssi.compareTo(a.rssi));
              _isScanning = false;
              _statusMessage = '';
            });
            return; // ✅ Success
          }

          // Empty list — retry if attempts remain
          if (attempt < maxRetries) {
            print('📡 Empty scan result, retrying in 3s...');
            if (mounted) {
              setState(() {
                _statusMessage =
                    'No networks found, retrying ($attempt/$maxRetries)...';
              });
            }
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('📡 Scan attempt $attempt error: $e');
        if (attempt < maxRetries) {
          if (mounted) {
            setState(() {
              _statusMessage =
                  'Scan failed, retrying ($attempt/$maxRetries)...';
            });
          }
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        // Final failure
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Could not scan WiFi networks. Make sure you are '
                'connected to the RoadSafe-AI-Setup WiFi and tap Rescan.';
          });
        }
        return;
      }
    }

    // All retries returned empty results
    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'No WiFi networks detected. Tap Rescan to try again.';
      });
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
      _statusMessage = 'Connecting to WiFi...';
      _connectionSuccess = false;
    });

    try {
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

      final data = json.decode(response.body);

      // Try to get IP from response first
      String? newIp;
      if (data is Map && data['ip'] != null) {
        newIp = data['ip'].toString();
      }

      if (data['success'] == true && newIp != null) {
        setState(() {
          _statusMessage = 'Connected! IP: $newIp';
          _connectionSuccess = true;
        });

        _showSnackBar('✓ WiFi configured successfully!', AppColors.success);

        // Wait and go back with IP
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, newIp);
        return;
      }

      // Some ESP32 firmwares reboot the module and don't return the new IP.
      // In that case we attempt to discover the device on the network.
      setState(() {
        _statusMessage = 'Searching for device on network...';
      });

      final devices = await CameraService().scanForDevices();
      if (devices.isNotEmpty) {
        newIp = devices.first.ipAddress;
        setState(() {
          _statusMessage = 'Found device at $newIp';
          _connectionSuccess = true;
        });

        _showSnackBar('✓ WiFi configured successfully!', AppColors.success);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, newIp);
        return;
      }

      // If we reach here, we couldn't discover the device
      setState(() {
        _statusMessage = 'Connection failed: ${data['message'] ?? 'Unknown'}';
        _connectionSuccess = false;
      });
      _showSnackBar('Failed to connect', AppColors.error);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _connectionSuccess = false;
      });
      _showSnackBar('Connection error', AppColors.error);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.purpleGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -60,
                      top: -60,
                      child: Icon(
                        Icons.wifi_rounded,
                        size: 280,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
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
                                Icons.settings_input_antenna_rounded,
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
                            Text(
                              'Connect ESP32-CAM to WiFi',
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
                    // Status Message
                    if (_statusMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
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
                                  ? Icons.check_circle_rounded
                                  : Icons.info_rounded,
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

                    // Scanning indicator
                    if (_isScanning)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text(
                              'Scanning for WiFi networks...',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),

                    // No networks found — empty state
                    if (!_isScanning && _networks.isEmpty) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No WiFi Networks Found',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Make sure you\'re connected to the\n'
                                'RoadSafe-AI-Setup network and try again.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _scanNetworks,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Rescan Networks'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Network List
                    if (!_isScanning && _networks.isNotEmpty) ...[
                      Text(
                        'Available Networks',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.primary, width: 2)
                                      : null,
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
