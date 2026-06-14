import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _semestreCtrl = TextEditingController();
  PlatformFile? _fileNuevos;
  PlatformFile? _fileHistorico;
  PlatformFile? _filePropuesta;
  bool _isLoading = false;

  Future<void> _pickFile(int type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null) {
      setState(() {
        if (type == 1) _fileNuevos = result.files.first;
        if (type == 2) _fileHistorico = result.files.first;
        if (type == 3) _filePropuesta = result.files.first;
      });
    }
  }

  Future<void> _uploadData() async {
    if (_semestreCtrl.text.isEmpty || _fileNuevos == null || _fileHistorico == null || _filePropuesta == null) {
      _mostrarSnackBar('Debe ingresar la clave del semestre y seleccionar los 3 archivos obligatorios', AppTheme.yellow);
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/api/carga-masiva'),
      );

      request.fields['semestre_clave'] = _semestreCtrl.text.trim().toUpperCase();

      await _appendFileToRequest(request, 'file_nuevos', _fileNuevos!);
      await _appendFileToRequest(request, 'file_historico', _fileHistorico!);
      await _appendFileToRequest(request, 'file_propuesta', _filePropuesta!);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _mostrarSnackBar('Procesamiento masivo completado con éxito', AppTheme.green);
        setState(() {
          _semestreCtrl.clear();
          _fileNuevos = null;
          _fileHistorico = null;
          _filePropuesta = null;
        });
      } else {
        _mostrarSnackBar('Error en el procesamiento de datos. Revisa los logs en backend.', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión con el servidor', AppTheme.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _appendFileToRequest(http.MultipartRequest request, String field, PlatformFile file) async {
    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(field, file.bytes!, filename: file.name));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(field, file.path!));
    }
  }

  Future<void> _downloadTemplate(String fileName) async {
    final url = Uri.parse('http://127.0.0.1:8000/templates/$fileName');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarSnackBar('No se pudo iniciar la descarga de $fileName', AppTheme.red);
    }
  }

  void _mostrarSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Carga de Datos',
      subtitle: 'Sincronización masiva de asignaciones académicas mediante archivos Excel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.accentLight),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Instrucciones de Carga', style: TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Ingresa la clave del semestre objetivo (Ej. 2024A o 2024B).\n'
                        '2. Selecciona los tres archivos requeridos en formato Excel o CSV.\n'
                        '3. El sistema integrará a los nuevos ingresos, respetará a los reingresos y ajustará grupos según la propuesta.\n'
                        '4. El algoritmo balanceará automáticamente la carga restante entre tutores activos.',
                        style: TextStyle(color: AppTheme.textPrimary, height: 1.5),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              const Text('Semestre Objetivo:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _semestreCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Ej. 2024A',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.normal, letterSpacing: 0),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _UploadCard(
                  title: 'Alumnos de Nuevo Ingreso',
                  description: 'Alumnos que ingresan por primera vez al sistema.',
                  file: _fileNuevos,
                  onSelect: () => _pickFile(1),
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF3498DB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _UploadCard(
                  title: 'Registro Histórico',
                  description: 'Base de datos del semestre anterior para reingresos.',
                  file: _fileHistorico,
                  onSelect: () => _pickFile(2),
                  icon: Icons.history_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _UploadCard(
                  title: 'Propuesta de Semestre',
                  description: 'Movimientos forzados autorizados por la coordinación.',
                  file: _filePropuesta,
                  onSelect: () => _pickFile(3),
                  icon: Icons.edit_document,
                  color: AppTheme.yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Align(
            alignment: Alignment.centerRight,
            child: _isLoading
                ? const CircularProgressIndicator(color: AppTheme.accent)
                : ElevatedButton.icon(
                    onPressed: _uploadData,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: const Text('Iniciar Procesamiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
          
          const SizedBox(height: 40),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 24),
          const Text('Plantillas de Formato', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Descarga los archivos base para la estructuración y registro de información antes de la carga.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _TemplateButton(title: 'Catálogo de Profesores', fileName: 'CatalogoProfesores.xlsx', onTap: () => _downloadTemplate('CatalogoProfesores.xlsx')),
              _TemplateButton(title: 'Registro Histórico', fileName: 'RegistroHistorico.xlsx', onTap: () => _downloadTemplate('RegistroHistorico.xlsx')),
              _TemplateButton(title: 'Nuevo Ingreso', fileName: 'NuevoIngreso.xlsx', onTap: () => _downloadTemplate('NuevoIngreso.xlsx')),
              _TemplateButton(title: 'Propuesta Semestre', fileName: 'PropuestaSemestre.xlsx', onTap: () => _downloadTemplate('PropuestaSemestre.xlsx')),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String description;
  final PlatformFile? file;
  final VoidCallback onSelect;
  final IconData icon;
  final Color color;

  const _UploadCard({
    required this.title,
    required this.description,
    required this.file,
    required this.onSelect,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFile = file != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasFile ? color.withOpacity(0.5) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hasFile ? color.withOpacity(0.3) : AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  hasFile ? Icons.check_circle_rounded : Icons.insert_drive_file_outlined,
                  color: hasFile ? color : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasFile ? file!.name : 'Sin archivo',
                    style: TextStyle(
                      color: hasFile ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSelect,
              icon: Icon(hasFile ? Icons.edit_rounded : Icons.upload_file_rounded, size: 18),
              label: Text(hasFile ? 'Cambiar Archivo' : 'Seleccionar', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: hasFile ? color : AppTheme.textPrimary,
                side: BorderSide(color: hasFile ? color.withOpacity(0.5) : AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateButton extends StatelessWidget {
  final String title;
  final String fileName;
  final VoidCallback onTap;

  const _TemplateButton({required this.title, required this.fileName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            const Icon(Icons.download_rounded, color: AppTheme.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(fileName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}