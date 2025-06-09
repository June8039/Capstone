import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise_video.dart';

class ExerciseVideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<ExerciseVideo> uploadExerciseVideo({
    required File videoFile,
    required String exerciseType,
    required int count,
    required String userId,
  }) async {
    try {
      // 고유한 ID 생성
      final String videoId = _uuid.v4();
      
      // Storage에 비디오 업로드
      final String storagePath = 'exercise_videos/$userId/$videoId.mp4';
      final storageRef = _storage.ref().child(storagePath);
      
      final UploadTask uploadTask = storageRef.putFile(videoFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Firestore에 메타데이터 저장
      final ExerciseVideo video = ExerciseVideo(
        id: videoId,
        videoUrl: downloadUrl,
        exerciseType: exerciseType,
        count: count,
        timestamp: DateTime.now(),
        userId: userId,
      );

      await _firestore
          .collection('exercise_videos')
          .doc(videoId)
          .set(video.toMap());

      return video;
    } catch (e) {
      throw Exception('Failed to upload exercise video: $e');
    }
  }

  Future<List<ExerciseVideo>> getUserExerciseVideos(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('exercise_videos')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ExerciseVideo.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch exercise videos: $e');
    }
  }

  Future<void> deleteExerciseVideo(ExerciseVideo video) async {
    try {
      // Storage에서 비디오 삭제
      final storageRef = _storage.refFromURL(video.videoUrl);
      await storageRef.delete();

      // Firestore에서 메타데이터 삭제
      await _firestore
          .collection('exercise_videos')
          .doc(video.id)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete exercise video: $e');
    }
  }
} 