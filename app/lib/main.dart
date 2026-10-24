import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StackSootheApp());
}

class StackSootheApp extends StatelessWidget {
  const StackSootheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StackSoothe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
