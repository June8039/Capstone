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
      appBar: AppBar(title: const Text("Exercises")),
      body: Center(
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children: [
              const Text('운동계획', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 운동 1 (클릭 시 CalibrationScreen으로 이동)
              GestureDetector(
                onTap: () => _startHeelRaiseFlow(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text(
                    '운동 1 (발 뒤꿈치 들기)',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                    children: [
                      OutlinedButton( onPressed: () {
                        // go to the exercise page
                      }, child: Text("난이도 1"), ),
                      OutlinedButton( onPressed: () {
                      // go to the exercise page
                      }, child: Text("난이도 2"), ),
                      OutlinedButton( onPressed: () {
                        // go to the exercise page
                      }, child: Text("난이도 3"), ),
                    ],
                ),
              ),
              const SizedBox(height: 16),
              // 운동 2 (스쿼트)
              GestureDetector(
                onTap: () => _startSquatFlow(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text(
                    '운동 2 (스쿼트)',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton( onPressed: () {
                      // go to the exercise page
                    }, child: Text("난이도 1"), ),
                    OutlinedButton( onPressed: () {
                      // go to the exercise page
                    }, child: Text("난이도 2"), ),
                    OutlinedButton( onPressed: () {
                      // go to the exercise page
                    }, child: Text("난이도 3"), ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
