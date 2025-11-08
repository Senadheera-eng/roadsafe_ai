import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Data Models ---

class DrivingSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int totalAlerts;
  final double safetyScore;
  final List<AlertEvent> alerts;

  DrivingSession({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalAlerts,
    required this.safetyScore,
    this.alerts = const [],
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'startTime': startTime,
        'endTime': endTime,
        'durationMs': duration.inMilliseconds,
        'totalAlerts': totalAlerts,
        'safetyScore': safetyScore,
        'alerts': alerts.map((a) => a.toJson()).toList(),
      };

  factory DrivingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final alertsData = data?['alerts'] as List<dynamic>? ?? [];

    return DrivingSession(
      id: doc.id,
      userId: data?['userId'] ?? 'unknown',
      startTime: (data?['startTime'] as Timestamp).toDate(),
      endTime: (data?['endTime'] as Timestamp).toDate(),
      duration: Duration(milliseconds: data?['durationMs'] ?? 0),
      totalAlerts: data?['totalAlerts'] ?? 0,
      safetyScore: (data?['safetyScore'] ?? 0.0).toDouble(),
      alerts: alertsData.map((a) => AlertEvent.fromJson(a)).toList(),
    );
  }
}

class AlertEvent {
  final DateTime time;
  final String type; // e.g., 'Eyes Closed', 'Yawn Detected', 'Head Nod'

  AlertEvent({
    required this.time,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'type': type,
      };

  factory AlertEvent.fromJson(Map<String, dynamic> json) => AlertEvent(
        time: (json['time'] as Timestamp).toDate(),
        type: json['type'] ?? 'Unknown',
      );
}

class SleepLog {
  final String id;
  final String userId;
  final DateTime wakeTime;
  final DateTime sleepTime;
  final Duration duration;

  SleepLog({
    required this.id,
    required this.userId,
    required this.wakeTime,
    required this.sleepTime,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'wakeTime': wakeTime,
        'sleepTime': sleepTime,
        'durationMinutes': duration.inMinutes,
      };

  factory SleepLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return SleepLog(
      id: doc.id,
      userId: data?['userId'] ?? 'unknown',
      wakeTime: (data?['wakeTime'] as Timestamp).toDate(),
      sleepTime: (data?['sleepTime'] as Timestamp).toDate(),
      duration: Duration(minutes: data?['durationMinutes'] ?? 0),
    );
  }
}

// --- Service Implementation ---

class DataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  User? get currentUser => _auth.currentUser;

  String get _sessionsCollection =>
      'users/${currentUser?.uid}/driving_sessions';
  String get _sleepLogsCollection => 'users/${currentUser?.uid}/sleep_logs';

  // --- DRIVING SESSIONS ---

  Future<void> addSession(DrivingSession session) async {
    if (currentUser == null) return;
    try {
      await _db.collection(_sessionsCollection).add(session.toJson());
    } catch (e) {
      print('Error adding driving session: $e');
    }
  }

  Stream<List<DrivingSession>> getSessions() {
    if (currentUser == null) return Stream.value([]);
    return _db
        .collection(_sessionsCollection)
        .orderBy('startTime', descending: true)
        .limit(10) // Limit to 10 latest sessions for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrivingSession.fromFirestore(doc))
            .toList());
  }

  // --- SLEEP LOGS ---

  Future<void> addSleepLog(SleepLog log) async {
    if (currentUser == null) return;
    try {
      await _db.collection(_sleepLogsCollection).add(log.toJson());
    } catch (e) {
      print('Error adding sleep log: $e');
    }
  }

  Stream<List<SleepLog>> getSleepLogs() {
    if (currentUser == null) return Stream.value([]);
    return _db
        .collection(_sleepLogsCollection)
        .orderBy('sleepTime', descending: true)
        .limit(7) // Last 7 nights
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SleepLog.fromFirestore(doc)).toList());
  }

  // --- REAL-TIME STATS (For HomePage Quick Stats) ---

  Stream<DrivingSession?> getLastSession() {
    if (currentUser == null) return Stream.value(null);
    return _db
        .collection(_sessionsCollection)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return DrivingSession.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  // This is a placeholder/mock function. Actual scoring is complex.
  Future<double> calculateSafetyScore(List<DrivingSession> sessions) async {
    if (sessions.isEmpty) return 100.0;

    // Average alerts per hour * 10
    double totalAlerts = sessions.fold(0, (sum, s) => sum + s.totalAlerts);
    double totalHours =
        sessions.fold(0.0, (sum, s) => sum + s.duration.inMinutes / 60.0);

    if (totalHours == 0) return 100.0;

    double riskFactor = (totalAlerts / totalHours) * 10.0;

    // Safety score capped at 100
    double score = 100.0 - (riskFactor * 5.0);

    return score.clamp(0.0, 99.9);
  }
}
