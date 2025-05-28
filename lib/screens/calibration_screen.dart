import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'heelraise_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
            // 완료 이벤트 로그 추가
            else if (event['type'] == 'completed') {
              debugPrint("기준 측정 완료 데이터 수신: ${event['baselineValues']}");
              setState(() => _isCompleted = true);
              final baselineValues =
              Map<String, dynamic>.from(event['baselineValues']);
              final lensFacing = event['lensFacing'] as int? ?? widget.initialLensFacing;
              Future.microtask(() {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HeelRaiseScreen(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기준 자세 측정')),
      body: _hasPermission
          ? Stack(
        children: [
          // 1. 카메라 미리보기
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: AndroidView(
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
          ),
          // 2. 진행률 UI
          if (!_isCompleted)
            _buildProgressUI(),
          // 3. 카메라 전환 버튼 (
          if (!_isCompleted)
            Positioned(
              bottom: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.cameraswitch,
                    color: Colors.white,
                    size: 28
                ),
                onPressed: _switchCamera,
                tooltip: '카메라 전환',
              ),
            ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }


  void _switchCamera() async {
    try {
      final newLensFacing = await _methodChannel.invokeMethod<int>('switchCamera');
      if (newLensFacing != null) {
        setState(() {
          _currentLensFacing = newLensFacing;
        });
        // 변경된 방향을 Native에 즉시 반영
        _methodChannel.invokeMethod('updateLensFacing', newLensFacing);
      }
    } catch (e) {
      debugPrint("카메라 전환 실패: $e");
    }
  }


  Widget _buildProgressUI() {
    return AnimatedOpacity(
      opacity: _progress < 1.0 ? 1.0 : 0.0, // 진행률 100% 미만일 때만 표시
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: _progress,
                color: Colors.white,
                strokeWidth: 6,
              ),
              const SizedBox(height: 20),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '카메라 앞에서 기본 자세를 유지해주세요',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}