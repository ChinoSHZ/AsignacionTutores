import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const TutorAssignmentApp());
}

class TutorAssignmentApp extends StatelessWidget {
  const TutorAssignmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TutorAssign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppTheme.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accent,
          surface: AppTheme.surface,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(AppTheme.accent.withValues(alpha:0.4)),
        ),
      ),
      home: const MainShell(),
    );
  }
}