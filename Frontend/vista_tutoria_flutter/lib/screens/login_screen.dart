import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Complete todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'MFA_REQUIRED') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/mfa-verify',
            arguments: {'temp_token': data['temp_token']},
          );
        } else if (data['status'] == 'SUCCESS') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() => _errorMessage = 'Respuesta inesperada del servidor');
        }
      } else {
        setState(() => _errorMessage = 'Credenciales inválidas');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error de conexión');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithMfaOnly() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Ingrese el correo para continuar');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login/mfa-start'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/mfa-verify',
          arguments: {'temp_token': data['temp_token']},
        );
      } else {
        setState(() => _errorMessage = 'Usuario no encontrado o error de servidor');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error de conexión');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Image.asset(
              'assets/images/UAEMex.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(width: 200, height: 200),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Image.asset(
              'assets/images/EscudoFacultad.jpg',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(width: 200, height: 200),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Facultad de Ingeniería de la UAEMéx',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistema de Asignación de Tutores y Tutorados',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Coordinación de Tutoría Académica',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: 650,
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
                      children: [
                        const Text(
                          'Inicio de Sesión',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_errorMessage.isNotEmpty) ...[
                          Text(_errorMessage, style: const TextStyle(color: AppTheme.red)),
                          const SizedBox(height: 16),
                        ],
                        _isLoading
                            ? const CircularProgressIndicator()
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        _emailController.clear();
                                        _passwordController.clear();
                                        setState(() => _errorMessage = '');
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('BORRAR'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.textSecondary,
                                        minimumSize: const Size.fromHeight(55),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(55),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('INGRESAR', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      onPressed: _loginWithMfaOnly,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(55),
                                        side: const BorderSide(color: AppTheme.accent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('INICIAR SESIÓN CON MFA', 
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}