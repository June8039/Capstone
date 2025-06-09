import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseVideo {
  final String id;
  final String videoUrl;
  final String exerciseType;
  final int count;
  final DateTime timestamp;
  final String userId;

  ExerciseVideo({
    required this.id,
    required this.videoUrl,
    required this.exerciseType,
    required this.count,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'exerciseType': exerciseType,
      'count': count,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  static ExerciseVideo fromMap(Map<String, dynamic> map) {
    return ExerciseVideo(
      id: map['id'],
      videoUrl: map['videoUrl'],
      exerciseType: map['exerciseType'],
      count: map['count'],
      timestamp: DateTime.parse(map['timestamp']),
      userId: map['userId'],
    );
  }
} 