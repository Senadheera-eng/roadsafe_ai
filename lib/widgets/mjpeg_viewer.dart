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

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.onFrameReceived,
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  bool _isDisposed = false;

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
      final response = await _httpClient!.send(request);

      print('📡 Stream response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Stream error: ${response.statusCode}');
      }

      List<int> buffer = [];
      bool inFrame = false;
      int jpegStart = -1;

      _streamSubscription = response.stream.listen(
        (chunk) {
          if (_isDisposed) return;

          buffer.addAll(chunk);

          // Process buffer to find JPEG frames
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
                // No start marker found, keep last byte
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

                  if (!_isDisposed && mounted) {
                    setState(() {
                      _currentFrame = frame;
                      _isLoading = false;
                    });

                    // Notify parent about new frame
                    widget.onFrameReceived?.call();
                  }

                  // Remove processed data
                  buffer.removeRange(0, i + 2);
                  inFrame = false;
                  jpegStart = -1;
                  break;
                }
              }

              // Prevent buffer overflow
              if (buffer.length > 2 * 1024 * 1024) {
                // 2MB limit
                print('⚠️ Buffer overflow, resetting...');
                buffer.clear();
                inFrame = false;
                jpegStart = -1;
              }

              break; // Wait for more data
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
              _error = 'Stream ended';
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );
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
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _httpClient?.close();
    _httpClient = null;
  }

  void _retry() {
    _stopStream();
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      );
    }

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
          ],
        ),
      );
    }

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
          ],
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
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
            ],
          ),
        );
      },
    );
  }
}
