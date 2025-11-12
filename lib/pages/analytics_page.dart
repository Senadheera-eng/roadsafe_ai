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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkForActiveSession(); // Check if session is already running
    _listenToActiveSession();
    _loadData();
  }

  // Check if there's already an active session when page loads
  void _checkForActiveSession() {
    if (_dataService.hasActiveSession) {
      setState(() {
        _activeSession = _dataService.activeSession;
      });
      print('📊 Found existing active session: ${_activeSession?.id}');
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
      print('📡 Received session update from stream:');
      print('   Session: ${session?.id ?? "NULL"}');
      print('   Is Active: ${session?.isActive ?? "N/A"}');

      if (mounted) {
        setState(() {
          _activeSession = session;
        });

        print('✅ UI state updated. Active session: ${_activeSession != null}');
      }
    });
  }

  Future<void> _loadData() async {
    _sessionsSubscription = _dataService.getSessions().listen((sessions) async {
      if (mounted) {
        // Calculate stats
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

        setState(() {
          _sessions = sessions;
          _totalDrivingTime = totalTime;
          _averageSafetyScore = avgScore;
          _totalAlerts = totalAlerts;
          _totalTrips = sessions.length;
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

  // Start a new trip
  Future<void> _startTrip() async {
    try {
      await _dataService.startSession(
        startLocation: 'Current Location', // TODO: Get actual location
      );

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

  // End current trip
  Future<void> _endTrip() async {
    if (_activeSession == null || !_dataService.hasActiveSession) {
      _showSnackBar(
        'No active trip to end',
        AppColors.warning,
        icon: Icons.warning_rounded,
      );
      return;
    }

    // Show confirmation dialog
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
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
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

    // Store score before ending
    final scoreBeforeEnd = _activeSession?.safetyScore ?? 0.0;

    try {
      print('🛑 Ending trip...');
      print('Current active session: ${_activeSession?.id}');

      await _dataService.endSession(
        endLocation: 'Destination', // TODO: Get actual location
      );

      print('✅ Trip ended successfully');

      // Force clear the active session in UI
      setState(() {
        _activeSession = null;
      });

      _showSnackBar(
        '🏁 Trip completed! Safety score: ${scoreBeforeEnd.toStringAsFixed(1)}',
        AppColors.success,
        icon: Icons.check_circle_rounded,
      );

      // Reload data to show updated history
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔄 Refreshing data...');
    } catch (e) {
      print('❌ Error ending trip: $e');
      print('Stack trace: ${StackTrace.current}');
      _showSnackBar(
        'Error ending trip: ${e.toString()}',
        AppColors.error,
        icon: Icons.error_rounded,
      );
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
              // App Bar
              _buildAppBar(),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Trip Section
                      if (_activeSession != null && _activeSession!.isActive)
                        _buildActiveTripCard()
                      else
                        _buildStartTripCard(),

                      const SizedBox(height: 24),

                      // Quick Stats
                      _buildSectionTitle('Quick Statistics'),
                      const SizedBox(height: 12),
                      _buildQuickStats(),

                      const SizedBox(height: 24),

                      // Performance Overview
                      _buildSectionTitle('Performance Overview'),
                      const SizedBox(height: 12),
                      _buildPerformanceCard(),

                      const SizedBox(height: 24),

                      // Recent Trips
                      _buildSectionTitle('Recent Trips'),
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
            // Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Icon Background
            Positioned(
              right: -60,
              top: -60,
              child: Icon(
                Icons.analytics_rounded,
                size: 280,
                color: Colors.white.withOpacity(0.1),
              ),
            ),

            // Title
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
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Analytics',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Track your driving performance',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to Drive?',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start monitoring your trip for safety analytics',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_filled_rounded, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Start Trip',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          // Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
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
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRIP IN PROGRESS',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('h:mm a').format(_activeSession!.startTime),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Time Display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.blueGradient
                    .map((c) => c.withOpacity(0.1))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Trip Duration',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
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

          // Alert Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTripStat(
                icon: Icons.warning_rounded,
                label: 'Alerts',
                value: _activeSession!.totalAlerts.toString(),
                color: AppColors.warning,
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: AppColors.textHint.withOpacity(0.2)),
              _buildTripStat(
                icon: Icons.route_rounded,
                label: 'Status',
                value: 'Active',
                color: AppColors.success,
              ),
            ],
          ),

          // Alert History (if there are alerts)
          if (_activeSession!.alerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_rounded,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Alert History',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._activeSession!.alerts
                      .take(3)
                      .map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _getAlertColor(alert.type),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('h:mm:ss a').format(alert.time),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  alert.type,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  if (_activeSession!.alerts.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${_activeSession!.alerts.length - 3} more alerts',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop_circle_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'End Trip',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTripStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time_rounded,
            label: 'Total Time',
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
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
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
                    Text(
                      'Safety Score',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _averageSafetyScore.toStringAsFixed(1),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          ' / 100',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                child: Icon(
                  _getScoreIcon(_averageSafetyScore),
                  color: scoreColor,
                  size: 48,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPerformanceStat(
                  icon: Icons.warning_amber_rounded,
                  label: 'Total Alerts',
                  value: _totalAlerts.toString(),
                  color: AppColors.warning,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.textHint.withOpacity(0.2),
                ),
                _buildPerformanceStat(
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: score / 100,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTrips() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first trip to see analytics',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show only recent trips (excluding active session)
    final completedSessions =
        _sessions.where((s) => !s.isActive).take(10).toList();

    return Column(
      children: completedSessions
          .map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTripCard(session),
              ))
          .toList(),
    );
  }

  Widget _buildTripCard(DrivingSession session) {
    final scoreColor = _getScoreColor(session.safetyScore);
    final dateStr = DateFormat('MMM dd, yyyy').format(session.startTime);
    final timeStr = DateFormat('h:mm a').format(session.startTime);
    final duration =
        '${session.duration.inHours}h ${session.duration.inMinutes.remainder(60)}m';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scoreColor, scoreColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    session.safetyScore.toStringAsFixed(0),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeStr • $duration',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _getScoreIcon(session.safetyScore),
                color: scoreColor,
                size: 24,
              ),
            ],
          ),
          if (session.totalAlerts > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${session.totalAlerts} ${session.totalAlerts == 1 ? 'alert' : 'alerts'} during trip',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (session.alerts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...session.alerts
                        .take(2)
                        .map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _getAlertIcon(alert.type),
                                  color: _getAlertColor(alert.type),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('h:mm a').format(alert.time),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    alert.type,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    if (session.alerts.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${session.alerts.length - 2} more',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textHint,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
