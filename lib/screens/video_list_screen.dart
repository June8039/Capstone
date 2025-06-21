// lib/screens/video_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import 'video_player_screen.dart';

class VideoListScreen extends StatelessWidget {
  const VideoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final storageRef = FirebaseStorage.instance.ref('videos/${user.uid}');

    return Scaffold(
      appBar: AppBar(title: const Text('내 운동 영상')),
      body: FutureBuilder<ListResult>(
        future: storageRef.listAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!.items;
          if (items.isEmpty) {
            return const Center(child: Text('저장된 영상이 없습니다.'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final ref = items[idx];

              // 파일명에서 타임스탬프(밀리초)만 추출해 DateTime 변환
              final name = ref.name; // e.g. "exercise_1623434335123.mp4" or "1623434335123.mp4"
              final parts = name.replaceAll(RegExp(r'\.mp4$'), '').split('_');
              final timestampStr = parts.isNotEmpty ? parts.last : '';
              final millis = int.tryParse(timestampStr) ?? 0;
              final recordedAt = DateTime.fromMillisecondsSinceEpoch(millis);
              final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(recordedAt);

              return ListTile(
                leading: const Icon(Icons.play_circle_outline, size: 40),
                title: Text(formattedDate),
                onTap: () async {
                  // 재생용 URL 가져와 화면 이동
                  final url = await ref.getDownloadURL();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(url: url),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
