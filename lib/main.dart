// main.dart

//import all the needed packages and files here
//I gotta find a way to organize the imports better and remove redundancy
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/calendar_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Firebase Core 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firestore 설정
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Firestore 연결 테스트
    try {
      print('Firestore 연결 테스트 시작...');
      final testDocument = await FirebaseFirestore.instance.collection('test').doc('connection_test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'connection_successful'
      });
      print('Firestore 연결 성공: 테스트 문서 생성됨');
    } catch (e) {
      print('Firestore 연결 테스트 실패: $e');
    }

    // Initialize locale data
    await initializeDateFormatting();
    
    // Run the app
    runApp(const MyApp());
  } catch (e) {
    print('Firebase 초기화 오류: $e');
    // 오류 발생 시 사용자에게 알림
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase 초기화 오류: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Navigation Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(), //main homescreen
    );
  }
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    //all pages should be defined here
    const ExerciseScreen(),
    const CalendarScreen(),
    const LoginScreen(), // 로그인 화면으로 변경
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.self_improvement),
            label: '운동',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}