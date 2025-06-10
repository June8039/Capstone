import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/mood_provider.dart';

class PersonalRecordScreen extends StatefulWidget {
  const PersonalRecordScreen({super.key});

  @override
  State<PersonalRecordScreen> createState() => _PersonalRecordScreenState();
}

class _PersonalRecordScreenState extends State<PersonalRecordScreen> {
  double _painScore = 0;
  double _moodScore = 5;
  final Map<DateTime, double> _painScores = {};

  @override
  void initState() {
    super.initState();
    // Load the current day's mood score if it exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final moodProvider = Provider.of<MoodProvider>(context, listen: false);
      final now = DateTime.now();
      final todayScore = moodProvider.getMoodScore(now);
      if (todayScore != null) {
        setState(() {
          _moodScore = todayScore;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final formattedDate = dateFormat.format(now);
    final moodProvider = Provider.of<MoodProvider>(context, listen: false);

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
      body: SingleChildScrollView(
        child: Padding(
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
              const SizedBox(height: 40),
              const Text(
                '오늘의 기분 점수',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('기분 점수: ${_moodScore.round()}'),
                  Row(
                    children: [
                      Text(_getMoodDescription(_moodScore)),
                      const SizedBox(width: 8),
                      Text(_getMoodEmoji(_moodScore),
                          style: const TextStyle(fontSize: 24)),
                    ],
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getMoodColor(_moodScore),
                  thumbColor: _getMoodColor(_moodScore),
                ),
                child: Slider(
                  value: _moodScore,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _moodScore.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _moodScore = value;
                    });
                    moodProvider.setMoodScore(
                        DateTime(now.year, now.month, now.day), value);
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '기분 점수 가이드:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Text('0-3: 기분 나쁨 '),
                  Text('😞', style: TextStyle(fontSize: 20)),
                ],
              ),
              Row(
                children: const [
                  Text('4-6: 기분 보통 '),
                  Text('😐', style: TextStyle(fontSize: 20)),
                ],
              ),
              Row(
                children: const [
                  Text('7-10: 기분 좋음 '),
                  Text('😊', style: TextStyle(fontSize: 20)),
                ],
              ),
            ],
          ),
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

  String _getMoodDescription(double score) {
    if (score <= 3) return '기분 나쁨';
    if (score <= 6) return '기분 보통';
    return '기분 좋음';
  }

  String _getMoodEmoji(double score) {
    if (score <= 3) return '😞';
    if (score <= 6) return '😐';
    return '😊';
  }

  Color _getMoodColor(double score) {
    if (score <= 3) return Colors.red;
    if (score <= 6) return Colors.yellow;
    return Colors.green;
  }
}
