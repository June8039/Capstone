import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';


class HeelRaiseScreen extends StatefulWidget {
  final Map<String, dynamic> baselineValues;
  final int initialLensFacing;
  const HeelRaiseScreen({
    super.key,
    required this.baselineValues,
    this.initialLensFacing = 0,
  });

  @override
  State<HeelRaiseScreen> createState() => _HeelRaiseScreenState();
}

class _HeelRaiseScreenState extends State<HeelRaiseScreen> {
  static const _methodChannel =
  MethodChannel('com.example.capstone_healthcare_app/heel_raise');
  static const _eventChannel =
  EventChannel('com.example.capstone_healthcare_app/heel_raise_events');

  int _count = 0;
  bool _isCompleted = false;
  StreamSubscription? _eventSubscription;

  FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  int? _pendingCount;

  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoPlayerFuture;

  late Stopwatch _stopwatch;
  late Timer _timer;
  String _elapsedTime = "00:00";

  @override
  void initState() {
    super.initState();
    debugPrint("HeelRaiseScreen initialLensFacing: ${widget.initialLensFacing}");
    _initTts();

    _videoController = VideoPlayerController.asset(
      'assets/videos/heel_raise_example.mp4',
    );
    _initializeVideoPlayerFuture = _videoController.initialize().then((_) {
      setState(() {});
      _videoController.setLooping(true); // 반복 재생
      _videoController.setVolume(0.0);
      _videoController.play();           // 자동 재생
    });

    _stopwatch = Stopwatch();
    // 타이머 시작
    _startTimer();
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _stopwatch.elapsed;
      setState(() {
        _elapsedTime =
        "${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timer.cancel();
  }

  @override
  void dispose() {
    _stopTimer();
    _methodChannel.invokeMethod('cancel');
    _eventSubscription?.cancel();
    _flutterTts.stop();
    _videoController.dispose();
    super.dispose();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_pendingCount != null) {
        final next = _pendingCount!;
        _pendingCount = null;
        _speakCount(next);
      }
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      _pendingCount = null;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      _pendingCount = null;
    });
  }

  void _flipCamera() {
    _methodChannel.invokeMethod('flipCamera');
  }

  void _startExercise() {
    if (widget.baselineValues == null) {
      print('baselineValues가 null입니다!');
      return;
    }

    if (!widget.baselineValues.containsKey('left_heel_y') ||
        !widget.baselineValues.containsKey('right_heel_y')) {
      print('필수 키 누락: left_heel_y 또는 right_heel_y');
      return;
    }

    final convertedValues = {
      'left_heel_y': (widget.baselineValues['left_heel_y'] as num).toDouble(),
      'right_heel_y': (widget.baselineValues['right_heel_y'] as num).toDouble(),
    };
    _methodChannel.invokeMethod('resetCount');
    _methodChannel.invokeMethod('initialize', convertedValues);
  }

  void _subscribeEventChannel() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        if (event['type'] == 'pose_update') {
          final newCount = event['count'] ?? _count;
          if (newCount > _count) {
            _speakCount(newCount);
          }
          setState(() => _count = newCount);
          if (event['status'] == 'completed') {
            setState(() => _isCompleted = true);
            _stopTimer();
            _videoController.pause(); // 운동 완료 시 영상 멈춤
          }
        }
      }
    });
  }

  Future<void> _speakCount(int count) async {
    if (_isSpeaking) {
      _pendingCount = count;
      return;
    }

    _isSpeaking = true;
    await _flutterTts.speak("$count회");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 상단 제목과 나가기 버튼
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: const Center(
                        child: Text(
                          '발 뒤꿈치 들기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '나가기',
                      ),
                    ),
                  ],
                ),
                // 타이머 표시
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    '경과 시간: $_elapsedTime',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            AndroidView(
                              viewType: 'NativeHeelRaiseView',
                              creationParams: {
                                'baselineValues': widget.baselineValues,
                                'initialLensFacing': widget.initialLensFacing.toInt(),
                              },
                              creationParamsCodec: StandardMessageCodec(),
                              onPlatformViewCreated: (viewId) {
                                _subscribeEventChannel();
                                _startExercise();
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[800],
                      ),
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: FutureBuilder(
                          future: _initializeVideoPlayerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done) {
                              return VideoPlayer(_videoController);
                            } else {
                              return const Center(child: CircularProgressIndicator());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            '횟수 : $_count회',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cameraswitch,
                            color: Colors.white, size: 28),
                        onPressed: _flipCamera,
                        tooltip: '카메라 전환',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isCompleted)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '운동 완료!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
