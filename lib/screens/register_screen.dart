import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercise_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _pw2Controller = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (_idController.text.isEmpty ||
        _pwController.text.isEmpty ||
        _pw2Controller.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필드를 입력하세요')),
      );
      return;
    }

    if (_pwController.text != _pw2Controller.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_idController.text)
          .get();

      if (userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 존재하는 사용자 ID입니다')),
        );
        return;
      }

      // 새 사용자 등록
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_idController.text)
          .set({
        'userId': _idController.text,
        'pwd': _pwController.text,
        'userName': _nameController.text,
      });

      // 자동 로그인 처리
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _idController.text);

      // 회원가입 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다')),
        );
      }

      // 메인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExerciseScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;
    final textSize = isTablet ? 18.0 : 14.0;
    final fieldHeight = isTablet ? 60.0 : 48.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(fontSize: textSize),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: _pwController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  style: TextStyle(fontSize: textSize),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: _pw2Controller,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  style: TextStyle(fontSize: textSize),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(fontSize: textSize),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: fieldHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          '회원가입',
                          style: TextStyle(fontSize: textSize),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _pw2Controller.dispose();
    _nameController.dispose();
    super.dispose();
  }
} 