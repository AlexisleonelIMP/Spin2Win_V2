import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // <-- ¡NUEVA IMPORTACIÓN!

import '../../../firebase_options.dart';
import '../../auth/screens/auth_wrapper.dart';
import '../../../core/theme/app_theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasError = false;
  String _errorMessage = '';
  String _loadingMessage = 'Preparando tu experiencia...';
  String _appVersion = '';

  final List<String> _loadingMessages = [
    'Verificando conexión a Internet...',
    'Conectando con nuestros servicios...',
    'Cargando configuraciones...',
    'Verificando versión de la app...',
    'Solicitando permisos necesarios...',
    'Todo listo para Spin2Win...',
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startLoadingMessages() {
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
        _loadingMessage = _loadingMessages[_currentMessageIndex];
      });
    });
  }

  Future<bool> _checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  Future<bool> _checkAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      setState(() {
        _appVersion = 'v$currentVersion';
      });

      final DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!configDoc.exists) {
        print('Documento de configuración de versión no encontrado en Firestore.');
        return true;
      }

      final String minimumVersion = configDoc.get('minimum_version_android') as String;

      bool needsUpdate = false;
      final List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
      final List<int> minimumParts = minimumVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < minimumParts.length; i++) {
        if (i >= currentParts.length) {
          needsUpdate = true;
          break;
        }
        if (currentParts[i] < minimumParts[i]) {
          needsUpdate = true;
          break;
        } else if (currentParts[i] > minimumParts[i]) {
          needsUpdate = false;
          break;
        }
      }

      if (needsUpdate) {
        _messageTimer?.cancel();
        setState(() {
          _errorMessage =
          'Tu aplicación está desactualizada.\nPor favor, actualiza a la versión $minimumVersion o superior.';
          _hasError = true;
          _animationController.stop();
        });
        _showForceUpdateDialog();
        return false;
      }
      return true;
    } catch (e) {
      print('Error al verificar la versión de la app: $e');
      return true;
    }
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Actualización Requerida'),
          content: const Text(
              'Una nueva versión de la aplicación está disponible y es requerida. Por favor, actualiza desde la Play Store.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Actualizar Ahora'),
              onPressed: () {
                launchUrl(Uri.parse('market://details?id=com.example.spin2win_v2'), mode: LaunchMode.externalApplication);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkAndRequestPermissions() async {
    PermissionStatus notificationStatus = await Permission.notification.status;

    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      notificationStatus = await Permission.notification.request();
    }

    if (notificationStatus.isGranted) {
      print('Permiso de notificaciones concedido.');
      return true;
    } else {
      _messageTimer?.cancel();
      setState(() {
        _errorMessage =
        'Permiso de notificaciones denegado.\nAlgunas funciones pueden no estar disponibles.';
        _hasError = true;
        _animationController.stop();
      });
      return false;
    }
  }

  Future<void> _initializeApp() async {
    setState(() {
      _hasError = false;
      _currentMessageIndex = 0;
      _loadingMessage = _loadingMessages[_currentMessageIndex];
    });
    _animationController.repeat();
    _startLoadingMessages();

    bool hasInternet = await _checkInternetConnectivity();
    if (!hasInternet) {
      _messageTimer?.cancel();
      setState(() {
        _errorMessage = 'No hay conexión a Internet.\nConéctate y vuelve a intentarlo.';
        _hasError = true;
        _animationController.stop();
      });
      return;
    }

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        _messageTimer?.cancel();
        setState(() {
          _errorMessage = 'Error al conectar con los servicios.\nInténtalo de nuevo más tarde.';
          _hasError = true;
          _animationController.stop();
        });
        return;
      }
    }

    bool isAppUpdated = await _checkAppVersion();
    if (!isAppUpdated) {
      return;
    }

    bool hasRequiredPermissions = await _checkAndRequestPermissions();
    if (!hasRequiredPermissions) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      _messageTimer?.cancel();
      // Antes de navegar, aplicamos un fade-out suave.
      await _animationController.forward(from: 0.0).then((_) => _animationController.stop());
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const AuthWrapper(),
          ),
        ),
      );
    }
  }

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _animationController,
          child: Image.asset(
            'assets/rueda-de-la-fortuna.png',
            width: 100,
            height: 100,
            color: Colors.amber.shade200,
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 60.0),
          child: LinearProgressIndicator(
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _loadingMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.amber.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/rueda-de-la-fortuna.png',
          width: 100,
          height: 100,
          color: Colors.grey,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
          onPressed: _initializeApp,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definir el estilo de la barra de estado y navegación aquí
    // Se usa SystemChrome.setSystemUIOverlayStyle para que los íconos de la barra de estado y navegación sean claros
    // sobre el fondo oscuro de la pantalla de carga.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light, // Para iconos de la barra de estado (hora, batería, Wi-Fi)
      statusBarBrightness: Brightness.dark,      // Para iOS (texto de la barra de estado en modo oscuro)
      systemNavigationBarIconBrightness: Brightness.light, // Para iconos de la barra de navegación (atrás, inicio, recientes)
      systemNavigationBarColor: darkTheme.scaffoldBackgroundColor, // Para el color de fondo de la barra de navegación
    ));

    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: darkTheme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Center(
              child: _hasError ? _buildErrorContent() : _buildLoadingIndicator(),
            ),
            if (_appVersion.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    color: Colors.amber.shade100,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}