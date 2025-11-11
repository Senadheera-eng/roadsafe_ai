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
  // MAIN SCANNING METHODS
  // ============================================

  Future<List<ESP32Device>> scanForDevices() async {
    print('\n🔍 ========== STARTING ESP32-CAM SCAN ==========');

    List<ESP32Device> foundDevices = [];

    // STEP 1: Try known IPs first (FASTEST)
    print('📍 Step 1: Checking known IP addresses...');
    final knownDevices = await _scanKnownIPs();
    if (knownDevices.isNotEmpty) {
      foundDevices.addAll(knownDevices);
      print('✅ Found ${knownDevices.length} devices at known IPs');
      _devicesController.add(foundDevices);

      if (foundDevices.isNotEmpty) {
        print(
            '🎉 ========== SCAN COMPLETE: ${foundDevices.length} DEVICES FOUND ==========\n');
        _startPeriodicScan(foundDevices);
        return foundDevices;
      }
    }

    // STEP 2: Get current network and scan it
    print('📍 Step 2: Scanning current network...');
    final currentNetwork = await _getCurrentNetworkBase();
    if (currentNetwork != null) {
      print('🌐 Current network: $currentNetwork.x');
      final networkDevices = await _scanNetworkRange(currentNetwork);
      foundDevices.addAll(networkDevices);

      if (networkDevices.isNotEmpty) {
        print('✅ Found ${networkDevices.length} devices on current network');
        _devicesController.add(foundDevices);
        print(
            '🎉 ========== SCAN COMPLETE: ${foundDevices.length} DEVICES FOUND ==========\n');
        _startPeriodicScan(foundDevices);
        return foundDevices;
      }
    }

    // STEP 3: Scan common network ranges
    print('📍 Step 3: Scanning common network ranges...');
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
      foundDevices.addAll(rangeDevices);

      if (rangeDevices.isNotEmpty) {
        print('✅ Found ${rangeDevices.length} devices on $range.x');
        _devicesController.add(foundDevices);
        break;
      }
    }

    _devicesController.add(foundDevices);
    print(
        '🎉 ========== SCAN COMPLETE: ${foundDevices.length} DEVICES FOUND ==========\n');

    if (foundDevices.isNotEmpty) {
      _startPeriodicScan(foundDevices);
    }

    return foundDevices;
  }

  Future<List<ESP32Device>> _scanKnownIPs() async {
    List<String> knownIPs = [
      '10.251.96.17', // YOUR KNOWN IP
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

  Future<String?> _getCurrentNetworkBase() async {
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

    List<int> priorityIPs = [17, 42, 100, 101, 102, 1, 200, 254];
    List<Future<ESP32Device?>> scanTasks = [];

    for (int ip in priorityIPs) {
      scanTasks.add(_checkESP32Device('$networkBase.$ip'));
    }

    final priorityResults = await Future.wait(scanTasks, eagerError: false);
    for (var device in priorityResults) {
      if (device != null) {
        devices.add(device);
        print('  ✅ ESP32-CAM found at ${device.ipAddress}');
        return devices;
      }
    }

    scanTasks.clear();
    for (int i = 1; i <= 254; i++) {
      if (!priorityIPs.contains(i)) {
        scanTasks.add(_checkESP32Device('$networkBase.$i'));

        if (scanTasks.length >= 50) {
          final batchResults = await Future.wait(scanTasks, eagerError: false);
          for (var device in batchResults) {
            if (device != null) {
              devices.add(device);
              print('  ✅ ESP32-CAM found at ${device.ipAddress}');
              return devices;
            }
          }
          scanTasks.clear();
        }
      }
    }

    if (scanTasks.isNotEmpty) {
      final batchResults = await Future.wait(scanTasks, eagerError: false);
      for (var device in batchResults) {
        if (device != null) {
          devices.add(device);
          print('  ✅ ESP32-CAM found at ${device.ipAddress}');
        }
      }
    }

    return devices;
  }

  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
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

            if (server.contains('esp32')) {
              isESP32 = true;
            }

            if (body.contains('esp32') ||
                (body.contains('camera') && body.contains('stream'))) {
              isESP32 = true;
            }

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

  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('\n🔗 Connecting to ESP32-CAM at ${device.ipAddress}...');

      final streamTest = await http
          .head(
            Uri.parse('http://${device.ipAddress}/stream'),
          )
          .timeout(const Duration(seconds: 5));

      if (streamTest.statusCode == 200) {
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
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Connection test failed: $e');
      return false;
    }
  }

  Future<bool> connectToIP(String ipAddress) async {
    print('\n🔗 Attempting direct connection to $ipAddress...');

    final device = await _checkESP32Device(ipAddress);

    if (device != null) {
      print('✅ ESP32-CAM confirmed at $ipAddress');
      return await connectToDevice(device);
    } else {
      print('❌ No ESP32-CAM found at $ipAddress');
      return false;
    }
  }

  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
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

      _devicesController.add(activeDevices);
    });
  }

  void _stopPeriodicScan() {
    _isPeriodicScanEnabled = false;
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
  }

  void dispose() {
    _stopPeriodicScan();
    _devicesController.close();
    _connectionController.close();
  }
}
