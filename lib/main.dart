import 'package:flutter/material.dart';
import 'models.dart';
import 'screens/list_screen.dart';

void main() {
  runApp(const RollChartBldrApp());
}

class RollChartBldrApp extends StatelessWidget {
  const RollChartBldrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROLLCHART-BLDR',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const RollChartListScreen(),
    );
  }
}