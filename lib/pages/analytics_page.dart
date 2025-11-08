import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final DataService _dataService = DataService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallSafetyScoreCard(),
                  const SizedBox(height: 24),
                  _buildSleepLogSection(),
                  const SizedBox(height: 24),
                  _buildDrivingHistory(),
                  const SizedBox(height: 24),
                  _buildAlertDistributionChart(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.successGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: -1,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver Analytics',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Monitor your alertness trends and data',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildOverallSafetyScoreCard() {
    return StreamBuilder<List<DrivingSession>>(
      stream: _dataService.getSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildPlaceholderCard(
              'No driving data available yet.', Icons.analytics_rounded);
        }

        final sessions = snapshot.data!;
        return FutureBuilder<double>(
          future: _dataService.calculateSafetyScore(sessions),
          builder: (context, scoreSnapshot) {
            final safetyScore = scoreSnapshot.data?.toStringAsFixed(1) ?? 'N/A';
            final scoreColor = scoreSnapshot.data != null
                ? scoreSnapshot.data! > 80
                    ? AppColors.success
                    : scoreSnapshot.data! > 50
                        ? AppColors.warning
                        : AppColors.error
                : AppColors.textSecondary;

            return GradientCard(
              gradientColors: [AppColors.analytics, AppColors.success],
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Safety Score',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 36),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    safetyScore,
                    style: AppTextStyles.displayLarge.copyWith(
                      fontSize: 64,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    safetyScore != 'N/A'
                        ? double.parse(safetyScore) > 80
                            ? 'Excellent performance! Keep up the alert driving.'
                            : 'Alert frequency suggests fatigue risk. Review your history.'
                        : 'Drive a session to generate your score.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSleepLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pre-Drive Sleep Log',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log Your Sleep',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Self-monitoring sleep helps correlate rest with driving performance.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: () => _showSleepLogDialog(context),
                text: 'Add Sleep Record',
                gradientColors: AppColors.infoGradient,
                icon: Icons.bed_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrivingHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Driving Sessions',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<DrivingSession>>(
          stream: _dataService.getSessions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildPlaceholderCard('No recent sessions recorded.',
                  Icons.history_toggle_off_rounded);
            }

            final sessions = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                return _buildSessionCard(sessions[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionCard(DrivingSession session) {
    final alertColor =
        session.totalAlerts > 0 ? AppColors.error : AppColors.success;
    final durationFormat =
        '${session.duration.inHours}h ${session.duration.inMinutes.remainder(60)}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Session: ${DateFormat('MMM d, h:mm a').format(session.startTime)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Alerts: ${session.totalAlerts}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: alertColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Duration: $durationFormat',
                    style: AppTextStyles.bodyMedium),
                const Spacer(),
                const Icon(Icons.score_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Score: ${session.safetyScore.toStringAsFixed(1)}%',
                    style: AppTextStyles.bodyMedium),
              ],
            ),
            if (session.alerts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: session.alerts
                    .map((alert) => Chip(
                          backgroundColor: AppColors.error.withOpacity(0.1),
                          label: Text(
                            '${alert.type} (${DateFormat('h:mm a').format(alert.time)})',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ))
                    .toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAlertDistributionChart() {
    // Placeholder for a visual chart (e.g., using flutter_charts or a custom painter)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risk Distribution (Last 7 Days)',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alert Type Frequency',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Mock Bar Chart Data
              _buildChartBar('Eyes Closed', 12, AppColors.error),
              _buildChartBar('Yawning', 7, AppColors.warning),
              _buildChartBar('Head Nod', 3, AppColors.secondary),
              const SizedBox(height: 12),
              Text(
                'Insight: Alerts peak between 2:00 AM - 4:00 AM. Avoid long trips during this window.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartBar(String label, int count, Color color) {
    // Simple bar chart visualization
    double normalizedWidth = (count / 15).clamp(0.1, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  height: 12,
                  width:
                      MediaQuery.of(context).size.width * 0.5 * normalizedWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count',
                    style: AppTextStyles.labelMedium.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(String message, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 20,
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSleepLogDialog(BuildContext context) {
    // Implement sleep log dialog here
    final TextEditingController sleepTimeController = TextEditingController();
    final TextEditingController wakeTimeController = TextEditingController();

    // Mock initial time for simplicity
    sleepTimeController.text = DateFormat.Hm()
        .format(DateTime.now().subtract(const Duration(hours: 8)));
    wakeTimeController.text = DateFormat.Hm().format(DateTime.now());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Log Sleep Time', style: AppTextStyles.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sleepTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Bed Time (Yesterday)',
                  prefixIcon: Icon(Icons.nights_stay_rounded),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    sleepTimeController.text = time.format(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wakeTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Wake Time (Today)',
                  prefixIcon: Icon(Icons.wb_sunny_rounded),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    wakeTimeController.text = time.format(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium),
            ),
            GradientButton(
              onPressed: () {
                _saveSleepLog(
                    sleepTimeController.text, wakeTimeController.text);
                Navigator.of(context).pop();
              },
              text: 'Save',
              height: 40,
              width: 100,
              gradientColors: AppColors.successGradient,
            ),
          ],
        );
      },
    );
  }

  void _saveSleepLog(String sleepTimeString, String wakeTimeString) {
    try {
      final now = DateTime.now();

      // Parse sleep time (from yesterday, typically)
      final TimeOfDay sleepTimeOfDay =
          TimeOfDay.fromDateTime(DateFormat.jm().parse(sleepTimeString));
      DateTime sleepTime = DateTime(now.year, now.month, now.day - 1,
          sleepTimeOfDay.hour, sleepTimeOfDay.minute);

      // Parse wake time (from today)
      final TimeOfDay wakeTimeOfDay =
          TimeOfDay.fromDateTime(DateFormat.jm().parse(wakeTimeString));
      DateTime wakeTime = DateTime(now.year, now.month, now.day,
          wakeTimeOfDay.hour, wakeTimeOfDay.minute);

      // Adjust if wake time is before sleep time (means sleep was overnight into today)
      if (wakeTime.isBefore(sleepTime)) {
        // If the wake time is earlier than the sleep time, it means the sleep happened overnight.
        // Since we set the sleep time to yesterday, we should keep it that way.
      } else if (wakeTime.difference(sleepTime).inHours > 16) {
        // If the difference is too large, assume sleep was earlier today.
        sleepTime = sleepTime.add(const Duration(days: 1));
      }

      final duration = wakeTime.difference(sleepTime);

      final log = SleepLog(
        id: '',
        userId: _dataService.currentUser!.uid,
        sleepTime: sleepTime,
        wakeTime: wakeTime,
        duration: duration,
      );

      _dataService.addSleepLog(log);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Sleep logged successfully! Duration: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving sleep log: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
