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

    // FIXED: Correct drowsiness detection logic
    bool isDrowsy = false;

    // Drowsy indicators with appropriate confidence thresholds
    if (confidence > 0.3) {
      // Only consider confident detections
      if (className.contains('closed') ||
          className.contains('drowsy') ||
          className.contains('sleepy') ||
          className.contains('tired')) {
        isDrowsy = true;
      } else if (className.contains('yawn')) {
        isDrowsy = true; // Yawning is a drowsiness indicator
      }
    }

    // REMOVED THE BUGGY LOGIC - open eyes are NOT drowsy!

    return DetectionBox(
      x: x - (width / 2),
      y: y - (height / 2),
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

  // Track closed eye duration
  static DateTime? _firstClosedEyeDetection;
  static const int CLOSED_EYE_THRESHOLD_SECONDS = 2;

  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      print('🔍 Starting drowsiness analysis...');
      print('📊 Image size: ${imageBytes.length} bytes');

      String base64Image = base64Encode(imageBytes);

      // Lower confidence to catch more detections, but we'll filter in logic
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

      print('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API call successful');
        final data = json.decode(response.body);
        print('📋 API Response: $data');

        final result = DrowsinessResult.fromJson(data);

        // Check closed eye duration
        result.checkClosedEyeDuration();

        print('🎯 Detection Result: ${result.isDrowsy ? "DROWSY" : "ALERT"}');
        print('   - Confidence: ${result.confidence.toStringAsFixed(2)}');
        print('   - Detection boxes: ${result.detectionBoxes.length}');
        print('   - Closed eye duration: ${result.closedEyeDurationSeconds}s');

        for (var box in result.detectionBoxes) {
          print(
              '📦 Detection: ${box.className} - ${(box.confidence * 100).toInt()}% ${box.isDrowsy ? "⚠️ DROWSY" : "✅ NORMAL"}');
        }

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

  static void resetClosedEyeTimer() {
    _firstClosedEyeDetection = null;
    print('🔄 Closed eye timer reset');
  }

  static int getClosedEyeDuration() {
    if (_firstClosedEyeDetection == null) return 0;
    return DateTime.now().difference(_firstClosedEyeDetection!).inSeconds;
  }

  static void updateClosedEyeTimer(bool hasClosedEyes) {
    if (hasClosedEyes) {
      _firstClosedEyeDetection ??= DateTime.now();
      print('👁️ Closed eyes detected for ${getClosedEyeDuration()}s');
    } else {
      if (_firstClosedEyeDetection != null) {
        print('👁️ Eyes opened - resetting timer');
      }
      _firstClosedEyeDetection = null;
    }
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('🚨 DROWSINESS ALERT TRIGGERED');

    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      print('📱 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        // Emergency vibration pattern - longer and more intense
        await Vibration.vibrate(
          pattern: [0, 1000, 300, 1000, 300, 1000],
          intensities: [0, 255, 0, 255, 0, 255],
        );
        print('✅ Emergency vibration triggered');
      } else {
        await Vibration.vibrate(duration: 2000);
        print('✅ Basic vibration triggered');
      }
    } catch (e) {
      print('❌ Vibration failed: $e');
    }
  }

  static Future<bool> testAPIConnection() async {
    try {
      print('🔗 Testing API connection...');
      final response = await http
          .get(Uri.parse('$API_URL/$MODEL_ID?api_key=$API_KEY'))
          .timeout(Duration(seconds: 10));

      print('📡 API Test Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 400) {
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
  int closedEyeDurationSeconds = 0;

  DrowsinessResult({
    required this.isDrowsy,
    required this.confidence,
    required this.totalPredictions,
    required this.detectionBoxes,
  });

  void checkClosedEyeDuration() {
    // Check if any detection shows closed eyes
    bool hasClosedEyes = detectionBoxes.any((box) =>
        (box.className.contains('closed') ||
            box.className.contains('drowsy') ||
            box.className.contains('sleepy')) &&
        box.confidence > 0.3);

    DrowsinessDetector.updateClosedEyeTimer(hasClosedEyes);
    closedEyeDurationSeconds = DrowsinessDetector.getClosedEyeDuration();
  }

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;
    List<DetectionBox> detectionBoxes = [];

    print('📝 Parsing API response...');

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      print('📊 Found ${totalPredictions} predictions');

      // Count detection types
      int openCount = 0;
      int closedCount = 0;
      int yawnCount = 0;
      int drowsyCount = 0;

      for (var pred in predictions) {
        try {
          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          final className = box.className.toLowerCase();

          // Count detection types
          if (className.contains('open')) openCount++;
          if (className.contains('closed')) closedCount++;
          if (className.contains('yawn')) yawnCount++;
          if (className.contains('drowsy') || className.contains('sleepy'))
            drowsyCount++;

          print(
              '🎯 Prediction: ${box.className} (${(box.confidence * 100).toInt()}%) at (${box.x.toInt()}, ${box.y.toInt()})');

          // Check for drowsiness
          if (box.isDrowsy && box.confidence > maxConfidence) {
            maxConfidence = box.confidence;
          }
        } catch (e) {
          print('❌ Error parsing detection box: $e');
        }
      }

      print('📊 Detection Summary:');
      print('   - Open eyes: $openCount');
      print('   - Closed eyes: $closedCount');
      print('   - Yawning: $yawnCount');
      print('   - Drowsy/Sleepy: $drowsyCount');

      // Determine drowsiness based on detections
      bool hasClosedEyes = closedCount > 0 || drowsyCount > 0;
      bool hasYawning = yawnCount > 0;

      // Check closed eye duration
      DrowsinessDetector.updateClosedEyeTimer(hasClosedEyes);
      int closedDuration = DrowsinessDetector.getClosedEyeDuration();

      // Drowsiness logic:
      // 1. Yawning = immediate alert
      // 2. Closed eyes for 2+ seconds = alert
      // 3. Multiple drowsy indicators = alert
      if (hasYawning && maxConfidence > 0.3) {
        isDrowsy = true;
        print('⚠️ YAWNING DETECTED');
      } else if (hasClosedEyes &&
          closedDuration >= DrowsinessDetector.CLOSED_EYE_THRESHOLD_SECONDS) {
        isDrowsy = true;
        print('⚠️ EYES CLOSED FOR ${closedDuration} SECONDS');
      } else if (closedCount >= 2 || drowsyCount >= 1) {
        isDrowsy = true;
        print('⚠️ MULTIPLE DROWSINESS INDICATORS');
      }
    } else {
      print('❌ No predictions found in response');
    }

    final result = DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
      detectionBoxes: detectionBoxes,
    );

    print(
        '📋 Final: ${result.isDrowsy ? "🚨 DROWSY" : "✅ ALERT"} (${result.detectionBoxes.length} boxes)');
    return result;
  }
}
