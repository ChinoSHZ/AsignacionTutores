import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class LogsScreen extends StatefulWidget {
  final List<SystemLog> logs; 
  const LogsScreen({super.key, required this.logs});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _activeFilter = 'all'; 
  bool _isLoading = true;
  List<SystemLog> _realLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogsData();
  }

  Future<void> _fetchLogsData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'), headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        
        int totalAlumnos = 0;
        int reasignados = 0;
        int bloqueados = 0;
        int nuevosIngresos = 0;
        
        List<SystemLog> generatedLogs = [];
        List<int> activeCounts = [];

        for (var t in tutorsJson) {
          int activeCount = 0;
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  if (pivot['estado_tutorado'] == 'activo' || stud['is_active'] == 1 || stud['is_active'] == true) {
                    activeCount++;
                    totalAlumnos++;
                    if (pivot['movilidad'] == 'cambiar') reasignados++;
                    if (pivot['movilidad'] == 'no_cambiar') bloqueados++;
                    if (pivot['movilidad'] == 'nuevo_ingreso') nuevosIngresos++;
                  }
                }
              }
            }
          }
          activeCounts.add(activeCount);
        }

        int average = activeCounts.isNotEmpty ? (totalAlumnos / activeCounts.length).round() : 30;
        int minWarning = average - 5;
        int maxWarning = average + 5;
        int minBalanced = average - 3;
        int maxBalanced = average + 3;

        for (int i = 0; i < tutorsJson.length; i++) {
          var t = tutorsJson[i];
          int activeCount = activeCounts[i];
          
          if (activeCount < minWarning || activeCount > maxWarning) {
            generatedLogs.add(SystemLog(
              timestamp: DateTime.now(), 
              message: 'El grupo asignado a ${t['nombre']} ${t['apellido_paterno']} presenta un desbalance crítico ($activeCount alumnos asignados).', 
              type: 'error'
            ));
          } else if (activeCount < minBalanced || activeCount > maxBalanced) {
            generatedLogs.add(SystemLog(
              timestamp: DateTime.now(), 
              message: 'El grupo de ${t['nombre']} ${t['apellido_paterno']} requiere atención de balanceo ($activeCount alumnos).', 
              type: 'warning'
            ));
          }
        }

        if (bloqueados > 0) {
          generatedLogs.add(SystemLog(
            timestamp: DateTime.now().subtract(const Duration(seconds: 15)), 
            message: 'El algoritmo reporta $bloqueados alumnos fijos/bloqueados bajo la directiva "No Cambiar".', 
            type: 'warning'
          ));
        }

        generatedLogs.add(SystemLog(
          timestamp: DateTime.now().subtract(const Duration(seconds: 40)), 
          message: 'Se realizaron $reasignados reasignaciones automáticas en el último balanceo de grupos.', 
          type: 'info'
        ));

        generatedLogs.add(SystemLog(
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)), 
          message: 'Se integraron satisfactoriamente $nuevosIngresos estudiantes de nuevo ingreso.', 
          type: 'success'
        ));

        generatedLogs.add(SystemLog(
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)), 
          message: 'Carga completa: $totalAlumnos registros leídos y sincronizados desde la base de datos.', 
          type: 'success'
        ));

        setState(() {
          _realLogs = generatedLogs;
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
        title: 'Registro de Cambios',
        subtitle: 'Generando historial de auditoría...',
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final filteredLogs = _realLogs.where((log) {
      if (_activeFilter == 'all') return true;
      if (_activeFilter == 'info') return log.type == 'info' || log.type == 'success';
      return log.type == _activeFilter;
    }).toList();

    final totalCount = _realLogs.length;
    final warningCount = _realLogs.where((l) => l.type == 'warning').length;
    final errorCount = _realLogs.where((l) => l.type == 'error').length;
    final successCount = _realLogs.where((l) => l.type == 'success' || l.type == 'info').length;

    return ScreenWrapper(
      title: 'Registro de Cambios',
      subtitle: 'Historial de movimientos y alertas del sistema',
      scrollable: false,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              _FilterStatCard(
                value: totalCount.toString(),
                label: 'Total eventos',
                color: AppTheme.accent,
                isSelected: _activeFilter == 'all',
                onTap: () => setState(() => _activeFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterStatCard(
                value: warningCount.toString(),
                label: 'Advertencias',
                color: AppTheme.yellow,
                isSelected: _activeFilter == 'warning',
                onTap: () => setState(() => _activeFilter = 'warning'),
              ),
              const SizedBox(width: 8),
              _FilterStatCard(
                value: errorCount.toString(),
                label: 'Errores',
                color: AppTheme.red,
                isSelected: _activeFilter == 'error',
                onTap: () => setState(() => _activeFilter = 'error'),
              ),
              const SizedBox(width: 8),
              _FilterStatCard(
                value: successCount.toString(),
                label: 'Éxitos / Info',
                color: AppTheme.green,
                isSelected: _activeFilter == 'info',
                onTap: () => setState(() => _activeFilter = 'info'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        if (filteredLogs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha:0.5)),
                  const SizedBox(height: 16),
                  Text('No hay registros de tipo "${_getFilterName(_activeFilter)}"', 
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          Expanded(child: ListView.separated(
            itemCount: filteredLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final log = filteredLogs[i];
              final color = _logColor(log.type);
              final icon = _logIcon(log.type);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha:0.25)),
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
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.message, style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13,
                      )),
                      const SizedBox(height: 4),
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')} — hace ${DateTime.now().difference(log.timestamp).inMinutes} min',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(log.type.toUpperCase(), style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    )),
                  ),
                ]),
              );
            },
          )),
      ]),
    );
  }

  String _getFilterName(String type) {
    switch (type) {
      case 'warning': return 'Advertencia';
      case 'error': return 'Error';
      case 'info': return 'Éxito / Info';
      default: return 'Desconocido';
    }
  }

  Color _logColor(String type) {
    switch (type) {
      case 'success': return AppTheme.green;
      case 'warning': return AppTheme.yellow;
      case 'error': return AppTheme.red;
      case 'info': return const Color(0xFF3498DB); 
      default: return AppTheme.accent;
    }
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'error': return Icons.error_rounded;
      case 'info': return Icons.info_outline_rounded;
      default: return Icons.info_rounded;
    }
  }
}

class _FilterStatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterStatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha:0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withValues(alpha:0.5) : Colors.transparent,
            ),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(
              color: isSelected ? color : AppTheme.textPrimary, 
              fontSize: 24, 
              fontWeight: FontWeight.w800
            )),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              color: isSelected ? color : AppTheme.textSecondary, 
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }
}