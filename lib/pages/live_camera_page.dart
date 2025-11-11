import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/camera_service.dart';
import '../services/drowsiness_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/mjpeg_viewer.dart';

class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  final CameraService _cameraService = CameraService();

  bool _isAnalyzing = false;
  bool _isDrowsy = false;
  double _eyeOpenPercentage = 100.0;
  Timer? _analysisTimer;
  Uint8List? _currentFrame;
  DrowsinessResult? _lastResult;

  int _alertCount = 0;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _startPeriodicAnalysis();
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _analyzeCurrentFrame(),
    );
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_isAnalyzing || !_cameraService.isConnected) return;

    setState(() => _isAnalyzing = true);

    try {
      final response = await http
          .get(
            Uri.parse(
                '${_cameraService.streamUrl.replaceAll('/stream', '')}/capture'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _currentFrame = response.bodyBytes;

        final result = await DrowsinessDetector.analyzeImage(_currentFrame!);

        if (result != null) {
          setState(() {
            _lastResult = result;
            _isDrowsy = result.isDrowsy;
            _eyeOpenPercentage = result.eyeOpenPercentage;
          });

          if (result.isDrowsy) {
            _alertCount++;
            await DrowsinessDetector.triggerDrowsinessAlert();
          }
        }
      }
    } catch (e) {
      print('Frame analysis error: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Live Monitoring',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.oceanGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildCameraFeed(),
              ),
              Expanded(
                flex: 2,
                child: _buildStatusSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFeed() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (_cameraService.isConnected)
                MjpegViewer(
                  streamUrl: _cameraService.streamUrl,
                  fit: BoxFit.contain,
                )
              else
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 48, color: Colors.white38),
                      SizedBox(height: 16),
                      Text(
                        'Camera Not Connected',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              if (_isAnalyzing)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Analyzing...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
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

  Widget _buildStatusSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Status',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDrowsy ? 'DROWSY' : 'ALERT',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color:
                              _isDrowsy ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isDrowsy
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    size: 48,
                    color: _isDrowsy ? AppColors.error : AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.percent_rounded,
                  label: 'Eye Opening',
                  value: '${_eyeOpenPercentage.toStringAsFixed(0)}%',
                  color: _eyeOpenPercentage > 50
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.notifications_active_rounded,
                  label: 'Alerts',
                  value: '$_alertCount',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
