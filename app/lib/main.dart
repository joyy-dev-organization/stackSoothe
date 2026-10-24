import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/diagnosis_client.dart';
import 'services/notebook_store.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StackSootheApp());
}

class StackSootheApp extends StatelessWidget {
  const StackSootheApp({
    super.key,
    this.notebookStore,
    this.settingsStore,
    this.diagnosisClient,
  });

  final NotebookStore? notebookStore;
  final SettingsStore? settingsStore;
  final DiagnosisClient? diagnosisClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StackSoothe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(
        notebookStore: notebookStore,
        settingsStore: settingsStore,
        diagnosisClient: diagnosisClient,
      ),
    );
  }
}
