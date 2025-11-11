import 'dart:async';
import 'package:http/http.dart' as http;
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

  @override
  String toString() => 'ESP32Device($ipAddress, $deviceName)';
}

class CameraService {
  Timer? _periodicScanTimer;
  bool _isPeriodicScanEnabled = false;

  // Singleton pattern
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  ESP32Device? _connectedDevice;
  final StreamController<List<ESP32Device>> _devicesController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();

  Stream<List<ESP32Device>> get devicesStream => _devicesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  ESP32Device? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice?.isConnected ?? false;

  String get streamUrl {
    if (_connectedDevice == null) return '';
    return 'http://${_connectedDevice!.ipAddress}/stream';
  }

  // ============================================
  // IMPROVED DETECTION - NO UI CHANGES
  // ============================================

  Future<List<ESP32Device>> scanForDevices() async {
    print('\n🔍 ========== STARTING ESP32-CAM SCAN ==========');

    List<ESP32Device> foundDevices = [];

    // STEP 1: Try your known IP first
    print('📍 Step 1: Checking known IP: 10.251.96.17');
    final knownDevice = await _checkESP32Device('10.251.96.17');
    if (knownDevice != null) {
      foundDevices.add(knownDevice);
      print('✅ Found ESP32-CAM at 10.251.96.17');
      _devicesController.add(foundDevices);
      _startPeriodicScan(foundDevices);
      return foundDevices;
    }

    // STEP 2: Try other common IPs
    print('📍 Step 2: Checking other known IPs...');
    final knownIPs = await scanKnownIPs();
    if (knownIPs.isNotEmpty) {
      foundDevices.addAll(knownIPs);
      _devicesController.add(foundDevices);
      _startPeriodicScan(foundDevices);
      return foundDevices;
    }

    // STEP 3: Scan current network
    print('📍 Step 3: Scanning current network...');
    final currentNetwork = await _getLocalNetworkBase();
    if (currentNetwork != null) {
      print('🌐 Current network: $currentNetwork.x');
      final networkDevices = await _scanNetworkRange(currentNetwork);
      foundDevices.addAll(networkDevices);

      if (networkDevices.isNotEmpty) {
        _devicesController.add(foundDevices);
        _startPeriodicScan(foundDevices);
        return foundDevices;
      }
    }

    // STEP 4: Scan common ranges
    print('📍 Step 4: Scanning common ranges...');
    final commonRanges = [
      '192.168.1',
      '192.168.0',
      '192.168.4',
      '10.0.0',
      '10.251.96',
      '10.19.80'
    ];

    for (String range in commonRanges) {
      if (currentNetwork != null && range == currentNetwork) continue;

      print('🔍 Scanning $range.x...');
      final rangeDevices = await _scanNetworkRange(range);
      if (rangeDevices.isNotEmpty) {
        foundDevices.addAll(rangeDevices);
        break;
      }
    }

    _devicesController.add(foundDevices);
    if (foundDevices.isNotEmpty) {
      _startPeriodicScan(foundDevices);
    }

    print('🎉 Scan complete: ${foundDevices.length} devices found\n');
    return foundDevices;
  }

  Future<List<ESP32Device>> scanKnownIPs() async {
    List<String> knownIPs = [
      '10.251.96.17', // YOUR IP
      '10.19.80.42',
      '192.168.1.100',
      '192.168.1.101',
      '192.168.4.1',
      '192.168.0.100',
    ];

    List<ESP32Device> devices = [];

    final results = await Future.wait(
      knownIPs.map((ip) => _checkESP32Device(ip)),
      eagerError: false,
    );

    for (var device in results) {
      if (device != null) {
        devices.add(device);
        print('  ✅ ESP32-CAM found at ${device.ipAddress}');
      }
    }

    return devices;
  }

  Future<String?> _getLocalNetworkBase() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty) {
        print('📱 Device IP: $wifiIP');
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          return '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }
    } catch (e) {
      print('⚠️ Could not get network info: $e');
    }
    return null;
  }

  Future<List<ESP32Device>> _scanNetworkRange(String networkBase) async {
    List<ESP32Device> devices = [];

    // Priority IPs to check first
    List<int> priorityIPs = [17, 42, 100, 101, 102, 1, 200, 254];

    // Check priority IPs
    for (int ip in priorityIPs) {
      final device = await _checkESP32Device('$networkBase.$ip');
      if (device != null) {
        devices.add(device);
        print('  ✅ ESP32-CAM found at ${device.ipAddress}');
        return devices; // Stop after first found
      }
    }

    return devices;
  }

  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      // Try multiple endpoints
      final endpoints = ['/', '/status', '/capture'];

      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse('http://$ipAddress$endpoint'),
            headers: {'Connection': 'close'},
          ).timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();
            final server = response.headers['server']?.toLowerCase() ?? '';

            bool isESP32 = false;

            // Check 1: Server header
            if (server.contains('esp32')) {
              isESP32 = true;
            }

            // Check 2: Body content
            if (body.contains('esp32') ||
                (body.contains('camera') && body.contains('stream'))) {
              isESP32 = true;
            }

            // Check 3: Stream endpoint
            if (!isESP32 && endpoint == '/') {
              try {
                final streamCheck = await http
                    .head(
                      Uri.parse('http://$ipAddress/stream'),
                    )
                    .timeout(const Duration(seconds: 1));

                if (streamCheck.statusCode == 200) {
                  isESP32 = true;
                }
              } catch (_) {}
            }

            if (isESP32) {
              return ESP32Device(
                ipAddress: ipAddress,
                deviceName: 'ESP32-CAM ($ipAddress)',
                isConnected: false,
              );
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}

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

  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('\n🔗 Connecting to ESP32-CAM at ${device.ipAddress}...');

      final basicTest = await http
          .get(
            Uri.parse('http://${device.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 5));

      if (basicTest.statusCode == 200) {
        print('✅ Basic connectivity OK');

        _connectedDevice = ESP32Device(
          ipAddress: device.ipAddress,
          deviceName: device.deviceName,
          isConnected: true,
        );

        _connectionController.add(true);
        print('✅ Successfully connected to ESP32-CAM!');
        print('📹 Stream URL: $streamUrl');
        return true;
      }
    } catch (e) {
      print('❌ Connection failed: $e');
    }

    _connectionController.add(false);
    return false;
  }

  void disconnect() {
    _connectedDevice = null;
    _connectionController.add(false);
    _stopPeriodicScan();
    print('🔌 Disconnected from ESP32-CAM');
  }

  Future<bool> testConnection() async {
    if (!isConnected || _connectedDevice == null) return false;

    try {
      final response = await http
          .head(
            Uri.parse('http://${_connectedDevice!.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Connection test failed: $e');
      return false;
    }
  }

  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
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
          '10.251.96.17',
          '10.19.80.42',
          '192.168.1.100',
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

  Future<bool> configureWifi(
      String ip, String ssid, String password, String deviceName) async {
    print('Attempting to configure ESP32 at $ip with SSID: $ssid');

    await Future.delayed(const Duration(seconds: 2));

    try {
      print('Mock Wi-Fi configuration successful.');
      return true;
    } catch (e) {
      print('Mock Wi-Fi configuration failed: $e');
      return false;
    }
  }

  void dispose() {
    _stopPeriodicScan();
    _devicesController.close();
    _connectionController.close();
  }
}
