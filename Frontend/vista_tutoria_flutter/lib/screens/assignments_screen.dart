import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class AssignmentsScreen extends StatefulWidget {
  final List<Tutor> tutors; // Se mantienen para compatibilidad, pero usaremos _realTutors
  final List<Student> students; // Se mantienen para compatibilidad, pero usaremos _realStudents
  final List<Career> careers;
  final void Function(Student, String) onReassign;

  const AssignmentsScreen({
    super.key,
    required this.tutors,
    required this.students,
    required this.careers,
    required this.onReassign,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  // ── ESTADO PARA DATOS REALES ──────────────────────────────
  bool _isLoading = true;
  List<Tutor> _realTutors = [];
  List<Student> _realStudents = [];
  // ──────────────────────────────────────────────────────────

  String _searchQuery = '';
  String _filterCareer = 'Todas';
  String _filterMobility = 'Todas';
  String _filterTutor = 'Todos';

  // ── Filtro de semestre ────────────────────────────────────
  String _filterSemestre = 'Todos';
  List<String> _semestres = ['Todos'];
  bool _loadingSemestres = false;
  // ──────────────────────────────────────────────────────────

  // Variables para paginación
  int _currentPage = 0;
  final int _itemsPerPage = 100;

  @override
  void initState() {
    super.initState();
    _loadSemestres();
    _fetchAsignacionesRealTime(); // Cargar datos reales de Postgres
  }

  // ── Carga de semestres desde el backend ────────────────
  Future<void> _loadSemestres() async {
    setState(() => _loadingSemestres = true);
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/semestres'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _semestres = [
            'Todos',
            ...data.map((s) => s['clave'].toString()),
          ];
        });
      }
    } catch (_) {
      // Si falla la carga, el combo queda solo con 'Todos'
    } finally {
      setState(() => _loadingSemestres = false);
    }
  }

  // ── Carga de asignaciones desde el backend ───────────────
  Future<void> _fetchAsignacionesRealTime() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        
        List<Tutor> loadedTutors = [];
        List<Student> loadedStudents = [];

        for (var t in tutorsJson) {
          List<Student> tutorStudents = [];
          
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  var movilidadDB = pivot['movilidad'] ?? 'no_cambiar';
                  
                  MobilityFlag flag = MobilityFlag.noChange;
                  if (movilidadDB == 'cambiar') flag = MobilityFlag.canChange;
                  if (movilidadDB == 'nuevo_ingreso') flag = MobilityFlag.newStudent;

                  var s = Student(
                    id: stud['id'].toString(),
                    name: '${stud['nombre']} ${stud['apellido_paterno']} ${stud['apellido_materno'] ?? ''}'.trim(),
                    accountNumber: stud['numero_cuenta'].toString(),
                    entryPeriod: stud['periodo_ingreso'] ?? '',
                    career: (t['licenciaturas'] != null && t['licenciaturas'].isNotEmpty) 
                        ? t['licenciaturas'][0]['abreviatura'] 
                        : 'N/A',
                    isReentry: flag != MobilityFlag.newStudent,
                    mobility: flag,
                    tutorId: t['id'].toString(),
                    isActive: stud['is_active'] == 1 || stud['is_active'] == true,
                  );
                  tutorStudents.add(s);
                  loadedStudents.add(s);
                }
              }
            }
          }

          loadedTutors.add(Tutor(
            id: t['id'].toString(),
            name: '${t['nombre']} ${t['apellido_paterno']}',
            department: 'Ingeniería',
            careers: (t['licenciaturas'] != null) 
                ? (t['licenciaturas'] as List).map((l) => l['abreviatura'] as String).toList() 
                : [],
            students: tutorStudents,
            isActive: t['estado'] == 'Activo',
          ));
        }

        setState(() {
          _realTutors = loadedTutors;
          _realStudents = loadedStudents;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error cargando asignaciones: $e");
      setState(() => _isLoading = false);
    }
  }
  // ──────────────────────────────────────────────────────────

  List<Student> get _filtered {
    return _realStudents.where((s) {
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.accountNumber.contains(_searchQuery) ||
          s.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCareer = _filterCareer == 'Todas' || s.career == _filterCareer;
      final matchMobility = _filterMobility == 'Todas' ||
          AppTheme.mobilityLabel(s.mobility) == _filterMobility;
      final matchTutor = _filterTutor == 'Todos' || s.tutorId == _filterTutor;
      final matchSemestre = _filterSemestre == 'Todos' || s.entryPeriod == _filterSemestre;

      return matchSearch && matchCareer && matchMobility && matchTutor && matchSemestre;
    }).toList();
  }

  void _showReassignDialog(Student student) {
    final available = _realTutors.where((t) => t.id != student.tutorId && t.count < 35).toList();
    showDialog(
      context: context,
      builder: (_) => _ReassignDialog(
        student: student,
        availableTutors: available,
        currentTutor: _realTutors.firstWhere((t) => t.id == student.tutorId),
        onReassign: (newId) {
          // Lógica local (luego la conectaremos a un UPDATE en Laravel)
          setState(() {
            final oldTutor = _realTutors.firstWhere((t) => t.id == student.tutorId);
            final newTutor = _realTutors.firstWhere((t) => t.id == newId);
            
            student.previousTutorId = student.tutorId;
            student.tutorId = newId;
            student.wasReassigned = true;

            oldTutor.students.remove(student);
            newTutor.students.add(student);
          });
        },
      ),
    );
  }

  void _showStudentDialog({Student? student}) {
    showDialog(
      context: context,
      builder: (_) => _StudentDialog(
        student: student,
        tutors: _realTutors,
        careersCatalog: widget.careers,
        onSave: (id, name, account, period, career, mobility, tutorId, isActive) {
          setState(() {
            if (student == null) {
              final newStudent = Student(
                id: id,
                name: name,
                accountNumber: account,
                entryPeriod: period,
                career: career,
                isReentry: mobility != MobilityFlag.newStudent,
                mobility: mobility,
                tutorId: tutorId,
                isActive: isActive,
              );
              _realStudents.add(newStudent);
              _realTutors.firstWhere((t) => t.id == tutorId).students.add(newStudent);
            } else {
              final index = _realStudents.indexOf(student);
              if (index != -1) {
                final updatedStudent = Student(
                  id: student.id,
                  name: name,
                  accountNumber: account,
                  entryPeriod: period,
                  career: career,
                  isReentry: student.isReentry,
                  mobility: mobility,
                  tutorId: tutorId,
                  previousTutorId: student.tutorId != tutorId
                      ? student.tutorId
                      : student.previousTutorId,
                  wasReassigned: student.tutorId != tutorId || student.wasReassigned,
                  isActive: isActive,
                );
                _realStudents[index] = updatedStudent;

                if (student.tutorId != tutorId) {
                  _realTutors.firstWhere((t) => t.id == student.tutorId).students.remove(student);
                  _realTutors.firstWhere((t) => t.id == tutorId).students.add(updatedStudent);
                }
              }
            }
          });
        },
      ),
    );
  }

  void _deleteStudent(Student student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar Alumno', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('¿Estás seguro de eliminar a ${student.name}?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _realStudents.remove(student);
                _realTutors.firstWhere((t) => t.id == student.tutorId).students.remove(student);

                final filteredCount = _filtered.length;
                final totalPages = (filteredCount / _itemsPerPage).ceil();
                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showCareerChangeDialog(Student student) {
    showDialog(
      context: context,
      builder: (_) => _QuickChangeDialog<String>(
        title: 'Cambiar Licenciatura',
        currentValue: student.career,
        options: widget.careers.map((c) => c.abbreviation).toList(),
        labelBuilder: (val) => val,
        onSave: (newCareer) {
          setState(() => student.career = newCareer);
        },
      ),
    );
  }

  void _showMobilityChangeDialog(Student student) {
    showDialog(
      context: context,
      builder: (_) => _QuickChangeDialog<MobilityFlag>(
        title: 'Cambiar Movilidad',
        currentValue: student.mobility,
        options: MobilityFlag.values,
        labelBuilder: (val) => AppTheme.mobilityLabel(val),
        onSave: (newMobility) {
          setState(() => student.mobility = newMobility);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Cálculo de paginación
    final totalPages = (filtered.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final paginatedStudents = filtered.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList();

    final careerOptions = ['Todas', ...widget.careers.map((c) => c.abbreviation)];
    final mobilities = ['Todas', 'Nuevo Ingreso', 'Sí Cambiar', 'No Cambiar'];

    final availableTutorsForFilter = _filterCareer == 'Todas'
        ? _realTutors
        : _realTutors.where((t) => t.careers.contains(_filterCareer)).toList();

    final tutorOptions = [
      ('Todos', 'Todos'),
      ...availableTutorsForFilter.map((t) => (t.id, t.name))
    ];

    return ScreenWrapper(
      title: 'Revisión de Asignaciones',
      subtitle: 'Gestión manual de asignaciones. ${filtered.length} registros en total.',
      scrollable: false,
      child: Column(children: [
        // Barra de Filtros y Alta
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _currentPage = 0;
                  }),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, matrícula o cuenta...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // ── NUEVO: BOTÓN DE REFRESCAR ──
              IconButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadSemestres();
                  _fetchAsignacionesRealTime();
                },
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.accent,
                tooltip: 'Actualizar datos',
              ),
              const SizedBox(width: 8),
              
              ElevatedButton.icon(
                onPressed: () => _showStudentDialog(),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Alta de Alumno'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Filtros:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(
                  child: _DropdownFilter<String>(
                      label: 'Carrera',
                      value: _filterCareer,
                      options: careerOptions,
                      onChanged: (v) {
                        setState(() {
                          _filterCareer = v ?? 'Todas';
                          _filterTutor = 'Todos';
                          _currentPage = 0;
                        });
                      })),
              const SizedBox(width: 10),
              Expanded(
                  child: _DropdownFilter<String>(
                      label: 'Movilidad',
                      value: _filterMobility,
                      options: mobilities,
                      onChanged: (v) {
                        setState(() {
                          _filterMobility = v ?? 'Todas';
                          _currentPage = 0;
                        });
                      })),
              const SizedBox(width: 10),
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: _filterTutor,
                decoration: InputDecoration(
                    labelText: 'Tutor',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                dropdownColor: AppTheme.surfaceLight,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                items: tutorOptions.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() {
                  _filterTutor = v ?? 'Todos';
                  _currentPage = 0;
                }),
              )),
              const SizedBox(width: 10),
              Expanded(
                child: _loadingSemestres
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                        ),
                      )
                    : _DropdownFilter<String>(
                        label: 'Semestre',
                        value: _filterSemestre,
                        options: _semestres,
                        onChanged: (v) {
                          setState(() {
                            _filterSemestre = v ?? 'Todos';
                            _currentPage = 0;
                          });
                        },
                      ),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: AppTheme.border)),
          child: const Row(children: [
            Expanded(flex: 3, child: _TableHeader('Alumno (ID / Cuenta)')),
            Expanded(flex: 2, child: _TableHeader('Licenciatura')),
            Expanded(flex: 3, child: _TableHeader('Tutor (Estado)')),
            Expanded(flex: 2, child: _TableHeader('Movilidad')),
            Expanded(flex: 1, child: _TableHeader('Estado')),
            SizedBox(width: 140, child: _TableHeader('Acciones', alignRight: true)),
          ]),
        ),

        // Cuerpo de la Tabla
        Expanded(
            child: Container(
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border.all(color: AppTheme.border)),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : paginatedStudents.isEmpty
              ? const Center(child: Text('No se encontraron alumnos con estos filtros', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.separated(
                  itemCount: paginatedStudents.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
                  itemBuilder: (_, i) {
                    final s = paginatedStudents[i];
                    final tutor = _realTutors.firstWhere(
                        (t) => t.id == s.tutorId,
                        orElse: () => _realTutors.first);
                    final mobilityColor = AppTheme.mobilityColor(s.mobility);
                    final isLocked = s.mobility == MobilityFlag.noChange;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: (!s.isActive)
                          ? AppTheme.red.withOpacity(0.02)
                          : (s.wasReassigned ? AppTheme.yellow.withOpacity(0.04) : Colors.transparent),
                      child: Row(children: [
                        Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: TextStyle(
                                        color: s.isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Text('${s.id} • Cta: ${s.accountNumber}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                  if (!s.isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                          color: AppTheme.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Baja',
                                          style: TextStyle(color: AppTheme.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                    )
                                  ]
                                ])
                              ],
                            )),

                        Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _showCareerChangeDialog(s),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: AppTheme.accent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text(s.career,
                                          style: const TextStyle(
                                              color: AppTheme.accentLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Ingreso: ${s.entryPeriod}',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ),
                            )),

                        Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: isLocked ? null : () => _showReassignDialog(s),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(tutor.name,
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                    Row(children: [
                                      Text('${tutor.count} alumnos • ',
                                          style: TextStyle(color: AppTheme.statusColor(tutor.status), fontSize: 10)),
                                      Text(tutor.isActive ? 'Activo' : 'Baja',
                                          style: TextStyle(
                                              color: tutor.isActive ? AppTheme.green : AppTheme.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ]),
                                  ],
                                ),
                              ),
                            )),

                        Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _showMobilityChangeDialog(s),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: mobilityColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: mobilityColor.withOpacity(0.3))),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(
                                          isLocked
                                              ? Icons.lock_rounded
                                              : (s.mobility == MobilityFlag.newStudent
                                                  ? Icons.fiber_new_rounded
                                                  : Icons.swap_horiz_rounded),
                                          size: 11,
                                          color: mobilityColor),
                                      const SizedBox(width: 4),
                                      Text(AppTheme.mobilityLabel(s.mobility),
                                          style: TextStyle(color: mobilityColor, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                                ]),
                              ),
                            )),

                        Expanded(
                            flex: 1,
                            child: Row(children: [
                              s.wasReassigned
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppTheme.yellow.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6)),
                                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text('C',
                                            style: TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.w800, fontSize: 12)),
                                        SizedBox(width: 4),
                                        Icon(Icons.cached_rounded, color: AppTheme.yellow, size: 12)
                                      ]))
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppTheme.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6)),
                                      child: const Text('M',
                                          style: TextStyle(
                                              color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 12))),
                            ])),

                        SizedBox(
                            width: 140,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                isLocked
                                    ? const Tooltip(
                                        message: 'Bloqueado',
                                        child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 10),
                                            child: Icon(Icons.lock_rounded, size: 16, color: AppTheme.textSecondary)))
                                    : IconButton(
                                        onPressed: () => _showReassignDialog(s),
                                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                        color: AppTheme.accent,
                                        tooltip: 'Reasignar',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8)),
                                IconButton(
                                    onPressed: () => _showStudentDialog(student: s),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    color: const Color(0xFF3498DB),
                                    tooltip: 'Editar',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8)),
                                IconButton(
                                    onPressed: () => _deleteStudent(s),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    color: AppTheme.red,
                                    tooltip: 'Eliminar',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8)),
                              ],
                            )),
                      ]),
                    );
                  },
                ),
        )),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textSecondary),
                      SizedBox(width: 10),
                      Text('Notas: ',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('En la columna Estado, ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Text('M', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(' = Mantener (Sin cambios)  |  ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Text('C', style: TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(' = Cambiar (Reasignado a un tutor distinto)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              if (totalPages > 1) ...[
                const SizedBox(width: 16),
                Container(
                  width: 1, height: 20, color: AppTheme.border, margin: const EdgeInsets.only(right: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 20),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  disabledColor: AppTheme.textSecondary.withOpacity(0.3),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 12),
                Text('Página ${_currentPage + 1} de $totalPages',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary, size: 20),
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  disabledColor: AppTheme.textSecondary.withOpacity(0.3),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ]
            ],
          ),
        ),
      ]),
    );
  }
}

// ==============================================================================
// UTILS
// ==============================================================================

class _TableHeader extends StatelessWidget {
  final String label;
  final bool alignRight;
  const _TableHeader(this.label, {this.alignRight = false});
  @override
  Widget build(BuildContext context) => Text(label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _DropdownFilter<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final void Function(T?) onChanged;

  const _DropdownFilter(
      {required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          filled: true,
          fillColor: AppTheme.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      dropdownColor: AppTheme.surfaceLight,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toString(), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}

// ==============================================================================
// DIALOGS
// ==============================================================================

class _QuickChangeDialog<T> extends StatefulWidget {
  final String title;
  final T currentValue;
  final List<T> options;
  final String Function(T) labelBuilder;
  final Function(T) onSave;

  const _QuickChangeDialog({
    required this.title, required this.currentValue, required this.options, required this.labelBuilder, required this.onSave,
  });

  @override
  State<_QuickChangeDialog<T>> createState() => _QuickChangeDialogState<T>();
}

class _QuickChangeDialogState<T> extends State<_QuickChangeDialog<T>> {
  late T _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      content: SizedBox(
        width: 300,
        child: DropdownButtonFormField<T>(
          value: _selectedValue,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          dropdownColor: AppTheme.surfaceLight,
          items: widget.options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(widget.labelBuilder(o), style: const TextStyle(color: AppTheme.textPrimary))))
              .toList(),
          onChanged: (v) => setState(() => _selectedValue = v as T),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          onPressed: () {
            widget.onSave(_selectedValue);
            Navigator.pop(context);
          },
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ReassignDialog extends StatelessWidget {
  final Student student;
  final List<Tutor> availableTutors;
  final Tutor currentTutor;
  final void Function(String) onReassign;
  
  const _ReassignDialog(
      {required this.student, required this.availableTutors, required this.currentTutor, required this.onReassign});

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
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.accent, size: 22)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Reasignar Alumno', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                      Text(student.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                    ]),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 20),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Text('Tutor actual: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text(currentTutor.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Text('${currentTutor.count} alumnos', style: TextStyle(color: AppTheme.statusColor(currentTutor.status), fontSize: 12))
                  ])),
              const SizedBox(height: 20),
              const Text('Tutores disponibles',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              if (availableTutors.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay tutores con capacidad disponible.', style: TextStyle(color: AppTheme.textSecondary)))
              else
                ...availableTutors.map((t) {
                  final color = AppTheme.statusColor(t.status);
                  final spotsLeft = 35 - t.count;
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
                          border: Border.all(color: color.withOpacity(0.3))),
                      child: Row(children: [
                        Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                            child: Center(
                                child: Text(t.name.split(' ').last[0], style: TextStyle(color: color, fontWeight: FontWeight.w800)))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(t.careers.join(' · '), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))
                            ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${t.count}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
                              Text(spotsLeft > 0 ? '+$spotsLeft espacios' : 'lleno', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10))
                            ]),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                      ]),
                    ),
                  );
                }),
            ]),
      ),
    );
  }
}

class _StudentDialog extends StatefulWidget {
  final Student? student;
  final List<Tutor> tutors;
  final List<Career> careersCatalog;
  final Function(String id, String name, String account, String period, String career, MobilityFlag mobility, String tutorId, bool isActive) onSave;

  const _StudentDialog({
    this.student, required this.tutors, required this.careersCatalog, required this.onSave,
  });

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  late TextEditingController _idCtrl, _nombreCtrl, _apPaternoCtrl, _apMaternoCtrl, _cuentaCtrl, _periodoCtrl;
  late String _selectedCareer;
  late MobilityFlag _selectedMobility;
  late String _selectedTutorId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final s = widget.student;

    _idCtrl = TextEditingController(text: s?.id ?? 'A${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    _cuentaCtrl = TextEditingController(text: s?.accountNumber ?? '');
    _periodoCtrl = TextEditingController(text: s?.entryPeriod ?? '');

    final nameParts = s?.name.split(' ') ?? [];
    _nombreCtrl = TextEditingController(text: nameParts.isNotEmpty ? nameParts[0] : '');
    _apPaternoCtrl = TextEditingController(text: nameParts.length > 1 ? nameParts[1] : '');
    _apMaternoCtrl = TextEditingController(text: nameParts.length > 2 ? nameParts.sublist(2).join(' ') : '');

    final careerExists = widget.careersCatalog.any((c) => c.abbreviation == s?.career);
    _selectedCareer = (careerExists && s != null)
        ? s.career
        : (widget.careersCatalog.isNotEmpty ? widget.careersCatalog.first.abbreviation : '');

    _selectedMobility = s?.mobility ?? MobilityFlag.newStudent;
    _selectedTutorId = s?.tutorId ?? (widget.tutors.isNotEmpty ? widget.tutors.first.id : '');
    _isActive = s?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Editar Alumno' : 'Alta de Alumno', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              if (!isEdit) _buildField('ID (Sistema)', _idCtrl, readOnly: true),
              if (!isEdit) const SizedBox(height: 12),

              _buildField('Nombre(s)', _nombreCtrl),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _buildField('Apellido Paterno', _apPaternoCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Apellido Materno', _apMaternoCtrl)),
              ]),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _buildField('Número de Cuenta', _cuentaCtrl, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Semestre (Ej: 2024A)', _periodoCtrl)),
              ]),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCareer.isEmpty ? null : _selectedCareer,
                decoration: _inputDeco('Licenciatura'),
                dropdownColor: AppTheme.surfaceLight,
                items: widget.careersCatalog
                    .map((c) => DropdownMenuItem(value: c.abbreviation, child: Text(c.abbreviation, style: const TextStyle(color: AppTheme.textPrimary))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCareer = v!),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                  value: _selectedTutorId.isEmpty ? null : _selectedTutorId,
                  decoration: _inputDeco('Tutor Asignado'),
                  dropdownColor: AppTheme.surfaceLight,
                  items: widget.tutors
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, style: const TextStyle(color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTutorId = v!),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<MobilityFlag>(
                  value: _selectedMobility,
                  decoration: _inputDeco('Movilidad'),
                  dropdownColor: AppTheme.surfaceLight,
                  items: MobilityFlag.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(AppTheme.mobilityLabel(m), style: const TextStyle(color: AppTheme.textPrimary))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedMobility = v!),
                )),
              ]),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Estado', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                subtitle: Text(_isActive ? 'Activo (Cursando)' : 'Baja (Inactivo)', style: TextStyle(color: _isActive ? AppTheme.green : AppTheme.red, fontSize: 11)),
                value: _isActive,
                activeColor: AppTheme.green,
                inactiveTrackColor: AppTheme.red.withOpacity(0.3),
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  onPressed: () {
                    final fullName = [
                      _nombreCtrl.text.trim(),
                      _apPaternoCtrl.text.trim(),
                      _apMaternoCtrl.text.trim()
                    ].where((s) => s.isNotEmpty).join(' ');
                    widget.onSave(_idCtrl.text, fullName, _cuentaCtrl.text, _periodoCtrl.text, _selectedCareer, _selectedMobility, _selectedTutorId, _isActive);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool isNumber = false, bool readOnly = false}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary, fontSize: 13),
      decoration: _inputDeco(label),
    );
  }
}