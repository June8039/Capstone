// main.dart

//import all the needed packages and files here
//I gotta find a way to organize the imports better and remove redundancy
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';

void main() async {
  // Initialize locale data
  await initializeDateFormatting();

  // Run the app
  runApp(const MyApp());
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
      home: const HomeScreen(),
      routes: {
        '/calendar': (context) => const CalendarScreen(),
      },
    );
  }
}