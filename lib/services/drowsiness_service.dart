import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// ============================================
// CONFIGURATION - STORE API KEY SECURELY
// ============================================
class DrowsinessConfig {
  // TODO: Move this to environment variables or Firebase Remote Config
  // For now, you MUST replace this with your actual API key
  // NEVER commit the real API key to Git!
  static const String API_KEY = "kU0QoAFfW5QbD4uwb3p1"; // ⚠️ REPLACE THIS
  static const String API_URL = "https://detect.roboflow.com";
  static const String MODEL_ID = "drowsiness-driver/1";

  // Detection thresholds
  static const double MIN_CONFIDENCE = 0.40; // Raised from 0.25
  static const int FRAMES_FOR_ALERT =
      3; // Must be drowsy for 3 consecutive frames
  static const double YAWN_CONFIDENCE = 0.35;
  static const double EYE_CLOSED_THRESHOLD = 20.0; // Eye opening < 20% = closed
}

// ============================================
// DETECTION BOX WITH IMPROVED LOGIC
// ============================================
class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final String className;
  final double confidence;
  final bool isDrowsy;
  final bool isYawn;
  final bool isEyeClosed;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.className,
    required this.confidence,
    required this.isDrowsy,
    required this.isYawn,
    required this.isEyeClosed,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    final className = (json['class'] ?? '').toString().toLowerCase().trim();
    final confidence = (json['confidence'] ?? 0.0).toDouble();

    final x = (json['x'] ?? 0.0).toDouble();
    final y = (json['y'] ?? 0.0).toDouble();
    final width = (json['width'] ?? 0.0).toDouble();
    final height = (json['height'] ?? 0.0).toDouble();

    bool isDrowsy = false;
    bool isYawn = false;
    bool isEyeClosed = false;

    // Only process high-confidence detections
    if (confidence >= DrowsinessConfig.MIN_CONFIDENCE) {
      // Exact matching for closed eyes (more precise)
      if (className == 'closed' ||
          className == 'close' ||
          className == 'eye closed') {
        isEyeClosed = true;
        isDrowsy = true;
      }

      // Drowsy states
      if (className == 'drowsy' ||
          className == 'sleepy' ||
          className == 'tired') {
        isDrowsy = true;
      }

      // Yawn detection (higher confidence required)
      if ((className == 'yawn' || className == 'yawning') &&
          confidence >= DrowsinessConfig.YAWN_CONFIDENCE) {
        isYawn = true;
        isDrowsy = true; // Yawning is also a drowsiness indicator
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
      isEyeClosed: isEyeClosed,
    );
  }

  @override
  String toString() {
    String flags = '';
    if (isDrowsy) flags += ' [DROWSY]';
    if (isYawn) flags += ' [YAWN]';
    if (isEyeClosed) flags += ' [EYES_CLOSED]';
    return '$className (${(confidence * 100).toStringAsFixed(1)}%)$flags';
  }
}

// ============================================
// TEMPORAL TRACKER FOR REDUCING FALSE POSITIVES
// ============================================
class DrowsinessTracker {
  static final Queue<bool> _drowsyHistory = Queue();
  static final Queue<bool> _yawnHistory = Queue();
  static final Queue<double> _eyeOpenHistory = Queue();
  static DateTime? _lastAlertTime;
  static int _consecutiveDrowsyFrames = 0;
  static int _totalDetections = 0;
  static int _drowsyDetections = 0;

  static const int HISTORY_SIZE = 5;
  static const Duration MIN_ALERT_INTERVAL = Duration(seconds: 3);

  static void addDetection(DrowsinessResult result) {
    _totalDetections++;

    // Track drowsiness
    _drowsyHistory.add(result.isDrowsy);
    if (_drowsyHistory.length > HISTORY_SIZE) {
      _drowsyHistory.removeFirst();
    }

    // Track yawns
    _yawnHistory.add(result.hasYawn);
    if (_yawnHistory.length > HISTORY_SIZE) {
      _yawnHistory.removeFirst();
    }

    // Track eye opening
    _eyeOpenHistory.add(result.eyeOpenPercentage);
    if (_eyeOpenHistory.length > HISTORY_SIZE) {
      _eyeOpenHistory.removeFirst();
    }

    // Update consecutive counter
    if (result.isDrowsy) {
      _consecutiveDrowsyFrames++;
      _drowsyDetections++;
    } else {
      _consecutiveDrowsyFrames = 0;
    }
  }

  static bool shouldTriggerAlert() {
    // Don't alert too frequently
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < MIN_ALERT_INTERVAL) {
      return false;
    }

    // Method 1: Consecutive drowsy frames
    if (_consecutiveDrowsyFrames >= DrowsinessConfig.FRAMES_FOR_ALERT) {
      _lastAlertTime = DateTime.now();
      return true;
    }

    // Method 2: Majority drowsy in recent history
    if (_drowsyHistory.length >= 3) {
      int drowsyCount = _drowsyHistory.where((d) => d).length;
      if (drowsyCount >= 3) {
        _lastAlertTime = DateTime.now();
        return true;
      }
    }

    // Method 3: Eyes consistently closed
    if (_eyeOpenHistory.length >= 3) {
      double avgEyeOpen =
          _eyeOpenHistory.reduce((a, b) => a + b) / _eyeOpenHistory.length;
      if (avgEyeOpen < DrowsinessConfig.EYE_CLOSED_THRESHOLD) {
        _lastAlertTime = DateTime.now();
        return true;
      }
    }

    // Method 4: Multiple yawns
    if (_yawnHistory.length >= 3) {
      int yawnCount = _yawnHistory.where((y) => y).length;
      if (yawnCount >= 2) {
        _lastAlertTime = DateTime.now();
        return true;
      }
    }

    return false;
  }

  static AlertLevel getAlertLevel() {
    if (_consecutiveDrowsyFrames >= 6) {
      return AlertLevel.critical;
    } else if (_consecutiveDrowsyFrames >= 4) {
      return AlertLevel.warning;
    } else {
      return AlertLevel.mild;
    }
  }

  static double getDrowsinessPercentage() {
    if (_totalDetections == 0) return 0.0;
    return (_drowsyDetections / _totalDetections) * 100;
  }

  static void reset() {
    _drowsyHistory.clear();
    _yawnHistory.clear();
    _eyeOpenHistory.clear();
    _consecutiveDrowsyFrames = 0;
    _totalDetections = 0;
    _drowsyDetections = 0;
  }

  static Map<String, dynamic> getStats() {
    return {
      'totalDetections': _totalDetections,
      'drowsyDetections': _drowsyDetections,
      'consecutiveDrowsy': _consecutiveDrowsyFrames,
      'drowsinessPercentage': getDrowsinessPercentage(),
    };
  }
}

enum AlertLevel { mild, warning, critical }

// ============================================
// IMPROVED VIBRATION SYSTEM
// ============================================
class VibrationManager {
  static bool _isVibrating = false;
  static Timer? _vibrationTimer;

  static Future<void> triggerAlert(AlertLevel level) async {
    // Prevent overlapping vibrations
    if (_isVibrating) {
      if (kDebugMode) print('⚠️ Vibration already active, skipping');
      return;
    }

    _isVibrating = true;

    try {
      bool? hasVibrator = await Vibration.hasVibrator();

      if (hasVibrator != true) {
        if (kDebugMode) print('⚠️ Device has no vibrator');
        _isVibrating = false;
        return;
      }

      if (kDebugMode) {
        print('');
        print('========================================');
        print('🚨 DROWSINESS ALERT: ${level.name.toUpperCase()}');
        print('========================================');
      }

      switch (level) {
        case AlertLevel.mild:
          await _mildVibration();
          break;
        case AlertLevel.warning:
          await _warningVibration();
          break;
        case AlertLevel.critical:
          await _criticalVibration();
          break;
      }

      if (kDebugMode) {
        print('✅ Alert completed');
        print('========================================\n');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Vibration error: $e');
    } finally {
      // Ensure flag is reset
      await Future.delayed(const Duration(milliseconds: 100));
      _isVibrating = false;
    }
  }

  static Future<void> _mildVibration() async {
    // Single short vibration (500ms)
    await Vibration.vibrate(duration: 500, amplitude: 128);
    if (kDebugMode) print('📳 Mild alert (500ms)');
  }

  static Future<void> _warningVibration() async {
    // Double pulse (2x 400ms with 200ms gap)
    await Vibration.vibrate(
      pattern: [0, 400, 200, 400],
      intensities: [0, 200, 0, 200],
    );
    if (kDebugMode) print('📳 Warning alert (double pulse)');
  }

  static Future<void> _criticalVibration() async {
    // Aggressive pattern: Long + 3 short pulses
    await Vibration.vibrate(
      pattern: [
        0, 800, // Long pulse
        200, // Gap
        200, 100, // Short pulse 1
        200, 100, // Short pulse 2
        200, 100, // Short pulse 3
      ],
      intensities: [
        0, 255, // Long at max
        0,
        255, 0, // Short pulses at max
        255, 0,
        255, 0,
      ],
    );
    if (kDebugMode) print('📳 CRITICAL alert (long + triple pulse)');
  }

  static Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
      _isVibrating = false;
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      if (kDebugMode) print('🛑 Vibration cancelled');
    } catch (e) {
      if (kDebugMode) print('⚠️ Error cancelling vibration: $e');
    }
  }

  static bool get isVibrating => _isVibrating;
}

// ============================================
// MAIN DROWSINESS DETECTOR
// ============================================
class DrowsinessDetector {
  static int _apiCallCount = 0;
  static int _consecutiveErrors = 0;
  static const int MAX_ERRORS_BEFORE_ALERT = 3;

  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      if (kDebugMode) {
        print(
            '\n🔍 Analyzing frame #${++_apiCallCount} (${imageBytes.length} bytes)...');
      }

      // Validate API key
      if (DrowsinessConfig.API_KEY == "YOUR_ROBOFLOW_API_KEY_HERE") {
        throw Exception(
            '⚠️ ROBOFLOW API KEY NOT SET! Update DrowsinessConfig.API_KEY');
      }

      String base64Image = base64Encode(imageBytes);

      final response = await http
          .post(
            Uri.parse('${DrowsinessConfig.API_URL}/${DrowsinessConfig.MODEL_ID}'
                '?api_key=${DrowsinessConfig.API_KEY}'
                '&confidence=${DrowsinessConfig.MIN_CONFIDENCE}'
                '&overlap=0.3'),
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

        _consecutiveErrors = 0; // Reset error counter on success

        if (kDebugMode && result.detectionBoxes.isNotEmpty) {
          print('📊 Detections: ${result.detectionBoxes.length}');
          for (var box in result.detectionBoxes) {
            print('  • $box');
          }
          print(
              '  👁️ Eye Opening: ${result.eyeOpenPercentage.toStringAsFixed(1)}%');

          if (result.isDrowsy) {
            print('  ⚠️ DROWSINESS DETECTED');
          }
        }

        // Add to temporal tracker
        DrowsinessTracker.addDetection(result);

        return result;
      } else if (response.statusCode == 429) {
        print('⚠️ API rate limit exceeded (429)');
        _consecutiveErrors++;
        return null;
      } else {
        print('❌ API Error: ${response.statusCode}');
        if (kDebugMode) print('   Response: ${response.body}');
        _consecutiveErrors++;
        return null;
      }
    } catch (e) {
      _consecutiveErrors++;
      print('❌ Detection error #$_consecutiveErrors: $e');

      if (_consecutiveErrors >= MAX_ERRORS_BEFORE_ALERT) {
        print(
            '🚨 Too many consecutive errors! Detection system may be failing.');
        // Could notify user here
      }

      return null;
    }
  }

  static Future<void> triggerAlertIfNeeded() async {
    if (DrowsinessTracker.shouldTriggerAlert()) {
      final level = DrowsinessTracker.getAlertLevel();
      await VibrationManager.triggerAlert(level);
    }
  }

  static void resetSession() {
    DrowsinessTracker.reset();
    _apiCallCount = 0;
    _consecutiveErrors = 0;
    VibrationManager.cancelVibration();
    if (kDebugMode) print('🔄 Detection session reset');
  }

  static Map<String, dynamic> getSessionStats() {
    return {
      'apiCalls': _apiCallCount,
      'consecutiveErrors': _consecutiveErrors,
      ...DrowsinessTracker.getStats(),
    };
  }
}

// ============================================
// DROWSINESS RESULT
// ============================================
class DrowsinessResult {
  final bool isDrowsy;
  final bool hasYawn;
  final double confidence;
  final int totalPredictions;
  final List<DetectionBox> detectionBoxes;
  final double eyeOpenPercentage;
  final int eyesClosedCount;
  final int eyesOpenCount;

  DrowsinessResult({
    required this.isDrowsy,
    required this.hasYawn,
    required this.confidence,
    required this.totalPredictions,
    required this.detectionBoxes,
    required this.eyeOpenPercentage,
    required this.eyesClosedCount,
    required this.eyesOpenCount,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    bool hasYawn = false;
    double maxConfidence = 0.0;
    int totalPredictions = 0;
    List<DetectionBox> detectionBoxes = [];

    double totalOpenConfidence = 0.0;
    double totalClosedConfidence = 0.0;
    int openCount = 0;
    int closedCount = 0;

    if (json['predictions'] != null) {
      final predictions = json['predictions'] as List;
      totalPredictions = predictions.length;

      for (var pred in predictions) {
        try {
          final box = DetectionBox.fromJson(pred);
          detectionBoxes.add(box);

          final className = box.className.toLowerCase();

          // Count open eyes
          if (className.contains('open') ||
              className == 'ope' ||
              className == 'opene') {
            totalOpenConfidence += box.confidence;
            openCount++;
          }

          // Count closed eyes
          if (className.contains('clos') ||
              className == 'closed' ||
              className == 'close') {
            totalClosedConfidence += box.confidence;
            closedCount++;
          }

          // Track yawns
          if (box.isYawn) {
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
          if (kDebugMode) print('⚠️ Error parsing detection: $e');
        }
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
      eyesClosedCount: closedCount,
      eyesOpenCount: openCount,
    );
  }

  @override
  String toString() {
    return 'DrowsinessResult(drowsy: $isDrowsy, yawn: $hasYawn, '
        'eyeOpen: ${eyeOpenPercentage.toStringAsFixed(1)}%, '
        'detections: $totalPredictions)';
  }
}
