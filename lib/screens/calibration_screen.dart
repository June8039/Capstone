import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'heelraise_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CalibrationScreen extends StatefulWidget {
  final int initialLensFacing;
  const CalibrationScreen({super.key, this.initialLensFacing = 0});


  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const _eventChannel =
  EventChannel('com.example.capstone_healthcare_app/calibration_events');
  static const _methodChannel =
  MethodChannel(
      'com.example.capstone_healthcare_app/calibration_method_channel');

  int _currentLensFacing = 0;
  double _progress = 0.0;
  bool _isCompleted = false;
  bool _hasPermission = false;
  StreamSubscription? _eventSubscription;
  String _positionFeedback = '화면 중앙의 녹색 박스 안에 서주세요';
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _initTts().then((_) {
      _speakGuideBoxInstruction();
    });
    _currentLensFacing = widget.initialLensFacing;
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      _setupEventListeners();
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: const Text('카메라 권한 필요'),
              content: const Text('기준 자세 측정을 위해 카메라 권한이 필요합니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                )
              ],
            ),
      );
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _speakGuideBoxInstruction() async {
    await _flutterTts.speak('화면 중앙의 녹색 박스 안에 서주세요');
  }

  void _setupEventListeners() {
    _eventSubscription?.cancel();
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((event) {
          if (!mounted) return;
          debugPrint("이벤트 수신: $event");
          if (event is Map) {
            // 진행률 업데이트 로그 추가
            if (event['type'] == 'progress') {
              debugPrint("진행률 업데이트 수신: ${event['value']}");
              setState(() => _progress = (event['value'] as num).toDouble());
            }
            // 위치 안내 메시지 업데이트
            else if (event['type'] == 'position_status') {
              final isInBox = event['isInBox'] as bool;
              setState(() {
                _positionFeedback = isInBox
                    ? '올바른 위치입니다!'
                    : '화면 중앙의 녹색 박스 안에 서주세요';
              });
            }
            // 완료 이벤트 로그 추가
            else if (event['type'] == 'completed') {
              debugPrint("기준 측정 완료 데이터 수신: ${event['baselineValues']}");
              setState(() => _isCompleted = true);
              final baselineValues =
              Map<String, dynamic>.from(event['baselineValues']);
              final lensFacing = event['lensFacing'] as int? ??
                  widget.initialLensFacing;
              Future.microtask(() {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        HeelRaiseScreen(
                          baselineValues: baselineValues,
                          initialLensFacing: lensFacing,
                        ),
                  ),
                );
              });
            }
          }
        }, onError: (error) {
          debugPrint('Event error: $error');
        });
  }

  @override
  void dispose() {
    try {
      _eventSubscription?.cancel();
    } catch (e) {
      debugPrint("스트림 해제 중 오류 무시: $e");
    }
    _eventSubscription = null;
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기준 자세 측정')),
      body: _hasPermission
          ? SafeArea(
        child: Stack(
          children: [
            AndroidView(
              viewType: 'NativeCalibrationView',
              creationParams: {
                'initialLensFacing': _currentLensFacing,
              },
              creationParamsCodec: StandardMessageCodec(),
              onPlatformViewCreated: (viewId) {
                _setupEventListeners();
                Future.delayed(const Duration(milliseconds: 500), () {
                  debugPrint("startCalibration 메서드 호출 시도");
                  _methodChannel.invokeMethod('startCalibration');
                });
              },
            ),
            // 2. 진행률 UI
            if (!_isCompleted)
              _buildProgressUI(),
            // 3. 위치 안내 메시지
            if (!_isCompleted)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _positionFeedback,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
          ],
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildProgressUI() {
    return AnimatedOpacity(
      opacity: _isCompleted ? 0.0 : 1.0, // 완료 시 숨김
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: Text(
            '카메라 앞에서 기본 자세를 유지해주세요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}