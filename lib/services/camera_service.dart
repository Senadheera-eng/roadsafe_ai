import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  ESP32Device copyWith({bool? isConnected}) {
    return ESP32Device(
      ipAddress: ipAddress,
      deviceName: deviceName,
      isConnected: isConnected ?? this.isConnected,
    );
  }
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
  // CACHING & QUICK CONNECT
  // ============================================

  Future<void> _cacheDeviceIP(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp32_last_ip', ip);
      await prefs.setInt(
          'esp32_last_connection', DateTime.now().millisecondsSinceEpoch);
      print('✅ Cached ESP32 IP: $ip');
    } catch (e) {
      print('⚠️ Failed to cache IP: $e');
    }
  }

  Future<String?> getCachedDeviceIP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedIP = prefs.getString('esp32_last_ip');
      final lastConnection = prefs.getInt('esp32_last_connection');

      if (cachedIP != null && lastConnection != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - lastConnection;
        final sevenDaysInMs = 7 * 24 * 60 * 60 * 1000;

        if (cacheAge < sevenDaysInMs) {
          print('📦 Found cached IP: $cachedIP');
          return cachedIP;
        } else {
          print('⏰ Cached IP expired');
        }
      }
    } catch (e) {
      print('⚠️ Failed to get cached IP: $e');
    }
    return null;
  }

  Future<void> setDiscoveredIP(String ip) async {
    await _cacheDeviceIP(ip);

    final device = ESP32Device(
      ipAddress: ip,
      deviceName: 'RoadSafe AI - ESP32-CAM',
      isConnected: false,
    );

    await connectToDevice(device);
    print('✅ Saved and connected to IP: $ip');
  }

  Future<bool> quickConnect() async {
    print('\n⚡ Attempting quick connect...');

    final cachedIP = await getCachedDeviceIP();
    if (cachedIP == null) {
      print('❌ No cached IP available');
      return false;
    }

    final device = await _checkESP32Device(cachedIP);
    if (device != null) {
      print('✅ Quick connect successful!');
      return await connectToDevice(device);
    }

    print('❌ Quick connect failed - device not responding');
    return false;
  }

  // ============================================
  // DEVICE DISCOVERY
  // ============================================

  Future<List<ESP32Device>> scanForDevices() async {
    print('\n🔍 ========== STARTING ESP32-CAM SCAN ==========');

    List<ESP32Device> foundDevices = [];

    // STEP 1: Try cached IP first
    print('🔍 Step 1: Checking cached IP...');
    final cachedIP = await getCachedDeviceIP();
    if (cachedIP != null) {
      final device = await _checkESP32Device(cachedIP);
      if (device != null) {
        foundDevices.add(device);
        _devicesController.add(foundDevices);
        _startPeriodicScan(foundDevices);
        print('✅ Found device at cached IP: $cachedIP');
        return foundDevices;
      }
    }

    // STEP 2: Try known IPs
    print('🔍 Step 2: Checking known IPs...');
    final knownIPs = await scanKnownIPs();
    if (knownIPs.isNotEmpty) {
      foundDevices.addAll(knownIPs);
      _devicesController.add(foundDevices);
      _startPeriodicScan(foundDevices);
      print('✅ Found ${knownIPs.length} device(s) in known IPs');
      return foundDevices;
    }

    // STEP 3: Scan current network
    print('🔍 Step 3: Scanning current network...');
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
    print('🔍 Step 4: Scanning common ranges...');
    final commonRanges = [
      '192.168.1',
      '192.168.0',
      '192.168.4',
      '10.0.0',
      '10.251.96',
      '10.19.80',
      '172.17.131',
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
      '192.168.4.1',
      '192.168.1.59',
      '10.251.96.17',
      '10.19.80.42',
      '192.168.1.100',
      '192.168.1.101',
      '192.168.0.100',
    ];

    List<ESP32Device> devices = [];

    print('  Checking ${knownIPs.length} known IPs...');

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
    List<int> priorityIPs = [1, 17, 42, 59, 100, 101, 102, 200, 254];

    print('  Scanning priority IPs in $networkBase.x...');

    final results = await Future.wait(
      priorityIPs.map((ip) => _checkESP32Device('$networkBase.$ip')),
      eagerError: false,
    );

    for (var device in results) {
      if (device != null) {
        devices.add(device);
        print('  ✅ ESP32-CAM found at ${device.ipAddress}');
        return devices;
      }
    }

    return devices;
  }

  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      final endpoints = ['/', '/stream'];

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
              print('  ✓ $ipAddress - Found via server header');
            }

            if (body.contains('roadsafe') ||
                body.contains('roadSafe') ||
                body.contains('drowsiness') ||
                body.contains('esp32-cam') ||
                body.contains('esp32cam')) {
              isESP32 = true;
              print('  ✓ $ipAddress - Found via RoadSafe content');
            }

            if (body.contains('camera') &&
                (body.contains('stream') || body.contains('live'))) {
              isESP32 = true;
              print('  ✓ $ipAddress - Found via camera/stream content');
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
                  print('  ✓ $ipAddress - Found via /stream endpoint');
                }
              } catch (_) {}
            }

            if (isESP32) {
              print('✅ ESP32-CAM identified at $ipAddress');
              return ESP32Device(
                ipAddress: ipAddress,
                deviceName: 'RoadSafe AI - ESP32-CAM',
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

  // ============================================
  // CONNECTION MANAGEMENT
  // ============================================

  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('\n🔗 Connecting to ESP32-CAM at ${device.ipAddress}...');

      final response = await http
          .get(
            Uri.parse('http://${device.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Connection OK');

        try {
          final streamTest = await http
              .head(
                Uri.parse('http://${device.ipAddress}/stream'),
              )
              .timeout(const Duration(seconds: 3));

          if (streamTest.statusCode == 200) {
            print('✅ Stream endpoint OK');
          }
        } catch (e) {
          print('⚠️ Stream endpoint check failed: $e');
        }

        _connectedDevice = device.copyWith(isConnected: true);
        await _cacheDeviceIP(device.ipAddress);
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
          .get(
            Uri.parse('http://${_connectedDevice!.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Connection test failed: $e');
      return false;
    }
  }

  Future<bool> resetESP32WiFi() async {
    if (_connectedDevice == null) {
      print('❌ No device connected');
      return false;
    }

    try {
      print('\n🔄 Sending WiFi reset command to ESP32...');
      print('   Target: ${_connectedDevice!.ipAddress}');

      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}/reset'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 Reset response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ WiFi reset command sent successfully');
        print('   ESP32 will restart in AP mode');

        // Clear cached IP since device will have new IP
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('esp32_last_ip');
        await prefs.remove('esp32_last_connection');

        // Disconnect from current device
        disconnect();

        print('✅ Local cache cleared');
        return true;
      } else {
        print('⚠️ Unexpected response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Reset failed: $e');
      return false;
    }
  }

  /// Clear cached device IP without sending reset to ESP32
  Future<void> clearCachedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('esp32_last_ip');
      await prefs.remove('esp32_last_connection');
      disconnect();
      print('✅ Cached device cleared');
    } catch (e) {
      print('⚠️ Failed to clear cache: $e');
    }
  }

  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
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
          final cachedIP = await getCachedDeviceIP();
          if (cachedIP != null) {
            final device = await _checkESP32Device(cachedIP);
            if (device != null) {
              activeDevices.add(device);
            }
          }
        }

        _devicesController.add(activeDevices);
      },
    );
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
