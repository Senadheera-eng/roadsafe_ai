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

    // Debug: Print what your model actually returns
    print(
        'Raw detection: class="$className", confidence=${(confidence * 100).toInt()}%');

    final x = (json['x'] ?? 0.0).toDouble();
    final y = (json['y'] ?? 0.0).toDouble();
    final width = (json['width'] ?? 0.0).toDouble();
    final height = (json['height'] ?? 0.0).toDouble();

    // Enhanced drowsiness detection based on common class names
    bool isDrowsy = false;

    if (confidence > 0.3) {
      // Check for drowsiness indicators - update these based on console debug output
      if (className.contains('drowsy') ||
          className.contains('closed') ||
          className.contains('close') ||
          className.contains('sleepy') ||
          className.contains('tired') ||
          className.contains('yawn') ||
          className.contains('blink') ||
          className.contains('shut') ||
          className == 'eyes_closed' ||
          className == 'closed_eyes' ||
          className == 'eye_closed') {
        isDrowsy = true;
        print(
            'DROWSY STATE DETECTED: $className at ${(confidence * 100).toInt()}%');
      } else if (className.contains('open') || className.contains('alert')) {
        isDrowsy = false;
        print('ALERT STATE: $className at ${(confidence * 100).toInt()}%');
      }
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
      print('Starting drowsiness analysis...');
      print('Image size: ${imageBytes.length} bytes');

      // Convert to base64
      String base64Image = base64Encode(imageBytes);

      // Make API request with optimized parameters
      final response = await http
          .post(
            Uri.parse(
                '$API_URL/$MODEL_ID?api_key=$API_KEY&confidence=0.3&overlap=0.5'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'RoadSafeAI/1.0',
            },
            body: base64Image,
          )
          .timeout(Duration(seconds: 10));

      print('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Full API Response: $data'); // Critical debug line

        final result = DrowsinessResult.fromJson(data);
        print(
            'Detection Result: ${result.isDrowsy ? "DROWSY" : "ALERT"} - Boxes: ${result.detectionBoxes.length}');

        // Log all detections for debugging
        for (var box in result.detectionBoxes) {
          print(
              'Detection: ${box.className} - ${(box.confidence * 100).toInt()}% ${box.isDrowsy ? "DROWSY" : "NORMAL"}');
        }

        return result;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Drowsiness detection error: $e');
      return null;
    }
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('DROWSINESS DETECTED - Triggering vibration');

    try {
      // Check if vibration is available
      bool? hasVibrator = await Vibration.hasVibrator();
      print('Device has vibrator: $hasVibrator');

      // First vibration - long alert
      try {
        await Vibration.vibrate(duration: 2000);
        print('Long vibration triggered');
      } catch (e) {
        print('Long vibration failed: $e');
      }

      // Wait briefly
      await Future.delayed(Duration(milliseconds: 300));

      // Second vibration - pattern
      try {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 500],
          intensities: [0, 255, 0, 255, 0, 255],
        );
        print('Pattern vibration triggered');
      } catch (e) {
        print('Pattern vibration failed: $e');
        // Fallback to simple vibration
        try {
          await Vibration.vibrate(duration: 1000);
          print('Fallback vibration successful');
        } catch (fallbackError) {
          print('All vibration methods failed: $fallbackError');
        }
      }
    } catch (e) {
      print('Vibration setup failed: $e');
    }
  }

  // Test API connectivity
  static Future<bool> testAPIConnection() async {
    try {
      print('Testing API connection...');

      final response = await http
          .get(
            Uri.parse('$API_URL/$MODEL_ID?api_key=$API_KEY'),
          )
          .timeout(Duration(seconds: 10));

      print('API Test Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 400) {
        // 400 is expected for GET request without image data
        print('API connection successful');
        return true;
      } else {
        print('API connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('API connection error: $e');
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

    print('Parsing API response...');

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      print('Found ${totalPredictions} predictions');

      for (var pred in predictions) {
        try {
          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          // Check if this detection indicates drowsiness
          if (box.isDrowsy) {
            isDrowsy = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
            }
            print(
                'DROWSINESS INDICATOR: ${box.className} at ${(box.confidence * 100).toInt()}%');
          }
        } catch (e) {
          print('Error parsing detection box: $e');
        }
      }
    } else {
      print('No predictions found in response');
    }

    final result = DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
      detectionBoxes: detectionBoxes,
    );

    print(
        'Final result: ${result.isDrowsy ? "DROWSY DETECTED" : "ALERT STATE"} with ${result.detectionBoxes.length} detection boxes');

    return result;
  }
}
