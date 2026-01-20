import 'package:cloud_firestore/cloud_firestore.dart';

class TripSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final int totalDetections;
  final int alertCount;
  final int yawnCount;
  final double safetyScore;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  TripSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.totalDetections,
    required this.alertCount,
    required this.yawnCount,
    required this.safetyScore,
    required this.isActive,
    this.metadata,
  });

  factory TripSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TripSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      durationMinutes: data['durationMinutes'] ?? 0,
      totalDetections: data['totalDetections'] ?? 0,
      alertCount: data['alertCount'] ?? 0,
      yawnCount: data['yawnCount'] ?? 0,
      safetyScore: (data['safetyScore'] ?? 100.0).toDouble(),
      isActive: data['isActive'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationMinutes': durationMinutes,
      'totalDetections': totalDetections,
      'alertCount': alertCount,
      'yawnCount': yawnCount,
      'safetyScore': safetyScore,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  String get riskLevel {
    if (safetyScore >= 90) return 'Excellent';
    if (safetyScore >= 75) return 'Good';
    if (safetyScore >= 60) return 'Fair';
    if (safetyScore >= 40) return 'Poor';
    return 'Critical';
  }

  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    } else {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(startTime);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }

  double get alertsPerHour {
    if (durationMinutes == 0) return 0;
    return (alertCount / durationMinutes) * 60;
  }
}

class AnalyticsSummary {
  final int totalTrips;
  final int totalDrivingMinutes;
  final int totalAlerts;
  final double averageSafetyScore;
  final int currentStreak; // Days without alerts
  final int longestStreak;
  final Map<String, int> alertsByTimeOfDay;
  final List<TripSession> recentTrips;
  final double weeklyImprovement; // Percentage change

  AnalyticsSummary({
    required this.totalTrips,
    required this.totalDrivingMinutes,
    required this.totalAlerts,
    required this.averageSafetyScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.alertsByTimeOfDay,
    required this.recentTrips,
    required this.weeklyImprovement,
  });

  String get totalDrivingTime {
    if (totalDrivingMinutes < 60) {
      return '$totalDrivingMinutes min';
    } else {
      final hours = totalDrivingMinutes ~/ 60;
      return '${hours}h';
    }
  }

  String get riskLevel {
    if (averageSafetyScore >= 90) return 'Low Risk';
    if (averageSafetyScore >= 75) return 'Moderate Risk';
    return 'High Risk';
  }
}
