import 'package:flutter/material.dart';

import 'calibration_screen.dart';
import 'heelraise_screen.dart';
import 'squat_screen.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  void _startHeelRaiseFlow(BuildContext context) async {
    // CalibrationScreen에서 측정 완료 후 baselineValues와 initialLensFacing 반환받음
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const CalibrationScreen(),
      ),
    );

    if (result != null) {
      final baselineValues = result['baselineValues'] as Map<String, dynamic>;
      final initialLensFacing = result['initialLensFacing'] as int;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HeelRaiseScreen(
            baselineValues: baselineValues,
            initialLensFacing: initialLensFacing,
          ),
        ),
      );
    }
  }

  void _startSquatFlow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SquatScreen(), // 캘리브레이션 없이 바로 이동
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("운동하기")),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                // 운동 1 (클릭 시 CalibrationScreen으로 이동)
                GestureDetector(
                  onTap: () => _startHeelRaiseFlow(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      '발 뒤꿈치 들기',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Image.asset('assets/Images/calf_raise.png'),
                  iconSize: 50,
                  onPressed: () => _startHeelRaiseFlow(context),
                ),
                const SizedBox(height: 16),
                // 운동 2 (스쿼트)
                GestureDetector(
                  onTap: () => _startSquatFlow(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      '스쿼트',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Image.asset('assets/Images/squat.png'),
                  iconSize: 50,
                  onPressed: () => _startSquatFlow(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}