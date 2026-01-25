import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_session.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // Get all trips for current user (SIMPLIFIED - NO ORDERING)
  Stream<List<TripSession>> getTripsStream() {
    print('📊 [STREAM] Getting trips for user: $_userId');

    if (_userId.isEmpty) {
      print('⚠️ [STREAM] No user logged in');
      return Stream.value([]);
    }

    return _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) {
      print('📊 [STREAM] Received ${snapshot.docs.length} trips');

      final trips = snapshot.docs
          .map((doc) {
            try {
              final trip = TripSession.fromFirestore(doc);
              print(
                  '  ✅ Trip ${doc.id}: ${trip.alertCount} alerts, score: ${trip.safetyScore}');
              return trip;
            } catch (e) {
              print('  ❌ Error parsing trip ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TripSession>()
          .toList();

      // Sort by start time (newest first)
      trips.sort((a, b) => b.startTime.compareTo(a.startTime));

      print('📊 [STREAM] Returning ${trips.length} valid trips');
      return trips;
    });
  }

  // Get analytics summary (SIMPLIFIED - NO ORDERING)
  Future<AnalyticsSummary> getAnalyticsSummary() async {
    print('\n========================================');
    print('📊 [SUMMARY] Getting analytics summary');
    print('📊 [SUMMARY] User ID: $_userId');
    print('========================================');

    if (_userId.isEmpty) {
      print('⚠️ [SUMMARY] No user logged in');
      return _getEmptySummary();
    }

    try {
      // Get ALL trips for this user (no ordering to avoid index issues)
      final tripsSnapshot = await _firestore
          .collection('trips')
          .where('userId', isEqualTo: _userId)
          .get();

      print(
          '📊 [SUMMARY] Found ${tripsSnapshot.docs.length} trips in Firestore');

      if (tripsSnapshot.docs.isEmpty) {
        print('⚠️ [SUMMARY] No trips found for user');
        return _getEmptySummary();
      }

      // Parse trips
      final sessions = <TripSession>[];
      for (var doc in tripsSnapshot.docs) {
        try {
          final trip = TripSession.fromFirestore(doc);
          sessions.add(trip);
          print('  ✅ Parsed trip ${doc.id}:');
          print('     - Start: ${trip.startTime}');
          print('     - Duration: ${trip.durationMinutes} min');
          print('     - Alerts: ${trip.alertCount}');
          print('     - Score: ${trip.safetyScore}');
        } catch (e) {
          print('  ❌ Error parsing trip ${doc.id}: $e');
        }
      }

      if (sessions.isEmpty) {
        print('⚠️ [SUMMARY] No valid sessions after parsing');
        return _getEmptySummary();
      }

      // Sort by start time (newest first)
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

      print(
          '📊 [SUMMARY] Calculating metrics from ${sessions.length} sessions...');

      // Calculate metrics
      int totalTrips = sessions.length;
      int totalMinutes =
          sessions.fold(0, (sum, trip) => sum + trip.durationMinutes);
      int totalAlerts = sessions.fold(0, (sum, trip) => sum + trip.alertCount);
      double avgScore =
          sessions.fold(0.0, (sum, trip) => sum + trip.safetyScore) /
              totalTrips;

      int currentStreak = _calculateCurrentStreak(sessions);
      int longestStreak = _calculateLongestStreak(sessions);
      Map<String, int> alertsByTime = _calculateAlertsByTime(sessions);
      double weeklyImprovement = _calculateWeeklyImprovement(sessions);

      print('📊 [SUMMARY] Metrics calculated:');
      print('   - Total trips: $totalTrips');
      print('   - Total minutes: $totalMinutes');
      print('   - Total alerts: $totalAlerts');
      print('   - Average score: ${avgScore.toStringAsFixed(1)}');
      print('   - Current streak: $currentStreak');
      print('   - Longest streak: $longestStreak');
      print(
          '   - Weekly improvement: ${weeklyImprovement.toStringAsFixed(1)}%');
      print('========================================\n');

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
    } catch (e, stackTrace) {
      print('❌ [SUMMARY] Error: $e');
      print('Stack trace: $stackTrace');
      return _getEmptySummary();
    }
  }

  AnalyticsSummary _getEmptySummary() {
    print('📊 [SUMMARY] Returning empty summary');
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

  int _calculateCurrentStreak(List<TripSession> sessions) {
    int streak = 0;
    for (var trip in sessions) {
      if (trip.alertCount == 0) {
        streak++;
      } else {
        break;
      }
    }
    print('  📈 Current streak: $streak');
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

    print('  📈 Longest streak: $longest');
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

    print('  📈 Alerts by time: $result');
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

    if (thisWeekTrips.isEmpty || lastWeekTrips.isEmpty) {
      print('  📈 Weekly improvement: 0.0% (insufficient data)');
      return 0.0;
    }

    double thisWeekAvg =
        thisWeekTrips.fold(0.0, (sum, t) => sum + t.safetyScore) /
            thisWeekTrips.length;
    double lastWeekAvg =
        lastWeekTrips.fold(0.0, (sum, t) => sum + t.safetyScore) /
            lastWeekTrips.length;

    if (lastWeekAvg == 0) return 0.0;

    double improvement = ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100;
    print('  📈 Weekly improvement: ${improvement.toStringAsFixed(1)}%');
    return improvement;
  }

  // Debug: Print all trips
  Future<void> debugPrintAllTrips() async {
    print('\n=== 🔍 DEBUG: ALL TRIPS IN DATABASE ===');
    try {
      final allTrips = await _firestore.collection('trips').get();
      print('Total trips in database: ${allTrips.docs.length}');
      print('Current user ID: $_userId');
      print('---');

      for (var doc in allTrips.docs) {
        final data = doc.data();
        print('Trip ID: ${doc.id}');
        print('  userId: ${data['userId']}');
        print('  startTime: ${data['startTime']}');
        print('  durationMinutes: ${data['durationMinutes']}');
        print('  alertCount: ${data['alertCount']}');
        print('  safetyScore: ${data['safetyScore']}');
        print('  isActive: ${data['isActive']}');
        print('  Match: ${data['userId'] == _userId ? "✅ YES" : "❌ NO"}');
        print('---');
      }

      print('======================================\n');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}
