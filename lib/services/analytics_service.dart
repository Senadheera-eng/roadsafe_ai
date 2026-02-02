import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/trip_session.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // ============================================
  // TRIP MANAGEMENT
  // ============================================

  /// Get trips stream with PROPER INDEXING
  ///
  /// IMPORTANT: This query requires a composite index in Firestore:
  /// Collection: trips
  /// Fields indexed: userId (Ascending), startTime (Descending)
  ///
  /// Create the index by:
  /// 1. Firebase Console → Firestore → Indexes
  /// 2. Click "Create Index"
  /// 3. Or use the error link from console when query fails
  Stream<List<TripSession>> getTripsStream({int limit = 50}) {
    if (kDebugMode) print('📊 [STREAM] Getting trips for user: $_userId');

    if (_userId.isEmpty) {
      if (kDebugMode) print('⚠️ [STREAM] No user logged in');
      return Stream.value([]);
    }

    return _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .orderBy('startTime', descending: true) // REQUIRES INDEX!
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('📊 [STREAM] Received ${snapshot.docs.length} trips');
      }

      final trips = snapshot.docs
          .map((doc) {
            try {
              final trip = TripSession.fromFirestore(doc);
              if (kDebugMode) {
                print('  ✅ Trip ${doc.id}: ${trip.alertCount} alerts, '
                    'score: ${trip.safetyScore}');
              }
              return trip;
            } catch (e) {
              if (kDebugMode) print('  ❌ Error parsing trip ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TripSession>()
          .toList();

      if (kDebugMode)
        print('📊 [STREAM] Returning ${trips.length} valid trips');
      return trips;
    }).handleError((error) {
      if (kDebugMode) {
        print('❌ [STREAM] Error: $error');

        if (error.toString().contains('index')) {
          print('');
          print('🚨 FIRESTORE INDEX REQUIRED!');
          print('═══════════════════════════════════════');
          print('Create a composite index for this query:');
          print('  Collection: trips');
          print('  Fields:');
          print('    - userId: Ascending');
          print('    - startTime: Descending');
          print('');
          print('Steps:');
          print('1. Go to Firebase Console');
          print('2. Firestore Database → Indexes');
          print('3. Click the link in the error message');
          print('   OR manually create the index');
          print('═══════════════════════════════════════');
          print('');
        }
      }

      return Stream.value(<TripSession>[]);
    });
  }

  /// Get analytics summary (optimized version)
  Future<AnalyticsSummary> getAnalyticsSummary() async {
    if (kDebugMode) {
      print('\n========================================');
      print('📊 [SUMMARY] Getting analytics summary');
      print('📊 [SUMMARY] User ID: $_userId');
      print('========================================');
    }

    if (_userId.isEmpty) {
      if (kDebugMode) print('⚠️ [SUMMARY] No user logged in');
      return _getEmptySummary();
    }

    try {
      // Get only recent trips (last 30 days) for performance
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final thirtyDaysTimestamp = Timestamp.fromDate(thirtyDaysAgo);

      // Query 1: Recent trips (with index)
      final recentTripsSnapshot = await _firestore
          .collection('trips')
          .where('userId', isEqualTo: _userId)
          .where('startTime', isGreaterThanOrEqualTo: thirtyDaysTimestamp)
          .orderBy('startTime', descending: true)
          .limit(100)
          .get();

      if (kDebugMode) {
        print(
            '📊 [SUMMARY] Found ${recentTripsSnapshot.docs.length} recent trips');
      }

      if (recentTripsSnapshot.docs.isEmpty) {
        // No recent trips, try getting all trips (fallback)
        if (kDebugMode)
          print('📊 [SUMMARY] No recent trips, fetching all trips...');

        final allTripsSnapshot = await _firestore
            .collection('trips')
            .where('userId', isEqualTo: _userId)
            .limit(100)
            .get();

        if (allTripsSnapshot.docs.isEmpty) {
          if (kDebugMode) print('⚠️ [SUMMARY] No trips found for user');
          return _getEmptySummary();
        }

        return _calculateSummaryFromSnapshot(allTripsSnapshot);
      }

      // Get aggregated stats (if you implement Cloud Functions)
      // This is optional but recommended for production
      DocumentSnapshot? statsDoc;
      try {
        statsDoc = await _firestore
            .collection('user_stats')
            .doc(_userId)
            .get()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        if (kDebugMode) print('⚠️ [SUMMARY] Could not get cached stats: $e');
      }

      return _calculateSummaryFromSnapshot(
        recentTripsSnapshot,
        cachedStats: statsDoc?.data() as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [SUMMARY] Error: $e');
        print('Stack trace: $stackTrace');
      }
      return _getEmptySummary();
    }
  }

  /// Calculate summary from Firestore snapshot
  AnalyticsSummary _calculateSummaryFromSnapshot(
    QuerySnapshot snapshot, {
    Map<String, dynamic>? cachedStats,
  }) {
    // Parse all trips
    final sessions = <TripSession>[];
    for (var doc in snapshot.docs) {
      try {
        final trip = TripSession.fromFirestore(doc);
        sessions.add(trip);

        if (kDebugMode) {
          print('  ✅ Parsed trip ${doc.id}:');
          print('     - Start: ${trip.startTime}');
          print('     - Duration: ${trip.durationMinutes} min');
          print('     - Alerts: ${trip.alertCount}');
          print('     - Score: ${trip.safetyScore}');
        }
      } catch (e) {
        if (kDebugMode) print('  ❌ Error parsing trip ${doc.id}: $e');
      }
    }

    if (sessions.isEmpty) {
      if (kDebugMode) print('⚠️ [SUMMARY] No valid sessions after parsing');
      return _getEmptySummary();
    }

    // Sessions are already sorted by Firestore query (descending startTime)
    if (kDebugMode) {
      print(
          '📊 [SUMMARY] Calculating metrics from ${sessions.length} sessions...');
    }

    // Calculate metrics
    int totalTrips = cachedStats?['totalTrips'] ?? sessions.length;
    int totalMinutes =
        sessions.fold(0, (sum, trip) => sum + trip.durationMinutes);
    int totalAlerts = sessions.fold(0, (sum, trip) => sum + trip.alertCount);
    double avgScore =
        sessions.fold(0.0, (sum, trip) => sum + trip.safetyScore) /
            sessions.length;

    // Use cached values if available for all-time stats
    if (cachedStats != null) {
      totalTrips = cachedStats['totalTrips'] ?? totalTrips;
      // totalMinutes and totalAlerts are from recent trips only
    }

    int currentStreak = _calculateCurrentStreak(sessions);
    int longestStreak =
        cachedStats?['longestStreak'] ?? _calculateLongestStreak(sessions);
    Map<String, int> alertsByTime = _calculateAlertsByTime(sessions);
    double weeklyImprovement = _calculateWeeklyImprovement(sessions);

    if (kDebugMode) {
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
    }

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

  AnalyticsSummary _getEmptySummary() {
    if (kDebugMode) print('📊 [SUMMARY] Returning empty summary');
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

  // ============================================
  // TRIP CREATION & UPDATES (WITH BATCHING)
  // ============================================

  /// Create a new trip session
  Future<String?> createTrip({
    required DateTime startTime,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = await _firestore.collection('trips').add({
        'userId': _userId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': null,
        'durationMinutes': 0,
        'totalDetections': 0,
        'alertCount': 0,
        'yawnCount': 0,
        'safetyScore': 100.0,
        'isActive': true,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ Created trip: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      if (kDebugMode) print('❌ Error creating trip: $e');
      return null;
    }
  }

  /// End a trip session with batch update
  Future<bool> endTrip(
    String tripId, {
    required DateTime endTime,
    required int totalDetections,
    required int alertCount,
    required int yawnCount,
  }) async {
    try {
      final tripRef = _firestore.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();

      if (!tripDoc.exists) {
        if (kDebugMode) print('❌ Trip not found: $tripId');
        return false;
      }

      final tripData = tripDoc.data()!;
      final startTime = (tripData['startTime'] as Timestamp).toDate();
      final durationMinutes = endTime.difference(startTime).inMinutes;

      // Calculate safety score
      final safetyScore = _calculateSafetyScore(
        durationMinutes: durationMinutes,
        alertCount: alertCount,
        yawnCount: yawnCount,
      );

      // Use batch write for atomic update
      final batch = _firestore.batch();

      // Update trip
      batch.update(tripRef, {
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': durationMinutes,
        'totalDetections': totalDetections,
        'alertCount': alertCount,
        'yawnCount': yawnCount,
        'safetyScore': safetyScore,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user stats (optional - for caching)
      final statsRef = _firestore.collection('user_stats').doc(_userId);
      batch.set(
          statsRef,
          {
            'userId': _userId,
            'totalTrips': FieldValue.increment(1),
            'totalAlerts': FieldValue.increment(alertCount),
            'lastTripAt': Timestamp.fromDate(endTime),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit();

      if (kDebugMode) {
        print('✅ Trip ended: $tripId');
        print('   Duration: $durationMinutes min');
        print('   Alerts: $alertCount');
        print('   Safety Score: $safetyScore');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error ending trip: $e');
      return false;
    }
  }

  /// Update active trip (for real-time updates)
  Future<void> updateActiveTrip(
    String tripId, {
    int? totalDetections,
    int? alertCount,
    int? yawnCount,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (totalDetections != null) updates['totalDetections'] = totalDetections;
      if (alertCount != null) updates['alertCount'] = alertCount;
      if (yawnCount != null) updates['yawnCount'] = yawnCount;

      await _firestore.collection('trips').doc(tripId).update(updates);

      if (kDebugMode) {
        print('✅ Updated trip $tripId: $updates');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating trip: $e');
    }
  }

  // ============================================
  // CALCULATION HELPERS
  // ============================================

  double _calculateSafetyScore({
    required int durationMinutes,
    required int alertCount,
    required int yawnCount,
  }) {
    if (durationMinutes == 0) return 100.0;

    // Start with perfect score
    double score = 100.0;

    // Penalty for alerts (exponential impact)
    double alertsPerHour = (alertCount / durationMinutes) * 60;
    score -= alertsPerHour * 15; // -15 points per alert/hour

    // Additional penalty for yawns
    double yawnsPerHour = (yawnCount / durationMinutes) * 60;
    score -= yawnsPerHour * 5; // -5 points per yawn/hour

    // Bonus for long alert-free sessions
    if (alertCount == 0 && durationMinutes > 30) {
      score += 5; // +5 bonus
    }

    // Extra penalty for very high alert frequency
    if (alertsPerHour > 5) {
      score -= (alertsPerHour - 5) * 10; // Additional penalty
    }

    return score.clamp(0.0, 100.0);
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
    if (kDebugMode) print('  📈 Current streak: $streak');
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

    if (kDebugMode) print('  📈 Longest streak: $longest');
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

    if (kDebugMode) print('  📈 Alerts by time: $result');
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
      if (kDebugMode)
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
    if (kDebugMode)
      print('  📈 Weekly improvement: ${improvement.toStringAsFixed(1)}%');
    return improvement;
  }

  // ============================================
  // DEBUG UTILITIES
  // ============================================

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

  /// Clear all user stats cache
  Future<void> clearStatsCache() async {
    try {
      await _firestore.collection('user_stats').doc(_userId).delete();
      if (kDebugMode) print('✅ Stats cache cleared');
    } catch (e) {
      if (kDebugMode) print('❌ Error clearing cache: $e');
    }
  }
}
