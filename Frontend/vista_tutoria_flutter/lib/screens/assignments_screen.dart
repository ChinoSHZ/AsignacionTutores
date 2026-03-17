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
          s.accountNumber.contains(_searchQuery) ||
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

  void _showEditDialog(Student student) {
    showDialog(
      context: context,
      builder: (_) => _EditStudentDialog(
        student: student,
        tutors: widget.tutors,
        onSave: (String career, MobilityFlag mobility, String tutorId) {
          setState(() {
            student.career = career;
            student.mobility = mobility;
            if (student.tutorId != tutorId) {
              widget.onReassign(student, tutorId);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final careers = ['Todas', ...{...widget.students.map((s) => s.career)}];
    final mobilities = ['Todas', 'Nuevo Ingreso', 'Sí Cambiar', 'No Cambiar'];
    
    // Filtro dependiente para tutores
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
        // Barra de Filtros
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
                hintText: 'Buscar por nombre, matrícula o cuenta...',
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

        // Cabecera de la Tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(children: [
            Expanded(flex: 3, child: _TableHeader('Alumno (ID / Cuenta)')),
            Expanded(flex: 2, child: _TableHeader('Académico')),
            Expanded(flex: 3, child: _TableHeader('Tutor (Estado)')),
            Expanded(flex: 2, child: _TableHeader('Movilidad')),
            Expanded(flex: 1, child: _TableHeader('Estado')),
            SizedBox(width: 120, child: _TableHeader('Acciones', alignRight: true)),
          ]),
        ),

        // Cuerpo de la Tabla
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
                  
                  // COLUMNA 1: Alumno (Nombre, ID, Cuenta)
                  Expanded(flex: 3, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
                      )),
                      const SizedBox(height: 2),
                      Text('${s.id} • Cta: ${s.accountNumber}', style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11,
                      )),
                    ],
                  )),

                  // COLUMNA 2: Académico (Carrera, Periodo)
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.career, style: const TextStyle(
                          color: AppTheme.accentLight, fontSize: 10, fontWeight: FontWeight.bold,
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text('Ingreso: ${s.entryPeriod}', style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10,
                      )),
                    ],
                  )),

                  // COLUMNA 3: Tutor y Estado
                  Expanded(flex: 3, child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.statusColor(tutor.status).withOpacity(0.15), 
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(
                        tutor.name.split(' ').last[0], 
                        style: TextStyle(color: AppTheme.statusColor(tutor.status), fontWeight: FontWeight.w700, fontSize: 12),
                      )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tutor.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis),
                        Row(children: [
                          Text('${tutor.count} alumnos • ', style: TextStyle(color: AppTheme.statusColor(tutor.status), fontSize: 10)),
                          Text(tutor.isActive ? 'Activo' : 'Baja', style: TextStyle(
                            color: tutor.isActive ? AppTheme.green : AppTheme.red, 
                            fontSize: 10, fontWeight: FontWeight.bold,
                          )),
                        ]),
                      ],
                    )),
                  ])),

                  // COLUMNA 4: Movilidad
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
                          size: 11, color: mobilityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(AppTheme.mobilityLabel(s.mobility), style: TextStyle(
                          color: mobilityColor, fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ]),
                    ),
                  ])),

                  // COLUMNA 5: Indicador de Estado (M / C)
                  Expanded(flex: 1, child: Row(children: [
                    s.wasReassigned 
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.yellow.withOpacity(0.2), 
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('C', style: TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.w800, fontSize: 12)),
                            SizedBox(width: 4),
                            Icon(Icons.cached_rounded, color: AppTheme.yellow, size: 12),
                          ]),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.15), 
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('M', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                  ])),

                  // COLUMNA 6: Acciones
                  SizedBox(width: 120, child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      isLocked
                        ? const Tooltip(
                            message: 'Alumno bloqueado',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.lock_rounded, size: 16, color: AppTheme.textSecondary),
                            ),
                          )
                        : IconButton(
                            onPressed: () => _showReassignDialog(s),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            color: AppTheme.accent,
                            tooltip: 'Reasignar',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                      
                      IconButton(
                        onPressed: () => _showEditDialog(s),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        color: const Color(0xFF3498DB),
                        tooltip: 'Editar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  )),
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
  final bool alignRight;
  const _TableHeader(this.label, {this.alignRight = false});
  
  @override
  Widget build(BuildContext context) => Text(
    label, 
    textAlign: alignRight ? TextAlign.right : TextAlign.left,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    )
  );
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

class _EditStudentDialog extends StatefulWidget {
  final Student student;
  final List<Tutor> tutors;
  final Function(String, MobilityFlag, String) onSave;

  const _EditStudentDialog({
    required this.student,
    required this.tutors,
    required this.onSave,
  });

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late String _selectedCareer;
  late MobilityFlag _selectedMobility;
  late String _selectedTutorId;

  @override
  void initState() {
    super.initState();
    _selectedCareer = widget.student.career;
    _selectedMobility = widget.student.mobility;
    _selectedTutorId = widget.student.tutorId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Editar Alumno: ${widget.student.name}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCareer,
              decoration: _inputDeco('Carrera'),
              dropdownColor: AppTheme.surfaceLight,
              items: ['Computación', 'IA', 'Robótica'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
              onChanged: (v) => setState(() => _selectedCareer = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MobilityFlag>(
              value: _selectedMobility,
              decoration: _inputDeco('Movilidad'),
              dropdownColor: AppTheme.surfaceLight,
              items: MobilityFlag.values.map((m) => DropdownMenuItem(value: m, child: Text(AppTheme.mobilityLabel(m), style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
              onChanged: (v) => setState(() => _selectedMobility = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTutorId,
              decoration: _inputDeco('Tutor Asignado'),
              dropdownColor: AppTheme.surfaceLight,
              items: widget.tutors.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
              onChanged: (v) => setState(() => _selectedTutorId = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          onPressed: () {
            widget.onSave(_selectedCareer, _selectedMobility, _selectedTutorId);
            Navigator.pop(context);
          },
          child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}