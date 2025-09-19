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

  static Future<void> triggerDrowsinessAlert() async {
    print('DROWSINESS DETECTED - Vibrating phone');

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
          pattern: [0, 1000, 300, 1000, 300, 1000],
          intensities: [0, 255, 0, 255, 0, 255]);
    }
  }
}

class DrowsinessResult {
  final bool isDrowsy;
  final double confidence;

  DrowsinessResult({
    required this.isDrowsy,
    required this.confidence,
  });

  factory DrowsinessResult.fromJson(Map<String, dynamic> json) {
    bool isDrowsy = false;
    double maxConfidence = 0.0;

    if (json['predictions'] != null) {
      for (var pred in json['predictions']) {
        final className = (pred['class'] ?? '').toString().toLowerCase();
        final confidence = (pred['confidence'] ?? 0.0).toDouble();

        if ((className.contains('drowsy') ||
                className.contains('closed') ||
                className.contains('sleepy')) &&
            confidence > 0.5) {
          isDrowsy = true;
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
          }
        }
      }
    }

    return DrowsinessResult(
      isDrowsy: isDrowsy,
      confidence: maxConfidence,
    );
  }
}
