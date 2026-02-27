import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';

void main() {
  runApp(const EmoCareApp());
}

class EmoCareApp extends StatelessWidget {
  const EmoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmoCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}