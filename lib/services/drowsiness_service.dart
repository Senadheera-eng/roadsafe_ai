import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';

class DrowsinessDetector {
  static const String API_KEY = "kU0QoAFfW5QbD4uwb3p1";
  static const String API_URL = "https://detect.roboflow.com";
  static const String MODEL_ID = "drowsiness-driver/1";

  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      print('🔍 Starting drowsiness analysis...');
      print('📊 Image size: ${imageBytes.length} bytes');

      // Convert to base64
      String base64Image = base64Encode(imageBytes);
      print('📝 Base64 length: ${base64Image.length}');

      // Make API request
      final response = await http
          .post(
            Uri.parse('$API_URL/$MODEL_ID?api_key=$API_KEY'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: base64Image,
          )
          .timeout(Duration(seconds: 15)); // Increased timeout

      print('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API call successful');
        final data = json.decode(response.body);
        print('📋 API Response: $data');

        final result = DrowsinessResult.fromJson(data);
        print(
            '🎯 Detection Result: ${result.isDrowsy ? "DROWSY" : "ALERT"} (${result.confidence})');

        return result;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('🚨 Drowsiness detection error: $e');
      return null;
    }
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('🚨 DROWSINESS DETECTED - Triggering vibration');

    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Strong vibration pattern
        await Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500, 200, 1000],
            intensities: [0, 255, 0, 255, 0, 255, 0, 255]);
        print('📳 Vibration triggered successfully');
      } else {
        print('❌ No vibrator available');
      }
    } catch (e) {
      print('❌ Vibration failed: $e');
    }
  }
}

class DrowsinessResult {
  final bool isDrowsy;
  final double confidence;
  final int totalPredictions;

  DrowsinessResult({
    required this.isDrowsy,
    required this.confidence,
    required this.totalPredictions,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;

    print('🔍 Parsing API response...');

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      print('📊 Found ${totalPredictions} predictions');

      for (var pred in predictions) {
        final className = (pred['class'] ?? '').toString().toLowerCase();
        final confidence = (pred['confidence'] ?? 0.0).toDouble();

        print(
            '🎯 Prediction: $className (confidence: ${confidence.toStringAsFixed(2)})');

        // Check for drowsiness indicators
        if ((className.contains('drowsy') ||
                className.contains('closed') ||
                className.contains('sleepy') ||
                className.contains('tired') ||
                className.contains('eyes_closed')) &&
            confidence > 0.3) {
          // Lower threshold for testing
          isDrowsy = true;
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
          }
          print('⚠️ Drowsiness indicator found: $className');
        }
      }
    } else {
      print('❌ No predictions found in response');
    }

    final result = DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
    );

    print('📋 Final result: ${result.isDrowsy ? "DROWSY" : "ALERT"}');
    return result;
  }
}
