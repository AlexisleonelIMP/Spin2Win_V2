import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/screens/loading_screen.dart';
import 'firebase_options.dart';
import 'core/providers/user_notifier.dart';
import 'core/providers/theme_notifier.dart'; // <-- ¡IMPORTACIÓN NECESARIA PARA THEMENOTIFIER!

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
        ChangeNotifierProvider(create: (_) => ThemeNotifier()), // <-- ¡AÑADIDO DE NUEVO EL PROVIDER PARA THEMNOTIFIER!
        ChangeNotifierProvider(create: (_) => UserNotifier()),
      ],
      child: const Spin2WinApp(),
    ),
  );
}

class Spin2WinApp extends StatelessWidget {
  const Spin2WinApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios de tema y reconstruye la app con el tema correspondiente.
    // final themeNotifier = Provider.of<ThemeNotifier>(context); <-- ¡OBTENER LA INSTANCIA AQUÍ!
    // Usamos Consumer para reconstruir solo la parte del tema si cambia.
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Spin2Win',
          theme: lightTheme, // Usas lightTheme directamente
          darkTheme: darkTheme, // Usas darkTheme directamente
          themeMode: themeNotifier.themeMode, // <-- ¡USAR EL THEMEMODE DEL NOTIFIER!
          navigatorObservers: <NavigatorObserver>[observer],
          home: const LoadingScreen(), // La primera pantalla que se muestra.
        );
      },
    );
  }
}