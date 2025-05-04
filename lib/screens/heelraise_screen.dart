import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeelRaiseScreen extends StatefulWidget {
  final Map<String, dynamic> baselineValues;
  const HeelRaiseScreen({super.key, required this.baselineValues});

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
  late StreamSubscription _eventSubscription;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        if (event['type'] == 'pose_update') {
          setState(() => _count = event['count'] ?? _count);
        } else if (event['type'] == 'completed') {
          setState(() => _isCompleted = true);
        }
      }
    });
    _startExercise();
  }

  void _startExercise() {
    _methodChannel.invokeMethod('initialize', widget.baselineValues);
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
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
                            const AndroidView(
                              viewType: 'NativeHeelRaiseView',
                              creationParams: {},
                              creationParamsCodec: StandardMessageCodec(),
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
                          child: Center(
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

  void _flipCamera() {
    _methodChannel.invokeMethod('flipCamera');
  }
}
