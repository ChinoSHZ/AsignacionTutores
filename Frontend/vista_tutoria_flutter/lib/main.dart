import 'package:flutter/material.dart';

void main() {
  runApp(const TutorAssignmentApp());
}

// ─── DATA MODELS ────────────────────────────────────────────────────────────

enum BalanceStatus { balanced, warning, critical }
enum MobilityFlag { canChange, noChange, newStudent }
enum Screen { upload, processing, dashboard, assignments, logs }

class Tutor {
  final String id;
  final String name;
  final String department;
  final List<String> careers;
  List<Student> students;

  Tutor({
    required this.id,
    required this.name,
    required this.department,
    required this.careers,
    List<Student>? students,
  }) : students = students ?? [];

  int get count => students.length;

  BalanceStatus get status {
    if (count >= 29 && count <= 31) return BalanceStatus.balanced;
    if (count >= 25 && count <= 35) return BalanceStatus.warning;
    return BalanceStatus.critical;
  }
}

class Student {
  final String id;
  final String name;
  final String career;
  final bool isReentry;
  final MobilityFlag mobility;
  String tutorId;
  String? previousTutorId;
  bool wasReassigned;

  Student({
    required this.id,
    required this.name,
    required this.career,
    required this.isReentry,
    required this.mobility,
    required this.tutorId,
    this.previousTutorId,
    this.wasReassigned = false,
  });
}

class SystemLog {
  final DateTime timestamp;
  final String message;
  final String type; // info, warning, error, success
  final String? studentId;

  SystemLog({
    required this.timestamp,
    required this.message,
    required this.type,
    this.studentId,
  });
}

// ─── MOCK DATA ───────────────────────────────────────────────────────────────

final List<Tutor> mockTutors = [
  Tutor(id: 't1', name: 'Dr. Ana García', department: 'Sistemas', careers: ['Computación', 'IA']),
  Tutor(id: 't2', name: 'Ing. Luis Mendoza', department: 'Sistemas', careers: ['Computación']),
  Tutor(id: 't3', name: 'Dra. Carmen Ríos', department: 'IA', careers: ['IA', 'Robótica']),
  Tutor(id: 't4', name: 'Dr. Pablo Torres', department: 'Sistemas', careers: ['Computación', 'Robótica']),
  Tutor(id: 't5', name: 'Ing. Sofía Vargas', department: 'IA', careers: ['IA']),
];

final List<Student> mockStudents = List.generate(155, (i) {
  final careers = ['Computación', 'IA', 'Robótica'];
  final mobilities = [MobilityFlag.canChange, MobilityFlag.noChange, MobilityFlag.newStudent];
  final tutorIds = ['t1', 't2', 't3', 't4', 't5'];
  final isReentry = i % 3 != 0;
  final mobility = isReentry
      ? (i % 5 == 0 ? MobilityFlag.noChange : (i % 4 == 0 ? MobilityFlag.canChange : MobilityFlag.noChange))
      : MobilityFlag.newStudent;
  
  final tutorIndex = i % 5;
  return Student(
    id: 'A${(1000 + i).toString()}',
    name: 'Alumno ${i + 1}',
    career: careers[i % 3],
    isReentry: isReentry,
    mobility: mobility,
    tutorId: tutorIds[tutorIndex],
    wasReassigned: isReentry && i % 7 == 0,
  );
});

final List<SystemLog> mockLogs = [
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 2)), message: 'Archivo "nuevos_ingresos.xlsx" cargado exitosamente. 58 registros.', type: 'success'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 2)), message: 'Archivo "historico_reingreso.xlsx" cargado. 97 registros.', type: 'success'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 1)), message: 'Iniciando algoritmo de balanceo...', type: 'info'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 1)), message: '12 alumnos de reingreso reasignados para equilibrar grupos.', type: 'info'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(seconds: 45)), message: '5 alumnos marcados como "No Cambiar" bloquearon el balanceo en Grupo Dr. Pablo Torres.', type: 'warning'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(seconds: 30)), message: 'Balanceo completado. Revisar grupo con desbalance crítico.', type: 'warning'),
];

// ─── THEME ───────────────────────────────────────────────────────────────────

class AppTheme {
  static const bg = Color(0xFF0F1117);
  static const surface = Color(0xFF1A1D27);
  static const surfaceLight = Color(0xFF242736);
  static const accent = Color(0xFF6C63FF);
  static const accentLight = Color(0xFF8B85FF);
  static const green = Color(0xFF2ECC71);
  static const yellow = Color(0xFFF39C12);
  static const red = Color(0xFFE74C3C);
  static const textPrimary = Color(0xFFF0F0F5);
  static const textSecondary = Color(0xFF8890A4);
  static const border = Color(0xFF2D3044);

  static Color statusColor(BalanceStatus s) {
    switch (s) {
      case BalanceStatus.balanced: return green;
      case BalanceStatus.warning: return yellow;
      case BalanceStatus.critical: return red;
    }
  }

  static Color mobilityColor(MobilityFlag f) {
    switch (f) {
      case MobilityFlag.canChange: return const Color(0xFF3498DB);
      case MobilityFlag.noChange: return red;
      case MobilityFlag.newStudent: return green;
    }
  }

  static String mobilityLabel(MobilityFlag f) {
    switch (f) {
      case MobilityFlag.canChange: return 'Sí Cambiar';
      case MobilityFlag.noChange: return 'No Cambiar';
      case MobilityFlag.newStudent: return 'Nuevo Ingreso';
    }
  }
}

// ─── MAIN APP ────────────────────────────────────────────────────────────────

class TutorAssignmentApp extends StatelessWidget {
  const TutorAssignmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TutorAssign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppTheme.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accent,
          surface: AppTheme.surface,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(AppTheme.accent.withOpacity(0.4)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── MAIN SHELL WITH SIDEBAR ──────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Screen _current = Screen.dashboard;
  final List<Tutor> tutors = mockTutors;
  final List<Student> students = mockStudents;

  @override
  void initState() {
    super.initState();
    // Populate tutors with students
    for (final t in tutors) {
      t.students = students.where((s) => s.tutorId == t.id).toList();
    }
    // Adjust counts to create interesting scenarios
    tutors[0].students = students.where((s) => s.tutorId == 't1').take(30).toList();
    tutors[1].students = students.where((s) => s.tutorId == 't2').take(28).toList() 
        + students.where((s) => s.tutorId == 't3').take(3).toList();
    tutors[2].students = students.where((s) => s.tutorId == 't3').take(31).toList();
    tutors[3].students = students.where((s) => s.tutorId == 't4').take(43).toList();
    tutors[4].students = students.where((s) => s.tutorId == 't5').take(18).toList();
  }

  void _reassign(Student student, String newTutorId) {
    setState(() {
      final oldTutor = tutors.firstWhere((t) => t.id == student.tutorId);
      final newTutor = tutors.firstWhere((t) => t.id == newTutorId);
      oldTutor.students.remove(student);
      student.tutorId = newTutorId;
      student.wasReassigned = true;
      newTutor.students.add(student);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(current: _current, onSelect: (s) => setState(() => _current = s)),
          Expanded(child: _buildScreen()),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_current) {
      case Screen.upload:
        return const UploadScreen();
      case Screen.processing:
        return const ProcessingScreen();
      case Screen.dashboard:
        return DashboardScreen(tutors: tutors);
      case Screen.assignments:
        return AssignmentsScreen(tutors: tutors, students: students, onReassign: _reassign);
      case Screen.logs:
        return LogsScreen(logs: mockLogs);
    }
  }
}

// ─── SIDEBAR ─────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final Screen current;
  final void Function(Screen) onSelect;

  const _Sidebar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Screen.upload, Icons.upload_file_rounded, 'Cargar Datos'),
      (Screen.processing, Icons.auto_fix_high_rounded, 'Procesamiento'),
      (Screen.dashboard, Icons.dashboard_rounded, 'Dashboard'),
      (Screen.assignments, Icons.people_alt_rounded, 'Asignaciones'),
      (Screen.logs, Icons.history_rounded, 'Registro'),
    ];

    return Container(
      width: 220,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, Color(0xFF9D4EDD)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TutorAssign', style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )),
                    Text('v2.0 Admin', style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('NAVEGACIÓN', style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final isActive = current == item.$1;
            return _SidebarItem(
              icon: item.$2,
              label: item.$3,
              isActive: isActive,
              onTap: () => onSelect(item.$1),
            );
          }),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.yellow, size: 16),
                  const SizedBox(width: 8),
                  const Text('Alerta', style: TextStyle(
                    color: AppTheme.yellow,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )),
                ]),
                const SizedBox(height: 6),
                const Text('1 grupo requiere atención manual', style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppTheme.accent.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18,
              color: isActive ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: isActive ? AppTheme.accentLight : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            )),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── UPLOAD SCREEN ────────────────────────────────────────────────────────────

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
    return _ScreenWrapper(
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
                    color: AppTheme.green.withOpacity(0.15),
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
          color: isLoaded ? color.withOpacity(0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLoaded ? color.withOpacity(0.4) : AppTheme.border,
            width: isLoaded ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: isLoaded ? color.withOpacity(0.2) : AppTheme.surfaceLight,
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── PROCESSING SCREEN ────────────────────────────────────────────────────────

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenWrapper(
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
          child: const Column(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 52),
            SizedBox(height: 16),
            Text('Algoritmo completado', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            )),
            SizedBox(height: 8),
            Text('El sistema procesó 155 alumnos en 1.4 segundos', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 14,
            )),
            SizedBox(height: 28),
            Row(children: [
              _StatBox('155', 'Total alumnos', AppTheme.accent),
              SizedBox(width: 14),
              _StatBox('12', 'Reasignados', AppTheme.yellow),
              SizedBox(width: 14),
              _StatBox('5', 'Bloqueados', AppTheme.red),
              SizedBox(width: 14),
              _StatBox('1', 'Grupos en alerta', AppTheme.red),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        const _LogItem(Icons.check_circle_rounded, AppTheme.green, 'Nuevos ingresos asignados aleatoriamente por carrera', '58 alumnos'),
        const _LogItem(Icons.history_rounded, Color(0xFF3498DB), 'Reingresantes mantienen tutor previo', '85 alumnos'),
        const _LogItem(Icons.swap_horiz_rounded, AppTheme.yellow, 'Reasignaciones por balanceo', '12 alumnos'),
        const _LogItem(Icons.lock_rounded, AppTheme.red, 'Bloqueados por "No Cambiar"', '5 alumnos'),
        const _LogItem(Icons.warning_rounded, AppTheme.red, 'Grupo Dr. Pablo Torres sin equilibrar (43 alumnos)', 'Requiere revisión manual'),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
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
            color: color.withOpacity(0.12),
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(detail, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── DASHBOARD SCREEN ─────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final List<Tutor> tutors;
  const DashboardScreen({super.key, required this.tutors});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterCareer = 'Todas';

  @override
  Widget build(BuildContext context) {
    final critical = widget.tutors.where((t) => t.status == BalanceStatus.critical).length;
    final balanced = widget.tutors.where((t) => t.status == BalanceStatus.balanced).length;

    // Obtener carreras únicas para el filtro
    final Set<String> allCareers = {};
    for (var t in widget.tutors) {
      allCareers.addAll(t.careers);
    }
    final filterOptions = ['Todas', ...allCareers.toList()..sort()];

    // Aplicar filtro
    final filteredTutors = widget.tutors.where((t) {
      if (_filterCareer == 'Todas') return true;
      return t.careers.contains(_filterCareer);
    }).toList();

    return _ScreenWrapper(
      title: 'Dashboard de Supervisión',
      subtitle: 'Resumen del estado actual de asignaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Metric Cards Row
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

        // Alert Banner (MODIFICADO: Sin botón de resolver)
        if (critical > 0) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.red.withOpacity(0.4)),
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

        // Sección de Tutores Header y Filtro (NUEVO)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estado por Tutor', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            )),
            // Filtro por Chips
            Row(
              children: filterOptions.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  selected: _filterCareer == c,
                  onSelected: (val) => setState(() => _filterCareer = c),
                  backgroundColor: AppTheme.surfaceLight,
                  selectedColor: AppTheme.accent.withOpacity(0.2),
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

        // Tutors Grid (MODIFICADO: Responsivo y compacto para +100 tutores)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // MaxCrossAxisExtent permite que Flutter calcule cuántas columnas caben
          // Si la pantalla es ancha, pondrá 4 o 5 columnas. Si es pequeña, 2 o 3.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240, 
            mainAxisExtent: 90, // Altura fija pequeña
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filteredTutors.length,
          itemBuilder: (_, i) => _CompactTutorCard(tutor: filteredTutors[i]),
        ),

        const SizedBox(height: 24),

        // Legend
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
}

// ─── COMPACT TUTOR CARD (NUEVA: Para evitar saturación visual) ──────────

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
        color: AppTheme.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
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
                  color: color.withOpacity(0.15),
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
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// Nota: Asegúrate de mantener la clase _MetricCard y _LegendDot que ya tenías abajo de este bloque.

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
                color: color.withOpacity(0.15),
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
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
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
                backgroundColor: color.withOpacity(0.15),
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

// ─── ASSIGNMENTS SCREEN ───────────────────────────────────────────────────────

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
    
    // 1. LÓGICA DE FILTRO DEPENDIENTE PARA TUTORES
    final availableTutorsForFilter = _filterCareer == 'Todas'
        ? widget.tutors // Muestra todos si no hay carrera específica seleccionada
        : widget.tutors.where((t) => t.careers.contains(_filterCareer)).toList(); // Filtra por carrera

    // 2. CONSTRUYE LAS OPCIONES DEL DROPDOWN
    final tutorOptions = [
      ('Todos', 'Todos'), 
      ...availableTutorsForFilter.map((t) => (t.id, t.name))
    ];

    return _ScreenWrapper(
      title: 'Revisión de Asignaciones',
      subtitle: 'Gestión manual de asignaciones. ${filtered.length} registros.',
      scrollable: false,
      child: Column(children: [
        // Filters Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            // Search
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
            // Filter Chips
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
                    // IMPORTANTE: Al cambiar la carrera, reiniciamos el tutor a 'Todos'
                    // para evitar errores de estado y dar el comportamiento que pediste.
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

        // Table Header
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

        // Table Body
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

// ─── REASSIGN DIALOG ──────────────────────────────────────────────────────────

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

// ─── LOGS SCREEN ──────────────────────────────────────────────────────────────

class LogsScreen extends StatefulWidget {
  final List<SystemLog> logs;
  const LogsScreen({super.key, required this.logs});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // Estado para controlar el filtro activo. Por defecto es 'all' (Total eventos)
  String _activeFilter = 'all'; 

  @override
  Widget build(BuildContext context) {
    // 1. Lógica de filtrado
    final filteredLogs = widget.logs.where((log) {
      if (_activeFilter == 'all') return true;
      return log.type == _activeFilter;
    }).toList();

    // 2. Lógica de conteo dinámico basado en los datos reales
    final totalCount = widget.logs.length;
    final warningCount = widget.logs.where((l) => l.type == 'warning').length;
    final errorCount = widget.logs.where((l) => l.type == 'error').length;
    final successCount = widget.logs.where((l) => l.type == 'success').length;

    return _ScreenWrapper(
      title: 'Registro de Cambios',
      subtitle: 'Historial de movimientos y alertas del sistema',
      scrollable: false,
      child: Column(children: [
        // Botones de Filtro
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
        
        // Mensaje si el filtro no arroja resultados
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
        // Lista de Logs Filtrados
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
      case 'info': return const Color(0xFF3498DB); // Azul para info
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

// NUEVO WIDGET INTERACTIVO PARA LOS BOTONES DEL FILTRO
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

// ─── SCREEN WRAPPER ──────────────────────────────────────────────────────────

class _ScreenWrapper extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  final bool scrollable; // <-- CAMBIO APLICADO AQUÍ

  const _ScreenWrapper({
    required this.title,
    required this.subtitle,
    required this.child,
    this.scrollable = true, // <-- CAMBIO APLICADO AQUÍ
  });

  @override
  Widget build(BuildContext context) {
    // CAMBIO APLICADO AQUÍ
    Widget content = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: child,
          )
        : Padding(
            padding: const EdgeInsets.all(28),
            child: child,
          );

    return Container(
      color: AppTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                )),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Sistema activo', style: TextStyle(
                    color: AppTheme.green, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ]),
          ),
          Expanded(child: content), // <-- CAMBIO APLICADO AQUÍ
        ],
      ),
    );
  }
}