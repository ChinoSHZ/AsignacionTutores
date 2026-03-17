import 'package:flutter/material.dart';

enum BalanceStatus { balanced, warning, critical }
enum MobilityFlag { canChange, noChange, newStudent }
// NUEVO: Agregamos 'tutors' entre dashboard y assignments
enum Screen { upload, processing, dashboard, tutors, assignments, logs } 

class Tutor {
  final String id;
  final String name;
  final String department;
  final List<String> careers;
  
  // NUEVOS CAMPOS
  String email;
  bool hasAI;
  bool isActive;
  
  List<Student> students;

  Tutor({
    required this.id,
    required this.name,
    required this.department,
    required this.careers,
    this.email = '', // Valor por defecto
    this.hasAI = false, // Valor por defecto
    this.isActive = true, // Activo por defecto
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