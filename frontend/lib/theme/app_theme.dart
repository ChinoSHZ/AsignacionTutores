import 'package:flutter/material.dart';
import '../models/models.dart';

class AppTheme {
  static const bg = Color(0xFF0F1117);
  static const surface = Color(0xFF1A1D27);
  static const surfaceLight = Color(0xFF242736);
  static const accent = Color(0xFF6C63FF);
  static const accentLight = Color(0xFF8B85FF);
  static const green = Color(0xFF2ECC71);
  static const yellow = Color(0xFFF39C12);
  static const red = Color(0xFFE74C3C);
  static const textPrimary = Color(0xFFF0F0F5);
  static const textSecondary = Color(0xFF8890A4);
  static const border = Color(0xFF2D3044);

  static Color statusColor(BalanceStatus s) {
    switch (s) {
      case BalanceStatus.balanced: return green;
      case BalanceStatus.warning: return yellow;
      case BalanceStatus.critical: return red;
    }
  }

  static Color mobilityColor(MobilityFlag f) {
    switch (f) {
      case MobilityFlag.canChange: return green; // Verde
      case MobilityFlag.noChange: return red;    // Rojo
      case MobilityFlag.newStudent: return const Color(0xFF3498DB); // Azul
    }
  }

  static String mobilityLabel(MobilityFlag f) {
    switch (f) {
      case MobilityFlag.canChange: return 'Sí Cambiar';
      case MobilityFlag.noChange: return 'No Cambiar';
      case MobilityFlag.newStudent: return 'Nuevo Ingreso';
    }
  }

  static ThemeData get lightTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textPrimary, fontFamily: 'monospace'),
      ),
    );
  }
}