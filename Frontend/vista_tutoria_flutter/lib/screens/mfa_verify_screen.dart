import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

class MfaVerifyScreen extends StatefulWidget {
  const MfaVerifyScreen({super.key});

  @override
  State<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<MfaVerifyScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String? _tempToken;
  String? _newPassword; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _tempToken = args['temp_token'];
      _newPassword = args['new_password']; 
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length < 6) {
      setState(() => _errorMessage = 'Ingrese el código completo');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/mfa/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_tempToken',
        },
        body: jsonEncode({
          'mfa_code': _codeController.text,
          if (_newPassword != null) 'new_password': _newPassword, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'SUCCESS') {
          if (!mounted) return;

          final String userName = data['user_name'] ?? 'Administrador';

          if (_newPassword != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contraseña actualizada con éxito')),
            );
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            Navigator.pushReplacementNamed(
              context, 
              '/home',
              arguments: {
                'first_login': false,
                'user_name': userName,
              }
            );
          }
        } else {
          setState(() => _errorMessage = 'Código incorrecto');
        }
      } else {
        setState(() {
          _errorMessage = 'Error en la verificación. Código HTTP: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de red: no se pudo conectar al servidor.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 48, color: AppTheme.accent),
              const SizedBox(height: 24),
              const Text(
                'Autenticación Multifactor',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingrese el código de 6 dígitos generado por Microsoft Authenticator para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Código MFA',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty) ...[
                Text(_errorMessage, style: const TextStyle(color: AppTheme.red)),
                const SizedBox(height: 16),
              ],
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyCode,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _newPassword != null ? 'CONFIRMAR CAMBIO' : 'VERIFICAR CÓDIGO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}