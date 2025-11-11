import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegViewer extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Duration timeout;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.loadingWidget,
    this.errorWidget,
    this.timeout = const Duration(seconds: 10),
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription<Uint8List>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startStream() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🎥 Starting MJPEG stream: ${widget.streamUrl}');

      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response =
          await http.Client().send(request).timeout(widget.timeout);

      if (response.statusCode == 200) {
        print('✅ Stream connected successfully');

        _streamSubscription = _parseMjpegStream(response.stream).listen(
          (frame) {
            if (mounted) {
              setState(() {
                _currentFrame = frame;
                _isLoading = false;
                _hasError = false;
              });
            }
          },
          onError: (error) {
            print('❌ Stream error: $error');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.toString();
                _isLoading = false;
              });
            }
          },
          onDone: () {
            print('ℹ️ Stream ended');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Stream ended';
                _isLoading = false;
              });
            }
          },
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Failed to start stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Stream<Uint8List> _parseMjpegStream(Stream<List<int>> stream) async* {
    final buffer = <int>[];
    const jpegStart = [0xFF, 0xD8];
    const jpegEnd = [0xFF, 0xD9];

    await for (var chunk in stream) {
      buffer.addAll(chunk);

      int startIdx = -1;
      int endIdx = -1;

      for (int i = 0; i < buffer.length - 1; i++) {
        if (buffer[i] == jpegStart[0] && buffer[i + 1] == jpegStart[1]) {
          startIdx = i;
        }
        if (buffer[i] == jpegEnd[0] && buffer[i + 1] == jpegEnd[1]) {
          endIdx = i + 1;
          break;
        }
      }

      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        final frame = Uint8List.fromList(buffer.sublist(startIdx, endIdx + 1));
        yield frame;

        buffer.removeRange(0, endIdx + 1);
      }

      if (buffer.length > 1024 * 1024) {
        buffer.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to camera...'),
              ],
            ),
          );
    }

    if (_hasError) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Stream Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _startStream,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_currentFrame == null) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Image.memory(
        _currentFrame!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
          );
        },
      ),
    );
  }
}
