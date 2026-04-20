import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import 'upload_screen.dart';
import 'processing_screen.dart';
import 'dashboard_screen.dart';
import 'careers_screen.dart';
import 'tutors_screen.dart';
import 'assignments_screen.dart';
import 'logs_screen.dart';
import 'usuarios_management_screen.dart'; 
import 'backup_screen.dart'; // <-- Se importó la nueva pantalla

// 1. Actualización del Enum para incluir las nuevas opciones
enum Screen { 
  upload, 
  processing, 
  dashboard, 
  careers, 
  tutors, 
  assignments, 
  logs, 
  users,
  backup, // <-- Opción de Respaldo agregada
  logout 
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Screen _current = Screen.dashboard;
  
  final List<Tutor> tutors = mockTutors;
  final List<Student> students = mockStudents;
  final List<Career> careers = mockCareers;

  @override
  void initState() {
    super.initState();
    for (final t in tutors) {
      t.students = students.where((s) => s.tutorId == t.id).toList();
    }
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
          _Sidebar(current: _current, onSelect: (s) {
            if (s == Screen.logout) {
              // Lógica de cierre de sesión inmediata
              Navigator.pushReplacementNamed(context, '/login');
            } else {
              setState(() => _current = s);
            }
          }),
          Expanded(child: _buildScreen()),
        ],
      ),
    );
  }

  // 2. Lógica para renderizar las pantallas
  Widget _buildScreen() {
    switch (_current) {
      case Screen.upload: 
        return const UploadScreen();
      case Screen.processing: 
        return const ProcessingScreen();
      case Screen.dashboard: 
        return DashboardScreen(tutors: tutors);
      case Screen.careers: 
        return CareersScreen(careers: careers); 
      case Screen.tutors: 
        return TutorsScreen(tutors: tutors, careers: careers); 
      case Screen.assignments: 
        return AssignmentsScreen(
          tutors: tutors, 
          students: students, 
          careers: careers, 
          onReassign: _reassign
        ); 
      case Screen.logs: 
        return LogsScreen(logs: mockLogs);
      case Screen.users:
        return const UsuariosManagementScreen();
      case Screen.backup:
        return const BackupScreen(); // <-- Renderizar la nueva pantalla de Respaldo
      case Screen.logout:
        return const SizedBox.shrink();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final Screen current;
  final void Function(Screen) onSelect;

  const _Sidebar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // 3. Inserción de los nuevos apartados en la lista de ítems
    final items = [
      (Screen.upload, Icons.upload_file_rounded, 'Cargar Datos'),
      (Screen.processing, Icons.auto_fix_high_rounded, 'Procesamiento'),
      (Screen.dashboard, Icons.dashboard_rounded, 'Dashboard'),
      (Screen.careers, Icons.book_rounded, 'Carreras'),
      (Screen.tutors, Icons.badge_rounded, 'Tutores'),
      (Screen.assignments, Icons.people_alt_rounded, 'Asignaciones'),
      (Screen.logs, Icons.history_rounded, 'Registro'),
      (Screen.users, Icons.manage_accounts_rounded, 'Usuarios'), 
      (Screen.backup, Icons.save_alt_rounded, 'Respaldo de Datos'), // <-- Nuevo ítem en el menú lateral
      (Screen.logout, Icons.logout_rounded, 'Cerrar Sesión'),      
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
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
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
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.yellow, size: 16),
                  SizedBox(width: 8),
                  Text('Alerta', style: TextStyle(
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
          color: isActive ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppTheme.accent.withValues(alpha: 0.3)) : null,
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