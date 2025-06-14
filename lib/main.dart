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
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize locale data
  await initializeDateFormatting();

  // Firebase Core 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run the app
  runApp(
    ChangeNotifierProvider(
      create: (context) => MoodProvider(),
      child: const MyApp(),
    ),
  );
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
      home: const LoginScreen(),
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
