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
  StreamSubscription<Uint8List>? _subscription;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _error;

  Timer? _detectionTimer;
  bool _isAnalyzing = false;
  List<DetectionBox> _detectionBoxes = [];
  Size? _imageSize;

  // Detection settings
  DateTime? _drowsinessStartTime;
  bool _isCurrentlyVibrating = false;
  Timer? _continuousVibrationTimer;
  static const Duration _drowsinessThreshold =
      Duration(milliseconds: 1500); // 1.5 seconds
  double _currentEyeOpenPercentage = 100.0;
  int _consecutiveDrowsyDetections = 0; // Track consecutive drowsy frames

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
    // Analyze every 1 second for faster detection
    _detectionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentFrame != null && !_isAnalyzing) {
        _analyzeCurrentFrame();
      }
    });
  }

  void _stopDrowsinessDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _stopContinuousVibration();
    _drowsinessStartTime = null;
    _isCurrentlyVibrating = false;
    _consecutiveDrowsyDetections = 0;
    setState(() {
      _detectionBoxes.clear();
    });
  }

  void _startContinuousVibration() {
    if (_isCurrentlyVibrating) return;

    _isCurrentlyVibrating = true;
    print('🔄 STARTING CONTINUOUS VIBRATION');

    // Vibrate immediately
    DrowsinessDetector.triggerDrowsinessAlert();

    // Continue vibrating every 2 seconds
    _continuousVibrationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_isCurrentlyVibrating) {
        print('🔄 REPEATING VIBRATION');
        DrowsinessDetector.triggerDrowsinessAlert();
      }
    });
  }

  void _stopContinuousVibration() {
    if (!_isCurrentlyVibrating) return;

    print('🛑 STOPPING CONTINUOUS VIBRATION');
    _isCurrentlyVibrating = false;
    _continuousVibrationTimer?.cancel();
    _continuousVibrationTimer = null;
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_currentFrame == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      print('');
      print(
          '=== FRAME ANALYSIS (${DateTime.now().millisecondsSinceEpoch % 100000}) ===');

      final result = await DrowsinessDetector.analyzeImage(_currentFrame!);

      if (result != null && mounted) {
        setState(() {
          _detectionBoxes = result.detectionBoxes;
          _currentEyeOpenPercentage = result.eyeOpenPercentage;
        });

        print(
            'Predictions: ${result.totalPredictions} | Eyes: ${result.eyeOpenPercentage.toStringAsFixed(1)}% | Drowsy: ${result.isDrowsy}');

        // Enhanced drowsiness detection - multiple criteria
        bool isDrowsyNow = false;

        // Criterion 1: API says drowsy
        if (result.isDrowsy) {
          isDrowsyNow = true;
          print('  - Criterion 1: Closed eyes detected');
        }

        // Criterion 2: Eye opening percentage very low (< 30%)
        if (result.eyeOpenPercentage < 30.0) {
          isDrowsyNow = true;
          print(
              '  - Criterion 2: Eye opening too low (${result.eyeOpenPercentage.toStringAsFixed(1)}%)');
        }

        // Criterion 3: Multiple closed eye detections
        int closedEyeCount = result.detectionBoxes
            .where((box) =>
                box.className.contains('clos') ||
                box.className.contains('shut'))
            .length;

        if (closedEyeCount > 0) {
          isDrowsyNow = true;
          print('  - Criterion 3: $closedEyeCount closed eye detection(s)');
        }

        if (isDrowsyNow) {
          _consecutiveDrowsyDetections++;
          print(
              'DROWSY STATE DETECTED (consecutive: $_consecutiveDrowsyDetections)');

          // Start timer on first detection
          if (_drowsinessStartTime == null) {
            _drowsinessStartTime = DateTime.now();
            print('DROWSINESS TIMER STARTED');
          } else {
            final duration = DateTime.now().difference(_drowsinessStartTime!);
            final ms = duration.inMilliseconds;

            print('Timer: ${ms}ms / ${_drowsinessThreshold.inMilliseconds}ms');

            // Trigger after 1.5 seconds
            if (duration >= _drowsinessThreshold) {
              if (!_isCurrentlyVibrating) {
                print('');
                print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
                print('CRITICAL DROWSINESS ALERT - 1.5 SECONDS EXCEEDED');
                print('Duration: ${ms}ms');
                print('Consecutive detections: $_consecutiveDrowsyDetections');
                print(
                    'Eye opening: ${result.eyeOpenPercentage.toStringAsFixed(1)}%');
                print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
                print('');

                // Start continuous vibration
                _startContinuousVibration();

                // UI Callback
                if (widget.onDrowsinessDetected != null) {
                  widget.onDrowsinessDetected!(result);
                }
              } else {
                print('Continuous vibration active (${ms}ms total)');
              }
            }
          }
        } else {
          // Eyes open - reset everything
          if (_drowsinessStartTime != null ||
              _consecutiveDrowsyDetections > 0) {
            print('EYES OPENED - Resetting all timers');
            if (_isCurrentlyVibrating) {
              print('DRIVER WOKE UP - Stopping vibration');
            }
          }

          _drowsinessStartTime = null;
          _consecutiveDrowsyDetections = 0;
          _stopContinuousVibration();
        }
      }
    } catch (e, stackTrace) {
      print('ANALYSIS ERROR: $e');
      print('Stack: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _startStream() {
    if (widget.stream.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _subscription = _mjpegStream(widget.stream).listen(
      (frame) {
        if (mounted) {
          setState(() {
            _currentFrame = frame;
            _isLoading = false;
            _error = null;
          });
          _getImageSize(frame);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _getImageSize(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _imageSize =
            Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      });
    } catch (e) {
      print('Error getting image size: $e');
    }
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  Stream<Uint8List> _mjpegStream(String url) async* {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to connect to stream');
      }

      const boundary = '123456789000000000000987654321';
      List<int> buffer = [];
      bool inImage = false;

      await for (List<int> chunk in response.stream) {
        buffer.addAll(chunk);

        if (!inImage) {
          String bufferStr = String.fromCharCodes(buffer);
          int startIndex = bufferStr.indexOf('\r\n\r\n');

          if (startIndex != -1) {
            inImage = true;
            buffer = buffer.sublist(startIndex + 4);
          }
        }

        if (inImage) {
          String bufferStr = String.fromCharCodes(buffer);
          int endIndex = bufferStr.indexOf(boundary);

          if (endIndex != -1) {
            List<int> imageData = buffer.sublist(0, endIndex);

            if (imageData.isNotEmpty) {
              yield Uint8List.fromList(imageData);
            }

            buffer = buffer.sublist(endIndex + boundary.length);
            inImage = false;
          }
        }

        if (buffer.length > 1024 * 1024) {
          buffer.clear();
          inImage = false;
        }
      }
    } catch (e) {
      yield* Stream.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.error?.call(context, _error!, null) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Stream Error',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          );
    }

    if (_isLoading) {
      return widget.loading ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Connecting to camera...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          );
    }

    if (_currentFrame == null) {
      return const Center(
        child: Text('No video data', style: TextStyle(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        // Video feed
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Image.memory(
                  _currentFrame!,
                  fit: BoxFit.cover,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  gaplessPlayback: true,
                ),

                // Detection overlay
                if (widget.enableDrowsinessDetection &&
                    _detectionBoxes.isNotEmpty)
                  ...buildDetectionOverlay(constraints),
              ],
            );
          },
        ),

        // AI Status indicator with Eye Opening Percentage
        if (widget.enableDrowsinessDetection)
          Positioned(
            top: 10,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAnalyzing ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAnalyzing ? Icons.psychology : Icons.visibility,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAnalyzing ? 'Analyzing...' : 'AI Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Eye Opening Percentage Display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentEyeOpenPercentage > 50
                        ? Colors.green
                        : _currentEyeOpenPercentage > 20
                            ? Colors.orange
                            : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentEyeOpenPercentage > 50
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Eyes: ${_currentEyeOpenPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Timer indicator (shows when drowsiness is being tracked)
        if (widget.enableDrowsinessDetection &&
            _drowsinessStartTime != null &&
            !_isCurrentlyVibrating)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(DateTime.now().difference(_drowsinessStartTime!).inMilliseconds / 1000).toStringAsFixed(1)}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Detection count
        if (widget.enableDrowsinessDetection &&
            _detectionBoxes.isNotEmpty &&
            _drowsinessStartTime == null)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Detections: ${_detectionBoxes.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Vibration status indicator
        if (widget.enableDrowsinessDetection && _isCurrentlyVibrating)
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.8),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'WAKE UP! DROWSINESS DETECTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> buildDetectionOverlay(BoxConstraints constraints) {
    if (_imageSize == null) return [];

    final scaleX = constraints.maxWidth / _imageSize!.width;
    final scaleY = constraints.maxHeight / _imageSize!.height;

    return _detectionBoxes.map((detection) {
      final left = detection.x * scaleX;
      final top = detection.y * scaleY;
      final width = detection.width * scaleX;
      final height = detection.height * scaleY;

      // Ensure bounds are within screen
      final adjustedLeft = left < 0
          ? 0.0
          : (left + width > constraints.maxWidth
              ? constraints.maxWidth - width
              : left);
      final adjustedTop = top < 0 ? 0.0 : top;
      final adjustedWidth =
          width > constraints.maxWidth ? constraints.maxWidth - 10 : width;

      // Create label text
      final confidenceText = '${(detection.confidence * 100).toInt()}%';
      final labelText = '${detection.className} $confidenceText';

      return Positioned(
        left: adjustedLeft,
        top: adjustedTop,
        child: Container(
          width: adjustedWidth < 50 ? 50 : adjustedWidth,
          height: height < 30 ? 30 : height,
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth - 20,
            minWidth: 40,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: detection.isDrowsy ? Colors.red : Colors.green,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: detection.isDrowsy ? Colors.red : Colors.green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
            child: Text(
              labelText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }).toList();
  }
}
