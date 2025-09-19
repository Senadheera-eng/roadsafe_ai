import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/camera_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/mjpeg_viewer.dart';

class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage>
    with TickerProviderStateMixin {
  Timer? _connectionWatchdog;
  String? _lastConnectedIP;

  final CameraService _cameraService = CameraService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isScanning = false;
  bool _isConnecting = false;
  List<ESP32Device> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Listen for device discoveries
    _cameraService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          _isScanning = false;
        });
      }
    });

    // Listen for connection status
    _cameraService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        if (isConnected) {
          _showMessage(
              'Connected to ESP32-CAM successfully!', AppColors.success);
        }
      }
    });

    // Auto-start scanning
    _startScanning();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectionWatchdog?.cancel();
    super.dispose();
  }

  void _startConnectionWatchdog() {
    _connectionWatchdog?.cancel();

    _connectionWatchdog = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_cameraService.isConnected) {
        final isStillConnected = await _cameraService.testConnection();
        if (!isStillConnected && mounted) {
          _showMessage(
              'Connection lost, attempting to reconnect...', AppColors.warning);

          // Try to reconnect to last known IP
          if (_lastConnectedIP != null) {
            final device = ESP32Device(
              ipAddress: _lastConnectedIP!,
              deviceName: 'ESP32-CAM ($_lastConnectedIP)',
              isConnected: false,
            );

            await _connectToDevice(device);
          }
        }
      }
    });
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    // Try targeted scan first
    final targetedDevices = await _cameraService.scanKnownIPs();

    if (targetedDevices.isNotEmpty) {
      setState(() {
        _discoveredDevices = targetedDevices;
        _isScanning = false;
      });
      return;
    }

    // If targeted scan fails, try full scan
    await _cameraService.scanForDevices();
  }

  // Update _connectToDevice method
  Future<void> _connectToDevice(ESP32Device device) async {
    setState(() {
      _isConnecting = true;
    });

    final success = await _cameraService.connectToDevice(device);

    if (success) {
      _lastConnectedIP = device.ipAddress;
      _startConnectionWatchdog();
    } else {
      _showMessage(
          'Failed to connect to ${device.deviceName}', AppColors.error);
    }
  }

  Future<void> _debugESP32Connection() async {
    const testIP = '10.19.80.42';

    _showMessage('Testing connection to $testIP...', AppColors.info);

    try {
      // Test 1: Basic HTTP GET
      print('Debug: Testing HTTP GET to $testIP');
      final response = await http.get(
        Uri.parse('http://$testIP/'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 10));

      print('Debug: HTTP Response Status: ${response.statusCode}');
      print('Debug: Response Headers: ${response.headers}');
      print('Debug: Response Body Length: ${response.body.length}');
      print(
          'Debug: Response Body Preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        _showMessage('HTTP connection successful!', AppColors.success);

        // Test 2: Check stream endpoint
        try {
          final streamResponse = await http
              .head(
                Uri.parse('http://$testIP/stream'),
              )
              .timeout(Duration(seconds: 5));

          print('Debug: Stream endpoint status: ${streamResponse.statusCode}');
          _showMessage('Stream endpoint accessible!', AppColors.success);

          // Manual device creation since auto-detection isn't working
          final device = ESP32Device(
            ipAddress: testIP,
            deviceName: 'ESP32-CAM ($testIP)',
            isConnected: false,
          );

          await _connectToDevice(device);
        } catch (e) {
          print('Debug: Stream test failed: $e');
          _showMessage('Stream endpoint failed: $e', AppColors.error);
        }
      } else {
        _showMessage(
            'HTTP failed with status: ${response.statusCode}', AppColors.error);
      }
    } catch (e) {
      print('Debug: Connection test failed: $e');
      _showMessage('Connection failed: $e', AppColors.error);
    }
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showManualIPDialog() {
    final TextEditingController ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Manual IP Entry',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your ESP32-CAM IP address:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g., 10.19.80.42',
                prefixIcon: const Icon(Icons.router_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can find the IP address in your ESP32 serial monitor or router admin panel.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                // Basic IP validation
                final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                if (ipRegex.hasMatch(ip)) {
                  final device = ESP32Device(
                    ipAddress: ip,
                    deviceName: 'ESP32-CAM ($ip)',
                    isConnected: false,
                  );
                  await _connectToDevice(device);
                } else {
                  _showMessage('Invalid IP address format', AppColors.error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Live Camera Feed',
          style: AppTextStyles.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection Status
                  _buildConnectionStatus(),

                  const SizedBox(height: 24),

                  // Camera Feed or Device List
                  if (_cameraService.isConnected)
                    _buildCameraFeed()
                  else
                    _buildDeviceDiscovery(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final isConnected = _cameraService.isConnected;
    final device = _cameraService.connectedDevice;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isConnected ? AppColors.success : AppColors.warning)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isConnected ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: isConnected ? AppColors.success : AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Camera Connected' : 'Camera Disconnected',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isConnected ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isConnected
                      ? 'Streaming from ${device?.deviceName ?? 'Unknown Device'}'
                      : 'Scan for ESP32-CAM devices to connect',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            IconButton(
              onPressed: () {
                _cameraService.disconnect();
                setState(() {});
              },
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Feed',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: MjpegViewer(
              isLive: true,
              error: (context, error, stack) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Feed Error',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check camera connection',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _cameraService.disconnect();
                          setState(() {});
                        },
                        child: const Text('Reconnect'),
                      ),
                    ],
                  ),
                );
              },
              stream: _cameraService.streamUrl,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Camera Controls
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _showMessage('Capture feature coming soon!', AppColors.info);
                },
                icon: const Icon(Icons.camera_rounded),
                label: const Text('Capture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _cameraService.testConnection();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceDiscovery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Available Devices',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        // Buttons Row - Fixed overflow issue
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showManualIPDialog(),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Manual IP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScanning,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _debugESP32Connection(),
              icon: const Icon(Icons.bug_report_rounded, size: 18),
              label: const Text('Debug'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Quick Connect Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final device = ESP32Device(
                ipAddress: '10.19.80.42',
                deviceName: 'ESP32-CAM (10.19.80.42)',
                isConnected: false,
              );
              await _connectToDevice(device);
            },
            icon: const Icon(Icons.flash_on_rounded),
            label: const Text('Quick Connect (10.19.80.42)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device List or States
        if (_discoveredDevices.isEmpty && !_isScanning)
          _buildEmptyState()
        else if (_discoveredDevices.isNotEmpty)
          Column(
            children: _discoveredDevices
                .map((device) => _buildDeviceCard(device))
                .toList(),
          )
        else if (_isScanning)
          _buildScanningState(),

        const SizedBox(height: 20),

        // Connection Tips Section
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connection Tips',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTipItem(
                  'Ensure ESP32-CAM is powered on and connected to Wi-Fi'),
              _buildTipItem('Both devices should be on the same network'),
              _buildTipItem('Check your router\'s admin panel for device IP'),
              _buildTipItem('Use Manual IP if auto-scan doesn\'t work'),
              _buildTipItem('Try Quick Connect for your known ESP32-CAM'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              color: AppColors.info,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ESP32Device device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.accentGradient,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'IP: ${device.ipAddress}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isConnecting ? null : () => _connectToDevice(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isConnecting ? 'Connecting...' : 'Connect',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 20,
      child: Column(
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No ESP32-CAM Devices Found',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your ESP32-CAM is powered on and connected to the same Wi-Fi network.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanningState() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 20,
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Scanning for Devices...',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
