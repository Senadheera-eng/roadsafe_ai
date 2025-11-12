import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================
// DATA MODELS
// ============================================

class AlertEvent {
  final String id;
  final DateTime time;
  final String type; // 'Eyes Closed', 'Yawn Detected', 'Head Nodding'
  final double? confidence;
  final String? details;

  AlertEvent({
    String? id,
    required this.time,
    required this.type,
    this.confidence,
    this.details,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': Timestamp.fromDate(time),
        'type': type,
        'confidence': confidence,
        'details': details,
      };

  factory AlertEvent.fromJson(Map<String, dynamic> json) => AlertEvent(
        id: json['id'],
        time: (json['time'] as Timestamp).toDate(),
        type: json['type'],
        confidence: json['confidence']?.toDouble(),
        details: json['details'],
      );
}

class DrivingSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final int totalAlerts;
  final double safetyScore; // 0-100
  final List<AlertEvent> alerts;
  final String? startLocation;
  final String? endLocation;
  final double? distanceKm;
  final bool isActive;

  DrivingSession({
    String? id,
    required this.userId,
    required this.startTime,
    this.endTime,
    Duration? duration,
    this.totalAlerts = 0,
    this.safetyScore = 100.0,
    this.alerts = const [],
    this.startLocation,
    this.endLocation,
    this.distanceKm,
    this.isActive = false,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        duration =
            duration ?? (endTime?.difference(startTime) ?? Duration.zero);

  // Calculate safety score based on alerts and duration
  double calculateSafetyScore() {
    if (duration.inMinutes == 0) return 100.0;

    // Base score
    double score = 100.0;

    // Deduct points for each alert type
    int eyesClosedCount = alerts.where((a) => a.type.contains('Closed')).length;
    int yawnCount = alerts.where((a) => a.type.contains('Yawn')).length;
    int noddingCount = alerts.where((a) => a.type.contains('Nodding')).length;

    // Severe penalty for eyes closed
    score -= eyesClosedCount * 15.0;

    // Medium penalty for yawning
    score -= yawnCount * 8.0;

    // Light penalty for head nodding
    score -= noddingCount * 5.0;

    // Additional penalty if alerts are frequent (more than 1 per 30 minutes)
    double alertsPerHour = (totalAlerts / duration.inMinutes) * 60;
    if (alertsPerHour > 2) {
      score -= (alertsPerHour - 2) * 5;
    }

    return score.clamp(0.0, 100.0);
  }

  String get riskLevel {
    if (safetyScore >= 90) return 'Excellent';
    if (safetyScore >= 75) return 'Good';
    if (safetyScore >= 60) return 'Fair';
    if (safetyScore >= 40) return 'Poor';
    return 'Critical';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'duration': duration.inSeconds,
        'totalAlerts': totalAlerts,
        'safetyScore': safetyScore,
        'alerts': alerts.map((a) => a.toJson()).toList(),
        'startLocation': startLocation,
        'endLocation': endLocation,
        'distanceKm': distanceKm,
        'isActive': isActive,
      };

  factory DrivingSession.fromJson(Map<String, dynamic> json) {
    final startTime = (json['startTime'] as Timestamp).toDate();
    final endTime = json['endTime'] != null
        ? (json['endTime'] as Timestamp).toDate()
        : null;

    return DrivingSession(
      id: json['id'],
      userId: json['userId'],
      startTime: startTime,
      endTime: endTime,
      duration: Duration(seconds: json['duration'] ?? 0),
      totalAlerts: json['totalAlerts'] ?? 0,
      safetyScore: (json['safetyScore'] ?? 100.0).toDouble(),
      alerts: (json['alerts'] as List?)
              ?.map((a) => AlertEvent.fromJson(a))
              .toList() ??
          [],
      startLocation: json['startLocation'],
      endLocation: json['endLocation'],
      distanceKm: json['distanceKm']?.toDouble(),
      isActive: json['isActive'] ?? false,
    );
  }

  DrivingSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int? totalAlerts,
    double? safetyScore,
    List<AlertEvent>? alerts,
    String? startLocation,
    String? endLocation,
    double? distanceKm,
    bool? isActive,
  }) {
    return DrivingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      totalAlerts: totalAlerts ?? this.totalAlerts,
      safetyScore: safetyScore ?? this.safetyScore,
      alerts: alerts ?? this.alerts,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      isActive: isActive ?? this.isActive,
    );
  }
}

class SleepLog {
  final String id;
  final String userId;
  final DateTime sleepTime;
  final DateTime wakeTime;
  final Duration duration;
  final int quality; // 1-5 rating

  SleepLog({
    String? id,
    required this.userId,
    required this.sleepTime,
    required this.wakeTime,
    Duration? duration,
    this.quality = 3,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        duration = duration ?? wakeTime.difference(sleepTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'sleepTime': Timestamp.fromDate(sleepTime),
        'wakeTime': Timestamp.fromDate(wakeTime),
        'duration': duration.inSeconds,
        'quality': quality,
      };

  factory SleepLog.fromJson(Map<String, dynamic> json) => SleepLog(
        id: json['id'],
        userId: json['userId'],
        sleepTime: (json['sleepTime'] as Timestamp).toDate(),
        wakeTime: (json['wakeTime'] as Timestamp).toDate(),
        duration: Duration(seconds: json['duration'] ?? 0),
        quality: json['quality'] ?? 3,
      );
}

// ============================================
// DATA SERVICE
// ============================================

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Active session management
  DrivingSession? _activeSession;
  Timer? _sessionTimer;
  final StreamController<DrivingSession?> _activeSessionController =
      StreamController<DrivingSession?>.broadcast();

  Stream<DrivingSession?> get activeSessionStream =>
      _activeSessionController.stream;
  DrivingSession? get activeSession => _activeSession;
  bool get hasActiveSession =>
      _activeSession != null && _activeSession!.isActive;

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  // Start a new driving session
  Future<DrivingSession> startSession({
    String? startLocation,
  }) async {
    if (currentUser == null) throw Exception('User not authenticated');
    if (hasActiveSession) throw Exception('Session already active');

    final session = DrivingSession(
      userId: currentUser!.uid,
      startTime: DateTime.now(),
      isActive: true,
      startLocation: startLocation,
    );

    _activeSession = session;
    _activeSessionController.add(_activeSession);

    // Start monitoring timer
    _startSessionTimer();

    print('🚗 Session started: ${session.id}');
    return session;
  }

  // End the current session
  Future<void> endSession({String? endLocation, double? distanceKm}) async {
    if (!hasActiveSession) {
      print('⚠️ No active session to end');
      throw Exception('No active session');
    }

    try {
      print('🛑 Starting to end session...');
      print('   Session ID: ${_activeSession!.id}');
      print('   Is Active: ${_activeSession!.isActive}');

      final endTime = DateTime.now();
      final duration = endTime.difference(_activeSession!.startTime);
      final safetyScore = _activeSession!.calculateSafetyScore();

      final completedSession = _activeSession!.copyWith(
        endTime: endTime,
        duration: duration,
        safetyScore: safetyScore,
        isActive: false,
        endLocation: endLocation,
        distanceKm: distanceKm,
      );

      print('📊 Calculated Score: ${completedSession.safetyScore}');

      // IMPORTANT: Stop timer and clear session IMMEDIATELY before saving
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _activeSession = null;

      // Broadcast null immediately to update UI
      _activeSessionController.add(null);
      print('📡 Broadcasted null session to stream');

      // Then save to Firestore
      await addSession(completedSession);
      print('💾 Session saved to Firestore');

      print('🏁 Session ended successfully: ${completedSession.id}');
      print('⏱️ Final Duration: ${completedSession.duration}');
    } catch (e) {
      print('❌ Error ending session: $e');
      print('Stack: ${StackTrace.current}');
      rethrow;
    }
  }

  // Add an alert to the active session
  Future<void> addAlertToActiveSession(AlertEvent alert) async {
    if (!hasActiveSession) return;

    final updatedAlerts = [..._activeSession!.alerts, alert];
    _activeSession = _activeSession!.copyWith(
      alerts: updatedAlerts,
      totalAlerts: updatedAlerts.length,
    );

    _activeSessionController.add(_activeSession);
    print('⚠️ Alert added to session: ${alert.type}');
  }

  // Timer to update session duration
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSession != null && _activeSession!.isActive) {
        final duration = DateTime.now().difference(_activeSession!.startTime);
        _activeSession = _activeSession!.copyWith(duration: duration);
        _activeSessionController.add(_activeSession);
      } else {
        timer.cancel();
      }
    });
  }

  // ============================================
  // FIRESTORE OPERATIONS
  // ============================================

  // Add a completed session to Firestore
  Future<void> addSession(DrivingSession session) async {
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sessions')
        .doc(session.id)
        .set(session.toJson());
  }

  // Get all sessions for current user
  Stream<List<DrivingSession>> getSessions() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrivingSession.fromJson(doc.data()))
            .toList());
  }

  // Get sessions for a specific date range
  Stream<List<DrivingSession>> getSessionsByDateRange(
      DateTime start, DateTime end) {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sessions')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrivingSession.fromJson(doc.data()))
            .toList());
  }

  // Get the last (most recent) session
  Stream<DrivingSession?> getLastSession() {
    if (currentUser == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return DrivingSession.fromJson(snapshot.docs.first.data());
    });
  }

  // Get a single session by ID
  Future<DrivingSession?> getSessionById(String sessionId) async {
    if (currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;
      return DrivingSession.fromJson(doc.data()!);
    } catch (e) {
      print('Error getting session: $e');
      return null;
    }
  }

  // Add sleep log
  Future<void> addSleepLog(SleepLog log) async {
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sleepLogs')
        .doc(log.id)
        .set(log.toJson());
  }

  // Get sleep logs
  Stream<List<SleepLog>> getSleepLogs() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('sleepLogs')
        .orderBy('sleepTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SleepLog.fromJson(doc.data())).toList());
  }

  // ============================================
  // ANALYTICS & STATISTICS
  // ============================================

  // Get total driving time (last 30 days)
  Future<Duration> getTotalDrivingTime() async {
    final sessions = await getSessions().first;
    final last30Days = sessions.where((s) =>
        s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 30))));

    return last30Days.fold<Duration>(
      Duration.zero,
      (total, session) => total + session.duration,
    );
  }

  // Get average safety score
  Future<double> getAverageSafetyScore() async {
    final sessions = await getSessions().first;
    if (sessions.isEmpty) return 100.0;

    final total =
        sessions.fold<double>(0, (sum, session) => sum + session.safetyScore);
    return total / sessions.length;
  }

  // Get total alerts count
  Future<int> getTotalAlertsCount() async {
    final sessions = await getSessions().first;
    return sessions.fold<int>(0, (sum, session) => sum + session.totalAlerts);
  }

  // Cleanup
  void dispose() {
    _sessionTimer?.cancel();
    _activeSessionController.close();
  }
}
