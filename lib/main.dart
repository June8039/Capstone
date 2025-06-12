// main.dart

//import all the needed packages and files here
//I gotta find a way to organize the imports better and remove redundancy
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/personal_record.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'providers/mood_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_healthcare_app/screens/heelraise_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize locale data
  await initializeDateFormatting();

  // Firebase Core 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform.copyWith(
      storageBucket: 'capstone-11bce.firebasestorage.app',
    ),
  );

  // Run the app
  runApp(
    ChangeNotifierProvider(
      create: (context) => MoodProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'healthcare_app',
      routes: {
        '/login': (_) => LoginScreen(),
        '/exercises': (_) => HeelRaiseScreen(baselineValues: <String, dynamic>{}),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? HeelRaiseScreen(baselineValues: <String, dynamic>{}) : LoginScreen();
        },
      ),
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
    const CalendarScreen(),
    const ExerciseScreen(), // Create this or any other screen
    const PersonalRecordScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // 인증 상태 변화 추적용 로그
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print('Auth state changed: $user');
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: '캘린더'),
          BottomNavigationBarItem(
            icon: Icon(Icons.self_improvement),
            label: '운동',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart),
            label: '나의 기록',
          ),
        ],
      ),
    );
  }
}
