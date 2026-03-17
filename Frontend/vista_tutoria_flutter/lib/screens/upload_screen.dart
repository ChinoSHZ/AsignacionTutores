import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _file1Loaded = false;
  bool _file2Loaded = false;

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Carga de Datos',
      subtitle: 'Importar archivos Excel para iniciar el proceso de asignación',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FileDropZone(
                label: 'Nuevos Ingresos',
                subtitle: 'Excel con alumnos de primer ingreso',
                icon: Icons.person_add_rounded,
                color: AppTheme.green,
                isLoaded: _file1Loaded,
                onLoad: () => setState(() => _file1Loaded = true),
              )),
              const SizedBox(width: 20),
              Expanded(child: _FileDropZone(
                label: 'Registro Histórico',
                subtitle: 'Excel con reingresantes y atributos de movilidad',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF3498DB),
                isLoaded: _file2Loaded,
                onLoad: () => setState(() => _file2Loaded = true),
              )),
            ],
          ),
          const SizedBox(height: 28),
          if (_file1Loaded && _file2Loaded) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.green),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Archivos listos', style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
                    Text('155 registros cargados. Puedes proceder con el algoritmo.', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13,
                    )),
                  ],
                )),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Iniciar Algoritmo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 28),
          _InfoCard(),
        ],
      ),
    );
  }
}

class _FileDropZone extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final bool isLoaded;
  final VoidCallback onLoad;

  const _FileDropZone({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isLoaded,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLoad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 200,
        decoration: BoxDecoration(
          color: isLoaded ? color.withValues(alpha:0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLoaded ? color.withValues(alpha:0.4) : AppTheme.border,
            width: isLoaded ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: isLoaded ? color.withValues(alpha:0.2) : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isLoaded ? Icons.check_circle_rounded : icon,
                color: isLoaded ? color : AppTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(
              color: isLoaded ? color : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            )),
            const SizedBox(height: 6),
            Text(
              isLoaded ? 'Archivo cargado ✓' : subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            if (!isLoaded) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha:0.3)),
                ),
                child: Text('Seleccionar archivo', style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 18),
            SizedBox(width: 10),
            Text('Reglas del Sistema', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            )),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            const _RuleChip(Icons.shuffle_rounded, 'Nuevos: Asignación aleatoria por carrera', AppTheme.green),
            const _RuleChip(Icons.lock_outline_rounded, 'No Cambiar: Inamovibles', AppTheme.red),
            const _RuleChip(Icons.swap_horiz_rounded, 'Sí Cambiar: Reasignables para balanceo', Color(0xFF3498DB)),
            const _RuleChip(Icons.balance_rounded, 'Meta: 29–31 alumnos por tutor', AppTheme.yellow),
          ]),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RuleChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}