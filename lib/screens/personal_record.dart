import 'package:flutter/material.dart';

class PersonalRecordScreen extends StatelessWidget {
  const PersonalRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 기록'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              '나의 기록',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            Text('여기에 개인 기록이 표시됩니다.'),
          ],
        ),
      ),
    );
  }
}
