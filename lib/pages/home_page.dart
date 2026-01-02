import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:road_safe_ai/pages/live_camera_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/feature_card.dart';
import '../widgets/glass_card.dart';
import 'safety_guide_page.dart';
import 'device_setup_page.dart';
import 'analytics_page.dart';
import '../services/data_service.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'help_support_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();

  late AnimationController _welcomeAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _welcomeSlideAnimation;
  late Animation<double> _welcomeFadeAnimation;
  late Animation<double> _cardsFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _ensureMockData();
  }

  void _ensureMockData() async {
    final sessionsStream = _dataService.getSessions();
    final firstSnapshot = await sessionsStream.first;

    if (firstSnapshot.isEmpty) {
      final session1 = DrivingSession(
        id: '',
        userId: _dataService.currentUser!.uid,
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now(),
        duration: const Duration(hours: 3),
        totalAlerts: 1,
        safetyScore: 95.5,
        alerts: [
          AlertEvent(
            time: DateTime.now().subtract(const Duration(minutes: 50)),
            type: 'Yawn Detected',
          ),
        ],
      );
      _dataService.addSession(session1);

      final session2 = DrivingSession(
        id: '',
        userId: _dataService.currentUser!.uid,
        startTime: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
        endTime: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        duration: const Duration(hours: 2),
        totalAlerts: 4,
        safetyScore: 68.2,
        alerts: [
          AlertEvent(
            time: DateTime.now().subtract(
              const Duration(days: 2, minutes: 150),
            ),
            type: 'Eyes Closed',
          ),
          AlertEvent(
            time: DateTime.now().subtract(
              const Duration(days: 2, minutes: 140),
            ),
            type: 'Yawn Detected',
          ),
        ],
      );
      _dataService.addSession(session2);

      final sleepLog = SleepLog(
        id: '',
        userId: _dataService.currentUser!.uid,
        sleepTime: DateTime.now().subtract(const Duration(hours: 9)),
        wakeTime: DateTime.now().subtract(const Duration(hours: 1)),
        duration: const Duration(hours: 8, minutes: 0),
      );
      _dataService.addSleepLog(sleepLog);
    }
  }

  void _initializeAnimations() {
    _welcomeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _welcomeSlideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(
        parent: _welcomeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _welcomeFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _welcomeAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardsFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardsAnimationController, curve: Curves.easeOut),
    );
  }

  void _startAnimations() {
    _welcomeAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _cardsAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _welcomeAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  void _navigateToLiveCamera() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LiveCameraPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AnalyticsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Beautiful Curved App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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

                  // Curved Bottom Shape
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

                  // App Bar Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // Top Row with Logo and Profile Button (NO NOTIFICATION BUTTON)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Logo and Title
                              Row(
                                children: [
                                  Container(
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
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Road Safe AI',
                                        style: AppTextStyles.headlineMedium
                                            .copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                      ),
                                      Text(
                                        'Driver Safety System',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.white.withOpacity(0.8),
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // ONLY Profile Button (Notification removed)
                              _buildActionButton(
                                icon: Icons.person_rounded,
                                onTap: () => _showProfileMenu(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Welcome Message
                          Text(
                            'Welcome back, $userName!',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your safety companion is ready',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Welcome Section
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _welcomeAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _welcomeSlideAnimation.value),
                  child: Opacity(
                    opacity: _welcomeFadeAnimation.value,
                    child: _buildWelcomeSection(userName),
                  ),
                );
              },
            ),
          ),

          // Quick Stats Section
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _cardsAnimationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _cardsFadeAnimation.value,
                  child: _buildQuickStatsSection(),
                );
              },
            ),
          ),

          // Feature Cards Grid
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _cardsAnimationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _cardsFadeAnimation.value,
                  child: _buildFeatureCardsSection(),
                );
              },
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
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
            child: Icon(icon, color: Colors.white, size: 22),
          ),

          // Badge (if needed for future use)
          if (showBadge && badgeCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(String userName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GradientCard(
        gradientColors: AppColors.sunsetGradient,
        padding: const EdgeInsets.all(24),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Protection Active',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Monitoring your alertness in real-time',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 16,
              opacity: 0.2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'ESP32 device connected and monitoring your safety',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return StreamBuilder<DrivingSession?>(
      stream: _dataService.getLastSession(),
      builder: (context, snapshot) {
        final lastSession = snapshot.data;

        final driveTime = lastSession != null
            ? '${lastSession.duration.inHours}h ${lastSession.duration.inMinutes.remainder(60)}m'
            : 'N/A';
        final alerts = lastSession?.totalAlerts.toString() ?? 'N/A';
        final safetyScore =
            lastSession?.safetyScore.toStringAsFixed(1) ?? 'N/A';
        final scoreColor = lastSession != null
            ? lastSession.safetyScore > 80
                ? AppColors.success
                : lastSession.safetyScore > 50
                    ? AppColors.warning
                    : AppColors.error
            : AppColors.textSecondary;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Session Metrics',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.timer_rounded,
                      value: driveTime,
                      label: 'Drive Time',
                      color: AppColors.info,
                      gradientColors: [AppColors.info, AppColors.secondary],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.warning_rounded,
                      value: alerts,
                      label: 'Alerts',
                      color: AppColors.warning,
                      gradientColors: [AppColors.warning, AppColors.accent],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.trending_up_rounded,
                      value: safetyScore,
                      label: 'Safety Score',
                      color: scoreColor,
                      gradientColors: [scoreColor, scoreColor.withOpacity(0.7)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    List<Color>? gradientColors,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      opacity: 0.8,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors ?? [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCardsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Safety Features',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              FeatureCard(
                icon: Icons.videocam_rounded,
                title: 'Live Camera',
                subtitle: 'Real-time ESP32 monitoring',
                color: AppColors.cameraFeed,
                gradientColors: AppColors.primaryGradient,
                onTap: () => _navigateToLiveCamera(),
              ),
              FeatureCard(
                icon: Icons.analytics_rounded,
                title: 'Analytics',
                subtitle: 'AI-powered behavior insights',
                color: AppColors.analytics,
                gradientColors: AppColors.successGradient,
                onTap: () => _navigateToAnalytics(),
              ),
              FeatureCard(
                icon: Icons.settings_rounded,
                title: 'Device Setup',
                subtitle: 'Configure your ESP32 device',
                color: AppColors.deviceSetup,
                gradientColors: AppColors.accentGradient,
                onTap: () => _navigateToDeviceSetup(),
              ),
              FeatureCard(
                icon: Icons.help_outline_rounded,
                title: 'Safety Guide',
                subtitle: 'Learn optimal usage patterns',
                color: AppColors.guidelines,
                gradientColors: AppColors.secondaryGradient,
                onTap: () => _navigateToSafetyGuide(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToSafetyGuide() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SafetyGuidePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToDeviceSetup() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DeviceSetupPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Enhanced Profile Menu for home_page.dart
// Replace your _showProfileMenu() method with this

  void _showProfileMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final userEmail = user?.email ?? 'No email';
    final photoUrl = user?.photoURL;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Profile Header with Photo and Info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.oceanGradient
                        .map((c) => c.withOpacity(0.12))
                        .toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Profile Picture with Animated Gradient Ring
                    Stack(
                      children: [
                        // Gradient Ring
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        // White Border
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? Image.network(
                                        photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _buildDefaultAvatar(userName);
                                        },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : _buildDefaultAvatar(userName),
                              ),
                            ),
                          ),
                        ),
                        // Online Status Indicator
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.email_rounded,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  userEmail,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Active Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.successGradient,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Active',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildModernMenuItem(
                      context: context,
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      subtitle: 'View and edit your profile',
                      gradientColors: AppColors.blueGradient,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfilePage()),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    _buildModernMenuItem(
                      context: context,
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'Manage your preferences',
                      gradientColors: AppColors.purpleGradient,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    _buildModernMenuItem(
                      context: context,
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact us',
                      gradientColors: AppColors.orangeGradient,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HelpSupportPage()),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Elegant Divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.textHint.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Logout Button (Special Red Theme)
                    _buildModernMenuItem(
                      context: context,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      gradientColors: [
                        AppColors.error,
                        const Color(0xFFFF6B6B)
                      ],
                      isDestructive: true,
                      onTap: () async {
                        final confirmed =
                            await _showLogoutConfirmation(context);

                        if (confirmed) {
                          await FirebaseAuth.instance.signOut();

                          if (context.mounted) {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Footer with App Info
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Road Safe AI',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v1.0.0',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

// Helper Widget: Build Default Avatar
  Widget _buildDefaultAvatar(String userName) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

// Helper Widget: Modern Menu Item
  Widget _buildModernMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: gradientColors.first.withOpacity(0.1),
        highlightColor: gradientColors.first.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withOpacity(0.06)
                : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDestructive
                  ? AppColors.error.withOpacity(0.2)
                  : AppColors.textHint.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDestructive
                    ? AppColors.error.withOpacity(0.08)
                    : Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Container with Gradient
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDestructive
                          ? [
                              AppColors.error.withOpacity(0.15),
                              AppColors.error.withOpacity(0.08),
                            ]
                          : [
                              gradientColors.first.withOpacity(0.18),
                              gradientColors.last.withOpacity(0.1),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDestructive
                              ? AppColors.error
                              : gradientColors.first)
                          .withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isDestructive ? AppColors.error : gradientColors.first,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 14),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDestructive
                              ? AppColors.error
                              : AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDestructive
                              ? AppColors.error.withOpacity(0.7)
                              : AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDestructive
                      ? AppColors.error.withOpacity(0.5)
                      : AppColors.textHint.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Confirm Logout',
              style: AppTextStyles.titleLarge
                  .copyWith(color: AppColors.textPrimary),
            ),
            content: Text(
              'Are you sure you want to log out of Road Safe AI?',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Logout',
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: itemColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
