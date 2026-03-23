import 'package:flutter/material.dart';
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

  List<Career> get _filteredCareers {
    if (_searchQuery.isEmpty) return widget.careers;
    return widget.careers.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        c.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _showCareerDialog({Career? career}) {
    showDialog(
      context: context,
      builder: (_) => _CareerDialog(
        career: career,
        onSave: (abbreviation, name) {
          setState(() {
            if (career == null) {
              // Alta (El ID se genera simulado)
              final newId = 'C${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
              widget.careers.add(Career(id: newId, abbreviation: abbreviation.toUpperCase(), name: name));
            } else {
              // Editar
              career.abbreviation = abbreviation.toUpperCase();
              career.name = name;
            }
          });
        },
      ),
    );
  }

  void _deleteCareer(Career career) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar Carrera', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('¿Estás seguro de eliminar ${career.abbreviation}? Esto podría afectar a los alumnos y tutores asignados a ella.', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => widget.careers.remove(career));
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
    final filtered = _filteredCareers;

    return ScreenWrapper(
      title: 'Catálogo de Carreras',
      subtitle: 'Administración de licenciaturas e ingenierías',
      scrollable: false,
      child: Column(children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar por abreviatura o nombre...',
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
              onPressed: () => _showCareerDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva Carrera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
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
            SizedBox(width: 80, child: Text('ID', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 100, child: Text('Abreviatura', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(child: Text('Nombre de la Carrera', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 100, child: Text('Acciones', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
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
          ? const Center(child: Text('No hay carreras registradas', style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
            itemBuilder: (_, i) {
              final c = filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  SizedBox(width: 80, child: Text(c.id, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                  SizedBox(width: 100, child: Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha:0.1), 
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c.abbreviation, style: const TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )),
                  Expanded(child: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                  SizedBox(width: 100, child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _showCareerDialog(career: c),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        color: const Color(0xFF3498DB),
                        tooltip: 'Editar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        onPressed: () => _deleteCareer(c),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        color: AppTheme.red,
                        tooltip: 'Borrar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
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

class _CareerDialog extends StatefulWidget {
  final Career? career;
  final Function(String abbreviation, String name) onSave;

  const _CareerDialog({this.career, required this.onSave});

  @override
  State<_CareerDialog> createState() => _CareerDialogState();
}

class _CareerDialogState extends State<_CareerDialog> {
  late TextEditingController _abrevCtrl, _nameCtrl;

  @override
  void initState() {
    super.initState();
    _abrevCtrl = TextEditingController(text: widget.career?.abbreviation ?? '');
    _nameCtrl = TextEditingController(text: widget.career?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.career != null;
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar Carrera' : 'Alta de Carrera', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _abrevCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDeco('Abreviatura (Ej: ICO)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: _inputDeco('Nombre completo de la carrera'),
            ),
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
      labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}