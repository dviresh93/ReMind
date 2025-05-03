// lib/app.dart

import 'package:flutter/material.dart';
import 'presentation/screens/home_screen.dart';

class ReMindApp extends StatelessWidget {
  const ReMindApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReMind',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Use Material 3
        useMaterial3: true,
        // Custom color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Use Material 3
        useMaterial3: true,
        // Custom color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      // Use system theme mode
      themeMode: ThemeMode.system,
      // Disable debug banner
      debugShowCheckedModeBanner: false,
      // Set the home screen
      home: const HomeScreen(),
    );
  }
}