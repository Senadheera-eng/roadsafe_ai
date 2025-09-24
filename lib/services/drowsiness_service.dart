import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';

class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final String className;
  final double confidence;
  final bool isDrowsy;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.className,
    required this.confidence,
    required this.isDrowsy,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    final className = (json['class'] ?? '').toString().toLowerCase();
    final confidence = (json['confidence'] ?? 0.0).toDouble();

    // Extract bounding box coordinates
    final x = (json['x'] ?? 0.0).toDouble();
    final y = (json['y'] ?? 0.0).toDouble();
    final width = (json['width'] ?? 0.0).toDouble();
    final height = (json['height'] ?? 0.0).toDouble();

    // Improved drowsiness detection logic
    bool isDrowsy = false;

    // Direct drowsiness indicators
    if ((className.contains('closed') ||
            className.contains('drowsy') ||
            className.contains('sleepy') ||
            className.contains('tired') ||
            className.contains('yawn')) &&
        confidence > 0.2) {
      // Lowered threshold
      isDrowsy = true;
    }

    // Low confidence "open" eyes might indicate tiredness
    if (className.contains('open') && confidence < 0.6) {
      isDrowsy = true; // Consider as potential drowsiness
    }

    return DetectionBox(
      x: x - (width / 2), // Convert center x to top-left x
      y: y - (height / 2), // Convert center y to top-left y
      width: width,
      height: height,
      className: className,
      confidence: confidence,
      isDrowsy: isDrowsy,
    );
  }
}

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
      print('🔄 Base64 length: ${base64Image.length}');

      // Make API request with lower confidence threshold for better detection
      final response = await http
          .post(
            Uri.parse(
                '$API_URL/$MODEL_ID?api_key=$API_KEY&confidence=0.1&overlap=0.3'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'RoadSafeAI/1.0',
            },
            body: base64Image,
          )
          .timeout(
              Duration(seconds: 10)); // Reduced timeout for faster response

      print('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API call successful');
        final data = json.decode(response.body);
        print('📋 API Response: $data');

        final result = DrowsinessResult.fromJson(data);
        print(
            '🎯 Detection Result: ${result.isDrowsy ? "DROWSY" : "ALERT"} (confidence: ${result.confidence.toStringAsFixed(2)}, boxes: ${result.detectionBoxes.length})');

        // Log all detections
        for (var box in result.detectionBoxes) {
          print(
              '📦 Detection: ${box.className} - ${(box.confidence * 100).toInt()}% ${box.isDrowsy ? "⚠️ DROWSY" : "✅ NORMAL"}');
        }

        return result;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');

        // Try to parse error message
        try {
          final errorData = json.decode(response.body);
          print('❌ Error details: $errorData');
        } catch (e) {
          print('❌ Raw error response: ${response.body}');
        }

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
      // Check if vibration is available
      bool? hasVibrator = await Vibration.hasVibrator();
      print('📱 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        print('📳 Starting emergency vibration pattern...');

        // Try simple vibration first
        try {
          await Vibration.vibrate(duration: 2000);
          print('✅ Simple vibration successful');
        } catch (e) {
          print('❌ Simple vibration failed: $e');
        }

        // Wait a moment
        await Future.delayed(Duration(milliseconds: 300));

        // Try pattern vibration
        try {
          await Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          print('✅ Pattern vibration successful');
        } catch (e) {
          print('❌ Pattern vibration failed: $e');
        }
      } else {
        print('❌ No vibrator available on this device');

        // Try fallback vibration anyway
        try {
          await Vibration.vibrate();
          print('✅ Fallback basic vibration worked');
        } catch (e) {
          print('❌ Even basic vibration failed: $e');
        }
      }
    } catch (e) {
      print('❌ Vibration setup failed: $e');
    }
  }

  // Manual test function for debugging
  static Future<void> testVibration() async {
    print('🧪 Testing vibration manually...');
    await triggerDrowsinessAlert();
  }

  // Test API connectivity
  static Future<bool> testAPIConnection() async {
    try {
      print('🔗 Testing API connection...');

      final response = await http
          .get(
            Uri.parse('$API_URL/$MODEL_ID?api_key=$API_KEY'),
          )
          .timeout(Duration(seconds: 10));

      print('📡 API Test Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 400) {
        // 400 is expected for GET request without image data
        print('✅ API connection successful');
        return true;
      } else {
        print('❌ API connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ API connection error: $e');
      return false;
    }
  }
}

class DrowsinessResult {
  final bool isDrowsy;
  final double confidence;
  final int totalPredictions;
  final List<DetectionBox> detectionBoxes;

  DrowsinessResult({
    required this.isDrowsy,
    required this.confidence,
    required this.totalPredictions,
    required this.detectionBoxes,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;
    List<DetectionBox> detectionBoxes = [];

    print('🔍 Parsing API response...');

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      print('📊 Found ${totalPredictions} predictions');

      for (var pred in predictions) {
        try {
          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          print(
              '🎯 Prediction: ${box.className} (confidence: ${(box.confidence * 100).toInt()}%) at (${box.x.toInt()}, ${box.y.toInt()})');

          // Check for drowsiness indicators
          if (box.isDrowsy) {
            isDrowsy = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
            }
            print('⚠️ Drowsiness indicator found: ${box.className}');
          }
        } catch (e) {
          print('❌ Error parsing detection box: $e');
          print('📋 Raw prediction data: $pred');
        }
      }
    } else {
      print('❌ No predictions found in response');
      print('📋 Full response: $json');
    }

    final result = DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
      detectionBoxes: detectionBoxes,
    );

    print(
        '📋 Final result: ${result.isDrowsy ? "DROWSY" : "ALERT"} with ${result.detectionBoxes.length} detection boxes');
    return result;
  }
}
