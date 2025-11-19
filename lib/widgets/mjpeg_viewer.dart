import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/drowsiness_service.dart';

class MjpegViewer extends StatefulWidget {
  final String stream;
  final bool isLive;
  final Widget Function(BuildContext, Object, StackTrace?)? error;
  final Widget? loading;
  final bool enableDrowsinessDetection;
  final Function(DrowsinessResult)? onDrowsinessDetected;

  const MjpegViewer({
    Key? key,
    required this.stream,
    this.isLive = true,
    this.error,
    this.loading,
    this.enableDrowsinessDetection = false,
    this.onDrowsinessDetected,
  }) : super(key: key);

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  StreamSubscription<List<int>>? _subscription;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _error;

  Timer? _detectionTimer;
  bool _isAnalyzing = false;
  List<DetectionBox> _detectionBoxes = [];
  Size? _imageSize;

  // Enhanced drowsiness detection variables
  DateTime? _eyesClosedStartTime;
  bool _hasTriggeredAlert = false;
  static const Duration _eyesClosedThreshold =
      Duration(milliseconds: 1500); // 1.5 seconds
  double _currentEyeOpenPercentage = 100.0;
  bool _isEyesClosed = false;

  // FPS tracking
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  double _currentFps = 0.0;

  // Frame skipping for better performance
  int _frameSkipCounter = 0;
  static const int _frameSkipRate =
      1; // Process every Nth frame (1 = no skip, 2 = skip every other)

  @override
  void initState() {
    super.initState();
    _startStream();

    if (widget.enableDrowsinessDetection) {
      _startDrowsinessDetection();
    }
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _stopStream();
      _startStream();
    }

    if (widget.enableDrowsinessDetection &&
        !oldWidget.enableDrowsinessDetection) {
      _startDrowsinessDetection();
    } else if (!widget.enableDrowsinessDetection &&
        oldWidget.enableDrowsinessDetection) {
      _stopDrowsinessDetection();
    }
  }

  @override
  void dispose() {
    _stopStream();
    _stopDrowsinessDetection();
    super.dispose();
  }

  void _startDrowsinessDetection() {
    // Optimized: Analyze every 1.5 seconds to reduce CPU load and improve FPS
    // This allows the video stream to run at full speed while still detecting drowsiness
    _detectionTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
      if (_currentFrame != null && !_isAnalyzing) {
        _analyzeCurrentFrame();
      }
    });
  }

  void _stopDrowsinessDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _eyesClosedStartTime = null;
    _hasTriggeredAlert = false;
    _isEyesClosed = false;
    setState(() {
      _detectionBoxes.clear();
      _currentEyeOpenPercentage = 100.0;
    });
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_currentFrame == null || _isAnalyzing) return;

    _isAnalyzing = true;

    try {
      final result = await DrowsinessDetector.analyzeImage(_currentFrame!);

      if (result != null && mounted) {
        setState(() {
          _detectionBoxes = result.detectionBoxes;
          _currentEyeOpenPercentage = result.eyeOpenPercentage;
        });

        // Check if eyes are closed (percentage < 20% or explicit closed detection)
        bool eyesClosed = result.eyeOpenPercentage < 20 ||
            result.detectionBoxes.any((box) =>
                box.className.toLowerCase().contains('clos') &&
                box.confidence > 0.3);

        if (eyesClosed) {
          // Eyes are closed
          if (_eyesClosedStartTime == null) {
            // Start tracking closed eyes
            _eyesClosedStartTime = DateTime.now();
            _hasTriggeredAlert = false;
            print('👁️ Eyes closed detected - Starting timer');
          } else {
            // Check if eyes have been closed for 1.5 seconds
            final closedDuration =
                DateTime.now().difference(_eyesClosedStartTime!);

            if (closedDuration >= _eyesClosedThreshold && !_hasTriggeredAlert) {
              print(
                  '⚠️ ALERT: Eyes closed for ${closedDuration.inMilliseconds}ms');
              _hasTriggeredAlert = true;

              // Trigger vibration alert
              await DrowsinessDetector.triggerDrowsinessAlert();

              // Notify parent
              if (widget.onDrowsinessDetected != null) {
                widget.onDrowsinessDetected!(result);
              }
            }
          }

          setState(() {
            _isEyesClosed = true;
          });
        } else {
          // Eyes are open - reset timer
          if (_eyesClosedStartTime != null) {
            print('👁️ Eyes opened - Resetting timer');
          }
          _eyesClosedStartTime = null;
          _hasTriggeredAlert = false;

          setState(() {
            _isEyesClosed = false;
          });
        }

        // Additional check: Low eye open percentage (backup trigger)
        if (result.eyeOpenPercentage < 20 && !_hasTriggeredAlert) {
          print(
              '⚠️ ALERT: Low eye percentage detected: ${result.eyeOpenPercentage.toStringAsFixed(1)}%');
          _hasTriggeredAlert = true;

          // Trigger vibration
          await DrowsinessDetector.triggerDrowsinessAlert();

          if (widget.onDrowsinessDetected != null) {
            widget.onDrowsinessDetected!(result);
          }
        }
      }
    } catch (e) {
      print('Error analyzing frame: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  void _startStream() {
    _isLoading = true;
    _error = null;

    try {
      final uri = Uri.parse(widget.stream);
      http.Client client = http.Client();

      final request = http.Request('GET', uri);
      // Optimized headers for better performance
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';

      client.send(request).then((response) {
        if (response.statusCode == 200) {
          print('✅ Stream connected: ${widget.stream}');

          _subscription = response.stream.listen(
            (chunk) {
              _processChunk(chunk);
            },
            onError: (error) {
              setState(() {
                _error = error.toString();
                _isLoading = false;
              });
            },
            onDone: () {
              print('Stream ended');
            },
            cancelOnError: true,
          );
        } else {
          setState(() {
            _error = 'HTTP ${response.statusCode}';
            _isLoading = false;
          });
        }
      }).catchError((error) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  final List<int> _buffer = [];
  static const _jpegStart = [0xFF, 0xD8];
  static const _jpegEnd = [0xFF, 0xD9];

  void _processChunk(List<int> chunk) {
    _buffer.addAll(chunk);

    while (true) {
      // Find JPEG start
      int startIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == _jpegStart[0] && _buffer[i + 1] == _jpegStart[1]) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        _buffer.clear();
        break;
      }

      // Find JPEG end
      int endIndex = -1;
      for (int i = startIndex + 2; i < _buffer.length - 1; i++) {
        if (_buffer[i] == _jpegEnd[0] && _buffer[i + 1] == _jpegEnd[1]) {
          endIndex = i + 2;
          break;
        }
      }

      if (endIndex == -1) {
        // Remove data before start marker
        if (startIndex > 0) {
          _buffer.removeRange(0, startIndex);
        }
        break;
      }

      // Extract frame
      final frame = Uint8List.fromList(_buffer.sublist(startIndex, endIndex));
      _buffer.removeRange(0, endIndex);

      // Update FPS
      _updateFps();

      // Frame skipping for better performance
      _frameSkipCounter++;
      if (_frameSkipCounter >= _frameSkipRate) {
        _frameSkipCounter = 0;

        // Update current frame
        if (mounted) {
          setState(() {
            _currentFrame = frame;
            _isLoading = false;
          });
        }
      }
    }
  }

  void _updateFps() {
    _frameCount++;
    final now = DateTime.now();
    final diff = now.difference(_lastFpsUpdate);

    if (diff.inMilliseconds >= 1000) {
      _currentFps = _frameCount / (diff.inMilliseconds / 1000.0);
      _frameCount = 0;
      _lastFpsUpdate = now;

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: widget.error?.call(context, _error!, null) ??
            Text('Error: $_error'),
      );
    }

    if (_isLoading || _currentFrame == null) {
      return Center(
        child: widget.loading ?? const CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Video feed - Full screen without black bars
            SizedBox.expand(
              child: Image.memory(
                _currentFrame!,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            ),

            // Detection overlay
            if (widget.enableDrowsinessDetection && _detectionBoxes.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: DetectionOverlayPainter(
                    detectionBoxes: _detectionBoxes,
                    imageSize: _imageSize,
                    isEyesClosed: _isEyesClosed,
                  ),
                ),
              ),

            // Eye open percentage display (top-left)
            if (widget.enableDrowsinessDetection)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getPercentageColor(_currentEyeOpenPercentage)
                        .withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isEyesClosed
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentEyeOpenPercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // FPS Counter (top-right)
            if (widget.enableDrowsinessDetection)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentFps.toStringAsFixed(1)} FPS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Warning indicator when eyes closed
            if (widget.enableDrowsinessDetection && _isEyesClosed)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _hasTriggeredAlert
                              ? 'DROWSINESS ALERT!'
                              : 'Eyes Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}

// Enhanced painter with green/red boxes
class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionBox> detectionBoxes;
  final Size? imageSize;
  final bool isEyesClosed;

  DetectionOverlayPainter({
    required this.detectionBoxes,
    required this.imageSize,
    required this.isEyesClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detectionBoxes.isEmpty) return;

    for (var box in detectionBoxes) {
      // Determine if this is an eye detection
      bool isEye = box.className.toLowerCase().contains('ope') ||
          box.className.toLowerCase().contains('clos') ||
          box.className.toLowerCase().contains('eye');

      // Determine box color based on detection
      Color boxColor;
      double strokeWidth;

      if (isEye) {
        // For eyes: Green if open, Red if closed
        bool isClosed =
            box.className.toLowerCase().contains('clos') || box.isDrowsy;
        boxColor = isClosed ? Colors.red : Colors.green;
        strokeWidth = 3.0;
      } else {
        // For other detections (yawn, etc.)
        boxColor = box.isDrowsy ? Colors.red : Colors.blue;
        strokeWidth = 2.5;
      }

      // Create paint for box outline
      final paint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      // Create paint for background
      final bgPaint = Paint()
        ..color = boxColor.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      // Scale coordinates to canvas size
      final rect = Rect.fromLTWH(
        box.x * size.width,
        box.y * size.height,
        box.width * size.width,
        box.height * size.height,
      );

      // Draw semi-transparent background
      canvas.drawRect(rect, bgPaint);

      // Draw box outline
      canvas.drawRect(rect, paint);

      // Draw confidence label with background
      final confidenceText = '${(box.confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: confidenceText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Draw label background
      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 24,
        textPainter.width + 12,
        20,
      );

      final labelBgPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelBgPaint,
      );

      // Draw text
      textPainter.paint(
        canvas,
        Offset(rect.left + 6, rect.top - 22),
      );
    }

    // Draw corner indicators for eyes
    for (var box in detectionBoxes) {
      bool isEye = box.className.toLowerCase().contains('ope') ||
          box.className.toLowerCase().contains('clos') ||
          box.className.toLowerCase().contains('eye');

      if (isEye) {
        bool isClosed =
            box.className.toLowerCase().contains('clos') || box.isDrowsy;
        Color cornerColor = isClosed ? Colors.red : Colors.green;

        final cornerPaint = Paint()
          ..color = cornerColor
          ..style = PaintingStyle.fill;

        final rect = Rect.fromLTWH(
          box.x * size.width,
          box.y * size.height,
          box.width * size.width,
          box.height * size.height,
        );

        // Draw corner circles
        final cornerRadius = 4.0;
        canvas.drawCircle(rect.topLeft, cornerRadius, cornerPaint);
        canvas.drawCircle(rect.topRight, cornerRadius, cornerPaint);
        canvas.drawCircle(rect.bottomLeft, cornerRadius, cornerPaint);
        canvas.drawCircle(rect.bottomRight, cornerRadius, cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) {
    return detectionBoxes != oldDelegate.detectionBoxes ||
        isEyesClosed != oldDelegate.isEyesClosed;
  }
}
