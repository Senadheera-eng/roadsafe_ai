import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'dart:async';

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

    final x = (json['x'] ?? 0.0).toDouble();
    final y = (json['y'] ?? 0.0).toDouble();
    final width = (json['width'] ?? 0.0).toDouble();
    final height = (json['height'] ?? 0.0).toDouble();

    bool isDrowsy = false;
    bool isYawn = false;

    if (confidence > 0.25) {
      if (className.contains('closed') ||
          className.contains('close') ||
          className.contains('clos')) {
        isDrowsy = true;
      }

      if (className.contains('drowsy') ||
          className.contains('sleepy') ||
          className.contains('tired')) {
        isDrowsy = true;
      }

      if (className.contains('yawn')) {
        isYawn = true;
        isDrowsy = true;
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
}

class DrowsinessDetector {
  static const String API_KEY = "kU0QoAFfW5QbD4uwb3p1";
  static const String API_URL = "https://detect.roboflow.com";
  static const String MODEL_ID = "drowsiness-driver/1";

  // Continuous vibration control
  static Timer? _vibrationTimer;
  static bool _isVibrating = false;

  // ✅ NEW: ESP32 alarm control
  static String? _esp32IP;
  static bool _esp32AlarmActive = false;

  // ✅ NEW: Set ESP32 IP address
  static void setESP32IP(String ip) {
    _esp32IP = ip;
    print('🔧 ESP32 IP set to: $ip');
  }

  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      print('\n🔍 Analyzing frame (${imageBytes.length} bytes)...');

      String base64Image = base64Encode(imageBytes);

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

        if (result.detectionBoxes.isNotEmpty) {
          print('🔊 Detections: ${result.detectionBoxes.length}');
          for (var box in result.detectionBoxes) {
            String status = '';
            if (box.isDrowsy) status += ' [DROWSY]';
            if (box.isYawn) status += ' [YAWN]';
            print(
                '  • ${box.className}: ${(box.confidence * 100).toStringAsFixed(1)}%$status');
          }
          print(
              '  👁️ Eye Opening: ${result.eyeOpenPercentage.toStringAsFixed(1)}%');
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

  // Start continuous vibration
  static Future<void> startContinuousVibration() async {
    if (_isVibrating) {
      print('⚠️ Vibration already active');
      return;
    }

    print('');
    print('========================================');
    print('🚨 STARTING CONTINUOUS VIBRATION');
    print('========================================');

    _isVibrating = true;

    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      print('📱 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        _vibrationTimer = Timer.periodic(
          const Duration(milliseconds: 2500),
          (timer) async {
            if (!_isVibrating) {
              timer.cancel();
              return;
            }

            try {
              await Vibration.vibrate(
                pattern: [
                  0,
                  800,
                  100,
                  800,
                  100,
                  800,
                  200,
                  500,
                  100,
                  500,
                  100,
                  500,
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
                ],
              );
              print('📳 Vibration pattern executed');
            } catch (e) {
              print('⚠️ Vibration pattern error: $e');
              try {
                await Vibration.vibrate(duration: 1000, amplitude: 255);
              } catch (e2) {
                print('⚠️ Fallback vibration failed: $e2');
              }
            }
          },
        );

        print('✅ CONTINUOUS VIBRATION STARTED');
      } else {
        print('⚠️ No vibrator detected');
        _isVibrating = false;
      }
    } catch (e) {
      print('❌ CRITICAL: Vibration initialization error: $e');
      _isVibrating = false;
    }

    print('========================================');
    print('');
  }

  // Stop continuous vibration
  static Future<void> stopContinuousVibration() async {
    print('');
    print('========================================');
    print('🛑 STOPPING CONTINUOUS VIBRATION');
    print('========================================');

    _isVibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await Vibration.cancel();
      print('✅ Vibration stopped');
    } catch (e) {
      print('⚠️ Error stopping vibration: $e');
    }

    print('========================================');
    print('');
  }

  // ✅ NEW: Start ESP32 buzzer alarm
  static Future<void> startESP32Alarm() async {
    if (_esp32IP == null) {
      print('⚠️ ESP32 IP not set, cannot trigger alarm');
      return;
    }

    if (_esp32AlarmActive) {
      print('⚠️ ESP32 alarm already active');
      return;
    }

    try {
      print('');
      print('========================================');
      print('🔊 SENDING ALARM TO ESP32');
      print('========================================');
      print('   Target IP: $_esp32IP');

      final response = await http
          .post(
            Uri.parse('http://$_esp32IP/alarm'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'command': 'ALARM_ON'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _esp32AlarmActive = true;
        print('✅ ESP32 ALARM ACTIVATED!');
        print('   Response: ${response.body}');
      } else {
        print('❌ ESP32 alarm failed: ${response.statusCode}');
        print('   Response: ${response.body}');
      }

      print('========================================');
      print('');
    } catch (e) {
      print('❌ ESP32 alarm error: $e');
    }
  }

  // ✅ NEW: Stop ESP32 buzzer alarm
  static Future<void> stopESP32Alarm() async {
    if (_esp32IP == null) {
      print('⚠️ ESP32 IP not set');
      return;
    }

    if (!_esp32AlarmActive) {
      print('⚠️ ESP32 alarm not active');
      return;
    }

    try {
      print('');
      print('========================================');
      print('🔇 STOPPING ESP32 ALARM');
      print('========================================');
      print('   Target IP: $_esp32IP');

      final response = await http
          .post(
            Uri.parse('http://$_esp32IP/alarm'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'command': 'ALARM_OFF'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _esp32AlarmActive = false;
        print('✅ ESP32 ALARM STOPPED!');
        print('   Response: ${response.body}');
      } else {
        print('❌ ESP32 alarm stop failed: ${response.statusCode}');
      }

      print('========================================');
      print('');
    } catch (e) {
      print('❌ ESP32 alarm stop error: $e');
    }
  }

  // ✅ NEW: Trigger BOTH phone vibration AND ESP32 buzzer
  static Future<void> triggerDrowsinessAlert() async {
    print('');
    print('╔════════════════════════════════════════╗');
    print('║   🚨 DROWSINESS ALERT TRIGGERED! 🚨   ║');
    print('╚════════════════════════════════════════╝');

    // Start phone vibration
    await startContinuousVibration();

    // Start ESP32 buzzer
    await startESP32Alarm();

    print('');
  }

  // ✅ NEW: Stop BOTH phone vibration AND ESP32 buzzer
  static Future<void> stopDrowsinessAlert() async {
    print('');
    print('╔════════════════════════════════════════╗');
    print('║   ✅ DROWSINESS ALERT STOPPED          ║');
    print('╚════════════════════════════════════════╝');

    // Stop phone vibration
    await stopContinuousVibration();

    // Stop ESP32 buzzer
    await stopESP32Alarm();

    print('');
  }

  // Check if currently alerting
  static bool get isVibrating => _isVibrating;
  static bool get isESP32AlarmActive => _esp32AlarmActive;
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

          if (box.isYawn) {
            yawnCount++;
            hasYawn = true;
          }

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
    );
  }
}
