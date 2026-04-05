import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'screens/mfa_verify_screen.dart';

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
          onSurface: AppTheme.textPrimary, 
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
          bodyMedium: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
          titleMedium: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: AppTheme.textSecondary),
          hintStyle: TextStyle(color: AppTheme.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.accent),
          ),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(AppTheme.accent.withValues(alpha:0.4)),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/mfa-verify': (context) => const MfaVerifyScreen(),
        '/home': (context) => const MainShell(),
      },
    );
  }
}