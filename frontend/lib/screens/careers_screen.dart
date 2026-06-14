import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class CareersScreen extends StatefulWidget {
  final List<Career> careers;
  const CareersScreen({super.key, required this.careers});

  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  String _searchQuery = '';
  bool _isLoading = true;
  String _errorMessage = '';
  List<Career> _apiCareers = [];

  @override
  void initState() {
    super.initState();
    _fetchCareersFromBackend();
  }

  // --- LEER (R) ---
  Future<void> _fetchCareersFromBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/licenciaturas'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          // Guardamos el ID numérico de la DB para poder hacer PUT y DELETE
          _apiCareers = data.map((json) => Career(
            id: json['id'].toString(), 
            abbreviation: json['abreviatura'],
            name: json['nombre'],
          )).toList();
        });
      } else {
        setState(() => _errorMessage = 'Error al cargar las licenciaturas del servidor');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error de conexión con el backend');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- CREAR Y ACTUALIZAR (C / U) ---
  Future<void> _saveCareer(String? id, String abrev, String name) async {
    setState(() => _isLoading = true);
    try {
      http.Response response;
      final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
      final body = jsonEncode({'abreviatura': abrev, 'nombre': name});

      if (id == null) {
        // Nueva Carrera (POST)
        response = await http.post(Uri.parse('http://127.0.0.1:8000/api/licenciaturas'), headers: headers, body: body);
      } else {
        // Editar Carrera (PUT)
        response = await http.put(Uri.parse('http://127.0.0.1:8000/api/licenciaturas/$id'), headers: headers, body: body);
      }

      if (response.statusCode == 200) {
        _mostrarSnackBar(id == null ? 'Licenciatura creada exitosamente' : 'Licenciatura actualizada exitosamente', AppTheme.green);
        await _fetchCareersFromBackend(); // Recargar la lista
      } else {
        _mostrarSnackBar('Error al guardar la licenciatura en la base de datos', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión', AppTheme.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ELIMINAR (D) ---
  Future<void> _deleteCareer(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/api/licenciaturas/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        _mostrarSnackBar('Licenciatura eliminada exitosamente', AppTheme.green);
        await _fetchCareersFromBackend();
      } else {
        _mostrarSnackBar('Error al eliminar de la base de datos', AppTheme.red);
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

  // MODAL DE FORMULARIO (NUEVO / EDITAR)
  void _showFormModal({Career? career}) {
    final abrevCtrl = TextEditingController(text: career?.abbreviation ?? '');
    final nameCtrl = TextEditingController(text: career?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          career == null ? 'Nueva Licenciatura' : 'Editar Licenciatura',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: abrevCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Abreviatura (ej. ICO)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Nombre Completo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              if (abrevCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                _saveCareer(career?.id, abrevCtrl.text.trim(), nameCtrl.text.trim());
              } else {
                _mostrarSnackBar('Por favor, llena todos los campos', AppTheme.yellow);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // MODAL DE CONFIRMACIÓN PARA ELIMINAR
  void _confirmDelete(Career career) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.red),
            SizedBox(width: 10),
            Text('Eliminar Licenciatura', style: TextStyle(color: AppTheme.red)),
          ],
        ),
        content: Text(
          '¿Estás seguro de querer eliminar la licenciatura ${career.abbreviation}?\n\nEsto desenlazará a los tutores y alumnos asociados a ella. Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteCareer(career.id);
            },
            child: const Text('Confirmar Eliminación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCareers = _apiCareers.where((c) {
      if (c.abbreviation == 'S/L') return false;
      
      return _searchQuery.isEmpty ||
          c.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ScreenWrapper(
      title: 'Catálogo de Licenciaturas',
      subtitle: 'Gestión de licenciaturas y programas académicos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar licenciatura...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Nueva Licenciatura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showFormModal(),
              )
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(children: [
              Expanded(flex: 1, child: Text('Abreviatura', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 4, child: Text('Nombre de la licenciatura', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              SizedBox(width: 100, child: Text('Acciones', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ]),
          ),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.accent)))
          else if (_errorMessage.isNotEmpty)
            Center(child: Padding(padding: EdgeInsets.all(20), child: Text(_errorMessage, style: const TextStyle(color: AppTheme.red))))
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border.all(color: AppTheme.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCareers.length,
                separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
                itemBuilder: (context, index) {
                  final career = filteredCareers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(career.abbreviation,
                                    style: const TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(career.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AppTheme.yellow),
                                tooltip: 'Editar Licenciatura',
                                onPressed: () => _showFormModal(career: career),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red),
                                tooltip: 'Eliminar Licenciatura',
                                onPressed: () => _confirmDelete(career),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}