import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ESP32Device {
  final String ipAddress;
  final String deviceName;
  final bool isConnected;
  final DateTime? lastSeen;

  ESP32Device({
    required this.ipAddress,
    required this.deviceName,
    required this.isConnected,
    this.lastSeen,
  });

  @override
  String toString() =>
      'ESP32Device($ipAddress, $deviceName, connected: $isConnected)';

  ESP32Device copyWith({bool? isConnected, DateTime? lastSeen}) {
    return ESP32Device(
      ipAddress: ipAddress,
      deviceName: deviceName,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class CameraService {
  // Singleton pattern
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  // State management
  ESP32Device? _connectedDevice;
  Timer? _periodicScanTimer;
  Timer? _connectionWatchdog;
  bool _isScanning = false;

  // Streams
  final StreamController<List<ESP32Device>> _devicesController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();
  final StreamController<String> _statusController =
      StreamController.broadcast();

  // Public getters
  Stream<List<ESP32Device>> get devicesStream => _devicesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;
  ESP32Device? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice?.isConnected ?? false;
  bool get isScanning => _isScanning;

  String get streamUrl {
    if (_connectedDevice == null) return '';
    return 'http://${_connectedDevice!.ipAddress}/stream';
  }

  // ============================================
  // IMPROVED CACHING SYSTEM
  // ============================================

  Future<void> _cacheDeviceIP(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp32_last_ip', ip);
      await prefs.setInt(
          'esp32_last_connection', DateTime.now().millisecondsSinceEpoch);

      // Also maintain a list of successful IPs
      List<String> knownIPs = prefs.getStringList('esp32_known_ips') ?? [];
      if (!knownIPs.contains(ip)) {
        knownIPs.insert(0, ip); // Add to front
        if (knownIPs.length > 5) {
          knownIPs = knownIPs.sublist(0, 5); // Keep only last 5
        }
        await prefs.setStringList('esp32_known_ips', knownIPs);
      }

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
          print(
              '📦 Found cached IP: $cachedIP (age: ${(cacheAge / 3600000).toStringAsFixed(1)}h)');
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

  Future<List<String>> _getKnownIPs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final knownIPs = prefs.getStringList('esp32_known_ips') ?? [];

      // Always include ESP32 AP mode default
      const defaultAP = '192.168.4.1';
      if (!knownIPs.contains(defaultAP)) {
        knownIPs.add(defaultAP);
      }

      return knownIPs;
    } catch (e) {
      print('⚠️ Failed to get known IPs: $e');
      return ['192.168.4.1'];
    }
  }

  // ============================================
  // IMPROVED DEVICE DETECTION
  // ============================================

  Future<ESP32Device?> _checkESP32Device(String ipAddress,
      {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      print('  🔍 Checking $ipAddress...');

      // Try multiple endpoints with LONGER timeout
      final endpoints = ['/stream', '/status', '/'];

      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse('http://$ipAddress$endpoint'),
            headers: {
              'Connection': 'close',
              'User-Agent': 'RoadSafeAI/1.0',
            },
          ).timeout(timeout); // INCREASED from 2s to 8s

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();
            final server = response.headers['server']?.toLowerCase() ?? '';
            final contentType =
                response.headers['content-type']?.toLowerCase() ?? '';

            bool isESP32 = false;
            String detectionMethod = '';

            // Detection method 1: Server header
            if (server.contains('esp32')) {
              isESP32 = true;
              detectionMethod = 'server header';
            }

            // Detection method 2: Content-type for stream
            if (endpoint == '/stream' &&
                contentType.contains('multipart/x-mixed-replace')) {
              isESP32 = true;
              detectionMethod = 'stream endpoint';
            }

            // Detection method 3: HTML content analysis
            if (body.contains('roadsafe') ||
                body.contains('esp32-cam') ||
                body.contains('esp32cam') ||
                body.contains('drowsiness')) {
              isESP32 = true;
              detectionMethod = 'content match';
            }

            // Detection method 4: Camera-specific keywords
            if (body.contains('camera') &&
                (body.contains('stream') ||
                    body.contains('live') ||
                    body.contains('mjpeg'))) {
              isESP32 = true;
              detectionMethod = 'camera keywords';
            }

            if (isESP32) {
              print('  ✅ ESP32-CAM FOUND at $ipAddress via $detectionMethod');
              return ESP32Device(
                ipAddress: ipAddress,
                deviceName: 'RoadSafe AI - ESP32-CAM',
                isConnected: false,
                lastSeen: DateTime.now(),
              );
            }
          }
        } catch (e) {
          // Timeout or connection refused - continue to next endpoint
          continue;
        }
      }

      // Additional check: Try HEAD request to /stream as final verification
      try {
        final streamCheck = await http
            .head(
              Uri.parse('http://$ipAddress/stream'),
            )
            .timeout(const Duration(seconds: 3));

        if (streamCheck.statusCode == 200) {
          final contentType =
              streamCheck.headers['content-type']?.toLowerCase() ?? '';
          if (contentType.contains('multipart') ||
              contentType.contains('mjpeg')) {
            print('  ✅ ESP32-CAM FOUND at $ipAddress via stream HEAD check');
            return ESP32Device(
              ipAddress: ipAddress,
              deviceName: 'RoadSafe AI - ESP32-CAM',
              isConnected: false,
              lastSeen: DateTime.now(),
            );
          }
        }
      } catch (_) {}
    } catch (e) {
      // Timeout or network error
    }

    return null;
  }

  // ============================================
  // SMART MULTI-PHASE SCANNING
  // ============================================

  Future<List<ESP32Device>> scanForDevices() async {
    if (_isScanning) {
      print('⚠️ Scan already in progress');
      return [];
    }

    _isScanning = true;
    _updateStatus('Starting device scan...');

    print('\n🔍 ========== SMART ESP32-CAM SCAN ==========');

    List<ESP32Device> foundDevices = [];

    try {
      // ===== PHASE 1: INSTANT - Cached IP (should be <1s) =====
      _updateStatus('Checking cached connection...');
      print('📱 PHASE 1: Quick Connect (cached IP)');

      final cachedIP = await _getCachedDeviceIP();
      if (cachedIP != null) {
        final device = await _checkESP32Device(cachedIP);
        if (device != null) {
          foundDevices.add(device);
          _devicesController.add(foundDevices);
          _updateStatus('Device found!');
          print('✅ PHASE 1 SUCCESS: Found at cached IP $cachedIP');
          _isScanning = false;
          return foundDevices;
        } else {
          print('⚠️ Cached IP no longer valid');
        }
      }

      // ===== PHASE 2: FAST - Known IPs (should be <5s) =====
      _updateStatus('Scanning known locations...');
      print('\n📱 PHASE 2: Known IPs Check');

      final knownIPs = await _getKnownIPs();
      print('  Checking ${knownIPs.length} known IPs: $knownIPs');

      // Check all known IPs in parallel
      final results = await Future.wait(
        knownIPs.map((ip) => _checkESP32Device(ip)),
        eagerError: false,
      );

      for (var device in results) {
        if (device != null &&
            !foundDevices.any((d) => d.ipAddress == device.ipAddress)) {
          foundDevices.add(device);
          print('✅ Found at known IP: ${device.ipAddress}');
        }
      }

      if (foundDevices.isNotEmpty) {
        _devicesController.add(foundDevices);
        _updateStatus('Device found!');
        print('✅ PHASE 2 SUCCESS: ${foundDevices.length} device(s) found');
        _isScanning = false;
        return foundDevices;
      }

      // ===== PHASE 3: MEDIUM - Current Network Scan (should be <15s) =====
      _updateStatus('Scanning your network...');
      print('\n📱 PHASE 3: Current Network Scan');

      final currentNetwork = await _getLocalNetworkBase();
      if (currentNetwork != null) {
        print('🌐 Current network: $currentNetwork.x');

        // Scan priority IPs first (common camera IPs)
        final priorityIPs = [1, 59, 100, 101, 102, 42, 17, 200, 254];
        print('  Scanning ${priorityIPs.length} priority IPs first...');

        final priorityResults = await Future.wait(
          priorityIPs.map((ip) => _checkESP32Device('$currentNetwork.$ip')),
          eagerError: false,
        );

        for (var device in priorityResults) {
          if (device != null &&
              !foundDevices.any((d) => d.ipAddress == device.ipAddress)) {
            foundDevices.add(device);
            print('✅ Found at priority IP: ${device.ipAddress}');
          }
        }

        if (foundDevices.isNotEmpty) {
          _devicesController.add(foundDevices);
          _updateStatus('Device found!');
          print('✅ PHASE 3 SUCCESS: ${foundDevices.length} device(s) found');
          _isScanning = false;
          return foundDevices;
        }

        // If still not found, scan more IPs (10-50, 60-99, 103-150)
        print('  Expanding search to more IPs...');
        _updateStatus('Deep scanning network...');

        final extendedIPs = [
          ...List.generate(41, (i) => i + 10), // 10-50
          ...List.generate(40, (i) => i + 60), // 60-99
          ...List.generate(48, (i) => i + 103), // 103-150
        ];

        // Scan in batches of 20 to avoid overwhelming the network
        for (int i = 0; i < extendedIPs.length; i += 20) {
          final batch = extendedIPs.skip(i).take(20).toList();

          final batchResults = await Future.wait(
            batch.map((ip) => _checkESP32Device('$currentNetwork.$ip',
                timeout: Duration(seconds: 3))),
            eagerError: false,
          );

          for (var device in batchResults) {
            if (device != null &&
                !foundDevices.any((d) => d.ipAddress == device.ipAddress)) {
              foundDevices.add(device);
              print('✅ Found at extended IP: ${device.ipAddress}');
              _devicesController.add(foundDevices);
              _updateStatus('Device found!');
              _isScanning = false;
              return foundDevices;
            }
          }
        }
      }

      // ===== PHASE 4: SLOW - Common Router Networks (optional) =====
      if (foundDevices.isEmpty) {
        print('\n📱 PHASE 4: Common Networks Scan (last resort)');
        _updateStatus('Scanning common networks...');

        final commonNetworks = [
          '192.168.1',
          '192.168.0',
          '192.168.4', // ESP32 AP mode
          '10.0.0',
        ];

        // Remove current network from common networks to avoid duplicates
        if (currentNetwork != null) {
          commonNetworks.removeWhere((network) => network == currentNetwork);
        }

        for (String network in commonNetworks) {
          print('  Checking common network: $network.x');

          // Only check priority IPs for common networks (to save time)
          final priorityIPs = [1, 4, 59, 100, 101];

          final results = await Future.wait(
            priorityIPs.map((ip) => _checkESP32Device('$network.$ip',
                timeout: Duration(seconds: 4))),
            eagerError: false,
          );

          for (var device in results) {
            if (device != null &&
                !foundDevices.any((d) => d.ipAddress == device.ipAddress)) {
              foundDevices.add(device);
              print('✅ Found at common network IP: ${device.ipAddress}');
              _devicesController.add(foundDevices);
              _updateStatus('Device found!');
              _isScanning = false;
              return foundDevices;
            }
          }
        }
      }
    } catch (e) {
      print('❌ Scan error: $e');
      _updateStatus('Scan error: $e');
    } finally {
      _isScanning = false;
    }

    _devicesController.add(foundDevices);

    if (foundDevices.isEmpty) {
      _updateStatus('No devices found');
      print('❌ SCAN COMPLETE: No ESP32-CAM devices found');
      print('=========================================\n');
    } else {
      _updateStatus('${foundDevices.length} device(s) found');
      print('✅ SCAN COMPLETE: ${foundDevices.length} device(s) found');
      print('=========================================\n');
    }

    return foundDevices;
  }

  Future<String?> _getLocalNetworkBase() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '0.0.0.0') {
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

  // ============================================
  // IMPROVED CONNECTION MANAGEMENT
  // ============================================

  Future<bool> connectToDevice(ESP32Device device) async {
    try {
      print('\n🔗 ========== CONNECTING TO ESP32-CAM ==========');
      print('IP Address: ${device.ipAddress}');
      print('Device Name: ${device.deviceName}');

      _updateStatus('Connecting to ${device.ipAddress}...');

      // Step 1: Verify basic connectivity with LONGER timeout
      print('Step 1: Testing basic connectivity...');
      final basicTest = await http
          .get(
            Uri.parse('http://${device.ipAddress}/'),
          )
          .timeout(const Duration(seconds: 10)); // INCREASED from 5s to 10s

      if (basicTest.statusCode != 200) {
        throw Exception('Basic connectivity failed: ${basicTest.statusCode}');
      }
      print('✅ Basic connectivity OK');

      // Step 2: Verify stream endpoint
      print('Step 2: Verifying stream endpoint...');
      final streamTest = await http
          .head(
            Uri.parse('http://${device.ipAddress}/stream'),
          )
          .timeout(const Duration(seconds: 8));

      if (streamTest.statusCode != 200) {
        print('⚠️ Stream endpoint returned: ${streamTest.statusCode}');
        // Don't fail completely, stream might work anyway
      } else {
        print('✅ Stream endpoint OK');
      }

      // Step 3: Test actual stream data
      print('Step 3: Testing stream data...');
      bool streamDataValid = await _testStreamData(device.ipAddress);

      if (!streamDataValid) {
        print('⚠️ Stream data test inconclusive, proceeding anyway');
      } else {
        print('✅ Stream data validated');
      }

      // Success - update state
      _connectedDevice =
          device.copyWith(isConnected: true, lastSeen: DateTime.now());
      await _cacheDeviceIP(device.ipAddress);
      _connectionController.add(true);
      _updateStatus('Connected successfully!');

      print('✅ ========== CONNECTION SUCCESSFUL ==========');
      print('📹 Stream URL: $streamUrl');
      print('===============================================\n');

      // Start connection watchdog
      _startConnectionWatchdog();

      return true;
    } catch (e) {
      print('❌ Connection failed: $e');
      _connectionController.add(false);
      _updateStatus('Connection failed: $e');
      return false;
    }
  }

  Future<bool> _testStreamData(String ipAddress) async {
    try {
      final request =
          http.Request('GET', Uri.parse('http://$ipAddress/stream'));
      final client = http.Client();
      final response =
          await client.send(request).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        client.close();
        return false;
      }

      // Read first few bytes to verify it's actual MJPEG data
      bool foundJPEGMarker = false;
      final subscription = response.stream.listen(
        (chunk) {
          // Look for JPEG start marker (0xFFD8)
          for (int i = 0; i < chunk.length - 1; i++) {
            if (chunk[i] == 0xFF && chunk[i + 1] == 0xD8) {
              foundJPEGMarker = true;
              break;
            }
          }
        },
        cancelOnError: true,
      );

      // Wait up to 3 seconds for JPEG marker
      await Future.delayed(const Duration(seconds: 3));
      await subscription.cancel();
      client.close();

      return foundJPEGMarker;
    } catch (e) {
      print('⚠️ Stream data test error: $e');
      return false;
    }
  }

  // Connection watchdog to detect disconnections
  void _startConnectionWatchdog() {
    _connectionWatchdog?.cancel();

    _connectionWatchdog = Timer.periodic(
      const Duration(seconds: 15),
      (timer) async {
        if (_connectedDevice != null) {
          final isStillConnected = await testConnection();

          if (!isStillConnected) {
            print('⚠️ Connection lost to ${_connectedDevice!.ipAddress}');
            _updateStatus('Connection lost - attempting to reconnect...');

            // Try to reconnect
            final reconnected = await connectToDevice(_connectedDevice!);

            if (!reconnected) {
              print('❌ Reconnection failed');
              disconnect();
            }
          }
        } else {
          timer.cancel();
        }
      },
    );
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
      return false;
    }
  }

  void disconnect() {
    print('🔌 Disconnecting from ESP32-CAM');
    _connectedDevice = null;
    _connectionController.add(false);
    _connectionWatchdog?.cancel();
    _updateStatus('Disconnected');
  }

  // ============================================
  // MANUAL IP CONNECTION (for troubleshooting)
  // ============================================

  Future<bool> connectToIP(String ipAddress) async {
    print('\n🔗 Manual connection to $ipAddress');
    _updateStatus('Testing connection to $ipAddress...');

    final device = await _checkESP32Device(ipAddress);

    if (device != null) {
      return await connectToDevice(device);
    } else {
      print('❌ No ESP32-CAM found at $ipAddress');
      _updateStatus('No device found at $ipAddress');
      return false;
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void _updateStatus(String status) {
    print('📊 Status: $status');
    _statusController.add(status);
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('esp32_last_ip');
      await prefs.remove('esp32_known_ips');
      await prefs.remove('esp32_last_connection');
      print('✅ Cache cleared');
    } catch (e) {
      print('⚠️ Failed to clear cache: $e');
    }
  }

  void dispose() {
    _connectionWatchdog?.cancel();
    _devicesController.close();
    _connectionController.close();
    _statusController.close();
  }
}
