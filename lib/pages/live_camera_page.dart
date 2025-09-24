import 'dart:async';
import '../services/drowsiness_service.dart';
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

  bool _isDrowsinessDetectionEnabled = false;
  DrowsinessResult? _lastDetectionResult;
  bool _isScanning = false;
  bool _isConnecting = false;
  List<ESP32Device> _discoveredDevices = [];
  bool _isAPITested = false;

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
          _testAPIConnection(); // Test API when camera connects
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

  Future<void> _testAPIConnection() async {
    if (_isAPITested) return;

    setState(() {
      _isAPITested = true;
    });

    _showMessage('Testing Roboflow API connection...', AppColors.info);

    final isAPIWorking = await DrowsinessDetector.testAPIConnection();

    if (isAPIWorking) {
      _showMessage('Roboflow API connected successfully!', AppColors.success);
    } else {
      _showMessage(
          'Warning: Roboflow API connection failed. Check your API key.',
          AppColors.error);
    }
  }

  void _startConnectionWatchdog() {
    _connectionWatchdog?.cancel();

    _connectionWatchdog = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_cameraService.isConnected) {
        try {
          final response = await http
              .head(
                Uri.parse(
                    'http://${_cameraService.connectedDevice?.ipAddress}/'),
              )
              .timeout(Duration(seconds: 3));

          if (response.statusCode != 200) {
            throw Exception('Device not responding');
          }
        } catch (e) {
          if (mounted) {
            print('Connection check failed: $e');
            _showMessage('Connection check failed', AppColors.warning);
          }
        }
      }
    });
  }

  void _onDrowsinessDetected(DrowsinessResult result) {
    setState(() {
      _lastDetectionResult = result;
    });

    _showMessage('DROWSINESS DETECTED! Phone is vibrating.', AppColors.error);

    // Show detailed detection info
    final drowsyBoxes =
        result.detectionBoxes.where((box) => box.isDrowsy).toList();
    if (drowsyBoxes.isNotEmpty) {
      final reasons = drowsyBoxes.map((box) => box.className).join(', ');
      _showMessage('Detected: $reasons', AppColors.warning);
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    // First try targeted scan for known IP
    final knownDevices = await _cameraService.scanKnownESP32();

    if (knownDevices.isNotEmpty) {
      setState(() {
        _discoveredDevices = knownDevices;
        _isScanning = false;
      });
      _showMessage('Found your ESP32-CAM!', AppColors.success);
      return;
    }

    // If known IP not found, do full scan
    await _cameraService.scanForDevices();

    setState(() {
      _isScanning = false;
    });

    if (_discoveredDevices.isEmpty) {
      _showMessage('ESP32-CAM not found. Try Quick Connect or Manual IP.',
          AppColors.warning);
    }
  }

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
          duration: Duration(seconds: message.contains('DROWSINESS') ? 5 : 3),
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
        actions: [
          // Debug button
          IconButton(
            onPressed: () => _showDebugInfo(),
            icon: const Icon(
              Icons.bug_report,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
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

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Camera Status:', style: AppTextStyles.titleMedium),
              Text('Connected: ${_cameraService.isConnected}'),
              Text(
                  'Device IP: ${_cameraService.connectedDevice?.ipAddress ?? "None"}'),
              Text('Stream URL: ${_cameraService.streamUrl}'),
              SizedBox(height: 16),
              Text('AI Detection:', style: AppTextStyles.titleMedium),
              Text('Enabled: $_isDrowsinessDetectionEnabled'),
              Text('API Tested: $_isAPITested'),
              Text(
                  'Last Result: ${_lastDetectionResult?.totalPredictions ?? 0} predictions'),
              if (_lastDetectionResult != null) ...[
                Text(
                    'Detection Boxes: ${_lastDetectionResult!.detectionBoxes.length}'),
                for (var box in _lastDetectionResult!.detectionBoxes)
                  Text(
                      '  - ${box.className}: ${(box.confidence * 100).toInt()}%'),
              ],
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _testAPIConnection();
                },
                child: Text('Test API Connection'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final isConnected = _cameraService.isConnected;
    final device = _cameraService.connectedDevice;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
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
                  isConnected
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
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
                        color:
                            isConnected ? AppColors.success : AppColors.warning,
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
                    setState(() {
                      _isAPITested = false;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),

          // API Status indicator
          if (isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isAPITested ? AppColors.success : AppColors.warning)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isAPITested ? AppColors.success : AppColors.warning,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAPITested ? Icons.cloud_done : Icons.cloud_off,
                    color: _isAPITested ? AppColors.success : AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isAPITested
                        ? 'Roboflow API Ready'
                        : 'Testing API Connection...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color:
                          _isAPITested ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
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

  Widget _buildCameraFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Feed',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // AI Detection Toggle
            Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  color: _isDrowsinessDetectionEnabled
                      ? AppColors.success
                      : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isDrowsinessDetectionEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isDrowsinessDetectionEnabled = value;
                    });

                    _showMessage(
                      value
                          ? 'AI Drowsiness Detection Enabled - You should see detection boxes'
                          : 'AI Drowsiness Detection Disabled',
                      value ? AppColors.success : AppColors.warning,
                    );
                  },
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          height: 400, // Increased height for better visibility
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
              enableDrowsinessDetection: _isDrowsinessDetectionEnabled,
              onDrowsinessDetected: _onDrowsinessDetected,
              stream: _cameraService.streamUrl,
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
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Detection Status Display
        if (_isDrowsinessDetectionEnabled && _lastDetectionResult != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lastDetectionResult!.isDrowsy
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _lastDetectionResult!.isDrowsy
                    ? AppColors.error
                    : AppColors.success,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _lastDetectionResult!.isDrowsy
                          ? Icons.warning
                          : Icons.check_circle,
                      color: _lastDetectionResult!.isDrowsy
                          ? AppColors.error
                          : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _lastDetectionResult!.isDrowsy
                          ? 'DROWSINESS DETECTED'
                          : 'Driver Alert',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _lastDetectionResult!.isDrowsy
                            ? AppColors.error
                            : AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Detections: ${_lastDetectionResult!.detectionBoxes.length}',
                  style: AppTextStyles.bodySmall,
                ),
                if (_lastDetectionResult!.detectionBoxes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: _lastDetectionResult!.detectionBoxes.map((box) {
                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: box.isDrowsy
                              ? AppColors.error.withOpacity(0.2)
                              : AppColors.info.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${box.className} ${(box.confidence * 100).toInt()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
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
                  _testAPIConnection();
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
        Text(
          'Available Devices',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
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
          ],
        ),
        const SizedBox(height: 16),
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
      ],
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
