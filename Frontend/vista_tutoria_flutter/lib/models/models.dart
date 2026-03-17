import 'package:flutter/material.dart';

enum BalanceStatus { balanced, warning, critical }
enum MobilityFlag { canChange, noChange, newStudent }
enum Screen { upload, processing, dashboard, tutors, assignments, logs }

class Tutor {
  final String id;
  final String name;
  final String department;
  final List<String> careers;
  String email;       // <-- NUEVO (Sin final para poder editarlo)
  bool hasAI;         // <-- NUEVO (Sin final)
  bool isActive;      // <-- MODIFICADO (Le quitamos el final para poder editarlo)
  List<Student> students;

  Tutor({
    required this.id,
    required this.name,
    required this.department,
    required this.careers,
    this.email = '',    // <-- Valor por defecto
    this.hasAI = false, // <-- Valor por defecto
    this.isActive = true,
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
  final String accountNumber; // <-- NUEVO ATRIBUTO
  final String entryPeriod;   // <-- NUEVO ATRIBUTO
  String career;              // <-- Modificable para edición
  final bool isReentry;
  MobilityFlag mobility;      // <-- Modificable para edición
  String tutorId;
  String? previousTutorId;
  bool wasReassigned;

  Student({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.entryPeriod,
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
  final String type; 
  final String? studentId;

  SystemLog({
    required this.timestamp,
    required this.message,
    required this.type,
    this.studentId,
  });
}