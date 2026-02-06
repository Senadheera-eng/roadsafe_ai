import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/camera_service.dart';
import '../services/drowsiness_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/mjpeg_viewer.dart';
import 'device_setup_page.dart';

class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage>
    with TickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final GlobalKey<MjpegViewerState> _mjpegKey = GlobalKey<MjpegViewerState>();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMonitoring = false;
  String? _currentDeviceIP;

  // Detection state
  Timer? _detectionTimer;
  DrowsinessResult? _lastDetection;
  int _detectionCount = 0;
  int _alertCount = 0;
  DateTime? _sessionStartTime;

  // FPS calculation
  int _frameCount = 0;
  double _currentFPS = 0.0;
  Timer? _fpsTimer;

  // Alert state
  bool _isAlerting = false;
  int _consecutiveClosedFrames = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _alertController;
  late Animation<double> _alertAnimation;

  ui.Image? _currentImage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkConnection();
    _startFPSCounter();
  }

  @override
  void dispose() {
    _stopMonitoring();
    _detectionTimer?.cancel();
    _fpsTimer?.cancel();
    _pulseController.dispose();
    _alertController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _alertController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _alertAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _alertController,
      curve: Curves.elasticOut,
    ));
  }

  // ============================================
  // ESP32 ALARM CONTROL (FIXED!)
  // ============================================

  Future<void> _triggerESP32Alarm(bool enable) async {
    final deviceIP = _cameraService.connectedDevice?.ipAddress;

    if (deviceIP == null) {
      print('❌ No ESP32 connected, cannot trigger alarm');
      print('   Using state IP: $_currentDeviceIP');

      // Try using state IP as fallback
      if (_currentDeviceIP == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ESP32 not connected - buzzer unavailable'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }
    }

    final targetIP = deviceIP ?? _currentDeviceIP!;
    final command = enable ? 'ALARM_ON' : 'ALARM_OFF';
    final url = 'http://$targetIP/alarm';

    print('');
    print('========================================');
    print('🔔 TRIGGERING ESP32 ALARM');
    print('========================================');
    print('   Command: $command');
    print('   URL: $url');
    print('   Device IP: $targetIP');
    print('   Timestamp: ${DateTime.now()}');

    // Try up to 3 times with shorter timeout
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('   Attempt $attempt/3...');

        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Connection': 'close',
              },
              body: json.encode({'command': command}),
            )
            .timeout(
              const Duration(seconds: 2), // Reduced from 3 to 2 seconds
            );

        print('   ✅ Response Status: ${response.statusCode}');
        print('   Response Body: ${response.body}');

        if (response.statusCode == 200) {
          print('✅ ESP32 alarm $command SUCCESS (attempt $attempt)');
          print('========================================\n');
          return; // Success! Exit immediately
        } else {
          print('⚠️ Unexpected status: ${response.statusCode}');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        }
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');

        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 300));
        } else {
          print('❌ ========================================');
          print('❌ ALL ATTEMPTS FAILED');
          print('❌ Error: $e');
          print('❌ ========================================\n');
        }
      }
    }
  }

  // ============================================
  // CONNECTION MANAGEMENT
  // ============================================

  Future<void> _checkConnection() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      bool connected = await _cameraService.quickConnect();

      if (connected) {
        final ip = _cameraService.connectedDevice?.ipAddress;
        setState(() {
          _isConnected = true;
          _currentDeviceIP = ip;
        });
        // Sync ESP32 IP to DrowsinessDetector so buzzer commands can reach the device
        if (ip != null) {
          DrowsinessDetector.setESP32IP(ip);
        }
        _showMessage('Connected to ESP32-CAM', AppColors.success);
      } else {
        await _scanForDevices();
      }
    } catch (e) {
      print('Connection check error: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final devices = await _cameraService.scanForDevices();

      if (devices.isNotEmpty) {
        bool connected = await _cameraService.connectToDevice(devices.first);

        if (connected) {
          final ip = devices.first.ipAddress;
          setState(() {
            _isConnected = true;
            _currentDeviceIP = ip;
          });
          // Sync ESP32 IP to DrowsinessDetector so buzzer commands can reach the device
          DrowsinessDetector.setESP32IP(ip);
          _showMessage('Connected to ESP32-CAM', AppColors.success);
        }
      } else {
        _showMessage('No devices found', AppColors.warning);
      }
    } catch (e) {
      _showMessage('Scan failed: ${e.toString()}', AppColors.error);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _stopMonitoring();
    _cameraService.disconnect();
    DrowsinessDetector.setESP32IP('');
    setState(() {
      _isConnected = false;
      _currentDeviceIP = null;
    });
    _showMessage('Disconnected', AppColors.info);
  }

  // ============================================
  // DROWSINESS DETECTION
  // ============================================

  void _startMonitoring() {
    if (!_isConnected) {
      _showMessage('Please connect to ESP32-CAM first', AppColors.warning);
      return;
    }

    setState(() {
      _isMonitoring = true;
      _sessionStartTime = DateTime.now();
      _alertCount = 0;
      _detectionCount = 0;
      _consecutiveClosedFrames = 0;
    });

    _showMessage('Monitoring started', AppColors.success);

    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (timer) => _performDetection(),
    );
  }

  Future<void> _stopMonitoring() async {
    _detectionTimer?.cancel();

    await DrowsinessDetector.stopContinuousVibration();
    await _triggerESP32Alarm(false);

    setState(() {
      _isMonitoring = false;
      _sessionStartTime = null;
      _lastDetection = null;
      _isAlerting = false;
    });

    if (_detectionCount > 0) {
      _showSessionSummary();
    }
  }

  Future<void> _performDetection() async {
    if (!_isConnected || !_isMonitoring) return;

    try {
      final currentFrame = _mjpegKey.currentState?.currentFrame;

      if (currentFrame == null) {
        print('⚠️ No frame available for detection');
        return;
      }

      print('📸 Capturing frame for detection (${currentFrame.length} bytes)');

      final result = await DrowsinessDetector.analyzeImage(currentFrame);

      if (result != null) {
        setState(() {
          _lastDetection = result;
          _detectionCount++;
        });

        if (result.isDrowsy) {
          _consecutiveClosedFrames++;
          print(
              '⚠️ Drowsy frame detected ($_consecutiveClosedFrames consecutive)');

          if (_consecutiveClosedFrames >= 2 && !_isAlerting) {
            print('🚨 TRIGGERING NEW ALERT (threshold reached)');
            await _triggerDrowsinessAlert();
          } else if (_isAlerting) {
            print('⚠️ Still drowsy, alert already active');
          }
        } else {
          if (_consecutiveClosedFrames > 0) {
            if (_isAlerting) {
              print('👀 Eyes opened, but ALERT STILL ACTIVE');
            } else {
              print('✅ Eyes open - resetting counter');
            }
          }
          _consecutiveClosedFrames = 0;
        }
      }
    } catch (e) {
      print('❌ Detection error: $e');
    }
  }

  // ============================================
  // ALERT TRIGGERING (FIXED!)
  // ============================================

  Future<void> _triggerDrowsinessAlert() async {
    if (_isAlerting) {
      print('⚠️ Alert already active');
      return;
    }

    setState(() {
      _isAlerting = true;
      _alertCount++;
    });

    print('');
    print('🚨 ========================================');
    print('🚨 DROWSINESS ALERT TRIGGERED!');
    print('🚨 ========================================');
    print('   Alert #$_alertCount');
    print('🚨 ========================================');
    print('');

    // FIX: Start animation immediately (non-blocking)
    _alertController.forward().then((_) {
      _alertController.reverse();
    });

    // FIX: Start vibration and ESP32 alarm in parallel, then show dialog
    try {
      print('📳 Starting phone vibration...');
      final vibrationFuture = DrowsinessDetector.startContinuousVibration();

      print('🔔 Triggering ESP32 buzzer...');
      final esp32Future = _triggerESP32Alarm(true);

      // Wait for BOTH to complete before showing dialog
      await Future.wait([
        vibrationFuture,
        esp32Future,
      ], eagerError: false);

      print('✅ Both alerts started successfully');
      print('');

      // NOW show the dialog after alerts are active
      if (mounted) {
        _showAlertDialog();
      }
    } catch (e) {
      print('❌ Alert trigger error: $e');
      // Still show dialog even if there's an error
      if (mounted) {
        _showAlertDialog();
      }
    }
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppColors.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (value * 0.4),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'DROWSINESS DETECTED!',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _lastDetection?.hasYawn == true
                    ? 'Yawning detected - Take a break!'
                    : 'Eyes closed for too long - Pull over safely!',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vibration, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Phone vibrating',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ESP32 buzzer active',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚠️ Alerts will continue until you press the button below',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  print('');
                  print('✅ ========================================');
                  print('✅ USER PRESSED "I\'M AWAKE"');
                  print('✅ ========================================');

                  print('   Stopping phone vibration...');
                  await DrowsinessDetector.stopContinuousVibration();
                  print('   ✓ Phone vibration stopped');

                  print('   Stopping ESP32 buzzer...');
                  await _triggerESP32Alarm(false);
                  print('   ✓ ESP32 buzzer stopped');

                  print('✅ All alerts dismissed');
                  print('✅ ========================================');
                  print('');

                  Navigator.pop(context);

                  await Future.delayed(const Duration(seconds: 1));
                  setState(() {
                    _isAlerting = false;
                    _consecutiveClosedFrames = 0;
                  });

                  print('📊 Alert state reset\n');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'I\'m Awake',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionSummary() {
    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Summary', style: AppTextStyles.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('Duration', '$minutes minutes'),
            _buildSummaryRow('Detections', '$_detectionCount'),
            _buildSummaryRow('Alerts', '$_alertCount'),
            _buildSummaryRow(
              'Status',
              _alertCount == 0
                  ? 'Excellent'
                  : _alertCount < 3
                      ? 'Good'
                      : 'Needs Rest',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style:
                AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================
  // FPS COUNTER
  // ============================================

  void _startFPSCounter() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentFPS = _frameCount.toDouble();
          _frameCount = 0;
        });
      }
    });
  }

  void _onFrameReceived() {
    _frameCount++;
  }

  // ============================================
  // UI HELPERS
  // ============================================

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // BUILD UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            Expanded(child: _buildCameraFeed()),
            if (_isMonitoring) _buildDetectionInfo(),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Live Camera Feed', style: AppTextStyles.headlineMedium),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _isConnected
          ? AppColors.success.withOpacity(0.1)
          : AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isConnected ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
              boxShadow: [
                if (_isConnected)
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected
                      ? 'Connected'
                      : _isConnecting
                          ? 'Connecting...'
                          : 'Disconnected',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: _isConnected ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_currentDeviceIP != null)
                  Text(
                    'IP: $_currentDeviceIP',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentFPS.toStringAsFixed(0)} FPS',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraFeed() {
    if (_isConnecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to ESP32-CAM...', style: AppTextStyles.bodyLarge),
          ],
        ),
      );
    }

    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 80, color: AppColors.textHint),
            const SizedBox(height: 24),
            Text(
              'Camera Disconnected',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan for ESP32-CAM devices to connect',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanForDevices,
              icon: const Icon(Icons.search),
              label: const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceSetupPage()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Device Setup'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: Center(
            child: MjpegViewer(
              key: _mjpegKey,
              streamUrl: _cameraService.streamUrl,
              fit: BoxFit.contain,
              onFrameReceived: _onFrameReceived,
            ),
          ),
        ),
        if (_lastDetection != null && _isMonitoring)
          CustomPaint(
            painter: DetectionOverlayPainter(
              detectionResult: _lastDetection!,
              imageSize: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.6),
            ),
            child: Container(),
          ),
        if (_lastDetection != null && _isMonitoring)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildDetectionOverlay(),
          ),
        if (_isMonitoring)
          Positioned(
            top: 16,
            left: 16,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MONITORING',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_isAlerting)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _alertAnimation,
              builder: (context, child) {
                return Container(
                  color:
                      AppColors.error.withOpacity(0.3 * _alertAnimation.value),
                  child: Center(
                    child: Transform.scale(
                      scale: _alertAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_rounded,
                                color: Colors.white, size: 60),
                            const SizedBox(height: 8),
                            Text(
                              'DROWSINESS\nDETECTED!',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDetectionOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Eye Opening: ${_lastDetection!.eyeOpenPercentage.toStringAsFixed(0)}%',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _lastDetection!.isDrowsy
                      ? AppColors.error
                      : AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastDetection!.hasYawn
                      ? 'YAWNING'
                      : _lastDetection!.isDrowsy
                          ? 'DROWSY'
                          : 'ALERT',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _lastDetection!.eyeOpenPercentage / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _lastDetection!.eyeOpenPercentage > 50
                    ? AppColors.success
                    : AppColors.error,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionInfo() {
    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Icons.timer,
            label: 'Duration',
            value: '$minutes:${seconds.toString().padLeft(2, '0')}',
          ),
          Container(width: 1, height: 40, color: AppColors.surfaceVariant),
          _buildInfoItem(
            icon: Icons.visibility,
            label: 'Detections',
            value: '$_detectionCount',
          ),
          Container(width: 1, height: 40, color: AppColors.surfaceVariant),
          _buildInfoItem(
            icon: Icons.warning,
            label: 'Alerts',
            value: '$_alertCount',
            valueColor: _alertCount > 0 ? AppColors.error : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style:
              AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // TEST BUTTONS (can remove after debugging)
          if (_isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        print('🧪 MANUAL TEST: Buzzer ON');
                        await _triggerESP32Alarm(true);
                        await Future.delayed(Duration(seconds: 2));
                        print('🧪 MANUAL TEST: Buzzer OFF');
                        await _triggerESP32Alarm(false);
                      },
                      icon: Icon(Icons.volume_up, size: 20),
                      label:
                          Text('Test Buzzer', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ip = _cameraService.connectedDevice?.ipAddress ??
                            _currentDeviceIP;
                        if (ip != null) {
                          print('🧪 Testing /test_alarm endpoint...');
                          try {
                            final response = await http
                                .get(
                                  Uri.parse('http://$ip/test_alarm'),
                                )
                                .timeout(Duration(seconds: 5));
                            print('✅ Test endpoint: ${response.statusCode}');
                            print('   ${response.body}');
                          } catch (e) {
                            print('❌ Test endpoint failed: $e');
                          }
                        }
                      },
                      icon: Icon(Icons.bug_report, size: 20),
                      label:
                          Text('Test Endpoint', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              if (!_isConnected)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _scanForDevices,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isConnecting ? 'Scanning...' : 'Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (_isConnected) ...[
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isMonitoring ? _stopMonitoring : _startMonitoring,
                    icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(
                        _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isMonitoring ? AppColors.error : AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.power_settings_new),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// DETECTION OVERLAY PAINTER
// ============================================

class DetectionOverlayPainter extends CustomPainter {
  final DrowsinessResult detectionResult;
  final Size imageSize;

  DetectionOverlayPainter({
    required this.detectionResult,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var detection in detectionResult.detectionBoxes) {
      final rect = Rect.fromCenter(
        center: Offset(
          detection.x * size.width,
          detection.y * size.height,
        ),
        width: detection.width * size.width,
        height: detection.height * size.height,
      );

      Color boxColor;
      if (detection.isYawn) {
        boxColor = Colors.orange;
      } else if (detection.isDrowsy) {
        boxColor = Colors.red;
      } else {
        boxColor = Colors.green;
      }

      final paint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(rect, paint);

      final labelPaint = Paint()..color = boxColor;
      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 24,
        120,
        24,
      );
      canvas.drawRect(labelRect, labelPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text:
              '${detection.className} ${(detection.confidence * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - 20),
      );
    }
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) =>
      oldDelegate.detectionResult != detectionResult;
}
