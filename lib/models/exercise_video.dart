// lib/models/exercise_video.dart

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

  /// Firestore에 저장할 Map으로 변환
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

  /// Firestore Document 데이터를 모델로 변환
  factory ExerciseVideo.fromMap(Map<String, dynamic> map) {
    return ExerciseVideo(
      id: map['id'] as String,
      videoUrl: map['videoUrl'] as String,
      exerciseType: map['exerciseType'] as String,
      count: map['count'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      userId: map['userId'] as String,
    );
  }
}
