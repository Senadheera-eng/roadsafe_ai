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
  final StreamController<String> _scanStatusController =
      StreamController.broadcast();

  Stream<List<ESP32Device>> get devicesStream => _devicesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get scanStatusStream => _scanStatusController.stream;
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

  Future<String?> _getCachedDeviceIP() async {
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
    _scanStatusController.add('Quick connecting...');

    final cachedIP = await _getCachedDeviceIP();
    if (cachedIP == null) {
      print('❌ No cached IP available');
      _scanStatusController.add('No cached device');
      return false;
    }

    final device = await _checkESP32Device(cachedIP);
    if (device != null) {
      print('✅ Quick connect successful!');
      _scanStatusController.add('Connected!');
      return await connectToDevice(device);
    }

    print('❌ Quick connect failed - device not responding');
    _scanStatusController.add('Quick connect failed');
    return false;
  }

  // ============================================
  // SMART NETWORK DETECTION
  // ============================================

  Future<String?> _getPhoneNetworkBase() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty) {
        print('📱 Phone IP: $wifiIP');
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          String networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';
          print('🌐 Detected network: $networkBase.x');
          return networkBase;
        }
      }
    } catch (e) {
      print('⚠️ Could not get phone IP: $e');
    }
    return null;
  }

  // ============================================
  // FAST PARALLEL SCANNING
  // ============================================

  Future<List<ESP32Device>> _fastParallelScan(List<String> ipAddresses) async {
    if (ipAddresses.isEmpty) return [];

    print('🚀 Scanning ${ipAddresses.length} IPs in parallel...');

    // Scan all IPs at once
    final results = await Future.wait(
      ipAddresses.map((ip) => _checkESP32Device(ip)),
      eagerError: false,
    );

    List<ESP32Device> devices = [];
    for (var device in results) {
      if (device != null) {
        devices.add(device);
        print('  ✅ Found at ${device.ipAddress}');
      }
    }

    return devices;
  }

  // ============================================
  // MAIN SCAN FUNCTION (FIXED!)
  // ============================================

  Future<List<ESP32Device>> scanForDevices() async {
    print('\n🔍 ========== STARTING ESP32 SCAN ==========');

    List<ESP32Device> foundDevices = [];

    // STEP 1: Check cached IP (< 1 second)
    print('📍 Step 1: Checking cached IP...');
    _scanStatusController.add('Checking cached device...');

    final cachedIP = await _getCachedDeviceIP();
    if (cachedIP != null) {
      final device = await _checkESP32Device(cachedIP);
      if (device != null) {
        foundDevices.add(device);
        _devicesController.add(foundDevices);
        _startPeriodicScan(foundDevices);
        _scanStatusController.add('Device found!');
        print('✅ Found at cached IP: $cachedIP');
        return foundDevices;
      }
      print('⚠️ Cached IP not responding');
    }

    // STEP 2: Get phone's network range
    print('🌐 Step 2: Detecting phone network...');
    _scanStatusController.add('Detecting network...');

    final phoneNetwork = await _getPhoneNetworkBase();

    // STEP 3: Build smart IP list
    print('📋 Step 3: Building scan list...');
    List<String> scanIPs = [];

    // Always check ESP32 AP mode
    scanIPs.add('192.168.4.1');

    // Add phone's network range (THIS IS THE KEY FIX!)
    if (phoneNetwork != null) {
      print('   Adding phone network: $phoneNetwork.x');
      _scanStatusController.add('Scanning $phoneNetwork.x...');

      // Common device IPs in same network as phone
      for (int i in [
        1,
        10,
        17,
        20,
        30,
        42,
        50,
        59,
        77,
        88,
        99,
        100,
        101,
        102,
        111,
        150,
        200,
        254
      ]) {
        scanIPs.add('$phoneNetwork.$i');
      }
    }

    // Add other common networks as fallback
    List<String> fallbackNetworks = [
      '192.168.1',
      '192.168.0',
      '10.0.0',
      '10.0.1',
    ];

    for (String network in fallbackNetworks) {
      if (network != phoneNetwork) {
        for (int i in [1, 17, 42, 59, 100, 101, 254]) {
          scanIPs.add('$network.$i');
        }
      }
    }

    // Remove duplicates
    scanIPs = scanIPs.toSet().toList();

    // STEP 4: Fast parallel scan
    print('🚀 Step 4: Scanning ${scanIPs.length} IPs...');
    _scanStatusController.add('Scanning ${scanIPs.length} IPs...');

    foundDevices = await _fastParallelScan(scanIPs);

    if (foundDevices.isNotEmpty) {
      _devicesController.add(foundDevices);
      _startPeriodicScan(foundDevices);
      _scanStatusController.add('Device found!');
      print('🎉 Found ${foundDevices.length} device(s)!');
    } else {
      _scanStatusController.add('No device found');
      print('❌ No devices found');
    }

    print('========================================\n');
    return foundDevices;
  }

  Future<ESP32Device?> _checkESP32Device(String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ipAddress/'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        final server = response.headers['server']?.toLowerCase() ?? '';

        // Check for ESP32/RoadSafe markers
        if (server.contains('esp32') ||
            body.contains('roadsafe') ||
            body.contains('esp32') ||
            body.contains('camera') ||
            body.contains('stream')) {
          // Verify stream endpoint exists
          try {
            final streamCheck = await http
                .head(
                  Uri.parse('http://$ipAddress/stream'),
                )
                .timeout(const Duration(seconds: 2));

            if (streamCheck.statusCode == 200) {
              return ESP32Device(
                ipAddress: ipAddress,
                deviceName: 'RoadSafe AI - ESP32-CAM',
                isConnected: false,
              );
            }
          } catch (_) {}
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
      print('\n🔗 Connecting to ${device.ipAddress}...');

      final response = await http
          .get(
            Uri.parse('http://${device.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _connectedDevice = device.copyWith(isConnected: true);
        await _cacheDeviceIP(device.ipAddress);
        _connectionController.add(true);
        print('✅ Connected!');
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
    print('🔌 Disconnected');
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
      return false;
    }
  }

  // ============================================
  // PERIODIC MONITORING
  // ============================================

  void _startPeriodicScan(List<ESP32Device> knownDevices) {
    _stopPeriodicScan();
    _isPeriodicScanEnabled = true;

    _periodicScanTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (!_isPeriodicScanEnabled) {
          timer.cancel();
          return;
        }

        List<ESP32Device> activeDevices = [];

        final results = await Future.wait(
          knownDevices.map((device) => _checkESP32Device(device.ipAddress)),
          eagerError: false,
        );

        for (var device in results) {
          if (device != null) {
            activeDevices.add(device);
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

  // ============================================
  // CLEANUP
  // ============================================

  void dispose() {
    _stopPeriodicScan();
    _devicesController.close();
    _connectionController.close();
    _scanStatusController.close();
  }
}
