import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
import 'copy_groups_screen.dart'; 
import 'usuarios_management_screen.dart'; 
import 'backup_screen.dart'; 

enum Screen { 
  upload, 
  processing, 
  dashboard, 
  careers, 
  tutors, 
  assignments, 
  logs, 
  copyGroups, 
  users,
  backup, 
  logout 
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Screen _current = Screen.dashboard;
  bool _isNavigating = false;
  
  String _userName = 'Cargando...';
  bool _showAlert = false;

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

    _fetchSidebarData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recuperamos el nombre enviado desde el Login
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('user_name')) {
      setState(() => _userName = args['user_name']);
    } else if (_userName == 'Cargando...') {
      setState(() => _userName = 'Administrador');
    }
  }

  Future<void> _fetchSidebarData() async {
    // 1. Obtener Datos del Dashboard para verificar el estado Crítico/Desvío
    try {
      final resDash = await http.get(Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'), headers: {'Accept': 'application/json'});
      if (resDash.statusCode == 200) {
        final data = jsonDecode(resDash.body);
        final List<dynamic> tutorsJson = data['tutores'] ?? [];
        
        int totalAlumnos = 0;
        List<int> activeCounts = [];

        for (var t in tutorsJson) {
          int activeCount = 0;
          if (t['grupos'] != null) {
            for (var grupo in t['grupos']) {
              if (grupo['tutorados'] != null) {
                for (var stud in grupo['tutorados']) {
                  var pivot = stud['pivot'] ?? {};
                  if (pivot['estado_tutorado'] == 'activo' || stud['is_active'] == 1 || stud['is_active'] == true) {
                    activeCount++;
                    totalAlumnos++;
                  }
                }
              }
            }
          }
          activeCounts.add(activeCount);
        }

        int average = activeCounts.isNotEmpty ? (totalAlumnos / activeCounts.length).round() : 30;
        int minBalanced = average - 3;
        int maxBalanced = average + 3;

        bool hasAlert = false;
        for (int count in activeCounts) {
          if (count < minBalanced || count > maxBalanced) {
            hasAlert = true;
            break;
          }
        }

        if (mounted) setState(() => _showAlert = hasAlert);
      }
    } catch (e) {
      // Manejo silencioso
    }
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

  void _handleNavigation(Screen s) async {
    if (s == Screen.logout) {
      bool hasRealUser = true;
      try {
        final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/usuarios'), headers: {'Accept': 'application/json'});
        if (response.statusCode == 200) {
          final List<dynamic> users = jsonDecode(response.body);
          hasRealUser = users.any((u) => u['email'] != 'admin@admin.com');
        }
      } catch (e) {
      }

      if (!hasRealUser) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.yellow),
                  SizedBox(width: 10),
                  Text("Acción denegada", style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              content: const Text(
                "Debe dar de alta al menos un usuario con contraseña antes de cerrar sesión para no perder el acceso al sistema.",
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
        return;
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    bool isException = s == Screen.upload || s == Screen.backup || s == Screen.logout;

    if (_isNavigating && !isException) return;

    setState(() => _current = s);

    if (!isException) {
      setState(() => _isNavigating = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isNavigating = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            current: _current, 
            onSelect: _handleNavigation,
            isNavigating: _isNavigating,
            userName: _userName,
            showAlert: _showAlert,
          ),
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
      case Screen.copyGroups: 
        return const CopyGroupsScreen(); 
      case Screen.users:
        return const UsuariosManagementScreen();
      case Screen.backup:
        return const BackupScreen();
      case Screen.logout:
        return const SizedBox.shrink();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final Screen current;
  final void Function(Screen) onSelect;
  final bool isNavigating;
  final String userName;
  final bool showAlert;

  const _Sidebar({
    required this.current, 
    required this.onSelect,
    required this.isNavigating,
    required this.userName,
    required this.showAlert,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Screen.upload, Icons.upload_file_rounded, 'Cargar Datos'),
      (Screen.processing, Icons.auto_fix_high_rounded, 'Procesamiento'),
      (Screen.dashboard, Icons.dashboard_rounded, 'Dashboard'),
      (Screen.careers, Icons.book_rounded, 'Licenciaturas'),
      (Screen.tutors, Icons.badge_rounded, 'Tutores'),
      (Screen.assignments, Icons.people_alt_rounded, 'Asignaciones'),
      (Screen.logs, Icons.history_rounded, 'Registro'),
      (Screen.copyGroups, Icons.content_copy_rounded, 'Copiar Grupos'), 
      (Screen.users, Icons.manage_accounts_rounded, 'Usuarios'), 
      (Screen.backup, Icons.save_alt_rounded, 'Respaldo de Datos'),
      (Screen.logout, Icons.logout_rounded, 'Cerrar Sesión'),      
    ];

    return Container(
      width: 220,
      color: AppTheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sistema de asignación\nde tutorados', style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  height: 1.2,
                                )),
                                const SizedBox(height: 2),
                                Text(userName, style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ), overflow: TextOverflow.ellipsis, maxLines: 1),
                              ],
                            ),
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
                      final isException = item.$1 == Screen.upload || item.$1 == Screen.backup || item.$1 == Screen.logout;
                      final isDisabled = isNavigating && !isException;
                      
                      return _SidebarItem(
                        icon: item.$2,
                        label: item.$3,
                        isActive: isActive,
                        isDisabled: isDisabled,
                        onTap: isDisabled ? () {} : () => onSelect(item.$1),
                      );
                    }),
                    const Spacer(),
                    if (showAlert) ...[
                      GestureDetector(
                        onTap: () => onSelect(Screen.logs),
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.warning_amber_rounded, color: AppTheme.yellow, size: 16),
                                SizedBox(width: 8),
                                Text('Alerta', style: TextStyle(
                                  color: AppTheme.yellow,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                )),
                              ]),
                              SizedBox(height: 6),
                              Text('Se requieren atención manual a los grupos\nVer en Registro', style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 16),
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDisabled;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isDisabled,
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
              color: isDisabled 
                  ? AppTheme.textSecondary.withOpacity(0.3) 
                  : (isActive ? AppTheme.accentLight : AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: isDisabled 
                  ? AppTheme.textSecondary.withOpacity(0.3) 
                  : (isActive ? AppTheme.accentLight : AppTheme.textSecondary),
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