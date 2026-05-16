import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FaceScanRecordScreen extends StatefulWidget {
  const FaceScanRecordScreen({super.key});

  @override
  State<FaceScanRecordScreen> createState() => _FaceScanRecordScreenState();
}

class _FaceScanRecordScreenState extends State<FaceScanRecordScreen> {
  static const int _maxDurationSeconds = 30;
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _error;

  XFile? _recorded;
  VideoPlayerController? _playback;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _disposePlayback() async {
    await _playback?.dispose();
    _playback = null;
    _recorded = null;
  }

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await _disposePlayback();
      if (!mounted) return;
      setState(() {});
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;
        setState(() => _elapsed += 1);
        if (_elapsed >= _maxDurationSeconds) {
          await _stopRecording(autoStop: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start recording: $e')));
    }
  }

  Future<void> _initPlayback(XFile file) async {
    await _playback?.dispose();
    if (!mounted) return;
    VideoPlayerController ctrl;
    if (kIsWeb) {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(file.path));
    } else {
      ctrl = VideoPlayerController.file(File(file.path));
    }
    try {
      await ctrl.initialize().timeout(const Duration(seconds: 15));
    } catch (e) {
      await ctrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open preview: $e')),
      );
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    await ctrl.setLooping(true);
    await ctrl.play();
    setState(() {
      _recorded = file;
      _playback = ctrl;
    });
  }

  Future<void> _stopRecording({bool autoStop = false}) async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return;
    try {
      final file = await c.stopVideoRecording();
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _recording = false);
      await _initPlayback(file);
      if (autoStop && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-stopped at $_maxDurationSeconds seconds.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to stop recording: $e')));
    }
  }

  Future<void> _discardRecordingAndRetry() async {
    await _disposePlayback();
    if (!mounted) return;
    setState(() {});
  }

  void _confirmRecording() {
    final file = _recorded;
    if (file == null) return;
    Navigator.of(context).pop(file);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_playback?.dispose());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final playback = _playback;
    final hasPlayback =
        playback != null && playback.value.isInitialized && _recorded != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Record Face Video (max 30s)'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : c == null
          ? const Center(
              child: Text(
                'Camera unavailable',
                style: TextStyle(color: Colors.white),
              ),
            )
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.black,
                        child: hasPlayback
                            ? SizedBox(
                                width: double.infinity,
                                height: 300,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: playback.value.size.width,
                                    height: playback.value.size.height,
                                    child: VideoPlayer(playback),
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 400,
                                child: ClipRRect(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: c.value.aspectRatio,
                                      child: CameraPreview(c),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!hasPlayback)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_recording) ...[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _recording
                                ? 'REC · $_elapsed / ${_maxDurationSeconds}s'
                                : '$_elapsed / ${_maxDurationSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: hasPlayback
                        ? Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      await _discardRecordingAndRetry();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    child: const Text('Record again'),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _confirmRecording,
                                    child: const Text('Use this video'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_recording)
                                ElevatedButton.icon(
                                  onPressed: _startRecording,
                                  icon: const Icon(Icons.videocam),
                                  label: const Text('Start recording'),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _stopRecording(autoStop: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB71C1C),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Stop'),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
