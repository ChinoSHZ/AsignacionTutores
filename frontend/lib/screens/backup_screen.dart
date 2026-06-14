import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; 
import '../theme/app_theme.dart';
import '../widgets/screen_wrapper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _fileNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _descargarRespaldo() async {
    final nombre = _fileNameController.text.trim();
    if (nombre.isEmpty) {
      _mostrarSnackBar('Por favor, ingresa un nombre para el archivo', AppTheme.yellow);
      return;
    }

    final safeName = nombre.endsWith('.sqlite') ? nombre : '$nombre.sqlite';
    final url = Uri.parse('http://127.0.0.1:8000/api/backup/export?filename=$safeName');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _fileNameController.clear();
        _mostrarSnackBar('Descarga iniciada exitosamente', AppTheme.green);
      } else {
        _mostrarSnackBar('No se pudo iniciar la descarga', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error al intentar ejecutar la descarga', AppTheme.red);
    }
  }

  Future<void> _seleccionarArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any, 
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      if (!file.name.toLowerCase().endsWith('.sqlite')) {
        _mostrarErrorExtension();
      } else {
        _mostrarConfirmacion(file);
      }
    }
  }

  void _mostrarErrorExtension() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.red),
            SizedBox(width: 10),
            Text('Error de Archivo', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'El archivo seleccionado no tiene un formato válido. Por favor, selecciona un archivo con extensión .sqlite.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _mostrarConfirmacion(PlatformFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.yellow),
            SizedBox(width: 10),
            Text('Confirmación', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          '¿Estás seguro de querer reemplazar la base de datos con ${file.name}?\n\nAdvertencia: Esto sobrescribirá el contenido actual del sistema.',
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
              _subirArchivo(file);
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _subirArchivo(PlatformFile file) async {
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/api/backup/import'),
      );

      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('backup_file', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('backup_file', file.path!));
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        _mostrarSnackBar('Base de datos restaurada exitosamente', AppTheme.green);
      } else {
        _mostrarSnackBar('Error al restaurar la base de datos', AppTheme.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión con el servidor', AppTheme.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      title: 'Respaldo de Datos',
      subtitle: 'Exporta o restaura la base de datos del sistema (SQLite)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading) const LinearProgressIndicator(color: AppTheme.accent),
          const SizedBox(height: 20),
          
          _buildSectionCard(
            title: 'Generar Respaldo (Exportar)',
            icon: Icons.download_rounded,
            color: AppTheme.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descarga una copia local del archivo .sqlite con toda la información actual.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fileNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del archivo (ej. respaldo_abril)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                      onPressed: _descargarRespaldo,
                      icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
                      label: const Text('Descargar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          _buildSectionCard(
            title: 'Restaurar Sistema (Importar)',
            icon: Icons.upload_rounded,
            color: AppTheme.yellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sube un archivo .sqlite previamente descargado para reemplazar los datos actuales del sistema.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    side: const BorderSide(color: AppTheme.yellow),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  ),
                  onPressed: _seleccionarArchivo,
                  icon: const Icon(Icons.file_upload_outlined, color: AppTheme.yellow),
                  label: const Text('Ingresar respaldo', style: TextStyle(color: AppTheme.yellow)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}