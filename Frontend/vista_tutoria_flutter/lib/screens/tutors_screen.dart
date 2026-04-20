import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class TutorsScreen extends StatefulWidget {
  final List<Tutor> tutors;
  final List<Career> careers;
  const TutorsScreen({super.key, required this.tutors, required this.careers});

  @override
  State<TutorsScreen> createState() => _TutorsScreenState();
}

class _TutorsScreenState extends State<TutorsScreen> {
  String _searchQuery = '';
  String _filterCareer = 'Todas';
  String _filterStatus = 'Todos';
  bool _isLoading = true;
  String _errorMessage = '';
  List<Tutor> _apiTutors = [];
  
  int _currentPage = 0;
  final int _itemsPerPage = 100;

  @override
  void initState() {
    super.initState();
    _fetchTutorsFromBackend();
  }

  Future<void> _fetchTutorsFromBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/profesores'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _apiTutors = data.map((json) {
            final nombre = json['nombre'] ?? '';
            final apPat = json['apellido_paterno'] ?? '';
            final apMat = json['apellido_materno'] ?? '';
            final nombreCompleto = json['nombre_completo'] ?? '$nombre $apPat $apMat'.trim();

            final String tutorId = json['id']?.toString() 
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

            return Tutor(
              id: tutorId,
              name: nombreCompleto.isEmpty ? 'Sin Nombre' : nombreCompleto,
              department: 'Asignado',
              careers: carrerasList,
              email: json['correo'] ?? '',
              isActive: json['estado'] == 'Activo',
            );
          }).toList();
          
          final maxPages = (_apiTutors.length / _itemsPerPage).ceil();
          if (_currentPage >= maxPages && maxPages > 0) {
            _currentPage = maxPages - 1;
          }
        });
      } else {
        setState(() => _errorMessage = 'Error al cargar los tutores');
      }
    } catch (e) {
      print("Error interno de Flutter detectado: $e");
      setState(() => _errorMessage = 'Error de conexión con el servidor');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTutor(String? id, String nombre, String apPaterno, String apMaterno, String email, List<String> carreras, bool isActive) async {
    setState(() => _isLoading = true);
    try {
      http.Response response;
      final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
      final body = jsonEncode({
        'nombre': nombre,
        'apellido_paterno': apPaterno,
        'apellido_materno': apMaterno,
        'correo': email,
        'carreras': carreras,
        'estado': isActive ? 'Activo' : 'Inactivo'
      });

      if (id == null || id.isEmpty) {
        response = await http.post(Uri.parse('http://127.0.0.1:8000/api/profesores'), headers: headers, body: body);
      } else {
        response = await http.put(Uri.parse('http://127.0.0.1:8000/api/profesores/$id'), headers: headers, body: body);
      }

      if (response.statusCode == 200) {
        _mostrarSnackBar(id == null || id.isEmpty ? 'Tutor registrado exitosamente' : 'Tutor actualizado', AppTheme.green);
        await _fetchTutorsFromBackend();
      } else {
        _mostrarSnackBar('Error al procesar la solicitud', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión', AppTheme.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTutor(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/api/profesores/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        _mostrarSnackBar('Tutor eliminado permanentemente', AppTheme.green);
        await _fetchTutorsFromBackend();
      } else {
        _mostrarSnackBar('Error al eliminar', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión', AppTheme.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: color));
  }

  void _showFormModal({Tutor? tutor}) {
    final parts = tutor?.name.split(' ') ?? [];
    final initNombre = parts.isNotEmpty ? parts[0] : '';
    final initApPat = parts.length > 1 ? parts[1] : '';
    final initApMat = parts.length > 2 ? parts.sublist(2).join(' ') : '';

    final nombreCtrl = TextEditingController(text: initNombre);
    final apPaternoCtrl = TextEditingController(text: initApPat);
    final apMaternoCtrl = TextEditingController(text: initApMat);
    final emailCtrl = TextEditingController(text: tutor?.email ?? '');
    
    List<String> selectedCareers = tutor != null ? tutor.careers.map((e) => e.trim()).toList() : [];
    bool isActive = tutor?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(tutor == null ? 'Nuevo Tutor' : 'Editar Tutor', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField('Nombre(s) *', nombreCtrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildField('Ap. Paterno *', apPaternoCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Ap. Materno', apMaternoCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField('Correo Institucional (Opcional)', emailCtrl),
                    const SizedBox(height: 16),
                    const Text('Licenciaturas Asignadas *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.careers.map((c) {
                        final abrev = c.abbreviation.trim();
                        final isSelected = selectedCareers.contains(abrev);
                        return FilterChip(
                          label: Text(abrev, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (val) {
                            setStateModal(() {
                              if (val) {
                                if (!selectedCareers.contains(abrev)) selectedCareers.add(abrev);
                              } else {
                                selectedCareers.remove(abrev);
                              }
                            });
                          },
                          backgroundColor: AppTheme.bg,
                          selectedColor: AppTheme.accent.withValues(alpha: 0.3),
                          checkmarkColor: AppTheme.textPrimary,
                          side: BorderSide(color: isSelected ? AppTheme.accent : AppTheme.border),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Estado Activo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      value: isActive,
                      activeColor: AppTheme.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setStateModal(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                onPressed: () {
                  if (tutor != null && tutor.id.isEmpty) {
                    _mostrarSnackBar('Error crítico: La base de datos no está enviando el ID del tutor. Revisa el backend.', AppTheme.red);
                    return;
                  }

                  if (nombreCtrl.text.isNotEmpty && apPaternoCtrl.text.isNotEmpty && selectedCareers.isNotEmpty) {
                    Navigator.pop(context);
                    _saveTutor(
                      tutor?.id, 
                      nombreCtrl.text.trim(), 
                      apPaternoCtrl.text.trim(), 
                      apMaternoCtrl.text.trim(), 
                      emailCtrl.text.trim(), 
                      selectedCareers, 
                      isActive
                    );
                  } else {
                    _mostrarSnackBar('Completa los campos obligatorios (*) y selecciona al menos una carrera', AppTheme.yellow);
                  }
                },
                child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _confirmDelete(Tutor tutor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.red), SizedBox(width: 10), Text('Eliminar Tutor', style: TextStyle(color: AppTheme.red))]),
        content: Text('¿Confirmas la eliminación permanente del tutor ${tutor.name}? Sus alumnos asignados quedarán sin tutor.', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteTutor(tutor.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> allCareers = {'Todas'};
    for (var c in widget.careers) {
      allCareers.add(c.abbreviation);
    }

    final filteredTutors = _apiTutors.where((t) {
      final matchSearch = _searchQuery.isEmpty || t.name.toLowerCase().contains(_searchQuery.toLowerCase()) || t.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCareer = _filterCareer == 'Todas' || t.careers.contains(_filterCareer);
      final matchStatus = _filterStatus == 'Todos' || (_filterStatus == 'Activos' ? t.isActive : !t.isActive);
      return matchSearch && matchCareer && matchStatus;
    }).toList();

    final totalPages = (filteredTutors.length / _itemsPerPage).ceil();
    final paginatedTutors = filteredTutors.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList();

    return ScreenWrapper(
      title: 'Plantilla de Tutores',
      subtitle: 'Administración del personal académico e IA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0; 
                  }),
                ),
              ),
              const SizedBox(width: 16),
              _buildDropdown(allCareers.toList(), _filterCareer, (val) => setState(() {
                _filterCareer = val!;
                _currentPage = 0; 
              })),
              const SizedBox(width: 16),
              _buildDropdown(['Todos', 'Activos', 'Inactivos'], _filterStatus, (val) => setState(() {
                _filterStatus = val!;
                _currentPage = 0; 
              })),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text('Nuevo Tutor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showFormModal(),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          else if (_errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage, style: const TextStyle(color: AppTheme.red)))
          else
            Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginatedTutors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final t = paginatedTutors[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: t.isActive ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceLight, shape: BoxShape.circle),
                            child: Center(child: Text(t.name[0], style: TextStyle(color: t.isActive ? AppTheme.accentLight : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 16))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: TextStyle(color: t.isActive ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(t.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: t.careers.map((c) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
                                child: Text(c, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                              )).toList(),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: t.isActive ? AppTheme.green.withValues(alpha: 0.1) : AppTheme.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text(t.isActive ? 'Activo' : 'Inactivo', style: TextStyle(color: t.isActive ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 16),
                          IconButton(icon: const Icon(Icons.edit_rounded, color: AppTheme.yellow, size: 20), onPressed: () => _showFormModal(tutor: t)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 20), onPressed: () => _confirmDelete(t)),
                        ],
                      ),
                    );
                  },
                ),
                if (totalPages > 0) 
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        const SizedBox(width: 16),
                        Text('Página ${_currentPage + 1} de $totalPages', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  )
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, void Function(String?) onChanged) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: AppTheme.surfaceLight,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}