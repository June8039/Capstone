import 'package:flutter/material.dart';

class MoodProvider extends ChangeNotifier {
  final Map<DateTime, double> _moodScores = {};

  Map<DateTime, double> get moodScores => _moodScores;

  void setMoodScore(DateTime date, double score) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _moodScores[normalizedDate] = score;
    notifyListeners();
  }

  double? getMoodScore(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _moodScores[normalizedDate];
  }
}
