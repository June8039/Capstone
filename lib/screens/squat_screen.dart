import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoPlayerFuture;

  late Stopwatch _stopwatch;
  late Timer _timer;
  String _elapsedTime = "00:00";

  File? _recordedVideoFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _subscribeEventChannel();

    _videoController = VideoPlayerController.asset(
      'assets/videos/squat_example.mp4',
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
  /// 녹화 시작: native 쪽 MediaRecorder에 저장 경로 전달
  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      _recordedVideoFile = File('${tempDir.path}/squat_$ts.mp4');
      await _methodChannel.invokeMethod('startRecording', {
        'outputPath': _recordedVideoFile!.path,
      });
    } catch (e) {
      print('녹화 시작 오류: $e');
    }
  }

  /// 녹화 중지: native 쪽 MediaRecorder stop
  Future<void> _stopRecording() async {
    try {
      await _methodChannel.invokeMethod('stopRecording');
    } catch (e) {
      print('녹화 중지 오류: $e');
    }
  }

  /// 업로드: Firebase Storage에 putFile 후 스낵바 알림
  Future<void> _uploadVideo() async {
    if (_recordedVideoFile == null) return;
    setState(() => _isUploading = true);

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('videos/squat_$ts.mp4');
      final task = ref.putFile(_recordedVideoFile!);

      task.snapshotEvents.listen((snapshot) {
        final progress =
            snapshot.bytesTransferred / snapshot.totalBytes * 100;
        print('업로드 진행률: ${progress.toStringAsFixed(1)}%');
      });

      await task.whenComplete(() => null);
      await ref.getDownloadURL(); // 필요 시 URL 활용

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 영상이 저장되었습니다.')),
      );
    } catch (e) {
      print('업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 저장 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() => _isUploading = false);
      try {
        await _recordedVideoFile?.delete();
      } catch (e) {
        print('임시 파일 삭제 오류: $e');
      }
    }
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
              _stopTimer();
              _videoController.pause(); // 운동 완료 시 영상 멈춤
              _stopRecording().then((_) => _uploadVideo());   // 녹화 중지 + 업로드
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
    _stopTimer();
    _methodChannel.invokeMethod('cancel');
    _eventSubscription?.cancel();
    _flutterTts.stop();
    _videoController.dispose();
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