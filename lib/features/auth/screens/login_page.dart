import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showPasswordReset = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmailPreference();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmailPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe && email != null) {
      setState(() {
        _emailController.text = email;
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _handleRememberMe(bool? value) async {
    setState(() {
      _rememberMe = value ?? false;
    });
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('rememberMe');
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_recoveryEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, ingresa tu correo electrónico.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _recoveryEmailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Se ha enviado un enlace a tu correo.')));
      setState(() {
        _showPasswordReset = false;
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión con Google: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa tu correo y contraseña.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _handleRememberMe(_rememberMe);
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Ocurrió un error. Intenta de nuevo.';
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          errorMessage = 'Correo o contraseña incorrectos.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Iniciar Sesión',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 80),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Correo electrónico',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.color
                          ?.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.color
                          ?.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 4.0),
                horizontalTitleGap: 8.0,
                leading: Checkbox(
                  value: _rememberMe,
                  onChanged: _handleRememberMe,
                  visualDensity: VisualDensity.compact,
                ),
                title: Text(
                  "Recordarme al iniciar",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withOpacity(0.7),
                  ),
                ),
                onTap: () => _handleRememberMe(!_rememberMe),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text('Ingresar'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                    height: 18.0),
                label: const Text('Ingresar con Google'),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                  backgroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : null,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const RegisterPage()));
                },
                child: Text.rich(
                  TextSpan(
                    text: '¿No tienes cuenta? ',
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withOpacity(0.6)),
                    children: [
                      TextSpan(
                        text: 'Regístrate',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showPasswordReset = !_showPasswordReset;
                  });
                },
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              if (_showPasswordReset)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Column(
                    children: [
                      const Text(
                          'Ingrese su correo para recuperar la contraseña.'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _recoveryEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo de recuperación',
                          hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color
                                  ?.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendPasswordResetEmail,
                        child: const Text('Enviar correo'),
                      )
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
