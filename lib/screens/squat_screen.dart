import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordedVideoFile = File('${tempDir.path}/exercise_$timestamp.mp4');

      await _methodChannel.invokeMethod('startRecording', {
        'outputPath': _recordedVideoFile!.path
      });
    } catch (e) {
      print('녹화 시작 오류: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _methodChannel.invokeMethod('stopRecording');
    } catch (e) {
      print('녹화 중지 오류: $e');
    }
  }

  Future<void> _uploadVideo() async {
    // 1. 파일 존재 및 크기 확인
    if (_recordedVideoFile == null || !await _recordedVideoFile!.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹화된 영상 파일이 존재하지 않습니다.')),
      );
      setState(() => _isUploading = false);
      return;
    }
    final fileLength = await _recordedVideoFile!.length();
    if (fileLength == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹화된 영상 파일이 비어 있습니다.')),
      );
      setState(() => _isUploading = false);
      return;
    }

    setState(() => _isUploading = true);

    // 2. 로그인 상태 확인
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다. 잠시 후 다시 시도해 주세요.')),
      );
      setState(() => _isUploading = false);
      return;
    }
    final userId = user.uid;

    try {
      // 3. 업로드 경로 및 태스크 생성
      final ref = FirebaseStorage.instance
          .ref('videos/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4');
      final uploadTask = ref.putFile(_recordedVideoFile!);

      // 4. 업로드 진행률 로그 (선택)
      uploadTask.snapshotEvents.listen((event) {
        final progress =
        (event.bytesTransferred / event.totalBytes * 100).toStringAsFixed(1);
        print('업로드 진행률: $progress%');
      });

      // 5. 실제 업로드 대기 및 에러 처리
      await uploadTask;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 영상이 저장되었습니다.')),
      );
    } on FirebaseException catch (e) {
      print('Firebase Storage 오류: ${e.code} - ${e.message}');
      String errorMessage = '영상 저장 중 오류가 발생했습니다.';
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        errorMessage = '권한이 없습니다. 로그인 상태를 확인하세요.';
      } else if (e.code == 'object-not-found') {
        errorMessage = '업로드할 파일을 찾을 수 없습니다.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('Storage 업로드 일반 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알 수 없는 오류가 발생했습니다.')),
      );
    } finally {
      setState(() => _isUploading = false);
      // 6. 임시 파일 삭제
      if (_recordedVideoFile != null && await _recordedVideoFile!.exists()) {
        try {
          await _recordedVideoFile!.delete();
        } catch (_) {}
      }
    }
  }

  void _subscribeEventChannel() {
    bool _isRecording = false; // 중복 녹화 방지용 플래그

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
        if (event is Map) {
          // 1. 카메라 준비 완료 시 녹화 시작
          if (event['type'] == 'camera_ready') {
            if (!_isRecording) {
              _isRecording = true;
              _startRecording();
            }
          }
          // 2. 운동 횟수 업데이트 및 완료 처리
          else if (event['type'] == 'pose_update') {
            final newCount = event['count'] ?? _count;
            if (newCount > _count) {
              _speakCount(newCount);
            }
            setState(() => _count = newCount);
            if (event['status'] == 'completed') {
              setState(() => _isCompleted = true);
              _stopTimer();
              _videoController.pause(); // 운동 완료 시 영상 멈춤
              _stopRecording();
            }
          }
          // 3. 녹화 완료 시 파일 처리
          else if (event['type'] == 'recording_complete') {
            final filePath = event['filePath'] as String?;
            if (filePath != null) {
              _recordedVideoFile = File(filePath);
              _uploadVideo(); // 자동 업로드
            }
            _isRecording = false; // 녹화 완료 후 플래그 해제
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
                      if (_isUploading)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 8),
                              const Text(
                                '영상 업로드 중...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
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