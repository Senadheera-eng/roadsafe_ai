import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// ✅ Request location permissions (required for WiFi SSID on Android 10+)
  static Future<bool> requestLocationPermissions(BuildContext context) async {
    print('\n📍 Checking location permissions...');

    // Check current status
    final status = await Permission.location.status;
    print('   Current status: $status');

    if (status.isGranted) {
      print('✅ Location permission already granted');
      return true;
    }

    if (status.isDenied) {
      // Show explanation dialog
      final shouldRequest = await _showPermissionExplanation(context);
      if (!shouldRequest) {
        print('❌ User declined permission request');
        return false;
      }

      // Request permission
      final result = await Permission.location.request();
      print('   Request result: $result');

      if (result.isGranted) {
        print('✅ Location permission granted');
        return true;
      }
    }

    if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      await _showOpenSettingsDialog(context);
      return false;
    }

    print('❌ Location permission not granted');
    return false;
  }

  /// ✅ Request nearby WiFi devices permission (Android 13+)
  static Future<bool> requestNearbyWiFiPermission(BuildContext context) async {
    print('\n📡 Checking nearby WiFi devices permission...');

    // This is only for Android 13+ (API 33+)
    // On older versions, it will return granted automatically
    final status = await Permission.nearbyWifiDevices.status;
    print('   Current status: $status');

    if (status.isGranted) {
      print('✅ Nearby WiFi permission already granted');
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.nearbyWifiDevices.request();
      print('   Request result: $result');

      if (result.isGranted) {
        print('✅ Nearby WiFi permission granted');
        return true;
      }
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(context);
      return false;
    }

    print('❌ Nearby WiFi permission not granted');
    return false;
  }

  /// ✅ Request all required permissions for WiFi configuration
  static Future<bool> requestAllWiFiPermissions(BuildContext context) async {
    print('\n🔐 Requesting all WiFi permissions...');

    final locationGranted = await requestLocationPermissions(context);
    if (!locationGranted) {
      print('❌ Location permission required for WiFi detection');
      return false;
    }

    final wifiGranted = await requestNearbyWiFiPermission(context);
    if (!wifiGranted) {
      print(
          '⚠️ Nearby WiFi permission not granted (may not be required on this Android version)');
      // Don't return false here, as this permission is only for Android 13+
    }

    print('✅ All required permissions granted');
    return true;
  }

  static Future<bool> _showPermissionExplanation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text('Location Permission'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why we need this permission:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'On Android 10 and above, apps need location permission to detect WiFi network names (SSID). This is a requirement from Google to protect user privacy.',
                ),
                SizedBox(height: 12),
                Text(
                  'We only use this permission to:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                    '• Detect if you\'re connected to the ESP32 setup network'),
                Text('• Verify the WiFi connection status'),
                SizedBox(height: 12),
                Text(
                  'We do NOT track your location or use GPS.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> _showOpenSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Location permission is required to detect WiFi networks.',
            ),
            SizedBox(height: 12),
            Text(
              'Please enable it in app settings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Tap "Open Settings" below'),
            Text('2. Find "Permissions"'),
            Text('3. Enable "Location"'),
            Text('4. Return to the app'),
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
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// ✅ Check if all required permissions are granted
  static Future<bool> hasAllWiFiPermissions() async {
    final locationStatus = await Permission.location.status;

    // Nearby WiFi permission is only for Android 13+
    // If not available, we consider it as granted
    final wifiStatus = await Permission.nearbyWifiDevices.status;

    print('📍 Permission Status:');
    print('   Location: $locationStatus');
    print('   Nearby WiFi: $wifiStatus');

    // Location is mandatory, WiFi permission is optional (Android 13+)
    return locationStatus.isGranted;
  }
}
