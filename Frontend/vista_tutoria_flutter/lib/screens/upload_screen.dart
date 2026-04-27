import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // Variables para almacenar los archivos físicos seleccionados
  PlatformFile? _fileNuevos;
  PlatformFile? _fileHistorico;
  PlatformFile? _filePropuesta;
  
  bool _isUploading = false;

  // ── NUEVO: Controlador para el semestre ──
  final TextEditingController _semestreCtrl = TextEditingController();

  // Función para abrir el selector de archivos
  Future<void> _pickFile(int fileType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null) {
      setState(() {
        if (fileType == 1) _fileNuevos = result.files.first;
        if (fileType == 2) _fileHistorico = result.files.first;
        if (fileType == 3) _filePropuesta = result.files.first;
      });
    }
  }

  // Función HTTP para enviar los archivos a Laravel
  Future<void> _uploadData() async {
    // 1. Validación: Asegurarnos de que los 3 archivos estén seleccionados
    if (_fileNuevos == null || _fileHistorico == null || _filePropuesta == null) {
      _showSnackBar('Por favor selecciona los 3 archivos antes de procesar.', AppTheme.yellow);
      return;
    }

    // ── NUEVO: Validación de semestre ──
    if (_semestreCtrl.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa la clave del semestre (Ej: 2024A).', AppTheme.yellow);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 2. Preparar la petición Multipart
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('http://127.0.0.1:8000/api/carga-masiva')
      );
      request.headers.addAll({'Accept': 'application/json'}); // Para ver el error exacto si falla

      // ── NUEVO: Enviar la clave del semestre al backend ──
      request.fields['semestre_clave'] = _semestreCtrl.text.trim().toUpperCase();

      // Helper para adjuntar archivos (soporta Web y Desktop/Mobile)
      Future<void> addFileToRequest(String fieldName, PlatformFile file) async {
        if (file.bytes != null) {
          // Para Flutter Web
          request.files.add(http.MultipartFile.fromBytes(fieldName, file.bytes!, filename: file.name));
        } else if (file.path != null) {
          // Para Desktop/Mobile
          request.files.add(await http.MultipartFile.fromPath(fieldName, file.path!));
        }
      }

      // 3. Adjuntar los archivos con los nombres que espera el controlador de Laravel
      await addFileToRequest('file_nuevos', _fileNuevos!);
      await addFileToRequest('file_historico', _fileHistorico!);
      await addFileToRequest('file_propuesta', _filePropuesta!);

      // 4. Enviar y esperar respuesta
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showSnackBar('Carga exitosa. La base de datos ha sido actualizada.', AppTheme.green);
        // Opcional: Limpiar los archivos después del éxito
        setState(() {
          _fileNuevos = null;
          _fileHistorico = null;
          _filePropuesta = null;
          _semestreCtrl.clear();
        });
      } else {
        var body = jsonDecode(response.body);
        String errorMsg = body['error'] ?? body['message'] ?? 'Error desconocido del servidor';
        _showSnackBar('Falló: $errorMsg', AppTheme.red);
      }
    } catch (e) {
      _showSnackBar('Error de conexión con el servidor: $e', AppTheme.red);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  void dispose() {
    _semestreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Carga de Datos',
      subtitle: 'Importar archivos Excel para actualizar la base de datos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Para que el botón ocupe el ancho
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FileDropZone(
                label: 'Nuevos Ingresos',
                subtitle: _fileNuevos?.name ?? 'Seleccionar CSV/Excel',
                icon: Icons.person_add_rounded,
                color: AppTheme.green,
                isLoaded: _fileNuevos != null,
                onLoad: () => _pickFile(1),
              )),
              const SizedBox(width: 16),
              Expanded(child: _FileDropZone(
                label: 'Registro Histórico',
                subtitle: _fileHistorico?.name ?? 'Seleccionar CSV/Excel',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF3498DB),
                isLoaded: _fileHistorico != null,
                onLoad: () => _pickFile(2),
              )),
              const SizedBox(width: 16),
              Expanded(child: _FileDropZone(
                label: 'Propuesta Semestre',
                subtitle: _filePropuesta?.name ?? 'Seleccionar CSV/Excel',
                icon: Icons.swap_horiz_rounded,
                color: AppTheme.yellow,
                isLoaded: _filePropuesta != null,
                onLoad: () => _pickFile(3),
              )),
            ],
          ),
          
          const SizedBox(height: 32),

          // ── NUEVO: CAMPO DE SEMESTRE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _semestreCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Clave del Semestre (Ej. 2024A)',
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.date_range_rounded, color: AppTheme.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botón de Envío
          _isUploading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : ElevatedButton.icon(
                onPressed: _uploadData,
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: const Text('PROCESAR ARCHIVOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

          const SizedBox(height: 32),
          
          const Text('Reglas del sistema:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            const _RuleChip(Icons.priority_high_rounded, 'Prioridad 1: Nuevos Ingresos', AppTheme.green),
            const _RuleChip(Icons.history_rounded, 'Prioridad 2: Histórico', Color(0xFF3498DB)),
            const _RuleChip(Icons.edit_document, 'Prioridad 3: Sobreescrituras', AppTheme.yellow),
          ]),
        ],
      ),
    );
  }
}

// El _FileDropZone (simulado aquí para que coincida con tu diseño anterior)
class _FileDropZone extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final bool isLoaded;
  final VoidCallback onLoad;

  const _FileDropZone({
    required this.label, required this.subtitle, required this.icon,
    required this.color, required this.isLoaded, required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLoad,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLoaded ? color.withValues(alpha: 0.1) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isLoaded ? color : AppTheme.border, width: 2),
        ),
        child: Column(
          children: [
            Icon(isLoaded ? Icons.check_circle_rounded : icon, color: isLoaded ? color : AppTheme.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RuleChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}