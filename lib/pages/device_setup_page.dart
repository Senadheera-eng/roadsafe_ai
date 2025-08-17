import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/modern_text_field.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _calibrationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _calibrationProgress;

  PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isConnecting = false;
  bool _isDeviceConnected = false;
  bool _isCalibrating = false;
  bool _isTestingCamera = false;

  // Controllers for user input
  final _wifiNameController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _deviceNameController = TextEditingController();

  // Setup steps data
  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Power Connection',
      description: 'Connect your ESP32 device to power',
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
      description: 'Position camera for optimal detection',
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
      description: 'Test the complete system',
      icon: Icons.verified_rounded,
      isCompleted: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'RoadSafe Device';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _calibrationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _calibrationProgress = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _calibrationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Simulate device detection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isDeviceConnected = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _calibrationController.dispose();
    _pageController.dispose();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

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
                const SizedBox(height: 16),
                _buildInstructionItem(
                  number: '3',
                  title: 'Power On Device',
                  description:
                      'The ESP32 LED should light up indicating it\'s powered on.',
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
                            ? 'Device Connected'
                            : 'Searching for Device...',
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
                            : 'Make sure the device is plugged in',
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
                    label: 'Wi-Fi Network Name',
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
                    onPressed: _connectToWiFi,
                    text: 'Connect to Wi-Fi',
                    isLoading: _isConnecting,
                    gradientColors: AppColors.primaryGradient,
                    icon: Icons.wifi_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pro Tips
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

            // Add some bottom padding for better scrolling experience
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
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              icon: Icons.camera_alt_rounded,
              title: 'Position Camera',
              subtitle: 'Optimal placement for detection',
            ),

            const SizedBox(height: 24),

            // Camera Preview Placeholder
            GradientCard(
              gradientColors: AppColors.darkGradient,
              padding: const EdgeInsets.all(24),
              borderRadius: 20,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Camera Preview',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          'Live feed will appear here',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Position Guidelines
                  Row(
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Distance: 60-80cm from your face',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.height_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Height: At eye level',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.center_focus_strong_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Angle: Pointing directly at driver seat',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            GradientButton(
              onPressed: _testCameraPosition,
              text: _isTestingCamera ? 'Testing...' : 'Test Camera Position',
              isLoading: _isTestingCamera,
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
        physics: BouncingScrollPhysics(),
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
                    onPressed: _startCalibration,
                    text:
                        _isCalibrating ? 'Calibrating...' : 'Start Calibration',
                    isLoading: _isCalibrating,
                    gradientColors: AppColors.successGradient,
                    icon: Icons.psychology_rounded,
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

                // Test Results
                _buildTestResult('Camera Detection', true),
                _buildTestResult('Wi-Fi Connection', true),
                _buildTestResult('Alert System', true),
                _buildTestResult('Face Recognition', true),

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

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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

  Widget _buildTestResult(String test, bool passed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.error_rounded,
            color: passed ? Colors.white : Colors.red[300],
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
              color: passed ? Colors.white : Colors.red[300],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
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
                child: Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: GradientButton(
              onPressed:
                  _currentStep < _steps.length - 1 ? _nextStep : _finishSetup,
              text: _currentStep < _steps.length - 1 ? 'Next' : 'Complete',
              gradientColors: AppColors.accentGradient,
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _steps[_currentStep].isCompleted = true;
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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

  Future<void> _connectToWiFi() async {
    if (_wifiNameController.text.isEmpty ||
        _wifiPasswordController.text.isEmpty) {
      _showMessage('Please enter Wi-Fi credentials', AppColors.error);
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    // Simulate connection process
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isConnecting = false;
    });

    _showMessage('Successfully connected to Wi-Fi!', AppColors.success);
  }

  Future<void> _testCameraPosition() async {
    setState(() {
      _isTestingCamera = true;
    });

    // Simulate camera testing
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isTestingCamera = false;
    });

    _showMessage('Camera position test completed!', AppColors.success);
  }

  Future<void> _startCalibration() async {
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

    // Wait for calibration to complete
    await Future.delayed(const Duration(seconds: 10));

    // Close dialog and update state
    if (mounted) {
      Navigator.of(context).pop();
      setState(() {
        _isCalibrating = false;
      });
      _showMessage('Calibration completed successfully!', AppColors.success);
    }

    // Reset animation for next time
    _calibrationController.reset();
  }

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
