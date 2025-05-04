import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'heelraise_screen.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const _eventChannel =
  EventChannel('com.example.capstone_healthcare_app/calibration_events');
  static const _methodChannel =
  MethodChannel(
      'com.example.capstone_healthcare_app/calibration_method_channel');

  double _progress = 0.0;
  bool _isCompleted = false;
  bool _hasPermission = false;
  late StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
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
            if (event['type'] == 'progress') {
              setState(() => _progress = event['value']);
            } else if (event['type'] == 'completed') {
              setState(() => _isCompleted = true);
              final baselineValues =
              Map<String, dynamic>.from(event['baselineValues']);
              Future.microtask(() {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        HeelRaiseScreen(baselineValues: baselineValues),
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
              creationParams: const {},
              creationParamsCodec: StandardMessageCodec(),
              onPlatformViewCreated: (viewId) {
                _setupEventListeners();
                Future.delayed(const Duration(milliseconds: 500), () {
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
      await _methodChannel.invokeMethod('switchCamera');
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