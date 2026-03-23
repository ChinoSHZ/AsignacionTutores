import 'package:flutter/material.dart';
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

  void _showTutorDialog({Tutor? tutor}) {
    showDialog(
      context: context,
      builder: (_) => _TutorDialog(
        tutor: tutor,
        careersCatalog: widget.careers,
        onSave: (id, name, email, selectedCareers, isActive) {
          setState(() {
            if (tutor == null) {
              widget.tutors.add(Tutor(
                id: id, name: name, department: 'General', careers: selectedCareers,
                email: email, hasAI: false, isActive: isActive,
              ));
            } else {
              final index = widget.tutors.indexOf(tutor);
              if (index != -1) {
                widget.tutors[index] = Tutor(
                  id: tutor.id, name: name, department: tutor.department,
                  careers: selectedCareers, email: email, hasAI: tutor.hasAI,
                  isActive: isActive, students: tutor.students,
                );
              }
            }
          });
        },
      ),
    );
  }

  // NUEVA FUNCIÓN: Eliminar Tutor
  void _deleteTutor(Tutor tutor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar Tutor', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('¿Estás seguro de eliminar a ${tutor.name}? Esto dejará a sus alumnos sin tutor asignado.', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => widget.tutors.remove(tutor));
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTutors;
    final careerOptions = ['Todas', ...widget.careers.map((c) => c.abbreviation).toList()..sort()];

    return ScreenWrapper(
      title: 'Gestión de Tutores',
      subtitle: 'Administración, altas y bajas del personal docente',
      scrollable: false,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre de tutor...', hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    filled: true, fillColor: AppTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showTutorDialog(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Alta de Tutor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Filtros:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(child: _DropdownFilter<String>(label: 'Carrera', value: _filterCareer, options: careerOptions, onChanged: (v) => setState(() => _filterCareer = v ?? 'Todas'))),
              const SizedBox(width: 10),
              Expanded(child: _DropdownFilter<String>(label: 'Estado', value: _filterStatus, options: const ['Todos', 'Activo', 'Baja'], onChanged: (v) => setState(() => _filterStatus = v ?? 'Todos'))),
              const Spacer(), 
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border.all(color: AppTheme.border)),
          child: const Row(children: [
            SizedBox(width: 60, child: _TableHeader('ID')),
            Expanded(flex: 2, child: _TableHeader('Tutor / Correo')),
            Expanded(flex: 2, child: _TableHeader('Carreras')),
            SizedBox(width: 100, child: _TableHeader('Estado')),
            SizedBox(width: 100, child: _TableHeader('Acciones', alignRight: true)), // Ensanchado para 2 botones
          ]),
        ),
        Expanded(child: Container(
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)), border: Border.all(color: AppTheme.border)),
          child: filtered.isEmpty 
          ? const Center(child: Text('No se encontraron tutores', style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
            itemBuilder: (_, i) {
              final t = filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: !t.isActive ? AppTheme.red.withOpacity(0.02) : Colors.transparent,
                child: Row(children: [
                  SizedBox(width: 60, child: Text(t.id, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: TextStyle(color: t.isActive ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(t.email.isEmpty ? 'Sin correo' : t.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  )),
                  Expanded(flex: 2, child: Wrap(
                    spacing: 4, runSpacing: 4,
                    children: t.careers.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(c, style: const TextStyle(color: AppTheme.accentLight, fontSize: 10)),
                    )).toList(),
                  )),
                  SizedBox(width: 100, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.isActive ? AppTheme.green.withOpacity(0.1) : AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6), border: Border.all(color: t.isActive ? AppTheme.green.withOpacity(0.3) : AppTheme.red.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.isActive ? AppTheme.green : AppTheme.red, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(t.isActive ? 'Activo' : 'Baja', style: TextStyle(color: t.isActive ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                  SizedBox(width: 100, child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _showTutorDialog(tutor: t),
                        icon: const Icon(Icons.edit_rounded, size: 16), color: const Color(0xFF3498DB),
                        tooltip: 'Editar tutor', constraints: const BoxConstraints(), padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        onPressed: () => _deleteTutor(t),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16), color: AppTheme.red,
                        tooltip: 'Eliminar tutor', constraints: const BoxConstraints(), padding: const EdgeInsets.all(8),
                      ),
                    ],
                  )),
                ]),
              );
            },
          ),
        )),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final bool alignRight;
  const _TableHeader(this.label, {this.alignRight = false});
  @override
  Widget build(BuildContext context) => Text(label, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600));
}

class _DropdownFilter<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final void Function(T?) onChanged;

  const _DropdownFilter({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true, fillColor: AppTheme.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      dropdownColor: AppTheme.surfaceLight, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toString()))).toList(), onChanged: onChanged,
    );
  }
}

// ... EL _TUTORDIALOG SE MANTIENE EXACTAMENTE IGUAL AL QUE TE DI EN LA RESPUESTA ANTERIOR ...
class _TutorDialog extends StatefulWidget {
  final Tutor? tutor;
  final List<Career> careersCatalog;
  final Function(String id, String name, String email, List<String> careers, bool isActive) onSave;

  const _TutorDialog({this.tutor, required this.careersCatalog, required this.onSave});

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
    final t = widget.tutor;
    _idCtrl = TextEditingController(text: t?.id ?? 't${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final nameParts = t?.name.split(' ') ?? [];
    _nombreCtrl = TextEditingController(text: nameParts.isNotEmpty ? nameParts[0] : '');
    _apPaternoCtrl = TextEditingController(text: nameParts.length > 1 ? nameParts[1] : '');
    _apMaternoCtrl = TextEditingController(text: nameParts.length > 2 ? nameParts.sublist(2).join(' ') : '');
    _emailCtrl = TextEditingController(text: t?.email ?? '');
    _selectedCareers = t?.careers.toList() ?? [];
    _isActive = t?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tutor != null;
    return Dialog(
      backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440, padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Editar Tutor' : 'Alta de Tutor', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              if (!isEdit) _buildField('ID (Matrícula)', _idCtrl),
              if (!isEdit) const SizedBox(height: 12),
              _buildField('Nombre(s)', _nombreCtrl),
              const SizedBox(height: 12),
              Row(children: [ Expanded(child: _buildField('Apellido Paterno', _apPaternoCtrl)), const SizedBox(width: 12), Expanded(child: _buildField('Apellido Materno', _apMaternoCtrl)), ]),
              const SizedBox(height: 12),
              _buildField('Correo Institucional', _emailCtrl),
              const SizedBox(height: 16),
              const Text('Carrera', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(8)),
                child: widget.careersCatalog.isEmpty ? const Text('No hay carreras', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)) : Wrap(
                  spacing: 16, runSpacing: 8,
                  children: widget.careersCatalog.map((c) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 24, height: 24, child: Checkbox(value: _selectedCareers.contains(c.abbreviation), activeColor: AppTheme.accent, side: const BorderSide(color: AppTheme.textSecondary), onChanged: (checked) { setState(() { if (checked == true) { _selectedCareers.add(c.abbreviation); } else { _selectedCareers.remove(c.abbreviation); } }); })),
                      const SizedBox(width: 8), Text(c.abbreviation, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ]
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Estado', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)), subtitle: Text(_isActive ? 'Activo (Participa)' : 'Baja (Inactivo)', style: TextStyle(color: _isActive ? AppTheme.green : AppTheme.red, fontSize: 11)),
                value: _isActive, activeColor: AppTheme.green, inactiveTrackColor: AppTheme.red.withOpacity(0.3), onChanged: (v) => setState(() => _isActive = v), contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                  onPressed: () {
                    final fullName = [_nombreCtrl.text.trim(), _apPaternoCtrl.text.trim(), _apMaternoCtrl.text.trim()].where((s) => s.isNotEmpty).join(' ');
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
      controller: ctrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true, fillColor: AppTheme.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}