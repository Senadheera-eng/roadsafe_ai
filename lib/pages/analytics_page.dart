import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../services/data_service.dart';
import 'dart:async';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  StreamSubscription<DrivingSession?>? _activeSessionSubscription;
  StreamSubscription<List<DrivingSession>>? _sessionsSubscription;

  DrivingSession? _activeSession;
  List<DrivingSession> _sessions = [];
  bool _isLoading = true;

  // Stats
  Duration _totalDrivingTime = Duration.zero;
  double _averageSafetyScore = 100.0;
  int _totalAlerts = 0;
  int _totalTrips = 0;
  double _bestSafetyScore = 0.0;
  Duration _longestTrip = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkForActiveSession();
    _listenToActiveSession();
    _loadData();
  }

  void _checkForActiveSession() {
    if (_dataService.hasActiveSession) {
      setState(() {
        _activeSession = _dataService.activeSession;
      });
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  void _listenToActiveSession() {
    _activeSessionSubscription =
        _dataService.activeSessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _activeSession = session;
        });
      }
    });
  }

  Future<void> _loadData() async {
    _sessionsSubscription = _dataService.getSessions().listen((sessions) async {
      if (mounted) {
        final now = DateTime.now();
        final last30Days = sessions.where(
            (s) => s.startTime.isAfter(now.subtract(const Duration(days: 30))));

        final totalTime = last30Days.fold<Duration>(
          Duration.zero,
          (total, session) => total + session.duration,
        );

        final avgScore = sessions.isEmpty
            ? 100.0
            : sessions.fold<double>(0, (sum, s) => sum + s.safetyScore) /
                sessions.length;

        final totalAlerts =
            sessions.fold<int>(0, (sum, s) => sum + s.totalAlerts);

        final bestScore = sessions.isEmpty
            ? 0.0
            : sessions
                .map((s) => s.safetyScore)
                .reduce((a, b) => a > b ? a : b);

        final longest = sessions.isEmpty
            ? Duration.zero
            : sessions.map((s) => s.duration).reduce((a, b) => a > b ? a : b);

        setState(() {
          _sessions = sessions;
          _totalDrivingTime = totalTime;
          _averageSafetyScore = avgScore;
          _totalAlerts = totalAlerts;
          _totalTrips = sessions.length;
          _bestSafetyScore = bestScore;
          _longestTrip = longest;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _activeSessionSubscription?.cancel();
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  // ============================================
  // TRIP ACTIONS
  // ============================================

  Future<void> _startTrip() async {
    try {
      await _dataService.startSession(startLocation: 'Current Location');
      _showSnackBar(
        '🚗 Trip started! Drive safely.',
        AppColors.success,
        icon: Icons.play_circle_filled_rounded,
      );
    } catch (e) {
      _showSnackBar(
        'Error: ${e.toString()}',
        AppColors.error,
        icon: Icons.error_rounded,
      );
    }
  }

  Future<void> _endTrip() async {
    if (_activeSession == null || !_dataService.hasActiveSession) {
      _showSnackBar('No active trip to end', AppColors.warning,
          icon: Icons.warning_rounded);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: AppColors.orangeGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('End Trip?', style: AppTextStyles.titleLarge),
          ],
        ),
        content: Text(
          'Are you sure you want to end the current trip? Your statistics will be saved.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('End Trip',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final scoreBeforeEnd = _activeSession?.safetyScore ?? 0.0;

    try {
      await _dataService.endSession(endLocation: 'Destination');
      setState(() {
        _activeSession = null;
      });
      _showSnackBar(
        '🏁 Trip completed! Safety score: ${scoreBeforeEnd.toStringAsFixed(1)}',
        AppColors.success,
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      _showSnackBar('Error ending trip: ${e.toString()}', AppColors.error,
          icon: Icons.error_rounded);
    }
  }

  void _showSnackBar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white),
            if (icon != null) const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Trip or Start Trip
                      if (_activeSession != null && _activeSession!.isActive)
                        _buildActiveTripCard()
                      else
                        _buildStartTripCard(),

                      const SizedBox(height: 24),

                      // Overview Stats
                      _buildSectionTitle('Overview', Icons.dashboard_rounded),
                      const SizedBox(height: 12),
                      _buildOverviewStats(),

                      const SizedBox(height: 24),

                      // Safety Score
                      _buildSectionTitle(
                          'Safety Performance', Icons.shield_rounded),
                      const SizedBox(height: 12),
                      _buildSafetyPerformanceCard(),

                      const SizedBox(height: 24),

                      // Recent Trips
                      _buildSectionTitle('Trip History', Icons.history_rounded),
                      const SizedBox(height: 12),
                      _buildRecentTrips(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // APP BAR
  // ============================================

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: -60,
              child: Icon(Icons.analytics_rounded,
                  size: 280, color: Colors.white.withOpacity(0.1)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text('Trip Analytics',
                        style: AppTextStyles.headlineLarge.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Monitor your driving safety',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // SECTION TITLE
  // ============================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style:
                AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ============================================
  // START TRIP CARD
  // ============================================

  Widget _buildStartTripCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.blueGradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Ready to Drive?',
              style: AppTextStyles.titleLarge
                  .copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Start a trip to track your driving safety.\nAlerts will be recorded automatically.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_filled_rounded, size: 24),
                  const SizedBox(width: 12),
                  Text('Start Trip',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTIVE TRIP CARD (with live alert timeline)
  // ============================================

  Widget _buildActiveTripCard() {
    if (_activeSession == null) return const SizedBox();

    final duration = _activeSession!.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.error.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('TRIP IN PROGRESS',
                        style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Started ${DateFormat('h:mm a').format(_activeSession!.startTime)}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Timer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.blueGradient
                    .map((c) => c.withOpacity(0.1))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text('Driving Duration',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HRS'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MIN'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SEC'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Live stats row
          Row(
            children: [
              Expanded(
                child: _buildLiveStat(
                  icon: Icons.warning_rounded,
                  label: 'Alerts',
                  value: _activeSession!.totalAlerts.toString(),
                  color: _activeSession!.totalAlerts > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLiveStat(
                  icon: Icons.visibility_off_rounded,
                  label: 'Eyes Closed',
                  value: _activeSession!.eyesClosedCount.toString(),
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLiveStat(
                  icon: Icons.sentiment_dissatisfied_rounded,
                  label: 'Yawns',
                  value: _activeSession!.yawnCount.toString(),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),

          // Alert timeline
          if (_activeSession!.alerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAlertTimeline(_activeSession!),
          ],

          const SizedBox(height: 20),

          // End Trip Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _endTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop_circle_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text('End Trip',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  // ============================================
  // ALERT TIMELINE (shows when driver fell asleep)
  // ============================================

  Widget _buildAlertTimeline(DrivingSession session) {
    final sortedAlerts = List<AlertEvent>.from(session.alerts)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Drowsiness Timeline',
                  style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                  '${sortedAlerts.length} event${sortedAlerts.length == 1 ? '' : 's'}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedAlerts.take(5).map((alert) {
            final timeSinceStart = alert.time.difference(session.startTime);
            final minutesIn = timeSinceStart.inMinutes;
            final secondsIn = timeSinceStart.inSeconds.remainder(60);
            final isLast =
                alert == sortedAlerts.last || sortedAlerts.indexOf(alert) == 4;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline dot & line
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getAlertColor(alert.type),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    _getAlertColor(alert.type).withOpacity(0.4),
                                blurRadius: 4),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_getAlertIcon(alert.type),
                                size: 14, color: _getAlertColor(alert.type)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(alert.type,
                                  style: AppTextStyles.labelLarge
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              DateFormat('h:mm:ss a').format(alert.time),
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${minutesIn}m ${secondsIn}s into trip',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primary, fontSize: 10),
                              ),
                            ),
                            if (alert.confidence != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(alert.confidence! * 100).toStringAsFixed(0)}%',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textHint, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (sortedAlerts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                '+${sortedAlerts.length - 5} more events',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================
  // OVERVIEW STATS (4-grid)
  // ============================================

  Widget _buildOverviewStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.access_time_rounded,
                label: 'Total Driving',
                value:
                    '${_totalDrivingTime.inHours}h ${_totalDrivingTime.inMinutes.remainder(60)}m',
                gradient: AppColors.blueGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.directions_car_rounded,
                label: 'Total Trips',
                value: _totalTrips.toString(),
                gradient: AppColors.purpleGradient,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.warning_amber_rounded,
                label: 'Total Alerts',
                value: _totalAlerts.toString(),
                gradient: AppColors.orangeGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_outlined,
                label: 'Longest Trip',
                value: _longestTrip.inMinutes == 0
                    ? '--'
                    : '${_longestTrip.inHours}h ${_longestTrip.inMinutes.remainder(60)}m',
                gradient: AppColors.greenGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: AppTextStyles.titleLarge
                  .copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ============================================
  // SAFETY PERFORMANCE CARD
  // ============================================

  Widget _buildSafetyPerformanceCard() {
    final scoreColor = _getScoreColor(_averageSafetyScore);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Average Safety Score',
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _averageSafetyScore.toStringAsFixed(1),
                          style: AppTextStyles.headlineLarge.copyWith(
                              fontWeight: FontWeight.bold, color: scoreColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(' / 100',
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildScoreBar(_averageSafetyScore, scoreColor),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getScoreIcon(_averageSafetyScore),
                    color: scoreColor, size: 48),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom stats
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPerfStat(
                  icon: Icons.emoji_events_rounded,
                  label: 'Best Score',
                  value: _bestSafetyScore > 0
                      ? _bestSafetyScore.toStringAsFixed(0)
                      : '--',
                  color: AppColors.success,
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: AppColors.textHint.withOpacity(0.2)),
                _buildPerfStat(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alerts / Trip',
                  value: _totalTrips > 0
                      ? (_totalAlerts / _totalTrips).toStringAsFixed(1)
                      : '--',
                  color: AppColors.warning,
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: AppColors.textHint.withOpacity(0.2)),
                _buildPerfStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Avg Score',
                  value: _averageSafetyScore.toStringAsFixed(0),
                  color: scoreColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(double score, Color color) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: score / 100,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildPerfStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: AppTextStyles.titleMedium
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  // ============================================
  // RECENT TRIPS
  // ============================================

  Widget _buildRecentTrips() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final completedSessions =
        _sessions.where((s) => !s.isActive).take(15).toList();

    if (completedSessions.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No trips yet',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Start your first trip to see analytics here',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: completedSessions
          .map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTripCard(session),
              ))
          .toList(),
    );
  }

  // ============================================
  // TRIP CARD (tap to expand)
  // ============================================

  Widget _buildTripCard(DrivingSession session) {
    final scoreColor = _getScoreColor(session.safetyScore);
    final dateStr = DateFormat('MMM dd, yyyy').format(session.startTime);
    final startTimeStr = DateFormat('h:mm a').format(session.startTime);
    final endTimeStr = session.endTime != null
        ? DateFormat('h:mm a').format(session.endTime!)
        : '--';
    final durationStr = _formatDuration(session.duration);

    return GestureDetector(
      onTap: () => _showTripDetail(session),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Safety score badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [scoreColor, scoreColor.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      session.safetyScore.toStringAsFixed(0),
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Trip info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr,
                          style: AppTextStyles.titleMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('$startTimeStr – $endTimeStr',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(durationStr,
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primary, fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
            // Alert summary row
            if (session.totalAlerts > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildMiniStat(
                        Icons.warning_rounded,
                        '${session.totalAlerts} alert${session.totalAlerts == 1 ? '' : 's'}',
                        AppColors.error),
                    const SizedBox(width: 16),
                    _buildMiniStat(
                        Icons.visibility_off_rounded,
                        '${session.eyesClosedCount} eyes closed',
                        AppColors.error),
                    const SizedBox(width: 16),
                    _buildMiniStat(
                        Icons.sentiment_dissatisfied_rounded,
                        '${session.yawnCount} yawn${session.yawnCount == 1 ? '' : 's'}',
                        AppColors.warning),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('No drowsiness alerts — Great driving!',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  // ============================================
  // TRIP DETAIL BOTTOM SHEET
  // ============================================

  void _showTripDetail(DrivingSession session) {
    final scoreColor = _getScoreColor(session.safetyScore);
    final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(session.startTime);
    final startTimeStr = DateFormat('h:mm:ss a').format(session.startTime);
    final endTimeStr = session.endTime != null
        ? DateFormat('h:mm:ss a').format(session.endTime!)
        : 'In Progress';
    final durationStr = _formatDuration(session.duration);
    final alertFreeStr = _formatDuration(session.longestAlertFreeStretch);
    final avgBetween = session.averageTimeBetweenAlerts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [scoreColor, scoreColor.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(session.safetyScore.toStringAsFixed(0),
                              style: AppTextStyles.titleLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  height: 1)),
                          const Text('score',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trip Details',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.bold)),
                        Text(dateStr,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(session.riskLevel,
                        style: AppTextStyles.labelLarge.copyWith(
                            color: scoreColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Trip Info Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.play_circle_rounded, 'Trip Started',
                        startTimeStr, AppColors.success),
                    _buildDivider(),
                    _buildDetailRow(Icons.stop_circle_rounded, 'Trip Ended',
                        endTimeStr, AppColors.error),
                    _buildDivider(),
                    _buildDetailRow(Icons.timer_rounded, 'Total Duration',
                        durationStr, AppColors.primary),
                    _buildDivider(),
                    _buildDetailRow(
                        Icons.shield_rounded,
                        'Safety Score',
                        '${session.safetyScore.toStringAsFixed(1)} / 100',
                        scoreColor),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Alert Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert Statistics',
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailStatBox(
                            'Total Alerts',
                            session.totalAlerts.toString(),
                            Icons.warning_rounded,
                            AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailStatBox(
                            'Eyes Closed',
                            session.eyesClosedCount.toString(),
                            Icons.visibility_off_rounded,
                            AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailStatBox(
                            'Yawns',
                            session.yawnCount.toString(),
                            Icons.sentiment_dissatisfied_rounded,
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailStatBox(
                            'Longest Safe Stretch',
                            alertFreeStr,
                            Icons.verified_rounded,
                            AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailStatBox(
                            'Avg Between Alerts',
                            avgBetween != null
                                ? _formatDuration(avgBetween)
                                : 'N/A',
                            Icons.swap_horiz_rounded,
                            AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Alert Timeline
              if (session.alerts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Drowsiness Events',
                          style: AppTextStyles.titleMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _buildFullAlertTimeline(session),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Text(value,
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1, thickness: 0.5, color: AppColors.textHint.withOpacity(0.2));
  }

  Widget _buildDetailStatBox(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFullAlertTimeline(DrivingSession session) {
    final sortedAlerts = List<AlertEvent>.from(session.alerts)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Column(
      children: sortedAlerts.asMap().entries.map((entry) {
        final index = entry.key;
        final alert = entry.value;
        final isLast = index == sortedAlerts.length - 1;
        final timeSinceStart = alert.time.difference(session.startTime);
        final minutesIn = timeSinceStart.inMinutes;
        final secondsIn = timeSinceStart.inSeconds.remainder(60);

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getAlertColor(alert.type),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _getAlertColor(alert.type).withOpacity(0.3),
                            blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 32,
                      color: AppColors.textHint.withOpacity(0.2),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getAlertColor(alert.type).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _getAlertColor(alert.type).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(_getAlertIcon(alert.type),
                          size: 18, color: _getAlertColor(alert.type)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alert.type,
                                style: AppTextStyles.labelLarge
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              '${DateFormat('h:mm:ss a').format(alert.time)}  •  ${minutesIn}m ${secondsIn}s into trip',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (alert.confidence != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.textHint.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(alert.confidence! * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.labelSmall.copyWith(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // TIME UNIT WIDGETS
  // ============================================

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(':',
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
    );
  }

  // ============================================
  // HELPERS
  // ============================================

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    } else {
      return '${d.inSeconds}s';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return AppColors.info;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getScoreIcon(double score) {
    if (score >= 90) return Icons.emoji_events_rounded;
    if (score >= 75) return Icons.thumb_up_rounded;
    if (score >= 60) return Icons.warning_rounded;
    return Icons.error_rounded;
  }

  Color _getAlertColor(String alertType) {
    final type = alertType.toLowerCase();
    if (type.contains('closed') || type.contains('eye')) {
      return AppColors.error;
    } else if (type.contains('yawn')) {
      return AppColors.warning;
    } else if (type.contains('nod')) {
      return AppColors.info;
    }
    return AppColors.textSecondary;
  }

  IconData _getAlertIcon(String alertType) {
    final type = alertType.toLowerCase();
    if (type.contains('closed') || type.contains('eye')) {
      return Icons.visibility_off_rounded;
    } else if (type.contains('yawn')) {
      return Icons.sentiment_dissatisfied_rounded;
    } else if (type.contains('nod')) {
      return Icons.swap_vert_rounded;
    }
    return Icons.warning_rounded;
  }
}
