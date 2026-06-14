import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class AssignmentsScreen extends StatefulWidget {
  final List<Tutor> tutors; 
  final List<Student> students; 
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
  bool _isLoading = true;
  List<Tutor> _realTutors = [];
  List<Student> _realStudents = [];
  List<Career> _apiCareers = [];

  String _searchQuery = '';
  String _filterCareer = 'Todas';
  String _filterMobility = 'Todas';
  String _filterTutor = 'Todos';

  String _filterPeriodo = 'Todos';
  List<String> _periodosIngreso = ['Todos'];

  int _currentPage = 0;
  final int _itemsPerPage = 100;

  @override
  void initState() {
    super.initState();
    _fetchAsignacionesRealTime(); 
  }

  Future<void> _fetchAsignacionesRealTime() async {
    setState(() => _isLoading = true);
    try {
      final profRes = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/profesores'),
        headers: {'Accept': 'application/json'}
      );
      
      List<Tutor> fullTutorsList = [];
      if (profRes.statusCode == 200) {
        final List<dynamic> pData = jsonDecode(profRes.body);
        for (var json in pData) {
          final nombre = json['nombre'] ?? '';
          final apPat = json['apellido_paterno'] ?? '';
          final apMat = json['apellido_materno'] ?? '';
          final nombreCompleto = json['nombre_completo'] ?? '$nombre $apPat $apMat'.trim();
          
          final String tId = json['id']?.toString() 
                ?? json['id_profesor']?.toString() 
                ?? json['profesor_id']?.toString() 
                ?? '';

          List<String> carrerasList = [];
          if (json['licenciaturas'] is List) {
            for (var lic in json['licenciaturas']) {
              if (lic is Map && lic.containsKey('abreviatura')) {
                carrerasList.add(lic['abreviatura'].toString().trim());
              } else if (lic is String) {
                carrerasList.add(lic.trim());
              }
            }
          }
          if (carrerasList.isEmpty) carrerasList.add('S/L');

          for (String c in carrerasList) {
             fullTutorsList.add(Tutor(
               id: '${tId}_$c',
               name: nombreCompleto.isEmpty ? 'Sin Nombre ($c)' : '$nombreCompleto ($c)',
               department: 'Ingeniería',
               careers: [c],
               isActive: json['estado'] == 'Activo',
               students: [],
             ));
          }
        }
      }

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<Career> loadedCareers = [];
        if (data['licenciaturas'] != null) {
          loadedCareers = (data['licenciaturas'] as List).map((j) => Career(
            id: j['id'].toString(), 
            abbreviation: j['abreviatura'], 
            name: j['nombre']
          )).toList();
        }

        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        List<Student> loadedStudents = [];

        for (var t in tutorsJson) {
          final tId = t['id'].toString();
          
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  var movilidadDB = pivot['movilidad'] ?? 'no_cambiar';
                  var estadoTutoradoDB = pivot['estado_tutorado'] ?? 'activo';
                  
                  MobilityFlag flag = MobilityFlag.noChange;
                  if (movilidadDB == 'cambiar') flag = MobilityFlag.canChange;
                  if (movilidadDB == 'nuevo_ingreso') flag = MobilityFlag.newStudent;

                  final careerAbrev = stud['licenciatura'] != null ? stud['licenciatura']['abreviatura'] : 'S/L';
                  final virtualTutorId = '${tId}_$careerAbrev';

                  var s = Student(
                    id: stud['id'].toString(),
                    name: '${stud['nombre']} ${stud['apellido_paterno']} ${stud['apellido_materno'] ?? ''}'.trim(),
                    accountNumber: stud['numero_cuenta'].toString(),
                    entryPeriod: stud['periodo_ingreso'] ?? '',
                    career: careerAbrev,
                    isReentry: flag != MobilityFlag.newStudent,
                    mobility: flag,
                    tutorId: virtualTutorId,
                    isActive: estadoTutoradoDB == 'activo',
                    wasReassigned: flag == MobilityFlag.canChange, 
                  );
                  loadedStudents.add(s);
                  
                  int tutorIdx = fullTutorsList.indexWhere((x) => x.id == virtualTutorId);
                  if (tutorIdx != -1) {
                    fullTutorsList[tutorIdx].students.add(s);
                  } else {
                    fullTutorsList.add(Tutor(
                      id: virtualTutorId,
                      name: '${t['nombre']} ${t['apellido_paterno']} ($careerAbrev)',
                      department: 'Ingeniería',
                      careers: [careerAbrev],
                      students: [s],
                      isActive: t['estado'] == 'Activo',
                    ));
                  }
                }
              }
            }
          }
        }

        final Set<String> extractedPeriods = {};
        for (var s in loadedStudents) {
          if (s.entryPeriod.isNotEmpty) extractedPeriods.add(s.entryPeriod);
        }
        final periodList = extractedPeriods.toList()..sort();

        setState(() {
          _apiCareers = loadedCareers;
          _realTutors = fullTutorsList;
          _realStudents = loadedStudents;
          _periodosIngreso = ['Todos', ...periodList];
          if (!_periodosIngreso.contains(_filterPeriodo)) _filterPeriodo = 'Todos';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveStudentToBackend(String account, String fullName, String period, String careerAbrev, MobilityFlag mobility, String tutorId, bool isActive) async {
    setState(() => _isLoading = true);

    try {
      final nameParts = fullName.split(' ');
      final nombre = nameParts.isNotEmpty ? nameParts[0] : 'Sin nombre';
      final apPaterno = nameParts.length > 1 ? nameParts[1] : '';
      final apMaterno = nameParts.length > 2 ? nameParts.sublist(2).join(' ') : '';
      
      String movStr = 'no_cambiar';
      if (mobility == MobilityFlag.canChange) movStr = 'cambiar';
      if (mobility == MobilityFlag.newStudent) movStr = 'nuevo_ingreso';

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/tutorados'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'numero_cuenta': account.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString().substring(5) : account,
          'nombre': nombre,
          'apellido_paterno': apPaterno,
          'apellido_materno': apMaterno,
          'periodo_ingreso': period.isEmpty ? 'N/A' : period,
          'licenciatura_abreviatura': careerAbrev,
          'tutor_id': tutorId.split('_')[0],
          'movilidad': movStr,
          'estado_tutorado': isActive,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado correctamente en la Base de Datos'), backgroundColor: AppTheme.green));
        await _fetchAsignacionesRealTime(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar el alumno'), backgroundColor: AppTheme.red));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión'), backgroundColor: AppTheme.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runManualRebalance() async {
    Navigator.pop(context); 
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/asignaciones/rebalanceo-manual'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'Reasignación completada'),
          backgroundColor: AppTheme.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error en el servidor al ejecutar el balanceo.'),
          backgroundColor: AppTheme.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error de red al intentar reasignar.'),
        backgroundColor: AppTheme.red,
      ));
    } finally {
      await _fetchAsignacionesRealTime();
    }
  }

  void _showRebalanceConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.balance_rounded, color: AppTheme.yellow),
            SizedBox(width: 10),
            Text('Reasignación Automática', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'El algoritmo de Robo Justo removerá alumnos de los profesores que superan el promedio y los asignará a los profesores con déficit (Incluyendo los dados de alta recientemente).\n\n'
          '• Se redistribuirán únicamente los alumnos marcados como "Sí Cambiar".\n'
          '• Los alumnos de "Nuevo Ingreso" y "No cambiar" son intocables.\n'
          '• Ningún profesor caerá de su piso mínimo.\n\n'
          '¿Desea ejecutar este proceso?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: _runManualRebalance,
            child: const Text('Ejecutar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<Student> get _filtered {
    return _realStudents.where((s) {
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.accountNumber.contains(_searchQuery) ||
          s.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCareer = _filterCareer == 'Todas' || s.career == _filterCareer;
      final matchMobility = _filterMobility == 'Todas' || AppTheme.mobilityLabel(s.mobility) == _filterMobility;
      final matchTutor = _filterTutor == 'Todos' || s.tutorId == _filterTutor;
      final matchPeriodo = _filterPeriodo == 'Todos' || s.entryPeriod == _filterPeriodo;
      
      return matchSearch && matchCareer && matchMobility && matchTutor && matchPeriodo;
    }).toList();
  }

  void _showTutorFilterDialog(List<(String, String)> options) {
    String localSearchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = options.where((o) => localSearchQuery.isEmpty || o.$2.toLowerCase().contains(localSearchQuery.toLowerCase())).toList();
          return Dialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtrar por Tutor', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setModalState(() => localSearchQuery = v),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar tutor...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: filtered.isEmpty
                        ? const Center(child: Text('No se encontraron tutores', style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(color: AppTheme.border),
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              return ListTile(
                                title: Text(t.$2, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                                onTap: () {
                                  setState(() {
                                    _filterTutor = t.$1;
                                    _currentPage = 0;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReassignDialog(Student student) {
    // Filtra evitando el mismo tutor real y forzando que el tutor imparta la misma licenciatura del alumno
    final available = _realTutors.where((t) => 
        t.id.split('_')[0] != student.tutorId.split('_')[0] && 
        t.isActive && 
        !t.name.contains('Sin tutor') && 
        t.careers.contains(student.career) &&
        t.students.where((st) => st.isActive).length < 35
    ).toList();
    
    showDialog(
      context: context,
      builder: (_) => _ReassignDialog(
        student: student,
        availableTutors: available,
        currentTutor: _realTutors.firstWhere((t) => t.id == student.tutorId),
        onReassign: (newId) {
          _saveStudentToBackend(
            student.accountNumber,
            student.name,
            student.entryPeriod,
            student.career,
            MobilityFlag.canChange, 
            newId,
            student.isActive
          );
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
        careersCatalog: _apiCareers,
        onSave: (id, name, account, period, career, mobility, tutorId, isActive) {
          _saveStudentToBackend(account, name, period, career, mobility, tutorId, isActive);
        },
      ),
    );
  }

  void _deleteStudent(Student student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Desactivar Alumno', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('¿Deseas marcar a ${student.name} como "Baja"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _saveStudentToBackend(
                student.accountNumber,
                student.name,
                student.entryPeriod,
                student.career,
                student.mobility, 
                student.tutorId,
                false 
              );
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }

  void _showCareerChangeDialog(Student student) {
    String initialVal = student.career;
    
    if (initialVal == 'S/L') {
      final validCareers = _apiCareers.where((c) => c.abbreviation != 'S/L');
      if (validCareers.isNotEmpty) {
        initialVal = validCareers.first.abbreviation;
      }
    }

    showDialog(
      context: context,
      builder: (_) => _QuickChangeDialog<String>(
        title: 'Cambiar Licenciatura',
        currentValue: initialVal,
        options: _apiCareers.where((c) => c.abbreviation != 'S/L').map((c) => c.abbreviation).toList(),
        labelBuilder: (val) => val,
        onSave: (newCareer) {
          _saveStudentToBackend(student.accountNumber, student.name, student.entryPeriod, newCareer, student.mobility, student.tutorId, student.isActive);
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
           _saveStudentToBackend(student.accountNumber, student.name, student.entryPeriod, student.career, newMobility, student.tutorId, student.isActive);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    final totalPages = (filtered.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final paginatedStudents = filtered.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList();

    final Set<String> allCareers = {'S/L'};
    for (var c in _apiCareers) {
      allCareers.add(c.abbreviation);
    }
    final careerOptions = ['Todas', ...allCareers.toList()..sort()];

    final mobilities = ['Todas', 'Nuevo Ingreso', 'Sí Cambiar', 'No Cambiar'];

    final availableTutorsForFilter = _filterCareer == 'Todas'
        ? _realTutors.where((t) => !t.name.contains('Sin tutor')).toList()
        : _realTutors.where((t) {
            if (t.name.contains('Sin tutor')) return false;
            return t.careers.contains(_filterCareer);
          }).toList();

    final tutorOptions = [
      ('Todos', 'Todos'),
      ...availableTutorsForFilter.map((t) => (t.id, t.name))
    ];

    int totalAlumnos = 0;
    for (var t in availableTutorsForFilter) {
      totalAlumnos += t.students.where((st) => st.isActive).length;
    }
    int average = availableTutorsForFilter.isNotEmpty ? (totalAlumnos / availableTutorsForFilter.length).round() : 30;
    
    int minBalanced = (average - 3).clamp(1, 999);
    int maxBalanced = average + 3;
    int minWarning = (average - 5).clamp(1, 999);
    int maxWarning = average + 5;

    Color getDynamicColor(int count) {
      if (count >= minBalanced && count <= maxBalanced) return AppTheme.green;
      if (count >= minWarning && count <= maxWarning) return AppTheme.yellow;
      return AppTheme.red;
    }

    return ScreenWrapper(
      title: 'Revisión de Asignaciones',
      subtitle: 'Gestión manual de asignaciones. ${filtered.length} registros en total.',
      scrollable: false,
      child: Column(children: [
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
              
              ElevatedButton.icon(
                onPressed: _showRebalanceConfirmDialog,
                icon: const Icon(Icons.balance_rounded, size: 18),
                label: const Text('Reasignar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.yellow.withOpacity(0.15),
                  foregroundColor: AppTheme.yellow,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.yellow.withOpacity(0.4)),
                  ),
                ),
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
                child: InkWell(
                  onTap: () => _showTutorFilterDialog(tutorOptions),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'Tutor',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tutorOptions.firstWhere((t) => t.$1 == _filterTutor, orElse: () => ('Todos', 'Todos')).$2,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DropdownFilter<String>(
                    label: 'Ingreso',
                    value: _filterPeriodo,
                    options: _periodosIngreso,
                    onChanged: (v) {
                      setState(() {
                        _filterPeriodo = v ?? 'Todos';
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Semáforo de balanceo ($_filterCareer): ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    text: '$minBalanced–$maxBalanced ',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: AppTheme.border)),
          child: const Row(children: [
            Expanded(flex: 3, child: _TableHeader('Alumno (ID / Cuenta)')),
            Expanded(flex: 1, child: _TableHeader('Carrera')),
            Expanded(flex: 1, child: _TableHeader('Ingreso')),
            Expanded(flex: 3, child: _TableHeader('Tutor (Estado)')),
            Expanded(flex: 2, child: _TableHeader('Movilidad')),
            Expanded(flex: 1, child: _TableHeader('Estado')),
            SizedBox(width: 140, child: _TableHeader('Acciones', alignRight: true)),
          ]),
        ),

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
                    final isSinTutor = tutor.name.contains('Sin tutor');
                    final activeStudentsCount = tutor.students.where((st) => st.isActive).length;

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
                            flex: 1,
                            child: InkWell(
                              onTap: () => _showCareerChangeDialog(s),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppTheme.accent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text(s.career,
                                          style: const TextStyle(
                                              color: AppTheme.accentLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            )),

                        Expanded(
                            flex: 1,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF9B59B6).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF9B59B6).withOpacity(0.3))),
                                child: Text(s.entryPeriod.isEmpty ? 'N/A' : s.entryPeriod,
                                    style: const TextStyle(
                                        color: Color(0xFF9B59B6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5)),
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
                                    Row(
                                      children: [
                                        if (isSinTutor)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6.0),
                                            child: Icon(Icons.person_off_rounded, color: AppTheme.red, size: 16),
                                          )
                                        else if (!tutor.isActive)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6.0),
                                            child: Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 14),
                                          ),
                                        Expanded(
                                          child: Text(isSinTutor ? 'Sin tutor asignado' : tutor.name,
                                              style: TextStyle(color: (tutor.isActive && !isSinTutor) ? AppTheme.textPrimary : AppTheme.red, fontSize: 12),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                    Row(children: [
                                      Text('$activeStudentsCount alumnos • ',
                                          style: TextStyle(color: isSinTutor ? AppTheme.red : getDynamicColor(activeStudentsCount), fontSize: 10)),
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
                                    tooltip: 'Eliminar / Baja',
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
                      Text(' = Mantener  |  ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Text('C', style: TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(' = Cambiar  |  ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 14),
                      Text(' = Tutor dado de baja  |  ',
                          style: TextStyle(color: AppTheme.red, fontSize: 12)),
                      Icon(Icons.person_off_rounded, color: AppTheme.red, size: 14),
                      Text(' = Sin tutor asignado  |  ', style: TextStyle(color: AppTheme.red, fontSize: 12)),
                      Text('S/L', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(' = Sin licenciatura', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
        )
      ]),
    );
  }
}

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
      isExpanded: true,
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
          isExpanded: true, 
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
                  child: Text(widget.labelBuilder(o), style: const TextStyle(color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)))
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

class _ReassignDialog extends StatefulWidget {
  final Student student;
  final List<Tutor> availableTutors;
  final Tutor currentTutor;
  final void Function(String) onReassign;
  
  const _ReassignDialog(
      {required this.student, required this.availableTutors, required this.currentTutor, required this.onReassign});

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredTutors = widget.availableTutors.where((t) {
      return _searchQuery.isEmpty || t.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
                      Text(widget.student.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))
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
                    Expanded(
                      child: Text(widget.currentTutor.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    Text('${widget.currentTutor.students.where((st)=>st.isActive).length} alumnos', style: TextStyle(color: AppTheme.statusColor(widget.currentTutor.status), fontSize: 12))
                  ])),
              const SizedBox(height: 20),
              
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar tutor...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              
              const Text('Tutores disponibles',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              
              SizedBox(
                height: 300,
                child: filteredTutors.isEmpty
                    ? const Center(child: Text('No se encontraron tutores.', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        itemCount: filteredTutors.length,
                        itemBuilder: (context, index) {
                          final t = filteredTutors[index];
                          final color = AppTheme.statusColor(t.status);
                          final activeCount = t.students.where((st)=>st.isActive).length;
                          final spotsLeft = 35 - activeCount;
                          
                          return GestureDetector(
                            onTap: () {
                              widget.onReassign(t.id);
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
                                      Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      Text(t.careers.join(' · '), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))
                                    ])),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$activeCount', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
                                      Text(spotsLeft > 0 ? '+$spotsLeft espacios' : 'lleno', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10))
                                    ]),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
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
    final validCareers = widget.careersCatalog.where((c) => c.abbreviation != 'S/L').toList();
    
    _selectedCareer = (careerExists && s != null && s.career != 'S/L')
        ? s.career
        : (validCareers.isNotEmpty ? validCareers.first.abbreviation : '');

    _selectedMobility = s?.mobility ?? MobilityFlag.newStudent;
    
    // Obtener los tutores activos y que impartan la carrera seleccionada por defecto
    final activeTutors = widget.tutors.where((t) => t.isActive && !t.name.contains('Sin tutor') && t.careers.contains(_selectedCareer)).toList();
    
    _selectedTutorId = s?.tutorId ?? (activeTutors.isNotEmpty ? activeTutors.first.id : '');
    
    if (s?.tutorId != null && !activeTutors.any((t) => t.id == s?.tutorId)) {
        final assignedTutor = widget.tutors.firstWhere((t) => t.id == s?.tutorId, orElse: () => Tutor(id: s!.tutorId, name: 'Desconocido', department: '', careers: []));
        if (!assignedTutor.name.contains('Sin tutor')) {
          activeTutors.add(assignedTutor);
        }
    }
    
    _isActive = s?.isActive ?? true;
  }

  // Refresca la lista de tutores cuando el usuario cambia la carrera en el menú
  void _onCareerChanged(String newCareer) {
    setState(() {
      _selectedCareer = newCareer;
      final activeTutorsForCareer = widget.tutors.where((t) => t.isActive && !t.name.contains('Sin tutor') && t.careers.contains(newCareer)).toList();
      _selectedTutorId = activeTutorsForCareer.isNotEmpty ? activeTutorsForCareer.first.id : '';
    });
  }

  void _showTutorSelection(List<Tutor> activeTutors) {
    String localSearchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredTutors = activeTutors.where((t) {
            return localSearchQuery.isEmpty || t.name.toLowerCase().contains(localSearchQuery.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccionar Tutor', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    onChanged: (v) => setModalState(() => localSearchQuery = v),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar tutor...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 300,
                    child: filteredTutors.isEmpty
                        ? const Center(child: Text('No se encontraron tutores', style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: filteredTutors.length,
                            separatorBuilder: (_, __) => const Divider(color: AppTheme.border),
                            itemBuilder: (_, i) {
                              final t = filteredTutors[i];
                              return ListTile(
                                title: Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                                subtitle: Text('${t.students.where((st)=>st.isActive).length} alumnos asignados', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                onTap: () {
                                  setState(() => _selectedTutorId = t.id);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;
    
    final activeTutors = widget.tutors.where((t) => t.isActive && !t.name.contains('Sin tutor') && t.careers.contains(_selectedCareer)).toList();
    
    if (isEdit && _selectedTutorId.isNotEmpty && !activeTutors.any((t) => t.id == _selectedTutorId)) {
      final assignedTutor = widget.tutors.firstWhere((t) => t.id == _selectedTutorId, orElse: () => Tutor(id: _selectedTutorId, name: 'Desconocido (Baja)', department: '', careers: []));
      if (!assignedTutor.name.contains('Sin tutor')) {
        activeTutors.insert(0, assignedTutor);
      }
    }

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
                isExpanded: true, 
                value: _selectedCareer.isEmpty ? null : _selectedCareer,
                decoration: _inputDeco('Licenciatura'),
                dropdownColor: AppTheme.surfaceLight,
                items: widget.careersCatalog
                    .where((c) => c.abbreviation != 'S/L')
                    .map((c) => DropdownMenuItem(value: c.abbreviation, child: Text(c.abbreviation, style: const TextStyle(color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => _onCareerChanged(v!),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showTutorSelection(activeTutors),
                    child: InputDecorator(
                      decoration: _inputDeco('Tutor Asignado (Activos)'),
                      child: Text(
                        activeTutors.any((t) => t.id == _selectedTutorId)
                            ? activeTutors.firstWhere((t) => t.id == _selectedTutorId).name
                            : 'Seleccionar Tutor...',
                        style: TextStyle(
                          color: _selectedTutorId.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<MobilityFlag>(
                  isExpanded: true, 
                  value: _selectedMobility,
                  decoration: _inputDeco('Movilidad'),
                  dropdownColor: AppTheme.surfaceLight,
                  items: MobilityFlag.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(AppTheme.mobilityLabel(m), style: const TextStyle(color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)))
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
                    if (_selectedTutorId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un tutor asignado')));
                      return;
                    }
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
  ]);
}