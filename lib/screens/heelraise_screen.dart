import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

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
    if (_recordedVideoFile == null) return;

    setState(() => _isUploading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/heel_raise_$timestamp.mp4');
      
      final uploadTask = storageRef.putFile(_recordedVideoFile!);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('업로드 진행률: $progress%');
      });

      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();

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
        await _recordedVideoFile!.delete();
      } catch (e) {
        print('임시 파일 삭제 오류: $e');
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
                      if (_isUploading)
                        const CircularProgressIndicator()
                      else
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
