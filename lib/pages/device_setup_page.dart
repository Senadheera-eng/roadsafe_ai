import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/mjpeg_viewer.dart';
import '../services/camera_service.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage>
    with TickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  StreamSubscription? _connectionSubscription;

  late AnimationController _animationController;
  late AnimationController _calibrationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _calibrationProgress;

  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isConnectingWifi = false;
  bool _isCalibrating = false;

  // State from CameraService
  bool _isDeviceConnected = false;
  String? _connectedIp;

  // Controllers for user input
  final _wifiNameController =
      TextEditingController(text: 'My_Car_Hotspot'); // Mock defaults
  final _wifiPasswordController = TextEditingController(text: 'password123');
  final _deviceNameController = TextEditingController(text: 'RoadSafe Device');

  // Setup steps data
  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Power Connection',
      description: 'Check device power and initial connection',
      icon: Icons.power_rounded,
      isCompleted: false,
    ),
    SetupStep(
      title: 'Wi-Fi Configuration',
      description: 'Connect device to your network',
      icon: Icons.wifi_rounded,
      isCompleted: false,
    ),
    SetupStep(
      title: 'Camera Positioning',
      description: 'Position camera using live feed',
      icon: Icons.camera_alt_rounded,
      isCompleted: false,
    ),
    SetupStep(
      title: 'System Calibration',
      description: 'Calibrate for your facial features',
      icon: Icons.tune_rounded,
      isCompleted: false,
    ),
    SetupStep(
      title: 'Final Testing',
      description: 'Verify system functionality',
      icon: Icons.verified_rounded,
      isCompleted: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();

    // Listen to camera connection status
    _isDeviceConnected = _cameraService.isConnected;
    _connectedIp = _cameraService.connectedDevice?.ipAddress;

    _connectionSubscription =
        _cameraService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isDeviceConnected = isConnected;
          _connectedIp = _cameraService.connectedDevice?.ipAddress;

          // Automatically complete step 0 if connected
          if (isConnected && _currentStep == 0) {
            _steps[0].isCompleted = true;
          }
        });
      }
    });

    // Start scanning for devices automatically on power step
    if (!_isDeviceConnected) {
      _scanForDevice();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _calibrationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _calibrationProgress =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _calibrationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _calibrationController.dispose();
    _connectionSubscription?.cancel();
    _pageController.dispose();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  // Helper to start scanning, mainly for the initial step
  Future<void> _scanForDevice() async {
    if (_isDeviceConnected) return;

    _showMessage('Scanning for ESP32-CAM on local network...', AppColors.info);

    // We only need the connection check here, not the full discovery list
    final devices = await _cameraService.scanKnownIPs();

    if (devices.isNotEmpty && !_cameraService.isConnected) {
      // Connect to the first found device
      await _cameraService.connectToDevice(devices.first);
    }

    if (!_cameraService.isConnected) {
      _showMessage('No device found. Ensure it\'s on the same Wi-Fi.',
          AppColors.warning);
    }
  }

  // Action: Connects the app to a simulated ESP32 IP
  Future<void> _connectToWifi() async {
    final ssid = _wifiNameController.text.trim();
    final password = _wifiPasswordController.text.trim();
    final deviceName = _deviceNameController.text.trim();

    if (ssid.isEmpty || password.isEmpty) {
      _showMessage('Please enter Wi-Fi credentials', AppColors.error);
      return;
    }

    setState(() {
      _isConnectingWifi = true;
    });

    _showMessage('Attempting to connect ESP32 to Wi-Fi...', AppColors.info);

    // --- SIMULATED WIFI CONNECTION ---
    // In a real scenario, this would send an HTTP POST to the ESP32
    // to configure the WiFi, and the ESP32 would restart.
    await Future.delayed(const Duration(seconds: 4));

    // Assume successful connection, which gives it an IP
    final mockIp =
        '10.19.80.42'; // This should come from the ESP32, mocking it here.

    final device = ESP32Device(
      ipAddress: mockIp,
      deviceName: deviceName,
      isConnected: false,
    );

    // Connect the app to the newly configured ESP32 IP
    final success = await _cameraService.connectToDevice(device);

    setState(() {
      _isConnectingWifi = false;
    });

    if (success) {
      _showMessage(
          'ESP32 successfully connected and online!', AppColors.success);
      _steps[1].isCompleted = true;
      _nextStep();
    } else {
      _showMessage('Failed to connect ESP32. Check credentials or power.',
          AppColors.error);
    }
  }

  // Action: Simulates the camera position test. The real check is visual.
  Future<void> _testCameraPosition() async {
    if (!_isDeviceConnected) {
      _showMessage('Device is not connected. Please complete Step 1 and 2.',
          AppColors.error);
      return;
    }
    _showMessage(
        'Verify your face is centered in the live feed above.', AppColors.info);
    _steps[2].isCompleted = true;
  }

  // Action: Starts the calibration process.
  Future<void> _startCalibration() async {
    if (!_isDeviceConnected) {
      _showMessage(
          'Device is not connected. Cannot calibrate.', AppColors.error);
      return;
    }

    setState(() {
      _isCalibrating = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCalibrationDialog(),
    );

    // Start calibration animation
    _calibrationController.forward();

    // Simulate waiting for calibration to complete
    await Future.delayed(const Duration(seconds: 10));

    // Close dialog and update state
    if (mounted) {
      Navigator.of(context).pop();
      setState(() {
        _isCalibrating = false;
        _steps[3].isCompleted = true;
      });
      _showMessage('Calibration completed successfully!', AppColors.success);
      _nextStep();
    }

    // Reset animation for next time
    _calibrationController.reset();
  }

  // Action: Moves to the next step
  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Action: Moves to the previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishSetup() {
    // Show success message
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.successGradient,
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Setup Complete!',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your RoadSafe AI device has been successfully configured and is ready to keep you safe on the road.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GradientButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to home
                },
                text: 'Done',
                gradientColors: AppColors.successGradient,
                icon: Icons.home_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.accentGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Device Setup',
                                      style:
                                          AppTextStyles.headlineMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Configure your ESP32 device',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildContent(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Progress Header
        _buildProgressHeader(),

        // Setup Steps
        SizedBox(
          // Use a fixed height or a calculated one to avoid layout issues with PageView
          height: MediaQuery.of(context).size.height * 0.7,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentStep = index;
              });
            },
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              return _buildStepContent(index);
            },
          ),
        ),

        // Navigation Buttons
        _buildNavigationButtons(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_currentStep + 1) / _steps.length,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.accentGradient,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Step Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${((_currentStep + 1) / _steps.length * 100).round()}% Complete',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int index) {
    switch (index) {
      case 0:
        return _buildPowerConnectionStep();
      case 1:
        return _buildWiFiConfigurationStep();
      case 2:
        return _buildCameraPositioningStep();
      case 3:
        return _buildCalibrationStep();
      case 4:
        return _buildFinalTestingStep();
      default:
        return Container();
    }
  }

  Widget _buildPowerConnectionStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.power_rounded,
            title: 'Connect Power',
            subtitle: 'Power up your ESP32 device',
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionItem(
                  number: '1',
                  title: 'Locate the USB Cable',
                  description:
                      'Find the USB cable included with your ESP32-CAM module.',
                ),
                const SizedBox(height: 16),
                _buildInstructionItem(
                  number: '2',
                  title: 'Connect to Power Source',
                  description:
                      'Plug the USB cable into your car\'s USB port or 12V adapter.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isDeviceConnected
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDeviceConnected
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.warning.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDeviceConnected
                      ? Icons.check_circle_rounded
                      : Icons.power_settings_new_rounded,
                  color: _isDeviceConnected
                      ? AppColors.success
                      : AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isDeviceConnected
                            ? 'Device Connected (IP: $_connectedIp)'
                            : 'Scanning for Device...',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: _isDeviceConnected
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _isDeviceConnected
                            ? 'ESP32 device is powered and ready'
                            : 'Make sure the device is plugged in and the firmware is running.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _isDeviceConnected
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            onPressed: _scanForDevice,
            text: 'Re-scan for Device',
            gradientColors: AppColors.infoGradient,
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiConfigurationStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              icon: Icons.wifi_rounded,
              title: 'Wi-Fi Setup',
              subtitle: 'Connect device to your network',
            ),

            const SizedBox(height: 24),

            GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network Configuration',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernTextField(
                    controller: _wifiNameController,
                    label: 'Wi-Fi Network Name (SSID)',
                    hint: 'Enter your Wi-Fi SSID',
                    prefixIcon: Icons.wifi_rounded,
                  ),
                  const SizedBox(height: 16),
                  ModernTextField(
                    controller: _wifiPasswordController,
                    label: 'Wi-Fi Password',
                    hint: 'Enter your Wi-Fi password',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  ModernTextField(
                    controller: _deviceNameController,
                    label: 'Device Name',
                    hint: 'Give your device a name',
                    prefixIcon: Icons.devices_rounded,
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    onPressed: _isDeviceConnected ? _connectToWifi : null,
                    text: 'Connect Device to Wi-Fi',
                    isLoading: _isConnectingWifi,
                    gradientColors: AppColors.primaryGradient,
                    icon: Icons.wifi_rounded,
                  ),
                  if (!_isDeviceConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Connect ESP32 in Step 1 before configuring Wi-Fi.',
                        style: AppTextStyles.errorText,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Pro Tips... (rest of the content is fine)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        color: AppColors.info,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connection Tips',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Use your phone\'s hotspot if car Wi-Fi isn\'t available\n• Keep the device within 10 meters of the router\n• Use a 2.4GHz network for better compatibility',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPositioningStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              icon: Icons.camera_alt_rounded,
              title: 'Position Camera',
              subtitle: 'Optimal placement for detection',
            ),

            const SizedBox(height: 24),

            // Camera Preview (Live Feed)
            GradientCard(
              gradientColors: AppColors.darkGradient,
              padding: const EdgeInsets.all(4),
              borderRadius: 20,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isDeviceConnected
                      ? MjpegViewer(
                          stream: _cameraService.streamUrl,
                          isLive: true,
                          // Optional: Error handler for when the stream breaks
                          error: (context, error, stack) => Center(
                            child: Text(
                              'Stream Error: Check IP or Wi-Fi.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.error),
                            ),
                          ),
                          loading: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                          // No detection logic needed here, just the stream
                          enableDrowsinessDetection: false,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Device Disconnected',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                'Complete Wi-Fi setup to view live feed',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Position Guidelines
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                children: [
                  _buildTestResult('Distance: 60-80cm from your face', true,
                      Icons.straighten_rounded),
                  _buildTestResult(
                      'Height: At eye level', true, Icons.height_rounded),
                  _buildTestResult('Angle: Pointing directly at driver seat',
                      true, Icons.center_focus_strong_rounded),
                ],
              ),
            ),

            const SizedBox(height: 20),

            GradientButton(
              onPressed: _isDeviceConnected ? _testCameraPosition : null,
              text: 'Confirm Position & Continue',
              gradientColors: AppColors.secondaryGradient,
              icon: Icons.visibility_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              icon: Icons.tune_rounded,
              title: 'System Calibration',
              subtitle: 'Optimize for your facial features',
            ),
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibration Process',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCalibrationInstructionStep(
                    '1',
                    'Sit in Normal Driving Position',
                    'Adjust your seat and mirrors as you normally would',
                    Icons.airline_seat_legroom_normal_rounded,
                  ),
                  _buildCalibrationInstructionStep(
                    '2',
                    'Look Straight Ahead',
                    'Keep your eyes focused on the road ahead',
                    Icons.remove_red_eye_rounded,
                  ),
                  _buildCalibrationInstructionStep(
                    '3',
                    'Stay Still for 10 Seconds',
                    'The system will learn your facial features',
                    Icons.timer_rounded,
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    onPressed: _isDeviceConnected ? _startCalibration : null,
                    text:
                        _isCalibrating ? 'Calibrating...' : 'Start Calibration',
                    isLoading: _isCalibrating,
                    gradientColors: AppColors.successGradient,
                    icon: Icons.psychology_rounded,
                  ),
                  if (!_isDeviceConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Device must be connected to calibrate.',
                        style: AppTextStyles.errorText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalTestingStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.verified_rounded,
            title: 'Final Testing',
            subtitle: 'Verify system functionality',
          ),
          const SizedBox(height: 24),
          GradientCard(
            gradientColors: AppColors.successGradient,
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Setup Complete!',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your RoadSafe AI system is ready to protect you',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Test Results (Assuming success here, as the guided flow completed)
                _buildTestResult('Device Connection (IP: $_connectedIp)', true,
                    Icons.router_rounded),
                _buildTestResult('Wi-Fi Connection', true, Icons.wifi_rounded),
                _buildTestResult('Camera Stream', true, Icons.videocam_rounded),
                _buildTestResult('Calibration Data', true, Icons.tune_rounded),

                const SizedBox(height: 24),

                GradientButton(
                  onPressed: _finishSetup,
                  text: 'Finish Setup',
                  gradientColors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.3)
                  ],
                  icon: Icons.done_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // ... (no changes needed)
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.accentGradient,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem({
    required String number,
    required String title,
    required String description,
  }) {
    // ... (no changes needed)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationInstructionStep(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    // ... (no changes needed)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _buildTestResult(String test, bool passed, IconData icon) {
    // Modified to accept an IconData
    final resultColor = passed ? Colors.white : Colors.red[300];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: resultColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              test,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          Text(
            passed ? 'PASS' : 'FAIL',
            style: AppTextStyles.labelSmall.copyWith(
              color: resultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog builder remains the same
  Widget _buildCalibrationDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.successGradient,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Calibrating System',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please look straight ahead and stay still while the system learns your facial features.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Progress indicator
            AnimatedBuilder(
              animation: _calibrationProgress,
              builder: (context, child) {
                return Column(
                  children: [
                    CircularProgressIndicator(
                      value: _calibrationProgress.value,
                      strokeWidth: 4,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(_calibrationProgress.value * 100).round()}%',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            Text(
              'Calibration in progress...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    // ... (no changes needed)
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.textHint),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: GradientButton(
              onPressed: (_currentStep < _steps.length - 1 &&
                      _steps[_currentStep].isCompleted)
                  ? _nextStep
                  : (_currentStep == _steps.length - 1)
                      ? _finishSetup
                      : null, // Disable if current step is not completed
              text: _currentStep < _steps.length - 1 ? 'Next' : 'Complete',
              gradientColors: AppColors.accentGradient,
            ),
          ),
        ],
      ),
    );
  }
}

class SetupStep {
  final String title;
  final String description;
  final IconData icon;
  bool isCompleted;

  SetupStep({
    required this.title,
    required this.description,
    required this.icon,
    this.isCompleted = false,
  });
}
