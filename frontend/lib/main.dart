import 'package:flutter/material.dart';
import 'features/starting/presentation/pages/starting_page.dart';

void main() {
  runApp(const MotionAIApp());
}

class MotionAIApp extends StatelessWidget {
  const MotionAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motion AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF5B9FED),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        fontFamily: 'Segoe UI',
      ),
      home: const StartingPage(),
      routes: {
        '/signin': (context) => const Placeholder(), // TODO: Replace with SigninPage
      },
    );
  }
}
