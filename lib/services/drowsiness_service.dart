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

    // Enhanced drowsiness detection - check for multiple possible class names
    bool isDrowsy = false;

    if (confidence > 0.2) {
      // Lower threshold to catch more detections
      // Check for various drowsiness indicators the model might return
      if (className.contains('close') || // "closed", "close", "eye_close"
          className.contains('shut') || // "shut", "eye_shut"
          className.contains('drowsy') || // "drowsy"
          className.contains('sleepy') || // "sleepy"
          className.contains('tired') || // "tired"
          className.contains('yawn') || // "yawn", "yawning"
          className.contains('blink') || // "blink", "long_blink"
          className.contains('nod')) {
        // "head_nod", "nodding"
        isDrowsy = true;
        print(
            '✅ Drowsiness detected in DetectionBox: "$className" at ${(confidence * 100).toInt()}%');
      } else if (className.contains('open')) {
        isDrowsy = false; // Open eyes are definitely NOT drowsy
        print(
            '👀 Alert state: Open eyes detected - "$className" at ${(confidence * 100).toInt()}%');
      } else {
        print(
            '❓ Unknown class detected: "$className" at ${(confidence * 100).toInt()}%');
      }
    } else {
      print(
          '📉 Low confidence detection ignored: "$className" at ${(confidence * 100).toInt()}%');
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
      print('Base64 encoded');

      // Make API request with adjusted confidence threshold
      final response = await http
          .post(
            Uri.parse(
                '$API_URL/$MODEL_ID?api_key=$API_KEY&confidence=0.2&overlap=0.3'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'RoadSafeAI/1.0',
            },
            body: base64Image,
          )
          .timeout(Duration(seconds: 10));

      print('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('API call successful');
        final data = json.decode(response.body);
        print('API Response: $data');

        final result = DrowsinessResult.fromJson(data);
        print(
            'Detection Result: ${result.isDrowsy ? "DROWSY" : "ALERT"} (confidence: ${result.confidence.toStringAsFixed(2)}, boxes: ${result.detectionBoxes.length})');

        // Log all detections
        for (var box in result.detectionBoxes) {
          print(
              'Detection: ${box.className} - ${(box.confidence * 100).toInt()}% ${box.isDrowsy ? "DROWSY" : "NORMAL"}');
        }

        return result;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');

        try {
          final errorData = json.decode(response.body);
          print('Error details: $errorData');
        } catch (e) {
          print('Raw error response: ${response.body}');
        }

        return null;
      }
    } catch (e) {
      print('Drowsiness detection error: $e');
      return null;
    }
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('');
    print('========================================');
    print('🚨 DROWSINESS ALERT TRIGGERED!');
    print('========================================');

    try {
      // Check if vibration is available
      bool? hasVibrator = await Vibration.hasVibrator();
      print('📱 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        print('📳 Starting STRONG vibration pattern...');

        // Try pattern 1: Long continuous vibration
        try {
          print(
              '  -> Attempt 1: 2-second continuous vibration at max intensity');
          await Vibration.vibrate(duration: 2000, amplitude: 255);
          await Future.delayed(Duration(milliseconds: 100));
          print('  ✅ Vibration pattern 1 completed');
        } catch (e) {
          print('  ❌ Vibration pattern 1 failed: $e');
        }

        // Try pattern 2: Pulsing pattern
        try {
          print('  -> Attempt 2: Pulsing pattern');
          await Vibration.vibrate(
            pattern: [0, 500, 100, 500, 100, 500, 100, 500],
            intensities: [0, 255, 0, 255, 0, 255, 0, 255],
          );
          await Future.delayed(Duration(milliseconds: 100));
          print('  ✅ Vibration pattern 2 completed');
        } catch (e) {
          print('  ❌ Vibration pattern 2 failed: $e');
        }

        // Try pattern 3: Emergency SOS pattern
        try {
          print('  -> Attempt 3: SOS emergency pattern');
          await Vibration.vibrate(
            pattern: [
              0,
              200,
              100,
              200,
              100,
              200,
              300,
              500,
              100,
              500,
              100,
              500,
              300,
              200,
              100,
              200,
              100,
              200
            ],
            intensities: [
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              255
            ],
          );
          print('  ✅ Vibration pattern 3 (SOS) completed');
        } catch (e) {
          print('  ❌ Vibration pattern 3 failed: $e');
        }

        print('✅ ALL VIBRATION PATTERNS COMPLETED');
      } else {
        print('⚠️ No vibrator hardware detected');

        // Try basic vibration anyway as fallback
        try {
          print('  -> Trying basic fallback vibration...');
          await Vibration.vibrate();
          await Future.delayed(Duration(milliseconds: 1000));
          await Vibration.vibrate();
          print('  ✅ Fallback vibration worked');
        } catch (e) {
          print('  ❌ Even fallback vibration failed: $e');
        }
      }
    } catch (e) {
      print('❌ CRITICAL: Vibration system error: $e');
      print('Stack: ${StackTrace.current}');
    }

    print('========================================');
    print('🔔 ALERT SEQUENCE FINISHED');
    print('========================================');
    print('');
  }

  static Future<void> testVibration() async {
    print('Testing vibration manually...');
    await triggerDrowsinessAlert();
  }

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
  final double eyeOpenPercentage; // NEW: Eye opening percentage

  DrowsinessResult({
    required this.isDrowsy,
    required this.confidence,
    required this.totalPredictions,
    required this.detectionBoxes,
    required this.eyeOpenPercentage,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;
    List<DetectionBox> detectionBoxes = [];

    // NEW: Calculate eye opening percentage
    double totalOpenConfidence = 0.0;
    double totalClosedConfidence = 0.0;
    int openCount = 0;
    int closedCount = 0;

    print('Parsing API response...');

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      print('📊 Found ${totalPredictions} predictions');
      print('📋 Raw predictions: $predictions');

      for (var pred in predictions) {
        try {
          final className = (pred['class'] ?? '').toString().toLowerCase();
          final confidence = (pred['confidence'] ?? 0.0).toDouble();

          print(
              '🎯 Raw Prediction: "$className" (confidence: ${(confidence * 100).toInt()}%)');

          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          // Check for ANY drowsiness indicators with lower threshold
          bool isThisDrowsy = false;

          if (confidence > 0.2) {
            // Lower threshold to catch more
            // Check for various possible drowsiness class names
            if (className.contains('close') || // "closed", "close"
                className.contains('shut') || // "shut"
                className.contains('drowsy') ||
                className.contains('sleepy') ||
                className.contains('tired') ||
                className.contains('yawn') ||
                className.contains('blink') || // long blinks
                className.contains('nod')) {
              // head nodding
              isThisDrowsy = true;
              print(
                  '⚠️ DROWSINESS INDICATOR FOUND: "$className" at ${(confidence * 100).toInt()}%');
            }
          }

          if (isThisDrowsy) {
            isDrowsy = true;
            if (confidence > maxConfidence) {
              maxConfidence = confidence;
            }
          }
        } catch (e) {
          print('Error parsing detection box: $e');
          print('Raw prediction data: $pred');
        }
      }

      // Determine drowsiness: closed eyes detected
      isDrowsy = closedCount > 0 || detectionBoxes.any((box) => box.isDrowsy);

      print('Open eyes: $openCount, Closed eyes: $closedCount');
      print('DROWSINESS STATUS: ${isDrowsy ? "DROWSY" : "ALERT"}');
    } else {
      print('No predictions found in response');
      print('Full response: $json');
    }

    // Calculate eye opening percentage (0-100%)
    double eyeOpenPercentage = 0.0;
    if (openCount > 0 || closedCount > 0) {
      double avgOpen = openCount > 0 ? (totalOpenConfidence / openCount) : 0.0;
      double avgClosed =
          closedCount > 0 ? (totalClosedConfidence / closedCount) : 0.0;

      if (avgOpen + avgClosed > 0) {
        eyeOpenPercentage = (avgOpen / (avgOpen + avgClosed)) * 100;
      } else if (openCount > 0) {
        eyeOpenPercentage = 100.0;
      } else {
        eyeOpenPercentage = 0.0;
      }
    }

    print('Eye Opening Percentage: ${eyeOpenPercentage.toStringAsFixed(1)}%');

    final result = DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
      detectionBoxes: detectionBoxes,
      eyeOpenPercentage: eyeOpenPercentage,
    );

    print(
        '📋 Final result: ${result.isDrowsy ? "🚨 DROWSY" : "✅ ALERT"} with ${result.detectionBoxes.length} detection boxes');
    if (result.isDrowsy) {
      print('🚨 DROWSINESS CONFIRMED - SHOULD VIBRATE NOW!');
    }
    return result;
  }
}
