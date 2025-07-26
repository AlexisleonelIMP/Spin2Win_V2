import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/screens/loading_screen.dart';
import 'firebase_options.dart';
import 'core/providers/user_notifier.dart';

void main() async {
  // Asegura que los bindings de Flutter estén inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Fija la orientación de la pantalla a vertical.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Ejecuta la aplicación.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => UserNotifier()),
      ],
      child: const Spin2WinApp(),
    ),
  );
}

class Spin2WinApp extends StatelessWidget {
  const Spin2WinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios de tema y reconstruye la app con el tema correspondiente.
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spin2Win',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const LoadingScreen(), // La primera pantalla que se muestra.
    );
  }
}