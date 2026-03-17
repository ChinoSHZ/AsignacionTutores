import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/screen_wrapper.dart';

class TutorsScreen extends StatefulWidget {
  final List<Tutor> tutors;
  const TutorsScreen({super.key, required this.tutors});

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
        onSave: (id, name, email, career, hasAI, isActive) {
          setState(() {
            if (tutor == null) {
              // Agregar nuevo
              widget.tutors.add(Tutor(
                id: id, name: name, department: 'General', careers: [career],
                email: email, hasAI: hasAI, isActive: isActive,
              ));
            } else {
              // Editar existente
              tutor.email = email;
              if (!tutor.careers.contains(career)) {
                tutor.careers[0] = career; // Simplificación para el ejemplo
              }
              tutor.hasAI = hasAI;
              tutor.isActive = isActive;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTutors;
    final Set<String> allCareers = {};
    for (var t in widget.tutors) { allCareers.addAll(t.careers); }
    final careers = ['Todas', ...allCareers.toList()..sort()];

    return ScreenWrapper(
      title: 'Gestión de Tutores',
      subtitle: 'Administración, altas y bajas del personal docente',
      scrollable: false,
      child: Column(children: [
        // Top Action Bar & Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre de tutor...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showTutorDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Alta de Tutor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Filtros:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(child: _DropdownFilter<String>(
                label: 'Carrera', value: _filterCareer, options: careers,
                onChanged: (v) => setState(() => _filterCareer = v ?? 'Todas'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _DropdownFilter<String>(
                label: 'Estado', value: _filterStatus, options: const ['Todos', 'Activo', 'Baja'],
                onChanged: (v) => setState(() => _filterStatus = v ?? 'Todos'),
              )),
              const Spacer(), // Balance visual
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(children: [
            SizedBox(width: 60, child: _TableHeader('ID')),
            Expanded(flex: 2, child: _TableHeader('Tutor / Correo')),
            Expanded(flex: 1, child: _TableHeader('Carreras')),
            Expanded(flex: 1, child: _TableHeader('IA Asignada')),
            SizedBox(width: 100, child: _TableHeader('Estado')),
            SizedBox(width: 80, child: _TableHeader('Acciones')),
          ]),
        ),

        // Table Body
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: AppTheme.border),
          ),
          child: filtered.isEmpty 
          ? const Center(child: Text('No se encontraron tutores', style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
            itemBuilder: (_, i) {
              final t = filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: !t.isActive ? AppTheme.red.withValues(alpha:0.02) : Colors.transparent,
                child: Row(children: [
                  SizedBox(width: 60, child: Text(t.id, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: TextStyle(color: t.isActive ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(t.email.isEmpty ? 'Sin correo' : t.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  )),
                  Expanded(flex: 1, child: Wrap(
                    spacing: 4, runSpacing: 4,
                    children: t.careers.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha:0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(c, style: const TextStyle(color: AppTheme.accentLight, fontSize: 10)),
                    )).toList(),
                  )),
                  Expanded(flex: 1, child: Row(children: [
                    Icon(t.hasAI ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: t.hasAI ? AppTheme.green : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(t.hasAI ? 'Sí' : 'No', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ])),
                  SizedBox(width: 100, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.isActive ? AppTheme.green.withValues(alpha:0.1) : AppTheme.red.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.isActive ? AppTheme.green.withValues(alpha:0.3) : AppTheme.red.withValues(alpha:0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.isActive ? AppTheme.green : AppTheme.red, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(t.isActive ? 'Activo' : 'Baja', style: TextStyle(color: t.isActive ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                  SizedBox(width: 80, child: IconButton(
                    onPressed: () => _showTutorDialog(tutor: t),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: AppTheme.textSecondary,
                    tooltip: 'Editar tutor',
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
  const _TableHeader(this.label);
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600));
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
      dropdownColor: AppTheme.surfaceLight,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toString()))).toList(),
      onChanged: onChanged,
    );
  }
}

// MODAL DE ALTA / EDICIÓN DE TUTOR
class _TutorDialog extends StatefulWidget {
  final Tutor? tutor;
  final Function(String id, String name, String email, String career, bool hasAI, bool isActive) onSave;

  const _TutorDialog({this.tutor, required this.onSave});

  @override
  State<_TutorDialog> createState() => _TutorDialogState();
}

class _TutorDialogState extends State<_TutorDialog> {
  late TextEditingController _idCtrl, _nameCtrl, _emailCtrl, _careerCtrl;
  late bool _hasAI, _isActive;

  @override
  void initState() {
    super.initState();
    final t = widget.tutor;
    _idCtrl = TextEditingController(text: t?.id ?? 't${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _emailCtrl = TextEditingController(text: t?.email ?? '');
    _careerCtrl = TextEditingController(text: t?.careers.isNotEmpty == true ? t!.careers.first : '');
    _hasAI = t?.hasAI ?? false;
    _isActive = t?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tutor != null;
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar Tutor' : 'Alta de Tutor', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            if (!isEdit) _buildField('ID (Matrícula)', _idCtrl),
            if (!isEdit) const SizedBox(height: 12),
            if (!isEdit) _buildField('Nombre Completo', _nameCtrl),
            if (!isEdit) const SizedBox(height: 12),
            _buildField('Correo Institucional', _emailCtrl),
            const SizedBox(height: 12),
            _buildField('Carrera Principal', _careerCtrl),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('IA Asignada', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              subtitle: const Text('¿Usa modelo de IA para seguimiento?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              value: _hasAI, activeColor: AppTheme.accent,
              onChanged: (v) => setState(() => _hasAI = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Estado', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              subtitle: Text(_isActive ? 'Activo (Participa)' : 'Baja (Inactivo)', style: TextStyle(color: _isActive ? AppTheme.green : AppTheme.red, fontSize: 11)),
              value: _isActive, activeColor: AppTheme.green, inactiveTrackColor: AppTheme.red.withValues(alpha:0.3),
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                onPressed: () {
                  widget.onSave(_idCtrl.text, _nameCtrl.text, _emailCtrl.text, _careerCtrl.text, _hasAI, _isActive);
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ])
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true, fillColor: AppTheme.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}