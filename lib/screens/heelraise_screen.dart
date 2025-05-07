import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeelRaiseScreen extends StatefulWidget {
  final Map<String, dynamic> baselineValues;
  final int initialLensFacing;
  const HeelRaiseScreen({
    super.key,
    required this.baselineValues,
    required this.initialLensFacing,
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

  @override
  void dispose() {
    _methodChannel.invokeMethod('cancel');
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _flipCamera() {
    _methodChannel.invokeMethod('flipCamera');
  }

  void _startExercise() {
    if (widget.baselineValues == null) {
      print('baselineValues가 null입니다!');
      return;
    }

    // 키 존재 여부 검증
    if (!widget.baselineValues.containsKey('left_heel_y') ||
        !widget.baselineValues.containsKey('right_heel_y')) {
      print('필수 키 누락: left_heel_y 또는 right_heel_y');
      return;
    }

    // 타입 검증 및 변환
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
          setState(() => _count = event['count'] ?? _count);
          if (event['status'] == 'completed') {
            setState(() => _isCompleted = true);
          }
        }
      }
    });
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
                Expanded(
                  child: Column(
                    children: [
                      // 카메라 뷰 (상단)
                      Expanded(
                        child: Stack(
                          children: [
                            AndroidView(
                              viewType: 'NativeHeelRaiseView',
                              creationParams: {
                                'baselineValues': widget.baselineValues,
                                'initialLensFacing': widget.initialLensFacing,
                              },
                              creationParamsCodec: StandardMessageCodec(),
                              onPlatformViewCreated: (viewId) {
                                // 네이티브 뷰 attach 이후에만 이벤트 구독 및 초기화
                                _subscribeEventChannel();
                                _startExercise();
                              },
                            ),
                          ],
                        ),
                      ),
                      // 구분선
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[800],
                      ),
                      // 예시 영상
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          color: Colors.black,
                          child: const Center(
                            child: Text(
                              '발 뒤꿈치 들기 예시 영상',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 카운트 표시 + 카메라 전환 버튼
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
            // 완료 시 오버레이
            if (_isCompleted)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 80),
                      const SizedBox(height: 20),
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
