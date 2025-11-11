import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/mjpeg_viewer.dart';
import 'live_camera_page.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  final CameraService _cameraService = CameraService();

  List<ESP32Device> _foundDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  int _currentStep = 0;
  bool _showPositioningGuide = false;

  // Setup steps
  final List<SetupStep> _setupSteps = [
    SetupStep(
      title: 'Scan for Device',
      description: 'Find your ESP32-CAM on the network',
      icon: Icons.search,
    ),
    SetupStep(
      title: 'Connect Device',
      description: 'Establish connection with ESP32-CAM',
      icon: Icons.link,
    ),
    SetupStep(
      title: 'Position Camera',
      description: 'Adjust camera angle for optimal detection',
      icon: Icons.videocam,
    ),
    SetupStep(
      title: 'Ready to Use',
      description: 'Start monitoring driver drowsiness',
      icon: Icons.check_circle,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingConnection();
  }

  void _checkExistingConnection() {
    if (_cameraService.isConnected) {
      setState(() {
        _currentStep = 2; // Skip to positioning step
        _showPositioningGuide = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title:
            const Text('Device Setup', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cameraService.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _cameraService.disconnect();
                setState(() {
                  _currentStep = 0;
                  _foundDevices.clear();
                  _showPositioningGuide = false;
                });
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.oceanGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<bool>(
            stream: _cameraService.connectionStream,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;

              if (isConnected && _showPositioningGuide) {
                return _buildPositioningGuide();
              }

              return _buildSetupSteps();
            },
          ),
        ),
      ),
    );
  }

  // ============================================
  // SETUP STEPS VIEW
  // ============================================

  Widget _buildSetupSteps() {
    return Column(
      children: [
        // Progress Indicator
        _buildProgressIndicator(),

        // Content Area
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Current Step Content
              _buildCurrentStepContent(),

              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(),

              const SizedBox(height: 24),

              // Found Devices
              if (_foundDevices.isNotEmpty) _buildFoundDevices(),

              const SizedBox(height: 24),

              // Instructions
              _buildInstructions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(
          _setupSteps.length,
          (index) => Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: index <= _currentStep
                          ? const LinearGradient(
                              colors: AppColors.primaryGradient)
                          : null,
                      color: index > _currentStep
                          ? Colors.white.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _setupSteps.length - 1) const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    final step = _setupSteps[_currentStep];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Icon(
                step.icon,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Step ${_currentStep + 1} of ${_setupSteps.length}',
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.title,
              style: AppTextStyles.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_currentStep) {
      case 0: // Scan step
        return Column(
          children: [
            GradientButton(
              onPressed: _isScanning ? null : _quickScan,
              text: 'Quick Scan (10.251.96.17)',
              isLoading: _isScanning && _foundDevices.isEmpty,
              gradientColors: AppColors.successGradient,
              icon: Icons.flash_on,
            ),
            const SizedBox(height: 12),
            GradientButton(
              onPressed: _isScanning ? null : _fullNetworkScan,
              text: 'Full Network Scan',
              isLoading: _isScanning && _foundDevices.isEmpty,
              gradientColors: AppColors.primaryGradient,
              icon: Icons.search,
            ),
          ],
        );

      case 1: // Connect step
        if (_foundDevices.isEmpty) {
          return GradientButton(
            onPressed: _quickScan,
            text: 'Scan Again',
            gradientColors: AppColors.primaryGradient,
            icon: Icons.refresh,
          );
        }
        return const SizedBox.shrink();

      case 2: // Position step
        return GradientButton(
          onPressed: () {
            setState(() {
              _showPositioningGuide = true;
            });
          },
          text: 'View Camera Feed',
          gradientColors: AppColors.primaryGradient,
          icon: Icons.videocam,
        );

      case 3: // Ready step
        return GradientButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LiveCameraPage()),
            );
          },
          text: 'Start Monitoring',
          gradientColors: AppColors.successGradient,
          icon: Icons.play_arrow,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFoundDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found Devices',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._foundDevices.map((device) => _buildDeviceCard(device)).toList(),
      ],
    );
  }

  Widget _buildDeviceCard(ESP32Device device) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.successGradient,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.videocam, color: Colors.white),
        ),
        title: Text(
          'ESP32-CAM',
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          device.ipAddress,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white70,
          ),
        ),
        trailing: _isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Connect'),
              ),
      ),
    );
  }

  Widget _buildInstructions() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Setup Instructions',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionStep('1', 'Power on your ESP32-CAM module'),
            _buildInstructionStep('2', 'Ensure ESP32-CAM is connected to WiFi'),
            _buildInstructionStep(
                '3', 'Make sure your phone is on the same network'),
            _buildInstructionStep('4', 'Tap "Quick Scan" to find your device'),
            _buildInstructionStep(
                '5', 'Connect and position the camera correctly'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.labelMedium.copyWith(
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
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // POSITIONING GUIDE VIEW
  // ============================================

  Widget _buildPositioningGuide() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showPositioningGuide = false;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Position Your Camera',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live Camera Feed
        // Live Camera Feed
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // MJPEG Stream - FIXED
                    MjpegViewer(
                      stream:
                          _cameraService.streamUrl, // ✅ Fixed: Added underscore
                    ),

                    // Face Detection Guide Overlay
                    CustomPaint(
                      painter: FaceGuidePainter(),
                      child: Container(),
                    ),

                    // Top Overlay with tips
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Position your face within the guide',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                ),
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
          ),
        ),

        // Positioning Instructions
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Positioning Tips
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Positioning Tips',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPositioningTip(
                          Icons.center_focus_strong,
                          'Center Face',
                          'Keep your face centered in the frame',
                          AppColors.primary,
                        ),
                        _buildPositioningTip(
                          Icons.zoom_out,
                          'Proper Distance',
                          'Maintain 30-50cm from the camera',
                          AppColors.success,
                        ),
                        _buildPositioningTip(
                          Icons.wb_sunny,
                          'Good Lighting',
                          'Ensure adequate lighting on your face',
                          AppColors.warning,
                        ),
                        _buildPositioningTip(
                          Icons.remove_red_eye,
                          'Eyes Visible',
                          'Make sure both eyes are clearly visible',
                          AppColors.info,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Confirm Button
                GradientButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 3; // Move to ready step
                      _showPositioningGuide = false;
                    });
                    _showSuccessDialog();
                  },
                  text: 'Position Confirmed',
                  gradientColors: AppColors.successGradient,
                  icon: Icons.check_circle,
                ),

                const SizedBox(height: 8),

                // Skip Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 3;
                      _showPositioningGuide = false;
                    });
                  },
                  child: Text(
                    'Skip for now',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositioningTip(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTIONS
  // ============================================

  Future<void> _quickScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      print('🔍 Quick scanning 10.251.96.17...');

      final device = await _cameraService.scanKnownIPs();

      if (device.isNotEmpty && mounted) {
        setState(() {
          _foundDevices = device;
          _currentStep = 1; // Move to connect step
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${device.length} ESP32-CAM device(s)'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No devices found. Try full network scan.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _fullNetworkScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning network...'),
                SizedBox(height: 8),
                Text(
                  'This may take up to 30 seconds',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final devices = await _cameraService.scanForDevices();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        setState(() {
          _foundDevices = devices;
          if (devices.isNotEmpty) {
            _currentStep = 1;
          }
        });

        if (devices.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${devices.length} ESP32-CAM device(s)'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No ESP32-CAM devices found on network'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _connectToDevice(ESP32Device device) async {
    setState(() => _isConnecting = true);

    try {
      final success = await _cameraService.connectToDevice(device);

      if (success && mounted) {
        setState(() {
          _currentStep = 2; // Move to positioning step
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Auto-show positioning guide after 1 second
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _showPositioningGuide = true;
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.successGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Setup Complete!',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ESP32-CAM is ready for drowsiness detection',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          GradientButton(
            onPressed: () {
              Navigator.pop(context);
            },
            text: 'Got it!',
            gradientColors: AppColors.primaryGradient,
          ),
        ],
      ),
    );
  }
}

// ============================================
// HELPER CLASSES
// ============================================

class SetupStep {
  final String title;
  final String description;
  final IconData icon;

  SetupStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

// Face Guide Painter for positioning overlay
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw oval guide for face
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.5;
    final ovalHeight = size.height * 0.6;

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawOval(rect, paint);

    // Draw corner guides
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom - cornerLength),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
