import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class CopyGroupsScreen extends StatefulWidget {
  const CopyGroupsScreen({super.key});

  @override
  State<CopyGroupsScreen> createState() => _CopyGroupsScreenState();
}

class _CopyGroupsScreenState extends State<CopyGroupsScreen> {
  bool _isLoading = true;
  List<dynamic> _tutors = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/asignaciones/dashboard'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tutors = data['tutores'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTutors = _tutors.where((t) {
      final String name = t['nombre_completo'] ?? '${t['nombre']} ${t['apellido_paterno']}';
      return _searchQuery.isEmpty || name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ScreenWrapper(
      title: 'Copiar Grupos',
      subtitle: 'Extraer matrículas de tutorados activos para reportes.',
      // SOLUCIÓN DE OVERFLOW: El ScreenWrapper envuelve sus 'child' en un SingleChildScrollView.
      // Por tanto, usar Expanded dentro de él causa el error. En su lugar usamos 'shrinkWrap: true' y 'NeverScrollableScrollPhysics' en la lista.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar profesor...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.accent,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.accent)))
          else if (filteredTutors.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No se encontraron profesores', style: TextStyle(color: AppTheme.textSecondary))))
          else
            ListView.builder(
              shrinkWrap: true, // Importante para que la lista funcione dentro de un SingleChildScrollView (ScreenWrapper)
              physics: const NeverScrollableScrollPhysics(), // Evita scroll conflictivo
              itemCount: filteredTutors.length,
              itemBuilder: (context, index) {
                final tutor = filteredTutors[index];
                final String tutorName = tutor['nombre_completo'] ?? '${tutor['nombre']} ${tutor['apellido_paterno']}';
                
                List<dynamic> activeStudents = [];
                if (tutor['grupos'] != null && tutor['grupos'].isNotEmpty) {
                  for (var group in tutor['grupos']) {
                    if (group['tutorados'] != null) {
                      for (var student in group['tutorados']) {
                        if (student['is_active'] == 1 || student['is_active'] == true) {
                          activeStudents.add(student);
                        }
                      }
                    }
                  }
                }

                String cuentasText = activeStudents.map((s) => s['numero_cuenta']).join(',\n');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), shape: BoxShape.circle),
                            child: Center(child: Text(tutorName[0], style: const TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 16))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tutorName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                                Text('${activeStudents.length} alumnos activos', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: cuentasText.isEmpty ? null : () {
                              Clipboard.setData(ClipboardData(text: cuentasText)).then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matrículas copiadas al portapapeles'), backgroundColor: AppTheme.green));
                              });
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                            label: const Text('Copiar', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3498DB),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: SingleChildScrollView(
                            child: Text(
                              cuentasText.isEmpty ? 'Sin alumnos asignados.' : cuentasText,
                              style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 13, height: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}