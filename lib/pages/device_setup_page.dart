import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/camera_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'camera_positioning_page.dart';

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  final CameraService _cameraService = CameraService();

  bool _isScanning = false;
  List<ESP32Device> _foundDevices = [];
  String _statusMessage = 'Ready to scan';
  bool _showManualEntry = false;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToStatus();

    // Auto-start scanning after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _startScanning();
    });
  }

  void _listenToStatus() {
    _cameraService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });

    _cameraService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _foundDevices = devices;
        });
      }
    });
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _foundDevices = [];
      _statusMessage = 'Scanning for ESP32-CAM...';
    });

    try {
      final devices = await _cameraService.scanForDevices();

      if (devices.isEmpty) {
        _showNoDevicesDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showNoDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: AppColors.error),
            SizedBox(width: 8),
            Text('No Devices Found'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not find ESP32-CAM on your network.',
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text('Troubleshooting Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTroubleshootingStep('1', 'Ensure ESP32-CAM is powered on'),
              _buildTroubleshootingStep(
                  '2', 'Check that ESP32-CAM is connected to WiFi'),
              _buildTroubleshootingStep(
                  '3', 'Make sure your phone is on the same WiFi network'),
              _buildTroubleshootingStep('4', 'Try restarting the ESP32-CAM'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Text('Manual Connection',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you know the IP address of your ESP32-CAM, you can connect manually.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showManualEntry = true;
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Manual IP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startScanning();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(ESP32Device device) async {
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
                Text('Connecting to ESP32-CAM...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await _cameraService.connectToDevice(device);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        _showSuccessDialog(device);
      } else {
        _showConnectionFailedDialog(device);
      }
    }
  }

  void _showSuccessDialog(ESP32Device device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            SizedBox(width: 8),
            Text('Connected!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Successfully connected to ESP32-CAM',
              style:
                  AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    device.ipAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
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
              Navigator.pop(context); // Go back to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showConnectionFailedDialog(ESP32Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Connection Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not connect to ESP32-CAM at ${device.ipAddress}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text('Possible causes:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTroubleshootingStep('•', 'Device went offline'),
            _buildTroubleshootingStep('•', 'Network connection lost'),
            _buildTroubleshootingStep('•', 'Firewall blocking connection'),
            _buildTroubleshootingStep('•', 'ESP32-CAM needs restart'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice(device);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectManualIP() async {
    final ipAddress = _ipController.text.trim();

    if (ipAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an IP address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Basic IP validation
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ipAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid IP address format'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Connecting to $ipAddress...';
    });

    final success = await _cameraService.connectToIP(ipAddress);

    setState(() {
      _isScanning = false;
    });

    if (success) {
      setState(() {
        _showManualEntry = false;
      });

      final device = ESP32Device(
        ipAddress: ipAddress,
        deviceName: 'RoadSafe AI - ESP32-CAM',
        isConnected: true,
      );
      _showSuccessDialog(device);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No ESP32-CAM found at $ipAddress'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _connectManualIP,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScanning,
              tooltip: 'Rescan',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Status Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          _isScanning
                              ? Icons.wifi_find
                              : _foundDevices.isNotEmpty
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                          size: 64,
                          color: _isScanning
                              ? AppColors.primary
                              : _foundDevices.isNotEmpty
                                  ? AppColors.success
                                  : AppColors.error.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning ? 'Scanning...' : _statusMessage,
                          style: AppTextStyles.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        if (_isScanning) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Manual IP Entry
                if (_showManualEntry) ...[
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit, color: AppColors.info),
                              const SizedBox(width: 8),
                              Text(
                                'Manual IP Connection',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _ipController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'IP Address',
                              hintText: '192.168.1.59',
                              prefixIcon: const Icon(Icons.router),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'Format: XXX.XXX.XXX.XXX',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showManualEntry = false;
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isScanning ? null : _connectManualIP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Connect'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Found Devices List
                if (_foundDevices.isNotEmpty) ...[
                  Text(
                    'Found Devices',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Expanded(
                  child: _foundDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.devices_other,
                                size: 80,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isScanning
                                    ? 'Searching for ESP32-CAM...'
                                    : 'No devices found yet',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              if (!_isScanning && !_showManualEntry) ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _startScanning,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Start Scanning'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showManualEntry = true;
                                    });
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Manual IP Entry'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _foundDevices.length,
                          itemBuilder: (context, index) {
                            final device = _foundDevices[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: AppColors.success,
                                  ),
                                ),
                                title: Text(
                                  device.deviceName,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  device.ipAddress,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.primary,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _connectToDevice(device),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Connect'),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Help Button
                if (!_showManualEntry)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showManualEntry = true;
                      });
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Having trouble? Try manual connection'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
