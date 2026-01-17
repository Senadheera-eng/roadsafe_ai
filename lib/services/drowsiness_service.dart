import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
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
  final bool isYawn;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.className,
    required this.confidence,
    required this.isDrowsy,
    required this.isYawn,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    final className = (json['class'] ?? '').toString().toLowerCase();
    final confidence = (json['confidence'] ?? 0.0).toDouble();

    // Extract bounding box coordinates
    final x = (json['x'] ?? 0.0).toDouble();
    final y = (json['y'] ?? 0.0).toDouble();
    final width = (json['width'] ?? 0.0).toDouble();
    final height = (json['height'] ?? 0.0).toDouble();

    bool isDrowsy = false;
    bool isYawn = false;

    // Minimum confidence threshold
    if (confidence > 0.25) {
      // Closed eyes indicators (HIGH PRIORITY for drowsiness)
      if (className.contains('closed') ||
          className.contains('close') ||
          className.contains('clos')) {
        isDrowsy = true;
      }

      // Drowsiness/sleepiness indicators
      if (className.contains('drowsy') ||
          className.contains('sleepy') ||
          className.contains('tired')) {
        isDrowsy = true;
      }

      // Yawning indicator
      if (className.contains('yawn')) {
        isYawn = true;
        isDrowsy = true; // Yawning also indicates drowsiness
      }
    }

    return DetectionBox(
      x: x,
      y: y,
      width: width,
      height: height,
      className: className,
      confidence: confidence,
      isDrowsy: isDrowsy,
      isYawn: isYawn,
    );
  }

  // Convert normalized coordinates to pixel coordinates
  Rect toRect(Size imageSize) {
    // Roboflow returns center coordinates, convert to top-left
    final left = (x - width / 2) * imageSize.width;
    final top = (y - height / 2) * imageSize.height;
    final right = (x + width / 2) * imageSize.width;
    final bottom = (y + height / 2) * imageSize.height;

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class DrowsinessDetector {
  static const String API_KEY = "kU0QoAFfW5QbD4uwb3p1";
  static const String API_URL = "https://detect.roboflow.com";
  static const String MODEL_ID = "drowsiness-driver/1";

  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      print('\n🔍 Analyzing frame (${imageBytes.length} bytes)...');

      // Convert to base64
      String base64Image = base64Encode(imageBytes);

      // Make API request with adjusted confidence threshold
      final response = await http
          .post(
            Uri.parse(
                '$API_URL/$MODEL_ID?api_key=$API_KEY&confidence=0.20&overlap=0.3'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'RoadSafeAI/1.0',
            },
            body: base64Image,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = DrowsinessResult.fromJson(data);

        // Log detection for debugging
        if (result.detectionBoxes.isNotEmpty) {
          print('📊 Detections: ${result.detectionBoxes.length}');
          for (var box in result.detectionBoxes) {
            String status = '';
            if (box.isDrowsy) status += ' [DROWSY]';
            if (box.isYawn) status += ' [YAWN]';
            print(
                '  • ${box.className}: ${(box.confidence * 100).toStringAsFixed(1)}%$status');
          }
          print(
              '  👁️ Eye Opening: ${result.eyeOpenPercentage.toStringAsFixed(1)}%');
        } else {
          print('⚠️ No detections found');
        }

        return result;
      } else {
        print('❌ API Error: ${response.statusCode}');
        print('   Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Detection error: $e');
      return null;
    }
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('');
    print('========================================');
    print('🚨 DROWSINESS ALERT TRIGGERED!');
    print('========================================');

    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      print('📱 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        print('📳 Starting STRONG vibration patterns...');

        // PATTERN 1: Long intense vibration (2.5 seconds)
        try {
          print('  → Pattern 1: Long intense burst');
          await Vibration.vibrate(duration: 2500, amplitude: 255);
          await Future.delayed(const Duration(milliseconds: 200));
          print('  ✓ Pattern 1 completed');
        } catch (e) {
          print('  ✗ Pattern 1 failed: $e');
        }

        // PATTERN 2: Rapid triple pulse (URGENT)
        try {
          print('  → Pattern 2: Triple pulse');
          await Vibration.vibrate(
            pattern: [0, 400, 100, 400, 100, 400],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          await Future.delayed(const Duration(milliseconds: 200));
          print('  ✓ Pattern 2 completed');
        } catch (e) {
          print('  ✗ Pattern 2 failed: $e');
        }

        // PATTERN 3: SOS pattern (. . . - - - . . .)
        try {
          print('  → Pattern 3: SOS emergency pattern');
          await Vibration.vibrate(
            pattern: [
              0, 200, 100, 200, 100, 200, // . . .
              200, // pause
              500, 100, 500, 100, 500, // - - -
              200, // pause
              200, 100, 200, 100, 200 // . . .
            ],
            intensities: [
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              0,
              255,
              0,
              255,
              0,
              255
            ],
          );
          print('  ✓ Pattern 3 (SOS) completed');
        } catch (e) {
          print('  ✗ Pattern 3 failed: $e');
        }

        // PATTERN 4: Final warning burst
        try {
          print('  → Pattern 4: Final warning');
          await Vibration.vibrate(duration: 1500, amplitude: 255);
          print('  ✓ Pattern 4 completed');
        } catch (e) {
          print('  ✗ Pattern 4 failed: $e');
        }

        print('✅ ALL VIBRATION PATTERNS COMPLETED');
      } else {
        print('⚠️ No vibrator detected, trying fallback...');

        // Fallback: Basic vibration
        try {
          await Vibration.vibrate(duration: 2000);
          await Future.delayed(const Duration(milliseconds: 300));
          await Vibration.vibrate(duration: 2000);
          print('✓ Fallback vibration completed');
        } catch (e) {
          print('✗ Fallback failed: $e');
        }
      }
    } catch (e) {
      print('❌ CRITICAL: Vibration error: $e');
    }

    print('========================================');
    print('');
  }

  static Future<void> testVibration() async {
    print('🧪 Testing vibration manually...');
    await triggerDrowsinessAlert();
  }
}

class DrowsinessResult {
  final bool isDrowsy;
  final bool hasYawn;
  final double confidence;
  final int totalPredictions;
  final List<DetectionBox> detectionBoxes;
  final double eyeOpenPercentage;

  DrowsinessResult({
    required this.isDrowsy,
    required this.hasYawn,
    required this.confidence,
    required this.totalPredictions,
    required this.detectionBoxes,
    required this.eyeOpenPercentage,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    bool hasYawn = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;
    List<DetectionBox> detectionBoxes = [];

    // Calculate eye states
    double totalOpenConfidence = 0.0;
    double totalClosedConfidence = 0.0;
    int openCount = 0;
    int closedCount = 0;
    int yawnCount = 0;

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      for (var pred in predictions) {
        try {
          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          final className = box.className.toLowerCase();

          // Count eye states
          if (className.contains('open') ||
              className.contains('ope') ||
              className.contains('opene')) {
            totalOpenConfidence += box.confidence;
            openCount++;
          } else if (className.contains('clos') ||
              className.contains('closed')) {
            totalClosedConfidence += box.confidence;
            closedCount++;
          }

          // Count yawns
          if (box.isYawn) {
            yawnCount++;
            hasYawn = true;
          }

          // Track drowsiness
          if (box.isDrowsy) {
            isDrowsy = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
            }
          }
        } catch (e) {
          print('⚠️ Error parsing detection: $e');
        }
      }

      if (isDrowsy) {
        print('⚠️ DROWSINESS DETECTED:');
        print('   - Open eyes: $openCount');
        print('   - Closed eyes: $closedCount');
        print('   - Yawns: $yawnCount');
      }
    }

    // Calculate eye opening percentage
    double eyeOpenPercentage = 100.0;

    if (openCount > 0 || closedCount > 0) {
      double avgOpen = openCount > 0 ? (totalOpenConfidence / openCount) : 0.0;
      double avgClosed =
          closedCount > 0 ? (totalClosedConfidence / closedCount) : 0.0;

      if (avgOpen + avgClosed > 0) {
        eyeOpenPercentage = (avgOpen / (avgOpen + avgClosed)) * 100;
      } else if (openCount > 0) {
        eyeOpenPercentage = 100.0;
      } else if (closedCount > 0) {
        eyeOpenPercentage = 0.0;
      }

      // Clamp between 0-100
      eyeOpenPercentage = eyeOpenPercentage.clamp(0.0, 100.0);
    } else if (closedCount > 0) {
      eyeOpenPercentage = 0.0;
    }

    return DrowsinessResult(
      isDrowsy: isDrowsy,
      hasYawn: hasYawn,
      confidence: maxConfidence,
      totalPredictions: totalPredictions,
      detectionBoxes: detectionBoxes,
      eyeOpenPercentage: eyeOpenPercentage,
    );
  }
}
