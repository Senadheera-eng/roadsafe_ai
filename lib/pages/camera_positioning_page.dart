import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/mjpeg_viewer.dart';

class CameraPositioningPage extends StatefulWidget {
  final String deviceIP;

  const CameraPositioningPage({
    super.key,
    required this.deviceIP,
  });

  @override
  State<CameraPositioningPage> createState() => _CameraPositioningPageState();
}

class _CameraPositioningPageState extends State<CameraPositioningPage> {
  bool _showGuideOverlay = true;
  int _currentStep = 0;

  final List<Map<String, String>> _positioningSteps = [
    {
      'title': 'Mount Camera',
      'description': 'Mount the ESP32-CAM on your dashboard using the bracket',
    },
    {
      'title': 'Face Camera',
      'description': 'Position it to face the driver\'s seat directly',
    },
    {
      'title': 'Check Visibility',
      'description': 'Ensure your entire face is visible in the frame',
    },
    {
      'title': 'Adjust Angle',
      'description': 'Tilt camera 15-30° downward for optimal face detection',
    },
    {
      'title': 'Check Lighting',
      'description': 'Make sure there\'s adequate lighting on your face',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Position Camera', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _showGuideOverlay ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showGuideOverlay = !_showGuideOverlay;
              });
            },
            tooltip: _showGuideOverlay ? 'Hide Guide' : 'Show Guide',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Feed
          Center(
            child: MjpegViewer(
              streamUrl: 'http://${widget.deviceIP}/stream',
              fit: BoxFit.contain,
            ),
          ),

          // Guide Overlay
          if (_showGuideOverlay) _buildGuideOverlay(),

          // Instructions Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInstructionsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return CustomPaint(
      painter: FaceGuidePainter(),
      child: Container(),
    );
  }

  Widget _buildInstructionsPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current Step Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _positioningSteps.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentStep
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Instruction
          Text(
            'Step ${_currentStep + 1}/${_positioningSteps.length}',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _positioningSteps[_currentStep]['title']!,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _positioningSteps[_currentStep]['description']!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Navigation Buttons
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_currentStep < _positioningSteps.length - 1) {
                      setState(() {
                        _currentStep++;
                      });
                    } else {
                      _finishPositioning();
                    }
                  },
                  icon: Icon(
                    _currentStep < _positioningSteps.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                  label: Text(
                    _currentStep < _positioningSteps.length - 1
                        ? 'Next'
                        : 'Finish',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _finishPositioning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 8),
            const Text('Setup Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera is positioned correctly!',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can now start using the drowsiness detection system.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Go to Live Camera Feed to start monitoring',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from positioning
              Navigator.pop(context); // Go back from device setup
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// Custom painter for face guide overlay
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw face oval guide
    final center = Offset(size.width / 2, size.height / 2);
    final faceWidth = size.width * 0.4;
    final faceHeight = size.height * 0.5;

    final rect = Rect.fromCenter(
      center: center,
      width: faceWidth,
      height: faceHeight,
    );

    // Draw oval
    canvas.drawOval(rect, paint);

    // Draw eye guides
    final eyeY = center.dy - faceHeight * 0.15;
    final eyeRadius = faceWidth * 0.08;
    final eyeSpacing = faceWidth * 0.25;

    // Left eye
    canvas.drawCircle(
      Offset(center.dx - eyeSpacing, eyeY),
      eyeRadius,
      paint,
    );

    // Right eye
    canvas.drawCircle(
      Offset(center.dx + eyeSpacing, eyeY),
      eyeRadius,
      paint,
    );

    // Draw crosshair at center
    final crosshairSize = 20.0;
    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      paint,
    );

    // Draw text guide
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Position your face here',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black,
              offset: Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        rect.bottom + 20,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
