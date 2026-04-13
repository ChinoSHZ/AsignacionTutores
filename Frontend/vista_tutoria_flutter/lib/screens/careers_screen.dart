import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class CareersScreen extends StatefulWidget {
  // Ya no dependemos exclusivamente de los mocks pasados por constructor
  final List<Career> careers; 
  const CareersScreen({super.key, required this.careers});

  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  String _searchQuery = '';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCareersFromBackend(); // Iniciamos la carga al entrar a la pantalla
  }

  // Método para obtener las licenciaturas desde Laravel
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
          // Limpiamos la lista actual y mapeamos los datos de Postgres al modelo Career
          widget.careers.clear();
          for (var item in data) {
            widget.careers.add(Career(
              id: item['codigo'], // Mapeo de 'codigo' de la DB a 'id' del modelo
              abbreviation: item['abreviatura'],
              name: item['nombre'],
            ));
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  List<Career> get _filteredCareers {
    if (_searchQuery.isEmpty) return widget.careers;
    return widget.careers.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        c.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Catálogo de Carreras',
      subtitle: 'Gestión de licenciaturas e ingenierías del sistema',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          // Mostramos loader o error si es necesario
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ))
          else if (_errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage, style: const TextStyle(color: AppTheme.red)))
          else
            _buildTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o abreviatura...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _fetchCareersFromBackend, // Botón para refrescar datos manualmente
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('REFRESCAR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showCareerDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('NUEVA CARRERA'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.bg),
        columns: const [
          DataColumn(label: Text('ID / CÓDIGO', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ABREV.', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('NOMBRE COMPLETO', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ACCIONES', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
        ],
        rows: _filteredCareers.map((c) => DataRow(cells: [
          DataCell(Text(c.id, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha:0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(c.abbreviation, style: const TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold)),
          )),
          DataCell(Text(c.name)),
          DataCell(Row(
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary), onPressed: () => _showCareerDialog(career: c)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.red), onPressed: () {}),
            ],
          )),
        ])).toList(),
      ),
    );
  }

  void _showCareerDialog({Career? career}) {
    showDialog(
      context: context,
      builder: (_) => _CareerDialog(
        career: career,
        onSave: (abbreviation, name) {
          setState(() {
            if (career == null) {
              final newId = 'C${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
              widget.careers.add(Career(id: newId, abbreviation: abbreviation.toUpperCase(), name: name));
            } else {
              career.abbreviation = abbreviation.toUpperCase();
              career.name = name;
            }
          });
        },
      ),
    );
  }
}

class _CareerDialog extends StatefulWidget {
  final Career? career;
  final Function(String, String) onSave;
  const _CareerDialog({this.career, required this.onSave});

  @override
  State<_CareerDialog> createState() => _CareerDialogState();
}

class _CareerDialogState extends State<_CareerDialog> {
  late TextEditingController _abrevCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _abrevCtrl = TextEditingController(text: widget.career?.abbreviation ?? '');
    _nameCtrl = TextEditingController(text: widget.career?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.career == null ? 'Nueva Carrera' : 'Editar Carrera', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentLight)),
            const SizedBox(height: 24),
            TextField(controller: _abrevCtrl, decoration: _inputDeco('Abreviatura (ej. ICO)')),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: _inputDeco('Nombre completo de la carrera')),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                onPressed: () {
                  if (_abrevCtrl.text.isNotEmpty && _nameCtrl.text.isNotEmpty) {
                    widget.onSave(_abrevCtrl.text, _nameCtrl.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Guardar'),
              ),
            ])
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      filled: true,
      fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}