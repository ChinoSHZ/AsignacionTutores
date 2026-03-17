import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Procesamiento',
      subtitle: 'Estado del algoritmo de balanceo',
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Column(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 52),
            SizedBox(height: 16),
            Text('Algoritmo completado', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            )),
            SizedBox(height: 8),
            Text('El sistema procesó 155 alumnos en 1.4 segundos', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 14,
            )),
            SizedBox(height: 28),
            Row(children: [
              _StatBox('155', 'Total alumnos', AppTheme.accent),
              SizedBox(width: 14),
              _StatBox('12', 'Reasignados', AppTheme.yellow),
              SizedBox(width: 14),
              _StatBox('5', 'Bloqueados', AppTheme.red),
              SizedBox(width: 14),
              _StatBox('1', 'Grupos en alerta', AppTheme.red),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        const _LogItem(Icons.check_circle_rounded, AppTheme.green, 'Nuevos ingresos asignados aleatoriamente por carrera', '58 alumnos'),
        const _LogItem(Icons.history_rounded, Color(0xFF3498DB), 'Reingresantes mantienen tutor previo', '85 alumnos'),
        const _LogItem(Icons.swap_horiz_rounded, AppTheme.yellow, 'Reasignaciones por balanceo', '12 alumnos'),
        const _LogItem(Icons.lock_rounded, AppTheme.red, 'Bloqueados por "No Cambiar"', '5 alumnos'),
        const _LogItem(Icons.warning_rounded, AppTheme.red, 'Grupo Dr. Pablo Torres sin equilibrar (43 alumnos)', 'Requiere revisión manual'),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.25)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11,
        )),
      ]),
    ));
  }
}

class _LogItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message, detail;
  const _LogItem(this.icon, this.color, this.message, this.detail);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(message, style: const TextStyle(
          color: AppTheme.textPrimary, fontSize: 13,
        ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(detail, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}