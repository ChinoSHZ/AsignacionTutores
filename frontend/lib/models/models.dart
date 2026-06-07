import 'package:flutter/material.dart';

enum BalanceStatus { balanced, warning, critical }
enum MobilityFlag { canChange, noChange, newStudent }
enum Screen { upload, processing, dashboard, careers, tutors, assignments, logs }

class Career {
  final String id;
  String abbreviation;
  String name;

  Career({
    required this.id,
    required this.abbreviation,
    required this.name,
  });
}

class Tutor {
  final String id;
  final String name;
  final String department;
  final List<String> careers; // Ahora almacenará las abreviaturas (ej. ['ICO', 'IIA'])
  String email;       
  bool hasAI;         
  bool isActive;      
  List<Student> students;

Tutor({
    required this.id,
    required this.name,
    required this.department,
    required this.careers,
    this.email = '',    
    this.hasAI = false, 
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
  final String accountNumber; 
  final String entryPeriod;   
  String career;              
  final bool isReentry;
  MobilityFlag mobility;      
  String tutorId;
  String? previousTutorId;
  bool wasReassigned;
  bool isActive; // <-- NUEVO ATRIBUTO

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
    this.isActive = true, // <-- POR DEFECTO ACTIVO
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