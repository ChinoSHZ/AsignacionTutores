import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class DashboardScreen extends StatefulWidget {
  final List<Tutor> tutors;
  const DashboardScreen({super.key, required this.tutors});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterCareer = 'Todas';
  bool _warningShown = false;

  @override
  Widget build(BuildContext context) {
    final bool isFirstLogin = ModalRoute.of(context)?.settings.arguments as bool? ?? false;

    if (isFirstLogin && !_warningShown) {
      _warningShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstLoginWarning(context);
      });
    }

    final critical = widget.tutors.where((t) => t.status == BalanceStatus.critical).length;
    final balanced = widget.tutors.where((t) => t.status == BalanceStatus.balanced).length;

    final Set<String> allCareers = {};
    for (var t in widget.tutors) {
      allCareers.addAll(t.careers);
    }
    final filterOptions = ['Todas', ...allCareers.toList()..sort()];

    final filteredTutors = widget.tutors.where((t) {
      if (_filterCareer == 'Todas') return true;
      return t.careers.contains(_filterCareer);
    }).toList();

    return ScreenWrapper(
      title: 'Dashboard de Supervisión',
      subtitle: 'Resumen del estado actual de asignaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          const Expanded(child: _MetricCard('155', 'Alumnos Asignados', Icons.people_rounded, AppTheme.accent, '+58 nuevos')),
          const SizedBox(width: 16),
          const Expanded(child: _MetricCard('12', 'Movimientos', Icons.swap_horiz_rounded, AppTheme.yellow, 'Reasignados automáticamente')),
          const SizedBox(width: 16),
          const Expanded(child: _MetricCard('5', 'Bloqueados', Icons.lock_rounded, AppTheme.red, '"No Cambiar" sin mover')),
          const SizedBox(width: 16),
          Expanded(child: _MetricCard('$balanced / ${widget.tutors.length}', 'Grupos Balanceados', Icons.balance_rounded, AppTheme.green, 'Meta: 29-31 alumnos')),
        ]),

        const SizedBox(height: 24),

        if (critical > 0) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.red.withValues(alpha: 0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.error_rounded, color: AppTheme.red),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Requiere atención manual', style: TextStyle(
                  color: AppTheme.red, fontWeight: FontWeight.w700, fontSize: 14,
                )),
                Text('Hay grupos con desbalance crítico. Los alumnos marcados como "No Cambiar" pueden estar bloqueando el algoritmo.', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12,
                )),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estado por Tutor', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            )),
            Row(
              children: filterOptions.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  selected: _filterCareer == c,
                  onSelected: (val) => setState(() => _filterCareer = c),
                  backgroundColor: AppTheme.surfaceLight,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.accentLight,
                  labelStyle: TextStyle(
                    color: _filterCareer == c ? AppTheme.accentLight : AppTheme.textSecondary,
                    fontWeight: _filterCareer == c ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )).toList(),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240, 
            mainAxisExtent: 90, 
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filteredTutors.length,
          itemBuilder: (_, i) => _CompactTutorCard(tutor: filteredTutors[i]),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Semáforo: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              SizedBox(width: 12),
              _LegendDot(AppTheme.green, '29–31 Equilibrado'),
              SizedBox(width: 20),
              _LegendDot(AppTheme.yellow, '25–35 Leve desvío'),
              SizedBox(width: 20),
              _LegendDot(AppTheme.red, '<20 o >40 Crítico'),
            ],
          ),
        ),
      ]),
    );
  }

  void _showFirstLoginWarning(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.yellow),
            SizedBox(width: 10),
            Text("Advertencia", style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          "Antes de cerrar sesión vincule un usuario y contraseña al sistema.",
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CompactTutorCard extends StatelessWidget {
  final Tutor tutor;
  const _CompactTutorCard({required this.tutor});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(tutor.status);
    final pct = (tutor.count / 40).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  tutor.name.split(' ').last[0],
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tutor.name, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('${tutor.count}', style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800,
              )),
            ],
          ),
          Text(tutor.careers.join(' · '), style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 10,
          ), maxLines: 1, overflow: TextOverflow.ellipsis),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value, label, sub;
  final IconData icon;
  final Color color;
  const _MetricCard(this.value, this.label, this.icon, this.color, this.sub);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ]),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(
            color: color, fontSize: 26, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12,
          )),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 11,
          )),
        ],
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  final Tutor tutor;
  const _TutorCard({required this.tutor});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(tutor.status);
    final pct = (tutor.count / 40).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(
            tutor.name.split(' ').last[0],
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tutor.name, style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(tutor.careers.join(' · '), style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 11,
            )),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ],
        )),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${tutor.count}', style: TextStyle(
              color: color, fontSize: 24, fontWeight: FontWeight.w800,
            )),
            const Text('alumnos', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 10,
            )),
          ],
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
  ]);
}