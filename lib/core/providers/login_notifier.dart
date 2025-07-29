import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginNotifier extends ChangeNotifier {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showPasswordReset = false;

  // Getters
  TextEditingController get emailController => _emailController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get recoveryEmailController => _recoveryEmailController;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  bool get showPasswordReset => _showPasswordReset;

  LoginNotifier() {
    _loadUserEmailPreference();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    super.dispose();
  }

  void togglePasswordReset() {
    _showPasswordReset = !_showPasswordReset;
    notifyListeners();
  }

  Future<void> _loadUserEmailPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe && email != null) {
      _emailController.text = email;
      _rememberMe = rememberMe;
      notifyListeners();
    }
  }

  Future<void> handleRememberMe(bool? value) async {
    _rememberMe = value ?? false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('rememberMe');
    }
  }

  Future<String> sendPasswordResetEmail() async {
    if (_recoveryEmailController.text.trim().isEmpty) {
      return 'Por favor, ingresa tu correo electrónico.';
    }
    _isLoading = true;
    notifyListeners();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _recoveryEmailController.text.trim());
      togglePasswordReset(); // Oculta el campo después de enviar
      return 'Se ha enviado un enlace a tu correo.';
    } on FirebaseAuthException catch (e) {
      return 'Error: ${e.message}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null; // El usuario canceló
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      return null; // Éxito
    } catch (e) {
      return 'Error al iniciar sesión con Google: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      return 'Por favor, completa tu correo y contraseña.';
    }
    await handleRememberMe(_rememberMe);
    _isLoading = true;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Correo o contraseña incorrectos.';
      }
      return 'Ocurrió un error. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}