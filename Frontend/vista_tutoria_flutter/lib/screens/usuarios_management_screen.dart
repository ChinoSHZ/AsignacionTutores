import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

class UsuariosManagementScreen extends StatefulWidget {
  const UsuariosManagementScreen({super.key});

  @override
  State<UsuariosManagementScreen> createState() => _UsuariosManagementScreenState();
}

class _UsuariosManagementScreenState extends State<UsuariosManagementScreen> {
  // Controladores Creación
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // Controladores Actualización
  final _updateEmailController = TextEditingController();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmNewPassController = TextEditingController();

  bool _obsPass = true;
  bool _obsConfirmPass = true;
  bool _obsOldPass = true;
  bool _obsNewPass = true;
  bool _obsConfirmNewPass = true;

  String _qrData = '';
  bool _isLoading = false;

  void _mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _crearUsuario() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || 
        _passController.text.isEmpty || _confirmPassController.text.isEmpty) {
      _mostrarMensaje('Todos los campos son obligatorios');
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _mostrarMensaje('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/usuarios/crear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'email': _emailController.text,
          'password': _passController.text,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() => _qrData = data['qr_auth_url']);
      } else {
        _mostrarMensaje('Error al crear usuario');
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _actualizarPassword(bool requiereMFA) async {
    if (_updateEmailController.text.isEmpty || _newPassController.text.isEmpty || _confirmNewPassController.text.isEmpty) {
      _mostrarMensaje('Ingrese el correo y la nueva contraseña');
      return;
    }

    if (_newPassController.text != _confirmNewPassController.text) {
      _mostrarMensaje('La nueva contraseña no coincide');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (requiereMFA) {
        // 1. Obtener token temporal para el correo de la sección de actualización
        final startRes = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/login/mfa-start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': _updateEmailController.text}),
        );

        if (startRes.statusCode == 200) {
          final data = jsonDecode(startRes.body);
          if (!mounted) return;
          // 2. Ir a verificación con la intención de actualizar
          Navigator.pushNamed(context, '/mfa-verify', arguments: {
            'temp_token': data['temp_token'],
            'intent': 'password_update',
            'new_password': _newPassController.text
          });
        } else {
          _mostrarMensaje('Usuario no encontrado');
        }
      } else {
        // Actualización directa (Lógica existente con password vieja)
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/usuarios/update-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _updateEmailController.text,
            'old_password': _oldPassController.text,
            'new_password': _newPassController.text,
          }),
        );
        if (response.statusCode == 200) {
          _mostrarMensaje('Contraseña actualizada');
          _newPassController.clear();
          _confirmNewPassController.clear();
          _oldPassController.clear();
        } else {
          _mostrarMensaje('Credenciales incorrectas');
        }
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSectionCard(
                  title: 'Agregar Nuevo Usuario',
                  children: [
                    _buildField(_nameController, 'Nombre'),
                    _buildField(_emailController, 'Correo'),
                    _buildPasswordField(_passController, 'Contraseña', _obsPass, () => setState(() => _obsPass = !_obsPass)),
                    _buildPasswordField(_confirmPassController, 'Confirmación de Contraseña', _obsConfirmPass, () => setState(() => _obsConfirmPass = !_obsConfirmPass)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _nameController.clear();
                            _emailController.clear();
                            _passController.clear();
                            _confirmPassController.clear();
                          },
                          child: const Text('Borrar'),
                        ),
                        const SizedBox(width: 10),
                        _isLoading 
                          ? const CircularProgressIndicator() 
                          : ElevatedButton(onPressed: _crearUsuario, child: const Text('Generar QR')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildSectionCard(
                  title: 'Código de Activación MFA',
                  children: [
                    if (_qrData.isNotEmpty) ...[
                      QrImageView(data: _qrData, size: 200, backgroundColor: Colors.white),
                      const Text('Escanea con Microsoft Authenticator'),
                    ] else const Text('Complete el formulario para generar el acceso'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildSectionCard(
            title: 'Actualizar Contraseña de Usuario',
            children: [
              Row(
                children: [
                  Expanded(child: _buildField(_updateEmailController, 'Correo del usuario')),
                  const SizedBox(width: 15),
                  Expanded(child: _buildPasswordField(_oldPassController, 'Contraseña vieja', _obsOldPass, () => setState(() => _obsOldPass = !_obsOldPass))),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildPasswordField(_newPassController, 'Nueva contraseña', _obsNewPass, () => setState(() => _obsNewPass = !_obsNewPass))),
                  const SizedBox(width: 15),
                  Expanded(child: _buildPasswordField(_confirmNewPassController, 'Confirmar nueva contraseña', _obsConfirmNewPass, () => setState(() => _obsConfirmNewPass = !_obsConfirmNewPass))),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      _updateEmailController.clear();
                      _oldPassController.clear();
                      _newPassController.clear();
                      _confirmNewPassController.clear();
                    },
                    child: const Text('Borrar'),
                  ),
                  const SizedBox(width: 15),
                  _isLoading && !requiereMFA_Placeholder 
                    ? const CircularProgressIndicator()
                    : ElevatedButton(onPressed: () => _actualizarPassword(false), child: const Text('Actualizar')),
                  const SizedBox(width: 15),
                  OutlinedButton(onPressed: () => _actualizarPassword(true), child: const Text('Cambiar contraseña con MFA')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Se añade una pequeña bandera visual para evitar que el botón parpadee innecesariamente
  bool get requiereMFA_Placeholder => false; 

  Widget _buildField(TextEditingController ctrl, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: toggle),
      ),
    ),
  );

  Widget _buildSectionCard({required String title, required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppTheme.border.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Divider(height: 30),
      ...children
    ]),
  );
}