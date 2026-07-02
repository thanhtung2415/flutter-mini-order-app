import 'package:flutter/material.dart';

void main() {
  runApp(const MiniOrderScaffoldApp());
}

class MiniOrderScaffoldApp extends StatelessWidget {
  const MiniOrderScaffoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Mini Order App',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('Flutter Mini Order App scaffold'),
        ),
      ),
    );
  }
}

