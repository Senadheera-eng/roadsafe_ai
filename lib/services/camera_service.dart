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
  Timer? _healthCheckTimer;
  bool _isPeriodicScanEnabled = false;
  int _consecutiveFailures = 0;
  static const int _scanTimeout = 3;
  static const String _esp32Identifier = 'ESP32-CAM';

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

  String get streamUrl {
    if (_connectedDevice == null) return '';
    return 'http://${_connectedDevice!.ipAddress}/stream';
  }

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

  Future<List<ESP32Device>> scanForDevices() async {
    print('Starting ESP32-CAM scan...');

    List<ESP32Device> devices = [];
    List<Future<ESP32Device?>> scanTasks = [];

    List<String> networkRanges = [
      '10.19.80',
      '192.168.1',
      '192.168.0',
      '192.168.4',
      '10.0.0',
    ];

    final currentNetwork = await _getLocalNetworkBase();
    if (currentNetwork != null && !networkRanges.contains(currentNetwork)) {
      networkRanges.insert(0, currentNetwork);
    }

    print('Scanning networks: ${networkRanges.join(', ')}');

    for (String range in networkRanges) {
      List<int> priorityIPs = [42, 100, 101, 102, 103, 104, 105, 200, 201, 202];

      for (int ip in priorityIPs) {
        if (ip <= 254) {
          scanTasks.add(_checkESP32Device('$range.$ip'));
        }
      }

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

      if (devices.isNotEmpty) {
        _startPeriodicScan(devices);
      }
    } catch (e) {
      print('Scan timeout or error: $e');
    }

    _devicesController.add(devices);
    return devices;
  }

  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_isPeriodicScanEnabled) {
        timer.cancel();
        return;
      }

      List<ESP32Device> activeDevices = [];

      for (ESP32Device device in knownDevices) {
        final activeDevice = await _checkESP32Device(device.ipAddress);
        if (activeDevice != null) {
          activeDevices.add(activeDevice);
        }
      }

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

  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ipAddress/'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        final server = response.headers['server']?.toLowerCase() ?? '';

        bool isESP32CAM = false;

        if (body.contains('esp32') &&
            (body.contains('camera') || body.contains('cam'))) {
          isESP32CAM = true;
        } else if (server.contains('esp32')) {
          isESP32CAM = true;
        } else if (body.contains('cameradivid') || body.contains('stream')) {
          try {
            final streamTest = await http
                .head(Uri.parse('http://$ipAddress/stream'))
                .timeout(Duration(seconds: 2));

            if (streamTest.statusCode == 200) {
              isESP32CAM = true;
            }
          } catch (e) {
            // Stream test failed
          }
        }

        if (isESP32CAM) {
          print('Confirmed ESP32-CAM at $ipAddress');
          return ESP32Device(
            ipAddress: ipAddress,
            deviceName: 'ESP32-CAM ($ipAddress)',
            isConnected: false,
          );
        }
      }
    } catch (e) {
      // Ignore connection errors
    }

    return null;
  }

  Future<List<ESP32Device>> scanKnownESP32() async {
    print('Scanning known ESP32-CAM IP: 10.19.80.42');

    List<ESP32Device> devices = [];

    final device = await _checkESP32Device('10.19.80.42');
    if (device != null) {
      devices.add(device);
    }

    if (devices.isEmpty) {
      List<String> similarIPs = [
        '10.19.80.41',
        '10.19.80.43',
        '10.19.80.44',
        '10.19.80.40',
      ];

      for (String ip in similarIPs) {
        final testDevice = await _checkESP32Device(ip);
        if (testDevice != null) {
          devices.add(testDevice);
          break;
        }
      }
    }

    _devicesController.add(devices);
    return devices;
  }

  Future<List<ESP32Device>> scanKnownIPs() async {
    print('Scanning known ESP32-CAM locations...');

    List<String> knownIPs = [
      '10.19.80.42',
      '192.168.1.100',
      '192.168.1.101',
      '192.168.4.1',
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

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _consecutiveFailures = 0;

    _healthCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!isConnected || _connectedDevice == null) {
        timer.cancel();
        return;
      }

      try {
        final response = await http
            .head(Uri.parse('http://${_connectedDevice!.ipAddress}/'))
            .timeout(Duration(seconds: 3));

        if (response.statusCode == 200) {
          _consecutiveFailures = 0;
          print('Health check: OK');
        } else {
          _consecutiveFailures++;
          print('Health check: Failed (status ${response.statusCode})');
        }
      } catch (e) {
        _consecutiveFailures++;
        print('Health check: Failed ($e)');
      }

      if (_consecutiveFailures >= 3) {
        print('ESP32 appears offline - auto-disconnecting');
        disconnect();
        timer.cancel();
      }
    });
  }

  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('Connecting to ESP32-CAM at ${device.ipAddress}...');

      final basicTest = await http
          .get(Uri.parse('http://${device.ipAddress}/'))
          .timeout(Duration(seconds: 5));

      if (basicTest.statusCode == 200) {
        print('Basic connectivity OK');

        _connectedDevice = ESP32Device(
          ipAddress: device.ipAddress,
          deviceName: device.deviceName,
          isConnected: true,
        );

        _connectionController.add(true);
        _startHealthCheck();
        print('Successfully connected to ESP32-CAM!');
        return true;
      }
    } catch (e) {
      print('Connection failed: $e');
    }

    _connectionController.add(false);
    return false;
  }

  void disconnect() {
    _healthCheckTimer?.cancel();
    _connectedDevice = null;
    _connectionController.add(false);
    print('Disconnected from ESP32-CAM');
  }

  Future<bool> testConnection() async {
    if (!isConnected || _connectedDevice == null) return false;

    try {
      final response = await http
          .head(Uri.parse('http://${_connectedDevice!.ipAddress}/'))
          .timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  void dispose() {
    _stopPeriodicScan();
    _healthCheckTimer?.cancel();
    _devicesController.close();
    _connectionController.close();
  }
}
