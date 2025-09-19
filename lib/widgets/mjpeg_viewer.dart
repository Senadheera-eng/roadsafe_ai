import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegViewer extends StatefulWidget {
  final String stream;
  final bool isLive;
  final Widget Function(BuildContext, Object, StackTrace?)? error;
  final Widget? loading;

  const MjpegViewer({
    Key? key,
    required this.stream,
    this.isLive = true,
    this.error,
    this.loading,
  }) : super(key: key);

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  StreamSubscription<Uint8List>? _subscription;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
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

      const boundary = '\r\n--123456789000000000000987654321\r\n';
      List<int> buffer = [];
      bool inImage = false;

      await for (List<int> chunk in response.stream) {
        buffer.addAll(chunk);

        if (!inImage) {
          // Look for image start
          String bufferStr = String.fromCharCodes(buffer);
          int startIndex = bufferStr.indexOf('\r\n\r\n');

          if (startIndex != -1) {
            inImage = true;
            buffer = buffer.sublist(startIndex + 4);
          }
        }

        if (inImage) {
          // Look for boundary (end of image)
          String bufferStr = String.fromCharCodes(buffer);
          int endIndex = bufferStr.indexOf(boundary);

          if (endIndex != -1) {
            // Extract image data
            List<int> imageData = buffer.sublist(0, endIndex);

            if (imageData.isNotEmpty) {
              yield Uint8List.fromList(imageData);
            }

            // Reset for next image
            buffer = buffer.sublist(endIndex + boundary.length);
            inImage = false;
          }
        }

        // Prevent buffer from growing too large
        if (buffer.length > 1024 * 1024) {
          // 1MB limit
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
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Stream Error',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
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
                Text(
                  'Connecting to camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
    }

    if (_currentFrame == null) {
      return const Center(
        child: Text(
          'No video data',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Image Error',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}
