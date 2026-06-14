import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  bool _isLoading = true;
  List<Tutor> _realTutors = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'), headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        
        List<Tutor> loadedTutors = [];
        for (var t in tutorsJson) {
          List<Student> tutorStudents = [];
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  if (pivot['estado_tutorado'] == 'activo' || stud['is_active'] == 1 || stud['is_active'] == true) {
                    MobilityFlag flag = MobilityFlag.noChange;
                    if (pivot['movilidad'] == 'cambiar') flag = MobilityFlag.canChange;
                    if (pivot['movilidad'] == 'nuevo_ingreso') flag = MobilityFlag.newStudent;
                    
                    tutorStudents.add(Student(
                      id: stud['id'].toString(),
                      name: stud['nombre'],
                      accountNumber: stud['numero_cuenta'].toString(),
                      entryPeriod: stud['periodo_ingreso'] ?? '',
                      career: stud['licenciatura'] != null ? stud['licenciatura']['abreviatura'] : 'S/L',
                      isReentry: flag != MobilityFlag.newStudent,
                      mobility: flag,
                      tutorId: t['id'].toString(),
                      isActive: true,
                    ));
                  }
                }
              }
            }
          }

          // BIFURCACIÓN VIRTUAL POR CARRERA
          List<String> officialCareers = (t['licenciaturas'] as List?)?.map((l) => l['abreviatura'].toString().trim()).toList() ?? [];
          if (officialCareers.isEmpty) officialCareers.add('S/L');

          Set<String> allCareersForTutor = {...officialCareers};
          for (var s in tutorStudents) {
             allCareersForTutor.add(s.career);
          }

          for (String c in allCareersForTutor) {
             List<Student> careerStudents = tutorStudents.where((s) => s.career == c).toList();
             if (!officialCareers.contains(c) && careerStudents.isEmpty) continue;

             final virtualId = '${t['id']}_$c';
             for (var s in careerStudents) {
                s.tutorId = virtualId;
             }

             loadedTutors.add(Tutor(
                id: virtualId,
                name: '${t['nombre']} ${t['apellido_paterno']} ($c)',
                department: 'Ingeniería',
                careers: [c],
                students: careerStudents,
                isActive: t['estado'] == 'Activo',
             ));
          }
        }
        setState(() {
          _realTutors = loadedTutors;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    bool isFirstLogin = false;
    
    if (args is Map<String, dynamic>) {
      isFirstLogin = args['first_login'] ?? false;
    } else if (args is bool) {
      isFirstLogin = args;
    }

    if (isFirstLogin && !_warningShown) {
      _warningShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstLoginWarning(context);
      });
    }

    if (_isLoading) {
      return const ScreenWrapper(
        title: 'Dashboard de Supervisión',
        subtitle: 'Cargando datos en tiempo real...',
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final Set<String> allCareers = {'S/L'};
    for (var t in _realTutors) {
      if (t.careers.isEmpty) {
        allCareers.add('S/L');
      } else {
        allCareers.addAll(t.careers);
      }
    }
    final filterOptions = ['Todas', ...allCareers.toList()..sort()];

    final filteredTutors = _realTutors.where((t) {
      if (_filterCareer == 'Todas') return true;
      if (_filterCareer == 'S/L' && t.careers.isEmpty) return true;
      return t.careers.contains(_filterCareer);
    }).toList();
    
    int totalAlumnos = 0;
    int reasignados = 0;
    int bloqueados = 0;
    int nuevos = 0;

    for (var t in filteredTutors) {
      totalAlumnos += t.count;
      reasignados += t.students.where((s) => s.mobility == MobilityFlag.canChange).length;
      bloqueados += t.students.where((s) => s.mobility == MobilityFlag.noChange).length;
      nuevos += t.students.where((s) => s.mobility == MobilityFlag.newStudent).length;
    }

    int average = filteredTutors.isNotEmpty ? (totalAlumnos / filteredTutors.length).round() : 30;
    
    int minBalanced = (average - 3).clamp(1, 999);
    int maxBalanced = average + 3;
    int minWarning = (average - 5).clamp(1, 999);
    int maxWarning = average + 5;

    final critical = filteredTutors.where((t) => t.count < minWarning || t.count > maxWarning).length;
    final balanced = filteredTutors.where((t) => t.count >= minBalanced && t.count <= maxBalanced).length;

    return ScreenWrapper(
      title: 'Dashboard de Supervisión',
      subtitle: 'Resumen del estado actual de asignaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          Expanded(child: _MetricCard('$totalAlumnos', 'Alumnos Asignados', Icons.people_rounded, AppTheme.accent, '+$nuevos nuevos')),
          const SizedBox(width: 16),
          Expanded(child: _MetricCard('$reasignados', 'Movimientos', Icons.swap_horiz_rounded, AppTheme.yellow, 'Reasignados automáticamente')),
          const SizedBox(width: 16),
          Expanded(child: _MetricCard('$bloqueados', 'Bloqueados', Icons.lock_rounded, AppTheme.red, '"No Cambiar" sin mover')),
          const SizedBox(width: 16),
          Expanded(child: _MetricCard('$balanced / ${filteredTutors.length}', 'Grupos Balanceados', Icons.balance_rounded, AppTheme.green, 'Meta: $minBalanced-$maxBalanced alumnos')),
        ]),

        const SizedBox(height: 24),

        if (critical > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.red.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.error_rounded, color: AppTheme.red),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$critical grupos requieren atención manual', style: const TextStyle(
                    color: AppTheme.red, fontWeight: FontWeight.w700, fontSize: 14,
                  )),
                  const Text('Hay grupos con desbalance crítico. Los alumnos marcados como "No Cambiar" pueden estar bloqueando el algoritmo.', style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12,
                  )),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Semáforo: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    text: '$minBalanced–$maxBalanced ',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Roboto'),
                    children: [
                      const TextSpan(text: '(Ideal: '),
                      TextSpan(text: '$average', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 13)),
                      const TextSpan(text: ') Equilibrado'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(width: 20),
              _LegendDot(AppTheme.yellow, '$minWarning–$maxWarning Leve desvío'),
              const SizedBox(width: 20),
              _LegendDot(AppTheme.red, '<$minWarning o >$maxWarning Crítico'),
            ],
          ),
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
          itemBuilder: (_, i) => _CompactTutorCard(
            tutor: filteredTutors[i],
            average: average,
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
  final int average;
  
  const _CompactTutorCard({required this.tutor, required this.average});

  BalanceStatus _getDynamicStatus() {
    int lowBalanced = (average - 3).clamp(1, 999);
    int highBalanced = average + 3;
    int lowWarning = (average - 5).clamp(1, 999);
    int highWarning = average + 5;

    if (tutor.count >= lowBalanced && tutor.count <= highBalanced) return BalanceStatus.balanced;
    if (tutor.count >= lowWarning && tutor.count <= highWarning) return BalanceStatus.warning;
    return BalanceStatus.critical;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(_getDynamicStatus());
    final pct = (tutor.count / (average + 10)).clamp(0.0, 1.0); 

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