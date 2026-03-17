import '../models/models.dart';

final List<Tutor> mockTutors = [
  Tutor(id: 't1', name: 'Dr. Ana García', department: 'Sistemas', careers: ['Computación', 'IA'], email: 'ana.garcia@inst.edu', hasAI: true, isActive: true),
  Tutor(id: 't2', name: 'Ing. Luis Mendoza', department: 'Sistemas', careers: ['Computación'], email: 'luis.mendoza@inst.edu', hasAI: false, isActive: true),
  Tutor(id: 't3', name: 'Dra. Carmen Ríos', department: 'IA', careers: ['IA', 'Robótica'], email: 'carmen.rios@inst.edu', hasAI: true, isActive: false), // Simulamos una baja
  Tutor(id: 't4', name: 'Dr. Pablo Torres', department: 'Sistemas', careers: ['Computación', 'Robótica'], email: 'pablo.torres@inst.edu', hasAI: false, isActive: true),
  Tutor(id: 't5', name: 'Ing. Sofía Vargas', department: 'IA', careers: ['IA'], email: 'sofia.vargas@inst.edu', hasAI: true, isActive: true),
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