import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_healthcare_app/services/exercise_video_service.dart'; // 실제 경로
import 'package:capstone_healthcare_app/models/exercise_video.dart';

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
  EventChannel('com.example.capstone_healthcare_app/heelraise_events');

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

  File? _recordedVideoFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("HeelRaiseScreen initialLensFacing: ${widget.initialLensFacing}");
    _initTts();
    _subscribeEventChannel();

    _videoController = VideoPlayerController.asset(
      'assets/videos/heel_raise_example.mp4',
    );
    _initializeVideoPlayerFuture = _videoController.initialize().then((_) {
      setState(() {});
      _videoController.setLooping(true);
      _videoController.setVolume(0.0);
      _videoController.play();
    });

    _stopwatch = Stopwatch();
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
      if (widget.baselineValues['left_eye_y'] != null)
        'left_eye_y': (widget.baselineValues['left_eye_y'] as num).toDouble(),
      if (widget.baselineValues['right_eye_y'] != null)
        'right_eye_y': (widget.baselineValues['right_eye_y'] as num).toDouble(),
    };
    _methodChannel.invokeMethod('resetCount');
    _methodChannel.invokeMethod('initialize', convertedValues);
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

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
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
            _videoController.pause();
            _stopRecording().then((_) {
              _uploadVideo();
            });
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
