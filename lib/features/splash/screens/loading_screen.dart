import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import '../../../firebase_options.dart';
import '../../../main.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  Future<void> _initializeApp() async {
    setState(() {
      _hasError = false;
    });
    _animationController.repeat();

    if (await _checkInternetConnectivity() == false) {
      setState(() {
        _errorMessage =
        'No hay conexión a Internet.\nConéctate y vuelve a intentarlo.';
        _hasError = true;
        _animationController.stop();
      });
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      setState(() {
        _errorMessage =
        'Error al conectar con los servicios.\nInténtalo de nuevo más tarde.';
        _hasError = true;
        _animationController.stop();
      });
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
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
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.amber.shade200
                : null,
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 60.0),
          child: LinearProgressIndicator(),
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
    return Scaffold(
      body: Center(
        child: _hasError ? _buildErrorContent() : _buildLoadingIndicator(),
      ),
    );
  }
}
