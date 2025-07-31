import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/user_notifier.dart';
import '../../../core/theme/app_theme.dart'; // Necesario para lightTheme/darkTheme
import '../views/exchange_view.dart';
import '../views/history_view.dart';
import '../views/home_view.dart';
import '../../../core/providers/theme_notifier.dart'; // <-- ¡IMPORTACIÓN NECESARIA!

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialUserData();
  }

  Future<void> _fetchInitialUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userCoins = (userDoc.data()?['coins'] ?? 0) as int;
        if (mounted) {
          Provider.of<UserNotifier>(context, listen: false).setInitialCoins(userCoins);
        }
      }
    } catch (e) {
      print("Error fetching initial user data: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text('¿Salir de Spin2Win?'),
          content: const Text('Se cerrará la aplicación.'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Sí, Salir'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    return shouldPop ?? false;
  }

  Future<void> _launchEmailSupport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    const String emailTo = 'soporte.spin2win@gmail.com';
    final String subject = 'Soporte Spin2Win - Usuario: ${user.email}';
    final String body = '''
¡Hola! Necesito ayuda con lo siguiente:

[Describe aquí tu problema o consulta]

---
*Por favor, no borres la siguiente información:*
Usuario Email: ${user.email}
Usuario UID: ${user.uid}
''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: emailTo,
      query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Could not launch $emailLaunchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo abrir la aplicación de correo.')),
        );
      }
    }
  }

  // Ahora ThemeNotifier está disponible a través de Provider
  void _showProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false); // No es necesario pasar como parámetro, se obtiene en el builder del Consumer

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text('Perfil y Opciones'),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesión iniciada como:',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  Text(
                    user?.email ?? 'No disponible',
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            // Reintroducimos el SwitchListTile y su Consumer para el ThemeNotifier
            Consumer<ThemeNotifier>( // <--- ¡BLOQUE REINTRODUCIDO!
              builder: (context, notifier, child) {
                return SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  value: notifier.themeMode == ThemeMode.dark,
                  onChanged: (bool value) {
                    notifier.toggleTheme(); // Llamada al método del notifier
                  },
                );
              },
            ),
            const Divider(), // Asegúrate de que este divisor esté donde lo quieras

            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _launchEmailSupport();
              },
              child: const Row(
                children: [
                  Icon(Icons.support_agent, size: 22),
                  SizedBox(width: 16),
                  Text('Soporte Técnico'),
                ],
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
              },
              child: const Center(
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userNotifier = Provider.of<UserNotifier>(context);
    // Ya no necesitamos esta línea aquí si el themeNotifier se obtiene en el Consumer del diálogo
    // final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> widgetOptions = [
      const HomePage(),
      const ExchangePage(),
      const HistoryPage(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/rueda-de-la-fortuna.png',
                width: 32,
                height: 32,
                color: isDarkMode ? Colors.amber.shade200 : null,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Spin2Win',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/monedas.png',
                    width: 24,
                    height: 24,
                    color: isDarkMode ? Colors.white : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${userNotifier.coins}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 22,
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () {
                    // La llamada al diálogo ahora es más simple
                    _showProfileDialog(context);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: widgetOptions.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Theme.of(context).colorScheme.secondary,
          unselectedItemColor:
          isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/rueda-de-la-fortuna.png',
                width: 24,
                height: 24,
                color: _selectedIndex == 0
                    ? Theme.of(context).colorScheme.secondary
                    : (isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade700),
              ),
              label: 'Jugar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz),
              label: 'Canjear',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Historial',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}