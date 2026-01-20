import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';
import '../models/trip_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  late TabController _tabController;

  AnalyticsSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final summary = await _analyticsService.getAnalyticsSummary();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_summary == null)
            _buildEmptyState()
          else
            SliverToBoxAdapter(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Analytics',
          style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.primaryGradient,
            ),
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: AnalyticsPatternPainter(),
                ),
              ),
              // Safety score badge
              if (_summary != null)
                Positioned(
                  right: 20,
                  bottom: 60,
                  child: _buildSafetyScoreBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyScoreBadge() {
    final score = _summary!.averageSafetyScore;
    Color scoreColor;

    if (score >= 90) {
      scoreColor = AppColors.success;
    } else if (score >= 75) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(0),
            style: AppTextStyles.headlineLarge.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
          ),
          Text(
            'Safety\nScore',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Quick stats
        _buildQuickStats(),

        const SizedBox(height: 24),

        // Tabs
        _buildTabBar(),

        const SizedBox(height: 16),

        // Tab content
        _buildTabContent(),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_fire_department,
              label: 'Current Streak',
              value: '${_summary!.currentStreak}',
              subtitle: 'trips',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.trending_up,
              label: 'Improvement',
              value:
                  '${_summary!.weeklyImprovement >= 0 ? '+' : ''}${_summary!.weeklyImprovement.toStringAsFixed(1)}%',
              subtitle: 'this week',
              color: _summary!.weeklyImprovement >= 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'History'),
          Tab(text: 'Insights'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 400,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildHistoryTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  // TAB 1: Overview
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistics', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),

          _buildOverviewCard(
            'Total Trips',
            '${_summary!.totalTrips}',
            Icons.directions_car,
            AppColors.primary,
          ),
          const SizedBox(height: 12),

          _buildOverviewCard(
            'Total Driving Time',
            _summary!.totalDrivingTime,
            Icons.access_time,
            Colors.blue,
          ),
          const SizedBox(height: 12),

          _buildOverviewCard(
            'Total Alerts',
            '${_summary!.totalAlerts}',
            Icons.warning,
            _summary!.totalAlerts > 0 ? AppColors.error : AppColors.success,
          ),
          const SizedBox(height: 12),

          _buildOverviewCard(
            'Risk Level',
            _summary!.riskLevel,
            Icons.shield,
            _summary!.averageSafetyScore >= 75
                ? AppColors.success
                : AppColors.warning,
          ),

          const SizedBox(height: 24),

          // Alerts by time chart
          Text('Alerts by Time of Day', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          _buildTimeOfDayChart(),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
      String label, String value, IconData icon, Color color) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOfDayChart() {
    final data = _summary!.alertsByTimeOfDay;
    final maxValue = data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b).toDouble();

    return GlassCard(
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue > 0 ? maxValue : 5,
            barTouchData: BarTouchData(enabled: true),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const titles = ['Morning', 'Afternoon', 'Evening', 'Night'];
                    if (value >= 0 && value < titles.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          titles[value.toInt()],
                          style: AppTextStyles.labelSmall,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              _buildBarGroup(
                  0, (data['Morning'] ?? 0).toDouble(), Colors.orange),
              _buildBarGroup(
                  1, (data['Afternoon'] ?? 0).toDouble(), Colors.blue),
              _buildBarGroup(
                  2, (data['Evening'] ?? 0).toDouble(), Colors.purple),
              _buildBarGroup(3, (data['Night'] ?? 0).toDouble(), Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  // TAB 2: History
  Widget _buildHistoryTab() {
    return StreamBuilder<List<TripSession>>(
      stream: _analyticsService.getTripsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text('No trips yet', style: AppTextStyles.bodyLarge),
              ],
            ),
          );
        }

        final trips = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            return _buildTripCard(trips[index]);
          },
        );
      },
    );
  }

  Widget _buildTripCard(TripSession trip) {
    Color scoreColor;
    if (trip.safetyScore >= 90) {
      scoreColor = AppColors.success;
    } else if (trip.safetyScore >= 75) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = AppColors.error;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car, color: scoreColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.formattedDate,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${trip.startTime.hour}:${trip.startTime.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.safetyScore.toStringAsFixed(0),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTripStat(Icons.access_time, trip.formattedDuration),
              _buildTripStat(Icons.warning, '${trip.alertCount} alerts'),
              _buildTripStat(
                  Icons.visibility, '${trip.totalDetections} checks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // TAB 3: Insights
  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Achievements', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          _buildAchievement(
            'Safe Driver',
            'Complete 10 trips without alerts',
            _summary!.currentStreak >= 10,
            Icons.emoji_events,
          ),
          const SizedBox(height: 12),
          _buildAchievement(
            'Marathon Driver',
            'Drive for 5+ hours total',
            _summary!.totalDrivingMinutes >= 300,
            Icons.timer,
          ),
          const SizedBox(height: 12),
          _buildAchievement(
            'Perfect Week',
            'Zero alerts for 7 days',
            _summary!.currentStreak >= 7,
            Icons.star,
          ),
          const SizedBox(height: 24),
          Text('Recommendations', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          ..._buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildAchievement(
      String title, String description, bool unlocked, IconData icon) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.textHint.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: unlocked ? AppColors.success : AppColors.textHint,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        unlocked ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendations() {
    List<Widget> recommendations = [];

    // Analyze data and provide insights
    if (_summary!.totalAlerts > 10) {
      recommendations.add(_buildRecommendationCard(
        'High Alert Frequency',
        'Consider taking more breaks during long drives. Aim for a 15-minute break every 2 hours.',
        Icons.coffee,
        AppColors.warning,
      ));
      recommendations.add(const SizedBox(height: 12));
    }

    final nightAlerts = _summary!.alertsByTimeOfDay['Night'] ?? 0;
    if (nightAlerts > 5) {
      recommendations.add(_buildRecommendationCard(
        'Night Driving Risk',
        'You have more alerts during night drives. Avoid late-night driving when possible.',
        Icons.nightlight,
        AppColors.error,
      ));
      recommendations.add(const SizedBox(height: 12));
    }

    if (_summary!.weeklyImprovement < 0) {
      recommendations.add(_buildRecommendationCard(
        'Declining Performance',
        'Your safety score decreased this week. Ensure you\'re getting adequate sleep.',
        Icons.trending_down,
        AppColors.error,
      ));
      recommendations.add(const SizedBox(height: 12));
    }

    if (recommendations.isEmpty) {
      recommendations.add(_buildRecommendationCard(
        'Great Job!',
        'Keep up the excellent driving habits. Your safety metrics look great!',
        Icons.thumb_up,
        AppColors.success,
      ));
    }

    return recommendations;
  }

  Widget _buildRecommendationCard(
      String title, String description, IconData icon, Color color) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: AppColors.textHint),
            const SizedBox(height: 24),
            Text(
              'No Analytics Data',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start monitoring to see your driving analytics',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for background pattern
class AnalyticsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
