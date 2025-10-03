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
    _detectionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_currentFrame != null && !_isAnalyzing) {
        _analyzeCurrentFrame();
      }
    });
  }

  void _stopDrowsinessDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    DrowsinessDetector.resetClosedEyeTimer();
    setState(() {
      _detectionBoxes.clear();
    });
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_currentFrame == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      print('Analyzing frame for drowsiness...');

      final result = await DrowsinessDetector.analyzeImage(_currentFrame!);

      if (result != null && mounted) {
        setState(() {
          _detectionBoxes = result.detectionBoxes;
        });

        print('Analysis complete - Predictions: ${result.totalPredictions}');
        print('Is Drowsy: ${result.isDrowsy}');
        print('Closed eye duration: ${result.closedEyeDurationSeconds}s');

        for (var box in result.detectionBoxes) {
          print(
              'Box: ${box.className} ${(box.confidence * 100).toInt()}% - Drowsy: ${box.isDrowsy}');
        }

        if (result.isDrowsy) {
          print('DROWSINESS DETECTED! Triggering alerts...');

          await DrowsinessDetector.triggerDrowsinessAlert();

          if (widget.onDrowsinessDetected != null) {
            print('Calling drowsiness callback...');
            widget.onDrowsinessDetected!(result);
          }
        } else {
          print('Driver appears alert');
        }
      } else {
        print('Analysis failed - no result');
      }
    } catch (e) {
      print('Frame analysis error: $e');
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
      if (mounted) {
        setState(() {
          _imageSize =
              Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        });
      }
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

      request.headers['Connection'] = 'keep-alive';

      final response = await client.send(request).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Stream connection timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      const boundary = '123456789000000000000987654321';
      List<int> buffer = [];
      bool inImage = false;
      int frameCount = 0;

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
              frameCount++;
              if (frameCount % 2 == 0) {
                yield Uint8List.fromList(imageData);
              }
            }

            buffer = buffer.sublist(endIndex + boundary.length);
            inImage = false;
          }
        }

        if (buffer.length > 500 * 1024) {
          buffer.clear();
          inImage = false;
          print('Buffer overflow - cleared');
        }
      }
    } catch (e) {
      print('Stream error: $e');
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
                if (widget.enableDrowsinessDetection &&
                    _detectionBoxes.isNotEmpty)
                  ...buildDetectionOverlay(constraints),
              ],
            );
          },
        ),
        if (widget.enableDrowsinessDetection)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),
        if (widget.enableDrowsinessDetection && _detectionBoxes.isNotEmpty)
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

      final adjustedLeft = left < 0
          ? 0.0
          : (left + width > constraints.maxWidth
              ? constraints.maxWidth - width
              : left);
      final adjustedTop = top < 0 ? 0.0 : top;
      final adjustedWidth =
          width > constraints.maxWidth ? constraints.maxWidth - 10 : width;

      final boxColor = detection.isDrowsy ? Colors.red : Colors.green;

      final labelText =
          '${detection.className} ${(detection.confidence * 100).toInt()}%';

      return Positioned(
        left: adjustedLeft,
        top: adjustedTop,
        child: Container(
          width: adjustedWidth < 50 ? 50 : adjustedWidth,
          height: height < 20 ? 20 : height,
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth - 20,
            minWidth: 40,
            minHeight: 20,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: boxColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: boxColor,
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
