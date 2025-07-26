import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/user_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../views/exchange_view.dart';
import '../views/history_view.dart';
import '../views/home_view.dart';

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
    // Obtenemos los datos del usuario UNA SOLA VEZ al cargar la página
    _fetchInitialUserData();
  }

  Future<void> _fetchInitialUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userCoins = (userDoc.data()?['coins'] ?? 0) as int;
        // Usamos el Provider para guardar las monedas iniciales en el estado local
        if (mounted) {
          Provider.of<UserNotifier>(context, listen: false).setInitialCoins(userCoins);
        }
      }
    } catch (e) {
      // Manejar error si no se pueden cargar los datos iniciales
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
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
    // ... (este método no cambia) ...
  }

  void _showProfileDialog(BuildContext context) {
    // ... (este método no cambia) ...
  }

  @override
  Widget build(BuildContext context) {
    // AHORA LEEMOS LAS MONEDAS DESDE NUESTRO NOTIFIER LOCAL
    final userCoins = Provider.of<UserNotifier>(context).coins;
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
                    '$userCoins', // Este valor ahora viene del Provider
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