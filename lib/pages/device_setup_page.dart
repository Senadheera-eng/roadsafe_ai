import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/modern_text_field.dart';
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

              if (isConnected) {
                return _buildConnectedView();
              }

              return _buildSetupView();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),

        Text(
          'Connect Your ESP32-CAM',
          style: AppTextStyles.displayMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Choose a connection method below',
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Quick Connect Button
        GradientButton(
          onPressed: _isScanning ? null : _quickConnect,
          text: 'Quick Connect (10.251.96.17)',
          isLoading: _isConnecting && !_isScanning,
          gradientColors: AppColors.successGradient,
          icon: Icons.flash_on,
        ),

        const SizedBox(height: 16),

        // Manual IP Entry
        GradientButton(
          onPressed: _isScanning ? null : _showManualIPDialog,
          text: 'Enter IP Manually',
          gradientColors: AppColors.infoGradient,
          icon: Icons.edit,
        ),

        const SizedBox(height: 16),

        // Scan Network
        GradientButton(
          onPressed: _isScanning ? null : _scanNetwork,
          text: 'Scan Network',
          isLoading: _isScanning,
          gradientColors: AppColors.primaryGradient,
          icon: Icons.search,
        ),

        const SizedBox(height: 32),

        // Found Devices
        if (_foundDevices.isNotEmpty) ...[
          Text(
            'Found Devices',
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._foundDevices.map((device) => _buildDeviceCard(device)).toList(),
        ],

        const SizedBox(height: 32),

        // Instructions
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 24),
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
                _buildInstructionStep('1', 'Power on your ESP32-CAM'),
                _buildInstructionStep('2', 'Connect to the same WiFi network'),
                _buildInstructionStep(
                    '3', 'Note the IP address shown on serial monitor'),
                _buildInstructionStep(
                    '4', 'Use Quick Connect or enter IP manually'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.successGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connected Successfully!',
              style: AppTextStyles.headlineLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Device:',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: Colors.white70),
                        ),
                        Text(
                          _cameraService.connectedDevice?.deviceName ??
                              'Unknown',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'IP Address:',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: Colors.white70),
                        ),
                        Text(
                          _cameraService.connectedDevice?.ipAddress ??
                              'Unknown',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LiveCameraPage()),
                );
              },
              text: 'Start Monitoring',
              gradientColors: AppColors.primaryGradient,
              icon: Icons.videocam,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _cameraService.disconnect();
              },
              child: Text(
                'Disconnect',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
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
              colors: AppColors.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.videocam, color: Colors.white),
        ),
        title: Text(
          device.deviceName,
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
            : IconButton(
                icon: const Icon(Icons.link, color: Colors.white),
                onPressed: () => _connectToDevice(device),
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

  Future<void> _quickConnect() async {
    setState(() => _isConnecting = true);

    try {
      final success = await _cameraService.connectToIP('10.251.96.17');

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to ESP32-CAM'),
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

  Future<void> _scanNetwork() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      final devices = await _cameraService.scanForDevices();

      if (mounted) {
        setState(() {
          _foundDevices = devices;
        });

        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No ESP32-CAM devices found'),
              backgroundColor: AppColors.warning,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _showManualIPDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ManualIPConnectionDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

// Manual IP Connection Dialog
class ManualIPConnectionDialog extends StatefulWidget {
  const ManualIPConnectionDialog({super.key});

  @override
  State<ManualIPConnectionDialog> createState() =>
      _ManualIPConnectionDialogState();
}

class _ManualIPConnectionDialogState extends State<ManualIPConnectionDialog> {
  final TextEditingController _ipController = TextEditingController();
  final CameraService _cameraService = CameraService();
  bool _isConnecting = false;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _connectToIP() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      _showError('Please enter an IP address');
      return;
    }

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      _showError('Invalid IP address format');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final success = await _cameraService.connectToIP(ip);

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        _showError('Could not connect to ESP32-CAM at this IP');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Manual IP Connection', style: AppTextStyles.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter your ESP32-CAM IP address:',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _ipController,
            label: 'IP Address',
            hint: '10.251.96.17',
            prefixIcon: Icons.wifi,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            'Example: 192.168.1.100',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
        ),
        GradientButton(
          onPressed: _isConnecting ? null : _connectToIP,
          text: 'Connect',
          isLoading: _isConnecting,
          gradientColors: AppColors.primaryGradient,
          width: 120,
          height: 40,
        ),
      ],
    );
  }
}
