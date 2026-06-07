import '../models/models.dart';

// NUEVO: Catálogo inicial de carreras
final List<Career> mockCareers = [
  Career(id: 'C01', abbreviation: 'ICO', name: 'Licenciatura de Ingeniería en Computación'),
  Career(id: 'C02', abbreviation: 'IME', name: 'Licenciatura de Ingeniería Mecánica'),
  Career(id: 'C03', abbreviation: 'ISES', name: 'Licenciatura de Ingeniería en Sistemas Energéticos Sustentables'),
  Career(id: 'C04', abbreviation: 'ICI', name: 'Licenciatura de Ingeniería Civil'),
  Career(id: 'C05', abbreviation: 'IEL', name: 'Licenciatura de Ingeniería en Electrónica'),
  Career(id: 'C06', abbreviation: 'IIA', name: 'Licenciatura de Ingeniería en Inteligencia Artificial'),
];

final List<Tutor> mockTutors = [
  Tutor(id: 't1', name: 'Dr. Ana García', department: 'Sistemas', careers: ['ICO', 'IIA'], isActive: true),
  Tutor(id: 't2', name: 'Ing. Luis Mendoza', department: 'Sistemas', careers: ['ICO'], isActive: false),
  Tutor(id: 't3', name: 'Dra. Carmen Ríos', department: 'IA', careers: ['IIA', 'IME'], isActive: true),
  Tutor(id: 't4', name: 'Dr. Pablo Torres', department: 'Sistemas', careers: ['ICO', 'IME'], isActive: true),
  Tutor(id: 't5', name: 'Ing. Sofía Vargas', department: 'IA', careers: ['IIA'], isActive: true),
];

final List<Student> mockStudents = List.generate(155, (i) {
  // Ahora usamos las abreviaturas
  final careers = ['ICO', 'IIA', 'IME', 'ISES', 'ICI', 'IEL'];
  final mobilities = [MobilityFlag.canChange, MobilityFlag.noChange, MobilityFlag.newStudent];
  final tutorIds = ['t1', 't2', 't3', 't4', 't5'];
  final isReentry = i % 3 != 0;
  final mobility = isReentry
      ? (i % 5 == 0 ? MobilityFlag.noChange : (i % 4 == 0 ? MobilityFlag.canChange : MobilityFlag.noChange))
      : MobilityFlag.newStudent;
  
  final tutorIndex = i % 5;
  final account = '31${(50000 + i).toString().padLeft(5, '0')}'; 
  final period = '202${3 + (i % 2)}${i % 2 == 0 ? 'A' : 'B'}';

  return Student(
    id: 'A${(1000 + i).toString()}',
    name: 'Alumno ${i + 1}',
    accountNumber: account,
    entryPeriod: period,
    career: careers[i % careers.length], // Distribuye entre las 6 carreras
    isReentry: isReentry,
    mobility: mobility,
    tutorId: tutorIds[tutorIndex],
    wasReassigned: isReentry && i % 7 == 0,
  );
});

// mockLogs se mantiene exactamente igual.
final List<SystemLog> mockLogs = [
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 2)), message: 'Archivo "nuevos_ingresos.xlsx" cargado exitosamente. 58 registros.', type: 'success'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 2)), message: 'Archivo "historico_reingreso.xlsx" cargado. 97 registros.', type: 'success'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 1)), message: 'Iniciando algoritmo de balanceo...', type: 'info'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(minutes: 1)), message: '12 alumnos de reingreso reasignados para equilibrar grupos.', type: 'info'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(seconds: 45)), message: '5 alumnos marcados como "No Cambiar" bloquearon el balanceo en Grupo Dr. Pablo Torres.', type: 'warning'),
  SystemLog(timestamp: DateTime.now().subtract(const Duration(seconds: 30)), message: 'Balanceo completado. Revisar grupo con desbalance crítico.', type: 'warning'),
];