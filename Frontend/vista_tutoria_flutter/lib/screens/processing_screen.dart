import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _isLoading = true;
  int _totalAlumnos = 0;
  int _reasignados = 0;
  int _bloqueados = 0;
  int _gruposAlerta = 0;
  int _nuevosIngresos = 0;
  int _mantienenTutor = 0;

  @override
  void initState() {
    super.initState();
    _fetchProcessingData();
  }

  Future<void> _fetchProcessingData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'), headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        
        int tempTotal = 0;
        int tempReasignados = 0;
        int tempBloqueados = 0;
        int tempNuevos = 0;
        int tempAlertas = 0;
        
        List<int> tutorStudentCounts = [];

        for (var t in tutorsJson) {
          int countForTutor = 0;
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  if (pivot['estado_tutorado'] == 'activo' || stud['is_active'] == 1 || stud['is_active'] == true) {
                    countForTutor++;
                    tempTotal++;
                    if (pivot['movilidad'] == 'cambiar') tempReasignados++;
                    if (pivot['movilidad'] == 'no_cambiar') tempBloqueados++;
                    if (pivot['movilidad'] == 'nuevo_ingreso') tempNuevos++;
                  }
                }
              }
            }
          }
          tutorStudentCounts.add(countForTutor);
        }
        
        // Cálculo del promedio y los umbrales dinámicos
        int average = tutorStudentCounts.isNotEmpty ? (tempTotal / tutorStudentCounts.length).round() : 30;
        int minWarning = average - 5;
        int maxWarning = average + 5;

        for (int count in tutorStudentCounts) {
          if (count < minWarning || count > maxWarning) {
            tempAlertas++;
          }
        }

        setState(() {
          _totalAlumnos = tempTotal;
          _reasignados = tempReasignados;
          _bloqueados = tempBloqueados;
          _nuevosIngresos = tempNuevos;
          _mantienenTutor = _bloqueados; 
          _gruposAlerta = tempAlertas;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScreenWrapper(
        title: 'Procesamiento',
        subtitle: 'Cargando estado del algoritmo...',
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

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
          child: Column(children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 52),
            const SizedBox(height: 16),
            const Text('Algoritmo de balanceo sincronizado', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            )),
            const SizedBox(height: 8),
            Text('El sistema reporta $_totalAlumnos alumnos activos de forma exitosa.', style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 14,
            )),
            const SizedBox(height: 28),
            Row(children: [
              _StatBox('$_totalAlumnos', 'Total alumnos', AppTheme.accent),
              const SizedBox(width: 14),
              _StatBox('$_reasignados', 'Reasignados', AppTheme.yellow),
              const SizedBox(width: 14),
              _StatBox('$_bloqueados', 'Bloqueados', AppTheme.red),
              const SizedBox(width: 14),
              _StatBox('$_gruposAlerta', 'Grupos en alerta', AppTheme.red),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _LogItem(Icons.check_circle_rounded, AppTheme.green, 'Nuevos ingresos asignados por el sistema', '$_nuevosIngresos alumnos'),
        _LogItem(Icons.history_rounded, const Color(0xFF3498DB), 'Reingresantes mantienen tutor previo', '$_mantienenTutor alumnos'),
        _LogItem(Icons.swap_horiz_rounded, AppTheme.yellow, 'Reasignaciones dinámicas por balanceo', '$_reasignados alumnos'),
        _LogItem(Icons.lock_rounded, AppTheme.red, 'Fijos por directiva "No Cambiar"', '$_bloqueados alumnos'),
        if (_gruposAlerta > 0)
          _LogItem(Icons.warning_rounded, AppTheme.red, 'Existen grupos fuera del umbral de tolerancia', '$_gruposAlerta grupos críticos'),
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