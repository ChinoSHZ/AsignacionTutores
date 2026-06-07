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

  List<dynamic> _usuarios = [];
  bool _isLoadingUsuarios = true;
  
  // Set para controlar qué correos están visibles
  final Set<dynamic> _revealedEmails = {};

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _isLoadingUsuarios = true);
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/usuarios'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _usuarios = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _mostrarMensaje('Error al cargar la lista de usuarios');
    } finally {
      setState(() => _isLoadingUsuarios = false);
    }
  }

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
        _fetchUsuarios();
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
        final startRes = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/login/mfa-start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': _updateEmailController.text}),
        );

        if (startRes.statusCode == 200) {
          final data = jsonDecode(startRes.body);
          if (!mounted) return;
          Navigator.pushNamed(context, '/mfa-verify', arguments: {
            'temp_token': data['temp_token'],
            'intent': 'password_update',
            'new_password': _newPassController.text
          });
        } else {
          _mostrarMensaje('Usuario no encontrado');
        }
      } else {
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

  Future<void> _ejecutarBorrado(dynamic id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/api/usuarios/$id'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        _mostrarMensaje('Usuario eliminado con éxito');
        _fetchUsuarios();
      } else {
        _mostrarMensaje('Error al eliminar usuario');
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _solicitarAutorizacionBorrado(Map<String, dynamic> usuarioTarget) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AuthActionDialog(
        usuario: usuarioTarget,
        title: 'Autorización Requerida',
        description: 'Para eliminar al usuario ${usuarioTarget['name']}, confirme su identidad.',
        buttonLabel: 'Eliminar',
        buttonColor: AppTheme.red,
        onAuthorized: () => _ejecutarBorrado(usuarioTarget['id']),
      ),
    );
  }

  void _solicitarAutorizacionVerCorreo(Map<String, dynamic> usuarioTarget) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AuthActionDialog(
        usuario: usuarioTarget,
        title: 'Ver Correo Electrónico',
        description: 'Para visualizar el correo de ${usuarioTarget['name']}, confirme su identidad.',
        buttonLabel: 'Autorizar',
        buttonColor: AppTheme.accent,
        onAuthorized: () {
          setState(() {
            _revealedEmails.add(usuarioTarget['id']);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 30),
          _buildSectionCard(
            title: 'Usuarios Registrados',
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(children: [
                  Expanded(flex: 1, child: Text('ID', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Nombre', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Correo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('MFA Activo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Acciones', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              if (_isLoadingUsuarios)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.accent)))
              else if (_usuarios.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay usuarios registrados', style: TextStyle(color: AppTheme.textSecondary))))
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
                    itemCount: _usuarios.length,
                    separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 0),
                    itemBuilder: (context, index) {
                      final u = _usuarios[index];
                      final bool mfaEnabled = u['mfa_enabled'] == 1 || u['mfa_enabled'] == true;
                      final bool isRevealed = _revealedEmails.contains(u['id']);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text(u['id'].toString(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                            Expanded(flex: 3, child: Text(u['name'].toString(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                            Expanded(
                              flex: 3, 
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isRevealed ? Icons.visibility_off : Icons.visibility,
                                      color: AppTheme.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      if (isRevealed) {
                                        setState(() {
                                          _revealedEmails.remove(u['id']);
                                        });
                                      } else {
                                        _solicitarAutorizacionVerCorreo(u);
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isRevealed ? u['email'].toString() : '******', 
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: mfaEnabled ? AppTheme.green.withValues(alpha: 0.1) : AppTheme.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(mfaEnabled ? 'Sí' : 'No', style: TextStyle(color: mfaEnabled ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 20),
                                    tooltip: 'Eliminar Usuario',
                                    onPressed: () => _solicitarAutorizacionBorrado(u),
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
        ],
      ),
    );
  }

  bool get requiereMFA_Placeholder => false; 

  Widget _buildField(TextEditingController ctrl, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(controller: ctrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary), filled: true, fillColor: AppTheme.bg, border: const OutlineInputBorder(borderSide: BorderSide.none))),
  );

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.bg,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary), onPressed: toggle),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const Divider(height: 30, color: AppTheme.border),
        ...children
      ]
    ),
  );
}

class _AuthActionDialog extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String title;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onAuthorized;

  const _AuthActionDialog({
    required this.usuario, 
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onAuthorized
  });

  @override
  State<_AuthActionDialog> createState() => _AuthActionDialogState();
}

class _AuthActionDialogState extends State<_AuthActionDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _mfaCtrl = TextEditingController();
  
  bool _isMfaStep = false;
  String? _tempToken;
  bool _isLoading = false;
  String _errorMsg = '';
  bool _obsPass = true;

  Future<void> _authWithPassword() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Ingrese correo y contraseña');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text, 'password': _passCtrl.text}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'SUCCESS') {
        Navigator.pop(context);
        widget.onAuthorized();
      } else {
        setState(() => _errorMsg = 'Credenciales inválidas o requiere MFA');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startMfa() async {
    if (_emailCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Ingrese su correo para iniciar MFA');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login/mfa-start'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tempToken = data['temp_token'];
          _isMfaStep = true;
        });
      } else {
        setState(() => _errorMsg = 'Usuario no encontrado o sin MFA');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyMfaAndAuthorize() async {
    if (_mfaCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Ingrese código válido');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/mfa/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_tempToken'
        },
        body: jsonEncode({'mfa_code': _mfaCtrl.text}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'SUCCESS') {
        Navigator.pop(context);
        widget.onAuthorized();
      } else {
        setState(() => _errorMsg = 'Código MFA inválido');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            if (!_isMfaStep) ...[
              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Su Correo Electrónico', filled: true, fillColor: AppTheme.bg, border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: _obsPass,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Su Contraseña',
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: Icon(_obsPass ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary), onPressed: () => setState(() => _obsPass = !_obsPass)),
                ),
              ),
            ] else ...[
              TextField(
                controller: _mfaCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(labelText: 'Código MFA', filled: true, fillColor: AppTheme.bg, border: OutlineInputBorder(borderSide: BorderSide.none), counterText: ''),
              ),
            ],
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errorMsg, style: const TextStyle(color: AppTheme.red, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
        if (!_isMfaStep) ...[
          OutlinedButton(onPressed: _isLoading ? null : _startMfa, style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.accent)), child: const Text('Usar MFA', style: TextStyle(color: AppTheme.accent))),
          ElevatedButton(onPressed: _isLoading ? null : _authWithPassword, style: ElevatedButton.styleFrom(backgroundColor: widget.buttonColor), child: Text(widget.buttonLabel, style: const TextStyle(color: Colors.white))),
        ] else ...[
          ElevatedButton(onPressed: _isLoading ? null : _verifyMfaAndAuthorize, style: ElevatedButton.styleFrom(backgroundColor: widget.buttonColor), child: const Text('Verificar y Continuar', style: TextStyle(color: Colors.white))),
        ],
      ],
    );
  }
}