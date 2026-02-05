import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/permission_service.dart';
import 'wifi_config_page.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  int _currentStep = 0;
  bool _wifiConfigured = false;
  String? _esp32IP;

  final List<SetupStepData> _setupSteps = [
    SetupStepData(
      title: 'Connect Power',
      description: 'Power up your ESP32 device',
      icon: Icons.power,
      color: AppColors.error,
    ),
    SetupStepData(
      title: 'Wi-Fi Setup',
      description: 'Connect device to your network',
      icon: Icons.wifi,
      color: AppColors.primary,
    ),
    SetupStepData(
      title: 'Position Camera',
      description: 'Optimal placement for detection',
      icon: Icons.videocam,
      color: AppColors.warning,
    ),
    SetupStepData(
      title: 'System Calibration',
      description: 'Optimize for your facial features',
      icon: Icons.tune,
      color: AppColors.success,
    ),
    SetupStepData(
      title: 'Final Testing',
      description: 'Verify system functionality',
      icon: Icons.check_circle,
      color: AppColors.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildProgressIndicator(),
                      Expanded(
                        child: _buildStepContent(),
                      ),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Setup',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Configure your ESP32 device',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            'Step ${_currentStep + 1} of ${_setupSteps.length}',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${((_currentStep + 1) / _setupSteps.length * 100).toInt()}% Complete',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              _setupSteps.length,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < _setupSteps.length - 1 ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final step = _setupSteps[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 50,
              color: step.color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            step.title,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildStepInstructions(),
        ],
      ),
    );
  }

  Widget _buildStepInstructions() {
    switch (_currentStep) {
      case 0:
        return _buildPowerStep();
      case 1:
        return _buildWiFiStep();
      case 2:
        return _buildCameraPositionStep();
      case 3:
        return _buildCalibrationStep();
      case 4:
        return _buildTestingStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPowerStep() {
    return Column(
      children: [
        _buildInstructionCard(
          '1',
          'Locate the USB Cable',
          'Find the USB cable included with your ESP32-CAM module.',
        ),
        _buildInstructionCard(
          '2',
          'Connect to Power Source',
          'Plug the USB cable into your car\'s USB port or a 5V adapter.',
        ),
        _buildInstructionCard(
          '3',
          'Wait for LED',
          'The ESP32 power LED should light up within 2-3 seconds.',
        ),
      ],
    );
  }

  Widget _buildWiFiStep() {
    return Column(
      children: [
        if (!_wifiConfigured) ...[
          _buildInstructionCard(
            '1',
            'Connect to ESP32 Network',
            'Open your phone\'s WiFi settings and connect to "Road-Safe-AI-Setup".',
          ),
          _buildInstructionCard(
            '2',
            'Return to App',
            'Once connected, come back to this app and tap "Configure WiFi".',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openWiFiConfig,
            icon: const Icon(Icons.settings_input_antenna),
            label: const Text('Configure WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'WiFi Configured!',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_esp32IP != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Device IP: $_esp32IP',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _wifiConfigured = false;
                      _esp32IP = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconfigure WiFi'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPositionStep() {
    return Column(
      children: [
        _buildInstructionCard(
          '1',
          'Mount on Dashboard',
          'Use the suction mount to attach the ESP32-CAM to your dashboard.',
        ),
        _buildInstructionCard(
          '2',
          'Face the Driver',
          'Position the camera to face the driver\'s seat directly.',
        ),
        _buildInstructionCard(
          '3',
          'Adjust Angle',
          'Tilt the camera 15-30° downward for optimal facial detection.',
        ),
        const SizedBox(height: 24),
        if (_esp32IP != null)
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to camera positioning page
              Navigator.pushNamed(
                context,
                '/camera-positioning',
                arguments: _esp32IP,
              );
            },
            icon: const Icon(Icons.videocam),
            label: const Text('Position Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalibrationStep() {
    return Column(
      children: [
        _buildInstructionCard(
          '1',
          'Sit in Normal Driving Position',
          'Adjust your seat and mirrors as you normally would.',
        ),
        _buildInstructionCard(
          '2',
          'Look Straight Ahead',
          'Keep your eyes focused on the road ahead for 10 seconds.',
        ),
        _buildInstructionCard(
          '3',
          'Stay Still',
          'The system will learn your baseline facial features.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // Start calibration
            _showCalibrationDialog();
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Calibration'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestingStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                'Setup Complete!',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Road Safe AI device is ready to protect you.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildInstructionCard(
          '✓',
          'Device Connection',
          'ESP32-CAM is connected and streaming.',
        ),
        _buildInstructionCard(
          '✓',
          'WiFi Configuration',
          'Device connected to your network.',
        ),
        _buildInstructionCard(
          '✓',
          'Camera Positioning',
          'Optimal angle for face detection.',
        ),
        _buildInstructionCard(
          '✓',
          'System Calibration',
          'Baseline features captured.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to live camera
          },
          icon: const Icon(Icons.play_circle_filled),
          label: const Text('Start Monitoring'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard(
      String number, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton.icon(
              onPressed: _canProceed() ? _handleNext : null,
              icon: Icon(
                _currentStep < _setupSteps.length - 1
                    ? Icons.arrow_forward
                    : Icons.check,
              ),
              label: Text(
                _currentStep < _setupSteps.length - 1 ? 'Next' : 'Finish',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true; // User manually confirms power
      case 1:
        return _wifiConfigured; // Need WiFi configured
      case 2:
        return _esp32IP != null; // Need device IP
      case 3:
        return true; // User manually confirms calibration
      case 4:
        return true; // Final step
      default:
        return false;
    }
  }

  void _handleNext() {
    if (_currentStep < _setupSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Setup complete
      Navigator.pop(context);
    }
  }

  Future<void> _openWiFiConfig() async {
    // ✅ Request permissions first
    final hasPermissions =
        await PermissionService.requestAllWiFiPermissions(context);

    if (!hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Location permission is required to detect WiFi networks'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Navigate to WiFi config page
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const WiFiConfigPage(),
      ),
    );

    if (result != null && mounted) {
      // WiFi configured successfully
      setState(() {
        _wifiConfigured = true;
        _esp32IP = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WiFi configured! Device IP: $result'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showCalibrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('System Calibration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Calibrating system...',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please stay still and look straight ahead',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Simulate calibration
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calibration complete!'),
          backgroundColor: AppColors.success,
        ),
      );
    });
  }
}

class SetupStepData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  SetupStepData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
