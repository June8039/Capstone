import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PersonalRecordScreen extends StatefulWidget {
  const PersonalRecordScreen({super.key});

  @override
  State<PersonalRecordScreen> createState() => _PersonalRecordScreenState();
}

class _PersonalRecordScreenState extends State<PersonalRecordScreen> {
  double _painScore = 0;
  final Map<DateTime, double> _painScores = {};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final formattedDate = dateFormat.format(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('나의 기록'),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘의 통증 점수',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('통증 점수: ${_painScore.round()}'),
                Text(_getPainDescription(_painScore)),
              ],
            ),
            Slider(
              value: _painScore,
              min: 0,
              max: 10,
              divisions: 10,
              label: _painScore.round().toString(),
              onChanged: (value) {
                setState(() {
                  _painScore = value;
                  _painScores[DateTime(now.year, now.month, now.day)] = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '통증 점수 가이드:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('0-2: 약한 통증'),
            Text('3-5: 중간 통증'),
            Text('6-8: 심한 통증'),
            Text('9-10: 매우 심한 통증'),
          ],
        ),
      ),
    );
  }

  String _getPainDescription(double score) {
    if (score <= 2) return '약한 통증';
    if (score <= 5) return '중간 통증';
    if (score <= 8) return '심한 통증';
    return '매우 심한 통증';
  }
}
