import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../services/exercise_video_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final _exerciseVideoService = ExerciseVideoService();

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
    _startRecording();
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
    };
    _methodChannel.invokeMethod('resetCount');
    _methodChannel.invokeMethod('initialize', convertedValues);
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordedVideoFile = File('${tempDir.path}/exercise_$timestamp.mp4');
      
      debugPrint('녹화 파일 경로: ${_recordedVideoFile!.path}');
      
      await _methodChannel.invokeMethod('startRecording', {
        'outputPath': _recordedVideoFile!.path
      });
      
      debugPrint('녹화 시작 성공');
    } catch (e) {
      debugPrint('녹화 시작 오류: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _methodChannel.invokeMethod('stopRecording');
      
      if (_recordedVideoFile != null) {
        final exists = await _recordedVideoFile!.exists();
        final fileSize = exists ? await _recordedVideoFile!.length() : 0;
        debugPrint('녹화 중지 - 파일 존재: $exists, 크기: $fileSize bytes');
      } else {
        debugPrint('녹화 중지 - 파일이 null입니다');
      }
    } catch (e) {
      debugPrint('녹화 중지 오류: $e');
    }
  }

  Future<void> _uploadVideo() async {
    if (_recordedVideoFile == null) {
      debugPrint('업로드 실패: 녹화 파일이 null입니다');
      return;
    }

    final exists = await _recordedVideoFile!.exists();
    if (!exists) {
      debugPrint('업로드 실패: 녹화 파일이 존재하지 않습니다');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      debugPrint('업로드 시작 - 파일 크기: ${await _recordedVideoFile!.length()} bytes');
      
      await _exerciseVideoService.uploadExerciseVideo(
        videoFile: _recordedVideoFile!,
        exerciseType: 'heel_raise',
        count: _count,
        userId: user.uid,
      );

      debugPrint('업로드 완료');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 영상이 저장되었습니다.')),
      );
    } catch (e) {
      debugPrint('업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 저장 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() => _isUploading = false);
      try {
        if (_recordedVideoFile != null && await _recordedVideoFile!.exists()) {
          await _recordedVideoFile!.delete();
          debugPrint('임시 파일 삭제 완료');
        }
      } catch (e) {
        debugPrint('임시 파일 삭제 오류: $e');
      }
    }
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
            _videoController.pause();
            _stopRecording().then((_) => _uploadVideo());
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
    return WillPopScope(
      onWillPop: () async {
        if (_isUploading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('영상 업로드 중입니다. 잠시만 기다려주세요.')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('발 뒤꿈치 들기'),
          leading: _isUploading
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
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
                                'initialLensFacing':
                                    widget.initialLensFacing.toInt(),
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
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return VideoPlayer(_videoController);
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '횟수: $_count',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          _elapsedTime,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '영상 저장 중...',
                        style: TextStyle(color: Colors.white),
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
