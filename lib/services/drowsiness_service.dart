import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DrowsinessDetector {
  static const String API_KEY = "kU0QoAFfW5QbD4uwb3p1";
  static const String API_URL = "https://detect.roboflow.com";
  static const String MODEL_ID = "drowsiness-driver/1";

  static bool _isInitialized = true;

  static Future<bool> initialize() async {
    print('Using Roboflow Hosted API for drowsiness detection');
    print('API URL: $API_URL');
    print('Model: $MODEL_ID');
    return true;
  }

  // Analyze image for drowsiness
  static Future<DrowsinessResult?> analyzeImage(Uint8List imageBytes) async {
    try {
      // Convert image to base64
      String base64Image = base64Encode(imageBytes);

      final response = await http
          .post(
            Uri.parse('$API_URL/$MODEL_ID?api_key=$API_KEY'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: base64Image,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DrowsinessResult.fromJson(data);
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Drowsiness detection error: $e');
      return null;
    }
  }
}

class DrowsinessResult {
  final List<Detection> predictions;
  final bool isDrowsy;
  final double confidence;

  DrowsinessResult({
    required this.predictions,
    required this.isDrowsy,
    required this.confidence,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    List<Detection> predictions = [];
    bool isDrowsy = false;
    double maxConfidence = 0.0;

    if (json['predictions'] != null) {
      for (var pred in json['predictions']) {
        final detection = Detection.fromJson(pred);
        predictions.add(detection);

        // Check for drowsiness indicators
        if ((detection.className.toLowerCase().contains('drowsy') ||
                detection.className.toLowerCase().contains('closed') ||
                detection.className.toLowerCase().contains('sleepy')) &&
            detection.confidence > 0.5) {
          isDrowsy = true;
          if (detection.confidence > maxConfidence) {
            maxConfidence = detection.confidence;
          }
        }
      }
    }

    return DrowsinessResult(
      predictions: predictions,
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
    );
  }
}

class Detection {
  final String className;
  final double confidence;
  final double x, y, width, height;

  Detection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      className: json['class'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
    );
  }
}

class AlertService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  static Future<void> triggerDrowsinessAlert() async {
    print('🚨 DROWSINESS DETECTED - Triggering alerts');

    // Vibrate phone
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500, 1000],
          intensities: [0, 255, 0, 255, 0, 255]);
    }

    // Play alert sound
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      // If custom sound fails, use system notification sound
      print('Custom sound failed, using system notification');
    }

    // Show notification
    const androidDetails = AndroidNotificationDetails(
      'drowsiness_alerts',
      'Drowsiness Alerts',
      channelDescription: 'Alerts when driver drowsiness is detected',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '🚨 WAKE UP!',
      'Drowsiness detected while driving. Please take a break.',
      details,
    );
  }

  static Future<void> stopAlerts() async {
    await _audioPlayer.stop();
    await Vibration.cancel();
  }
}
