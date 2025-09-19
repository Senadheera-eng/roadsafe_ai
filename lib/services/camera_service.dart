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

  // Get local network info
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

  // Scan for ESP32-CAM devices on the network
  Future<List<ESP32Device>> scanForDevices() async {
    print('Starting ESP32-CAM scan...');

    List<ESP32Device> devices = [];
    List<Future<ESP32Device?>> scanTasks = [];

    // Get current network base
    final networkBase = await _getLocalNetworkBase();

    List<String> networkRanges = [];

    if (networkBase != null) {
      networkRanges.add(networkBase);
      print('Scanning primary network: $networkBase.x');
    }

    // Add common network ranges if current network is different
    List<String> commonRanges = [
      '192.168.1',
      '192.168.0',
      '10.0.0',
      '172.16.0'
    ];
    for (String range in commonRanges) {
      if (!networkRanges.contains(range)) {
        networkRanges.add(range);
      }
    }

    // If ESP32 reported a specific range, add it
    if (networkBase != null && !networkRanges.contains('10.19.80')) {
      networkRanges.add('10.19.80');
    }

    print('Scanning networks: ${networkRanges.join(', ')}');

    // Scan each network range
    for (String range in networkRanges) {
      for (int i = 1; i <= 254; i++) {
        final ipAddress = '$range.$i';
        scanTasks.add(_checkESP32Device(ipAddress));
      }
    }

    // Wait for all scans to complete with timeout
    try {
      final results = await Future.wait(scanTasks).timeout(
        Duration(seconds: 10), // Increased timeout for multiple ranges
      );

      devices = results
          .where((device) => device != null)
          .cast<ESP32Device>()
          .toList();
      print('Found ${devices.length} ESP32-CAM devices');
    } catch (e) {
      print('Scan timeout or error: $e');
    }

    _devicesController.add(devices);
    return devices;
  }

  // Check if an IP address is an ESP32-CAM device
  // In your _checkESP32Device method, replace the existing one with this:
  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      // Try multiple endpoints that ESP32-CAM might use
      List<String> endpoints = ['/', '/status', '/stream'];

      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse('http://$ipAddress$endpoint'),
            headers: {'Connection': 'close'},
          ).timeout(Duration(seconds: 2)); // Reduced timeout

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();
            final server = response.headers['server']?.toLowerCase() ?? '';

            // More comprehensive ESP32 detection
            bool isESP32 = body.contains('esp32') ||
                body.contains('camera') ||
                body.contains('cam') ||
                server.contains('esp32') ||
                response.headers.containsKey('x-esp32') ||
                body.contains('stream');

            if (isESP32) {
              print('✅ Found ESP32-CAM at $ipAddress');

              // Test if stream endpoint works
              try {
                final streamTest = await http
                    .head(
                      Uri.parse('http://$ipAddress/stream'),
                    )
                    .timeout(Duration(seconds: 2));

                if (streamTest.statusCode == 200) {
                  print('✅ Stream endpoint confirmed at $ipAddress');
                }
              } catch (e) {
                print('⚠️ Stream endpoint not available at $ipAddress');
              }

              return ESP32Device(
                ipAddress: ipAddress,
                deviceName: 'ESP32-CAM ($ipAddress)',
                isConnected: false,
              );
            }
          }
        } catch (e) {
          // Try next endpoint
          continue;
        }
      }
    } catch (e) {
      // Ignore - expected for non-ESP32 devices
    }

    return null;
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

  void dispose() {
    _devicesController.close();
    _connectionController.close();
  }
}
