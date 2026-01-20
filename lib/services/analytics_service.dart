import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_session.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // Get all trips for current user
  Stream<List<TripSession>> getTripsStream() {
    return _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripSession.fromFirestore(doc))
            .toList());
  }

  // Get analytics summary
  Future<AnalyticsSummary> getAnalyticsSummary() async {
    final trips = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .orderBy('startTime', descending: true)
        .get();

    if (trips.docs.isEmpty) {
      return AnalyticsSummary(
        totalTrips: 0,
        totalDrivingMinutes: 0,
        totalAlerts: 0,
        averageSafetyScore: 100.0,
        currentStreak: 0,
        longestStreak: 0,
        alertsByTimeOfDay: {},
        recentTrips: [],
        weeklyImprovement: 0.0,
      );
    }

    final sessions =
        trips.docs.map((doc) => TripSession.fromFirestore(doc)).toList();

    // Calculate total metrics
    int totalTrips = sessions.length;
    int totalMinutes =
        sessions.fold(0, (sum, trip) => sum + trip.durationMinutes);
    int totalAlerts = sessions.fold(0, (sum, trip) => sum + trip.alertCount);
    double avgScore =
        sessions.fold(0.0, (sum, trip) => sum + trip.safetyScore) / totalTrips;

    // Calculate streaks
    int currentStreak = _calculateCurrentStreak(sessions);
    int longestStreak = _calculateLongestStreak(sessions);

    // Alerts by time of day
    Map<String, int> alertsByTime = _calculateAlertsByTime(sessions);

    // Weekly improvement
    double weeklyImprovement = _calculateWeeklyImprovement(sessions);

    return AnalyticsSummary(
      totalTrips: totalTrips,
      totalDrivingMinutes: totalMinutes,
      totalAlerts: totalAlerts,
      averageSafetyScore: avgScore,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      alertsByTimeOfDay: alertsByTime,
      recentTrips: sessions.take(10).toList(),
      weeklyImprovement: weeklyImprovement,
    );
  }

  int _calculateCurrentStreak(List<TripSession> sessions) {
    int streak = 0;
    for (var trip in sessions) {
      if (trip.alertCount == 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateLongestStreak(List<TripSession> sessions) {
    int longest = 0;
    int current = 0;

    for (var trip in sessions) {
      if (trip.alertCount == 0) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }

    return longest;
  }

  Map<String, int> _calculateAlertsByTime(List<TripSession> sessions) {
    Map<String, int> result = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };

    for (var trip in sessions) {
      final hour = trip.startTime.hour;
      String timeOfDay;

      if (hour >= 5 && hour < 12) {
        timeOfDay = 'Morning';
      } else if (hour >= 12 && hour < 17) {
        timeOfDay = 'Afternoon';
      } else if (hour >= 17 && hour < 21) {
        timeOfDay = 'Evening';
      } else {
        timeOfDay = 'Night';
      }

      result[timeOfDay] = (result[timeOfDay] ?? 0) + trip.alertCount;
    }

    return result;
  }

  double _calculateWeeklyImprovement(List<TripSession> sessions) {
    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final thisWeekTrips =
        sessions.where((t) => t.startTime.isAfter(lastWeek)).toList();
    final lastWeekTrips = sessions
        .where((t) =>
            t.startTime.isAfter(twoWeeksAgo) && t.startTime.isBefore(lastWeek))
        .toList();

    if (thisWeekTrips.isEmpty || lastWeekTrips.isEmpty) return 0.0;

    double thisWeekAvg =
        thisWeekTrips.fold(0.0, (sum, t) => sum + t.safetyScore) /
            thisWeekTrips.length;
    double lastWeekAvg =
        lastWeekTrips.fold(0.0, (sum, t) => sum + t.safetyScore) /
            lastWeekTrips.length;

    return ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100;
  }

  // Get trips for specific date range
  Future<List<TripSession>> getTripsByDateRange(
      DateTime start, DateTime end) async {
    final trips = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime', descending: true)
        .get();

    return trips.docs.map((doc) => TripSession.fromFirestore(doc)).toList();
  }
}
