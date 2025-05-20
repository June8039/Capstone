import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SquatScreen extends StatefulWidget {
  const SquatScreen({super.key});

  @override
  State<SquatScreen> createState() => _SquatScreenState();
}

class _SquatScreenState extends State<SquatScreen> {
  static const _methodChannel =
  MethodChannel('com.example.capstone_healthcare_app/squat');
  static const _eventChannel =
  EventChannel('com.example.capstone_healthcare_app/squat_events');

  int _count = 0;
  bool _isCompleted = false;
  StreamSubscription? _eventSubscription;

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  int? _pendingCount;

  @override
  void initState() {
    super.initState();
    _initTts();
    _subscribeEventChannel();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
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

  void _subscribeEventChannel() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
        if (event is Map) {
          debugPrint("이벤트 수신: $event");
          if (event['type'] == 'pose_update') {
            final newCount = event['count'] ?? _count;
            if (newCount > _count) {
              _speakCount(newCount);
            }
            setState(() => _count = newCount);
            if (event['status'] == 'completed') {
              setState(() => _isCompleted = true);
            }
          }
        }
      },
      onError: (error) => debugPrint("이벤트 오류: $error"),
    );
  }

  Future<void> _speakCount(int count) async {
    if (_isSpeaking) {
      _pendingCount = count;
      return;
    }

    _isSpeaking = true;
    await _flutterTts.speak("$count회");
  }

  void _startExercise() {
    _methodChannel.invokeMethod('startSquat');
  }

  void _flipCamera() {
    _methodChannel.invokeMethod('flipCamera');
  }

  @override
  void dispose() {
    _methodChannel.invokeMethod('cancel');
    _eventSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
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
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: const Center(
                        child: Text(
                          '스쿼트',
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
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            AndroidView(
                              viewType: 'NativeSquatView',
                              creationParams: {},
                              creationParamsCodec: StandardMessageCodec(),
                              onPlatformViewCreated: (id) {
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
                        child: Container(
                          color: Colors.black,
                          child: const Center(
                            child: Text('스쿼트 예시 영상', style: TextStyle(color: Colors.white54)),
                          ),
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
