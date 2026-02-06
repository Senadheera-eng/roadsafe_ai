import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MjpegViewer extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final VoidCallback? onFrameReceived;
  final Function(Uint8List)? onFrameCaptured; // Callback for frame capture

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.onFrameReceived,
    this.onFrameCaptured,
  });

  @override
  State<MjpegViewer> createState() => MjpegViewerState();
}

class MjpegViewerState extends State<MjpegViewer> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  bool _isDisposed = false;
  bool _isPaused = false;

  // Public getter for current frame (used by live_camera_page for detection)
  Uint8List? get currentFrame => _currentFrame;

  /// Whether the stream is currently paused (e.g., during alarm)
  bool get isPaused => _isPaused;

  /// Stop the stream programmatically (e.g., when drowsiness alarm triggers)
  void stopStream() {
    _isPaused = true;
    _stopStream();
    if (mounted) {
      setState(() {});
    }
  }

  /// Restart the stream after it was paused (e.g., after alarm is dismissed)
  void restartStream() {
    _isPaused = false;
    _error = null;
    _currentFrame = null;
    _startStream();
  }

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopStream();
    super.dispose();
  }

  Future<void> _startStream() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('📹 Starting MJPEG stream: ${widget.streamUrl}');

      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));

      // Add headers for better streaming
      request.headers.addAll({
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
      });

      final response = await _httpClient!.send(request);

      print('📡 Stream response: ${response.statusCode}');
      print('📡 Content-Type: ${response.headers['content-type']}');

      if (response.statusCode != 200) {
        throw Exception('Stream error: ${response.statusCode}');
      }

      List<int> buffer = [];
      bool inFrame = false;
      int jpegStart = -1;
      int frameCount = 0;

      _streamSubscription = response.stream.listen(
        (chunk) {
          if (_isDisposed) return;

          // Add new data to buffer
          buffer.addAll(chunk);

          // Process buffer to find and extract JPEG frames
          while (buffer.length > 2) {
            if (!inFrame) {
              // Look for JPEG start marker (0xFFD8)
              for (int i = 0; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                  jpegStart = i;
                  inFrame = true;
                  break;
                }
              }

              if (!inFrame) {
                // No start marker found, keep only last byte in case it's 0xFF
                if (buffer.length > 1) {
                  buffer = [buffer.last];
                }
                break;
              }
            }

            if (inFrame) {
              // Look for JPEG end marker (0xFFD9)
              for (int i = jpegStart + 2; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
                  // Found complete JPEG frame
                  final frame = Uint8List.fromList(
                    buffer.sublist(jpegStart, i + 2),
                  );

                  frameCount++;

                  if (!_isDisposed && mounted) {
                    setState(() {
                      _currentFrame = frame;
                      _isLoading = false;
                    });

                    // Notify parent about new frame (for FPS counting)
                    widget.onFrameReceived?.call();

                    // Send frame to parent for processing (for Roboflow detection)
                    widget.onFrameCaptured?.call(frame);

                    if (frameCount % 30 == 0) {
                      print(
                          '📸 Received $frameCount frames (${frame.length} bytes)');
                    }
                  }

                  // Remove processed frame from buffer
                  buffer.removeRange(0, i + 2);
                  inFrame = false;
                  jpegStart = -1;
                  break;
                }
              }

              // Prevent buffer overflow (2MB limit)
              if (buffer.length > 2 * 1024 * 1024) {
                print(
                    '⚠️ Buffer overflow (${buffer.length} bytes), resetting...');
                buffer.clear();
                inFrame = false;
                jpegStart = -1;
              }

              // If we're still in a frame but don't have the end marker yet,
              // wait for more data
              if (inFrame && buffer.length < 1024 * 1024) {
                break;
              }
            }
          }
        },
        onError: (error) {
          print('❌ Stream error: $error');
          if (!_isDisposed && mounted) {
            setState(() {
              _error = 'Stream error: $error';
              _isLoading = false;
            });
          }
        },
        onDone: () {
          print('🔚 Stream ended');
          if (!_isDisposed && mounted) {
            setState(() {
              _error = 'Stream ended unexpectedly';
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );

      print('✅ MJPEG stream started successfully');
    } catch (e) {
      print('❌ Connection error: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _error = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _stopStream() {
    print('🛑 Stopping MJPEG stream...');
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _httpClient?.close();
    _httpClient = null;
  }

  void _retry() {
    print('🔄 Retrying stream connection...');
    _stopStream();
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading camera stream...',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.streamUrl,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white54,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Paused state (alarm active — stream intentionally stopped)
    if (_isPaused) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_rounded,
                size: 80, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Stream Paused',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Drowsiness alert active',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '🔊 Buzzer sounding on ESP32',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.redAccent),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Stream Error',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Copy stream URL to clipboard for debugging
                print('Stream URL: ${widget.streamUrl}');
              },
              child: Text(
                'Stream URL: ${widget.streamUrl}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Waiting for frames state
    if (_currentFrame == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Waiting for frames...',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Stream connected, receiving data...',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Display current frame
    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true, // Smooth transitions between frames
      errorBuilder: (context, error, stackTrace) {
        print('❌ Image decode error: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to decode frame',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Frame size: ${_currentFrame!.length} bytes',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}
