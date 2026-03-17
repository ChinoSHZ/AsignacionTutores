import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final filteredLogs = widget.logs.where((log) {
      if (_activeFilter == 'all') return true;
      return log.type == _activeFilter;
    }).toList();

    final totalCount = widget.logs.length;
    final warningCount = widget.logs.where((l) => l.type == 'warning').length;
    final errorCount = widget.logs.where((l) => l.type == 'error').length;
    final successCount = widget.logs.where((l) => l.type == 'success').length;

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
                label: 'Éxitos',
                color: AppTheme.green,
                isSelected: _activeFilter == 'success',
                onTap: () => setState(() => _activeFilter = 'success'),
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
                  Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
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
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
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
                        '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')} — hace ${DateTime.now().difference(log.timestamp).inMinutes} min',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
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
      case 'success': return 'Éxito';
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
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
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