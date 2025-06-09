import 'package:flutter/material.dart';
import 'calibration_screen.dart';
import 'heelraise_screen.dart';
import 'squat_screen.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  void _startHeelRaiseFlow(BuildContext context) async {
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

  void _startSquatFlow(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SquatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("운동 도우미"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _startHeelRaiseFlow(context),
              child: const Text('발 뒤꿈치 들기'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _startSquatFlow(context),
              child: const Text('스쿼트'),
            ),
          ],
        ),
      ),
    );
  }
}
