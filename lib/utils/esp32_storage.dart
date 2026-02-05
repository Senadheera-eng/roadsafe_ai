import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for persisting ESP32 IP address and WiFi configuration
class ESP32Storage {
  static const String _keyESP32IP = 'esp32_configured_ip';
  static const String _keyWiFiSSID = 'esp32_wifi_ssid';
  static const String _keyWiFiConfigured = 'esp32_wifi_configured';
  static const String _keyLastConnected = 'esp32_last_connected';

  /// Save the ESP32's IP address after successful WiFi configuration
  static Future<bool> saveESP32IP(String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyESP32IP, ipAddress);
      await prefs.setString(
          _keyLastConnected, DateTime.now().toIso8601String());
      await prefs.setBool(_keyWiFiConfigured, true);

      print('✅ Saved ESP32 IP: $ipAddress');
      return true;
    } catch (e) {
      print('❌ Failed to save IP: $e');
      return false;
    }
  }

  /// Get the cached ESP32 IP address
  static Future<String?> getESP32IP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString(_keyESP32IP);

      if (ip != null) {
        print('📦 Retrieved cached IP: $ip');
      } else {
        print('📦 No cached IP found');
      }

      return ip;
    } catch (e) {
      print('❌ Failed to retrieve IP: $e');
      return null;
    }
  }

  /// Save the WiFi SSID that ESP32 is connected to
  static Future<bool> saveWiFiSSID(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWiFiSSID, ssid);
      print('✅ Saved WiFi SSID: $ssid');
      return true;
    } catch (e) {
      print('❌ Failed to save SSID: $e');
      return false;
    }
  }

  /// Get the WiFi SSID that ESP32 is connected to
  static Future<String?> getWiFiSSID() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWiFiSSID);
    } catch (e) {
      print('❌ Failed to retrieve SSID: $e');
      return null;
    }
  }

  /// Check if WiFi has been configured
  static Future<bool> isWiFiConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyWiFiConfigured) ?? false;
    } catch (e) {
      print('❌ Failed to check WiFi configured status: $e');
      return false;
    }
  }

  /// Get the last connected timestamp
  static Future<DateTime?> getLastConnectedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_keyLastConnected);

      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      print('❌ Failed to retrieve last connected time: $e');
      return null;
    }
  }

  /// Clear all ESP32 configuration (used when "Forget WiFi" is pressed)
  static Future<bool> clearAllConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyESP32IP);
      await prefs.remove(_keyWiFiSSID);
      await prefs.remove(_keyWiFiConfigured);
      await prefs.remove(_keyLastConnected);

      print('✅ Cleared all ESP32 configuration');
      return true;
    } catch (e) {
      print('❌ Failed to clear configuration: $e');
      return false;
    }
  }

  /// Get configuration summary for debugging
  static Future<Map<String, dynamic>> getConfigurationSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'ip': prefs.getString(_keyESP32IP),
        'ssid': prefs.getString(_keyWiFiSSID),
        'configured': prefs.getBool(_keyWiFiConfigured) ?? false,
        'last_connected': prefs.getString(_keyLastConnected),
      };
    } catch (e) {
      print('❌ Failed to get configuration summary: $e');
      return {};
    }
  }
}
