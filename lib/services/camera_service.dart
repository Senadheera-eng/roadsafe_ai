import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';

class ESP32Device {
  final String ipAddress;
  final String deviceName;
  final bool isConnected;

  ESP32Device({
    required this.ipAddress,
    required this.deviceName,
    required this.isConnected,
  });
}

class CameraService {
  Timer? _periodicScanTimer;
  bool _isPeriodicScanEnabled = false;
  static const int _scanTimeout = 3; // seconds
  static const String _esp32Identifier = 'ESP32-CAM';

  // Singleton pattern
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  ESP32Device? _connectedDevice;
  StreamController<List<ESP32Device>> _devicesController =
      StreamController.broadcast();
  StreamController<bool> _connectionController = StreamController.broadcast();

  Stream<List<ESP32Device>> get devicesStream => _devicesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  ESP32Device? get connectedDevice => _connectedDevice;

  bool get isConnected => _connectedDevice?.isConnected ?? false;

  // Get the camera stream URL
  String get streamUrl {
    if (_connectedDevice == null) return '';
    return 'http://${_connectedDevice!.ipAddress}/stream';
  }

  // Replace the _getLocalNetworkBase method with this improved version:
  Future<String?> _getLocalNetworkBase() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          return '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }
    } catch (e) {
      print('Error getting network info: $e');
    }
    return null;
  }

  // Update scanForDevices method to handle multiple network ranges:
  Future<List<ESP32Device>> scanForDevices() async {
    print('Starting ESP32-CAM scan...');

    List<ESP32Device> devices = [];
    List<Future<ESP32Device?>> scanTasks = [];

    // Define multiple network ranges to scan
    List<String> networkRanges = [
      '10.19.80', // Your specific network
      '192.168.1', // Common ranges
      '192.168.0',
      '192.168.4', // ESP32 AP mode
      '10.0.0',
    ];

    // Try to get current network first
    final currentNetwork = await _getLocalNetworkBase();
    if (currentNetwork != null && !networkRanges.contains(currentNetwork)) {
      networkRanges.insert(0, currentNetwork);
    }

    print('Scanning networks: ${networkRanges.join(', ')}');

    // Scan each network range with reduced timeout for faster scanning
    for (String range in networkRanges) {
      // Focus on common ESP32 IP ranges first
      List<int> priorityIPs = [42, 100, 101, 102, 103, 104, 105, 200, 201, 202];

      // Add priority IPs first
      for (int ip in priorityIPs) {
        if (ip <= 254) {
          scanTasks.add(_checkESP32Device('$range.$ip'));
        }
      }

      // Then scan remaining range
      for (int i = 1; i <= 254; i++) {
        if (!priorityIPs.contains(i)) {
          scanTasks.add(_checkESP32Device('$range.$i'));
        }
      }
    }

    try {
      final results = await Future.wait(scanTasks).timeout(
        Duration(seconds: 15),
      );

      devices = results
          .where((device) => device != null)
          .cast<ESP32Device>()
          .toList();
      print('Found ${devices.length} ESP32-CAM devices');

      // If devices found, start periodic verification
      if (devices.isNotEmpty) {
        _startPeriodicScan(devices);
      }
    } catch (e) {
      print('Scan timeout or error: $e');
    }

    _devicesController.add(devices);
    return devices;
  }

// Add periodic scanning to maintain device list
  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_isPeriodicScanEnabled) {
        timer.cancel();
        return;
      }

      List<ESP32Device> activeDevices = [];

      // Quick check of known devices
      for (ESP32Device device in knownDevices) {
        final activeDevice = await _checkESP32Device(device.ipAddress);
        if (activeDevice != null) {
          activeDevices.add(activeDevice);
        }
      }

      // If no known devices respond, do a quick scan of likely IPs
      if (activeDevices.isEmpty) {
        List<String> quickScanIPs = [
          '10.19.80.42',
          '192.168.1.100',
          '192.168.1.101',
          '192.168.4.1',
        ];

        for (String ip in quickScanIPs) {
          final device = await _checkESP32Device(ip);
          if (device != null) {
            activeDevices.add(device);
          }
        }
      }

      _devicesController.add(activeDevices);
    });
  }

  void _stopPeriodicScan() {
    _isPeriodicScanEnabled = false;
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
  }

  // Check if an IP address is an ESP32-CAM device
  // In your _checkESP32Device method, replace the existing one with this:
  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      print('Checking IP: $ipAddress');

      final response = await http.get(
        Uri.parse('http://$ipAddress/'),
        headers: {
          'Connection': 'close',
          'User-Agent': 'RoadSafeAI/1.0',
        },
      ).timeout(Duration(seconds: 5));

      print('IP $ipAddress responded with status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        print(
            'Response body preview for $ipAddress: ${body.substring(0, body.length > 100 ? 100 : body.length)}');

        // More lenient detection - any working HTTP server could be ESP32
        bool couldBeESP32 = body.contains('esp32') ||
            body.contains('camera') ||
            body.contains('cam') ||
            body.contains('stream') ||
            body.contains('video') ||
            body.contains('html') || // Basic web server
            response.headers['server']?.toLowerCase().contains('esp') == true;

        if (couldBeESP32) {
          print('✅ Potential ESP32-CAM found at $ipAddress');
          return ESP32Device(
            ipAddress: ipAddress,
            deviceName: 'ESP32-CAM ($ipAddress)',
            isConnected: false,
          );
        } else {
          print('❌ $ipAddress responded but doesn\'t appear to be ESP32-CAM');
        }
      }
    } catch (e) {
      // Only log if it's not a common network error
      if (!e.toString().contains('Connection refused') &&
          !e.toString().contains('No route to host')) {
        print('Error checking $ipAddress: $e');
      }
    }

    return null;
  }

  Future<List<ESP32Device>> scanKnownIPs() async {
    print('Scanning known ESP32-CAM locations...');

    List<String> knownIPs = [
      '10.19.80.42', // Your specific IP
      '192.168.1.100',
      '192.168.1.101',
      '192.168.4.1', // ESP32 AP mode default
      '192.168.0.100',
    ];

    List<ESP32Device> devices = [];

    for (String ip in knownIPs) {
      final device = await _checkESP32Device(ip);
      if (device != null) {
        devices.add(device);
        print('Found ESP32-CAM at: $ip');
      }
    }

    print('Targeted scan complete. Found ${devices.length} devices.');
    _devicesController.add(devices);
    return devices;
  }

// Update dispose method
  void dispose() {
    _stopPeriodicScan();
    _devicesController.close();
    _connectionController.close();
  }

  // Connect to a specific ESP32 device
  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('Connecting to ${device.ipAddress}...');

      // Test the stream endpoint
      final streamResponse = await http
          .head(
            Uri.parse('http://${device.ipAddress}/stream'),
          )
          .timeout(Duration(seconds: 5));

      if (streamResponse.statusCode == 200) {
        _connectedDevice = ESP32Device(
          ipAddress: device.ipAddress,
          deviceName: device.deviceName,
          isConnected: true,
        );

        _connectionController.add(true);
        print('Successfully connected to ${device.ipAddress}');
        return true;
      }
    } catch (e) {
      print('Failed to connect to ${device.ipAddress}: $e');
    }

    _connectionController.add(false);
    return false;
  }

  // Disconnect from current device
  void disconnect() {
    _connectedDevice = null;
    _connectionController.add(false);
    print('Disconnected from ESP32-CAM');
  }

  // Test if current connection is still active
  Future<bool> testConnection() async {
    if (_connectedDevice == null) return false;

    try {
      final response = await http
          .head(
            Uri.parse('http://${_connectedDevice!.ipAddress}/stream'),
          )
          .timeout(Duration(seconds: 3));

      final isConnected = response.statusCode == 200;
      if (!isConnected) {
        disconnect();
      }

      return isConnected;
    } catch (e) {
      disconnect();
      return false;
    }
  }
}
