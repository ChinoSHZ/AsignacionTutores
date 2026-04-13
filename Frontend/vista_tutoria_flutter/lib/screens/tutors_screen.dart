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
          widget.tutors.clear();
          for (var item in data) {
            final nombreCompleto = '${item['nombre']} ${item['apellido_paterno']} ${item['apellido_materno'] ?? ''}'.trim();
            
            // Mapeo de la relación Muchos a Muchos [cite: 13]
            List<String> listaCarreras = (item['licenciaturas'] as List)
                .map((lic) => lic['abreviatura'].toString())
                .toList();

            widget.tutors.add(Tutor(
              id: item['id'], // UUID [cite: 13]
              name: nombreCompleto,
              department: listaCarreras.isNotEmpty ? listaCarreras.first : 'Sin Carrera',
              careers: listaCarreras,
              isActive: item['estado'] == 'Activo',
            ));
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${response.statusCode}';
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

  List<Tutor> get _filteredTutors {
    return widget.tutors.where((t) {
      final matchSearch = _searchQuery.isEmpty || t.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCareer = _filterCareer == 'Todas' || t.careers.contains(_filterCareer);
      final matchStatus = _filterStatus == 'Todos' || 
                         (_filterStatus == 'Activo' && t.isActive) || 
                         (_filterStatus == 'Baja' && !t.isActive);
      return matchSearch && matchCareer && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Gestión de Tutores',
      subtitle: 'Catálogo de profesores y estado de actividad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
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
    final filterOptions = ['Todas', ...widget.careers.map((c) => c.abbreviation)];

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar tutor...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildDropdown('Carrera', _filterCareer, filterOptions, (v) => setState(() => _filterCareer = v!)),
        const SizedBox(width: 12),
        _buildDropdown('Estado', _filterStatus, ['Todos', 'Activo', 'Baja'], (v) => setState(() => _filterStatus = v!)),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _fetchTutorsFromBackend,
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
          onPressed: () => _showTutorDialog(),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('NUEVO TUTOR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
          dropdownColor: AppTheme.surface,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        ),
      ),
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
          DataColumn(label: Text('NOMBRE DEL TUTOR', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('LICENCIATURAS', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ESTADO', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ACCIONES', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
        ],
        rows: _filteredTutors.map((t) => DataRow(cells: [
          DataCell(Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Wrap(
            spacing: 4,
            children: t.careers.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(c, style: const TextStyle(color: AppTheme.accentLight, fontSize: 10, fontWeight: FontWeight.bold)),
            )).toList(),
          )),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (t.isActive ? AppTheme.green : AppTheme.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(t.isActive ? 'Activo' : 'Baja', style: TextStyle(color: t.isActive ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold)),
          )),
          DataCell(Row(
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showTutorDialog(tutor: t)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.red), onPressed: () {}),
            ],
          )),
        ])).toList(),
      ),
    );
  }

  void _showTutorDialog({Tutor? tutor}) {
    showDialog(
      context: context,
      builder: (_) => _TutorDialog(
        tutor: tutor,
        careers: widget.careers,
        onSave: (id, name, email, selectedCareers, isActive) {
          setState(() {
            if (tutor == null) {
              widget.tutors.add(Tutor(id: id, name: name, department: selectedCareers.first, careers: selectedCareers, isActive: isActive));
            } else {
              // Actualización local omitida para brevedad, se recomienda fetch tras guardar en DB
            }
          });
        },
      ),
    );
  }
}

class _TutorDialog extends StatefulWidget {
  final Tutor? tutor;
  final List<Career> careers;
  final Function(String, String, String, List<String>, bool) onSave;
  const _TutorDialog({this.tutor, required this.careers, required this.onSave});

  @override
  State<_TutorDialog> createState() => _TutorDialogState();
}

class _TutorDialogState extends State<_TutorDialog> {
  late TextEditingController _idCtrl, _nombreCtrl, _apPaternoCtrl, _apMaternoCtrl, _emailCtrl;
  late List<String> _selectedCareers;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final names = widget.tutor?.name.split(' ') ?? ['', '', ''];
    _idCtrl = TextEditingController(text: widget.tutor?.id ?? '');
    _nombreCtrl = TextEditingController(text: names.isNotEmpty ? names[0] : '');
    _apPaternoCtrl = TextEditingController(text: names.length > 1 ? names[1] : '');
    _apMaternoCtrl = TextEditingController(text: names.length > 2 ? names[2] : '');
    _emailCtrl = TextEditingController(text: widget.tutor?.email ?? '');
    _selectedCareers = widget.tutor != null ? List.from(widget.tutor!.careers) : [];
    _isActive = widget.tutor?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.tutor == null ? 'Nuevo Tutor' : 'Editar Tutor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentLight)),
              const SizedBox(height: 24),
              if (widget.tutor != null) _buildField('ID (UUID)', _idCtrl),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _buildField('Nombre(s)', _nombreCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Ap. Paterno', _apPaternoCtrl)),
              ]),
              const SizedBox(height: 16),
              _buildField('Ap. Materno', _apMaternoCtrl),
              const SizedBox(height: 16),
              _buildField('Correo electrónico', _emailCtrl),
              const SizedBox(height: 20),
              const Text('Licenciaturas asignadas:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.careers.map((c) {
                  final isSelected = _selectedCareers.contains(c.abbreviation);
                  return FilterChip(
                    label: Text(c.abbreviation, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppTheme.textSecondary)),
                    selected: isSelected,
                    onSelected: (val) => setState(() => val ? _selectedCareers.add(c.abbreviation) : _selectedCareers.remove(c.abbreviation)),
                    selectedColor: AppTheme.accent,
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(children: [
                const Text('Estado Activo:'),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: AppTheme.green),
              ]),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                  onPressed: () {
                    final fullName = '${_nombreCtrl.text} ${_apPaternoCtrl.text} ${_apMaternoCtrl.text}'.trim();
                    widget.onSave(_idCtrl.text, fullName, _emailCtrl.text, _selectedCareers, _isActive);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ])
            ],
          ),
        ),
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
}