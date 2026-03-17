import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class AssignmentsScreen extends StatefulWidget {
  final List<Tutor> tutors;
  final List<Student> students;
  final void Function(Student, String) onReassign;

  const AssignmentsScreen({
    super.key,
    required this.tutors,
    required this.students,
    required this.onReassign,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _searchQuery = '';
  String _filterCareer = 'Todas';
  String _filterMobility = 'Todas';
  String _filterTutor = 'Todos';

  List<Student> get _filtered {
    return widget.students.where((s) {
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCareer = _filterCareer == 'Todas' || s.career == _filterCareer;
      final matchMobility = _filterMobility == 'Todas' ||
          AppTheme.mobilityLabel(s.mobility) == _filterMobility;
      final matchTutor = _filterTutor == 'Todos' || s.tutorId == _filterTutor;
      return matchSearch && matchCareer && matchMobility && matchTutor;
    }).toList();
  }

  void _showReassignDialog(Student student) {
    final available = widget.tutors.where((t) =>
        t.id != student.tutorId && t.count < 35
    ).toList();

    showDialog(
      context: context,
      builder: (_) => _ReassignDialog(
        student: student,
        availableTutors: available,
        currentTutor: widget.tutors.firstWhere((t) => t.id == student.tutorId),
        onReassign: (newId) {
          widget.onReassign(student, newId);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final careers = ['Todas', ...{...widget.students.map((s) => s.career)}];
    final mobilities = ['Todas', 'Nuevo Ingreso', 'Sí Cambiar', 'No Cambiar'];
    
    final availableTutorsForFilter = _filterCareer == 'Todas'
        ? widget.tutors 
        : widget.tutors.where((t) => t.careers.contains(_filterCareer)).toList(); 

    final tutorOptions = [
      ('Todos', 'Todos'), 
      ...availableTutorsForFilter.map((t) => (t.id, t.name))
    ];

    return ScreenWrapper(
      title: 'Revisión de Asignaciones',
      subtitle: 'Gestión manual de asignaciones. ${filtered.length} registros.',
      scrollable: false,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o matrícula...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Filtros:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(child: _DropdownFilter<String>(
                label: 'Carrera',
                value: _filterCareer,
                options: careers,
                onChanged: (v) {
                  setState(() {
                    _filterCareer = v ?? 'Todas';
                    _filterTutor = 'Todos'; 
                  });
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _DropdownFilter<String>(
                label: 'Movilidad',
                value: _filterMobility,
                options: mobilities,
                onChanged: (v) => setState(() => _filterMobility = v ?? 'Todas'),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: _filterTutor,
                decoration: InputDecoration(
                  labelText: 'Tutor',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                dropdownColor: AppTheme.surfaceLight,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                items: tutorOptions.map((t) => DropdownMenuItem(
                  value: t.$1, 
                  child: Text(t.$2, overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (v) => setState(() => _filterTutor = v ?? 'Todos'),
              )),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(children: [
            Expanded(flex: 2, child: _TableHeader('Alumno / Matrícula')),
            Expanded(flex: 2, child: _TableHeader('Carrera')),
            Expanded(flex: 3, child: _TableHeader('Tutor Asignado')),
            Expanded(flex: 2, child: _TableHeader('Tipo / Movilidad')),
            SizedBox(width: 120, child: _TableHeader('Acción')),
          ]),
        ),

        Expanded(child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: AppTheme.border),
          ),
          child: filtered.isEmpty 
          ? const Center(
              child: Text('No se encontraron alumnos con estos filtros', style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
            itemBuilder: (_, i) {
              final s = filtered[i];
              final tutor = widget.tutors.firstWhere((t) => t.id == s.tutorId, orElse: () => widget.tutors.first);
              final mobilityColor = AppTheme.mobilityColor(s.mobility);
              final isLocked = s.mobility == MobilityFlag.noChange;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: s.wasReassigned ? AppTheme.yellow.withOpacity(0.04) : Colors.transparent,
                child: Row(children: [
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(s.name, style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13,
                        )),
                        if (s.wasReassigned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.yellow.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Movido', style: TextStyle(
                              color: AppTheme.yellow, fontSize: 9, fontWeight: FontWeight.w700,
                            )),
                          ),
                        ],
                      ]),
                      Text(s.id, style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11,
                      )),
                    ],
                  )),
                  Expanded(flex: 2, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s.career, style: const TextStyle(
                      color: AppTheme.accentLight, fontSize: 12,
                    )),
                  )),
                  Expanded(flex: 3, child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.statusColor(tutor.status).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(
                        tutor.name.split(' ').last[0],
                        style: TextStyle(
                          color: AppTheme.statusColor(tutor.status),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tutor.name, style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12,
                        ), overflow: TextOverflow.ellipsis),
                        Text('${tutor.count} alumnos', style: TextStyle(
                          color: AppTheme.statusColor(tutor.status), fontSize: 10,
                        )),
                      ],
                    )),
                  ])),
                  Expanded(flex: 2, child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: mobilityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: mobilityColor.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isLocked ? Icons.lock_rounded : (s.mobility == MobilityFlag.newStudent ? Icons.fiber_new_rounded : Icons.swap_horiz_rounded),
                          size: 11,
                          color: mobilityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(AppTheme.mobilityLabel(s.mobility), style: TextStyle(
                          color: mobilityColor, fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ]),
                    ),
                  ])),
                  SizedBox(width: 120, child: isLocked
                    ? Tooltip(
                        message: 'Este alumno no puede ser reasignado',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_rounded, size: 13, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Bloqueado', style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11,
                            )),
                          ]),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () => _showReassignDialog(s),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                        label: const Text('Reasignar', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          backgroundColor: AppTheme.accent.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                  ),
                ]),
              );
            },
          ),
        )),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  const _TableHeader(this.label);
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  ));
}

class _DropdownFilter<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final void Function(T?) onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      dropdownColor: AppTheme.surfaceLight,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toString(), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}

class _ReassignDialog extends StatelessWidget {
  final Student student;
  final List<Tutor> availableTutors;
  final Tutor currentTutor;
  final void Function(String) onReassign;

  const _ReassignDialog({
    required this.student,
    required this.availableTutors,
    required this.currentTutor,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reasignar Alumno', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18,
                )),
                Text(student.name, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13,
                )),
              ]),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
              ),
            ]),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Text('Tutor actual: ', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13,
                )),
                Text(currentTutor.name, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
                )),
                const Spacer(),
                Text('${currentTutor.count} alumnos', style: TextStyle(
                  color: AppTheme.statusColor(currentTutor.status), fontSize: 12,
                )),
              ]),
            ),

            const SizedBox(height: 20),

            const Text('Tutores disponibles', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.5,
            )),
            const SizedBox(height: 10),

            if (availableTutors.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay tutores con capacidad disponible.', style: TextStyle(
                  color: AppTheme.textSecondary,
                )),
              )
            else
              ...availableTutors.map((t) {
                final color = AppTheme.statusColor(t.status);
                final spotsLeft = 31 - t.count;
                return GestureDetector(
                  onTap: () {
                    onReassign(t.id);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(t.name.split(' ').last[0], style: TextStyle(
                          color: color, fontWeight: FontWeight.w800,
                        ))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: const TextStyle(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                          Text(t.careers.join(' · '), style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11,
                          )),
                        ],
                      )),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${t.count}', style: TextStyle(
                          color: color, fontSize: 20, fontWeight: FontWeight.w800,
                        )),
                        Text(spotsLeft > 0 ? '+$spotsLeft espacios' : 'lleno', style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 10,
                        )),
                      ]),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}