import 'package:flutter/material.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const AnimaApp());
}

class AnimaApp extends StatelessWidget {
  const AnimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anima E-ink Reader',
      theme: eInkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
