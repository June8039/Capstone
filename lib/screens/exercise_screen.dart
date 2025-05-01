import 'package:flutter/material.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercises")),
      body: Center(
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children: [
              Text('운동계획', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('운동 1'),
              Padding(
                  padding: EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text('난이도 1'),
                    Text('난이도 2'),
                    Text('난이도 3'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('운동 2'),
              Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text('난이도 1'),
                    Text('난이도 2'),
                    Text('난이도 3'),
                  ],
                ),
              )

            ],
          )
        )
      ),
    );
  }
}
