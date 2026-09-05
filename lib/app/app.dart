import 'package:flutter/material.dart';
import '../features/plant_list/presentation/plant_list_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const PlantListScreen(),
    );
  }
}
