import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Importación para el soporte por email
import 'dart:async';
import 'dart:math';
import 'dart:ui';

// Asegúrate de tener tu archivo firebase_options.dart
import 'firebase_options.dart';

// =======================================================================
// ===== DEFINICIÓN DE TEMAS (EXTRAÍDO PARA REUTILIZAR) =====
// =======================================================================
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.amber,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: const Color(0xFFFDFBF3),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
    bodyMedium: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.amber,
    brightness: Brightness.light,
  ).copyWith(
    secondary: const Color(0xFFF9693B),
    surface: const Color(0xFFFFFFFF),
    onSurface: Colors.black87,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFF8E1),
    elevation: 1,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      color: Colors.black87,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.black87),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: UnderlineInputBorder(),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.amber),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFF9693B),
    ),
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // La inicialización de Firebase ahora se hará en la pantalla de carga
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const Spin2WinApp(),
    ),
  );
}

// --- CONTROLADOR DEL TEMA (MODO OSCURO/CLARO) ---
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

// --- Modelo para los Premios ---
class PrizeItem {
  final String label;
  final int value;
  final Color color;

  PrizeItem({required this.label, required this.value, required this.color});
}

// =======================================================================
// ===== 1. WIDGET PRINCIPAL DE LA APP Y TEMA =====
// =======================================================================
class Spin2WinApp extends StatelessWidget {
  const Spin2WinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Spin2Win',
          theme: lightTheme,
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.amber,
            fontFamily: 'Poppins',
            scaffoldBackgroundColor: const Color(0xFF121212),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
              bodyMedium:
                  TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            ),
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.amber,
              brightness: Brightness.dark,
            ).copyWith(
              secondary: const Color(0xFFF9693B),
              surface: const Color(0xFF1E1E1E),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: const UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber.shade400),
              ),
              labelStyle: TextStyle(color: Colors.grey.shade400),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade400,
              ),
            ),
          ),
          themeMode: themeNotifier.themeMode,
          home: const LoadingScreen(),
        );
      },
    );
  }
}

// =======================================================================
// ===== PANTALLA DE CARGA CON VERIFICACIÓN DE INTERNET =====
// =======================================================================
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

// =======================================================================
// ===== MANEJO DE AUTENTICACIÓN (LOGIN/LOGOUT) =====
// =======================================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainPage();
        }
        return const LoginPage();
      },
    );
  }
}

// =======================================================================
// ===== PÁGINA PRINCIPAL (CONTENEDOR DE JUEGO, CANJE, HISTORIAL) =====
// =======================================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

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
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, Salir'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
    return shouldPop ?? false;
  }

  // Función para abrir el cliente de email para soporte
  Future<void> _launchEmailSupport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String emailTo = 'soporte.spin2win@gmail.com';
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

  void _showProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    user?.email ?? 'No disponible',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  value: themeNotifier.themeMode == ThemeMode.dark,
                  onChanged: (bool value) {
                    themeNotifier.toggleTheme();
                    setDialogState(() {});
                  },
                );
              },
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Cierra el diálogo antes de abrir el email
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
                Navigator.of(context).pop();
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> widgetOptions = [
      const HomePage(),
      const ExchangePage(),
      const HistoryPage(),
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder:
          (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Spin2Win'), actions: const [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.0)),
              ),
            ]),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        }

        final userCoins =
            (snapshot.data?.data() as Map<String, dynamic>?)?['coins'] ?? 0;

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                        '$userCoins',
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
      },
    );
  }
}

// =======================================================================
// ===== 4. PÁGINA DE JUEGO (RULETA) =====
// =======================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<FortuneWheelState> _wheelKey = GlobalKey();
  bool _isSpinning = false;

  final List<PrizeItem> _prizes = [
    PrizeItem(label: '10 Monedas', value: 10, color: Colors.blue.shade400),
    PrizeItem(label: '20 Monedas', value: 20, color: Colors.green.shade400),
    PrizeItem(label: '30 Monedas', value: 30, color: Colors.orange.shade400),
    PrizeItem(label: '40 Monedas', value: 40, color: Colors.purple.shade400),
    PrizeItem(label: '50 Monedas', value: 50, color: Colors.red.shade400),
    PrizeItem(label: '60 Monedas', value: 60, color: Colors.teal.shade400),
    PrizeItem(label: '70 Monedas', value: 70, color: Colors.pink.shade400),
    PrizeItem(label: 'Nada', value: 0, color: Colors.grey.shade600),
  ];

  Future<void> _updateUserCoins(PrizeItem prize) async {
    if (prize.value == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Mejor suerte la próxima vez!')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final historyRef = userRef.collection('rouletteHistory').doc();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final currentCoins = (snapshot.data()?['coins'] ?? 0) as int;
      final newCoins = currentCoins + prize.value;

      transaction.set(userRef, {'coins': newCoins}, SetOptions(merge: true));
      transaction.set(historyRef, {
        'prize': prize.label,
        'coins': prize.value,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    if (mounted) {
      final prizeText = '${prize.value} monedas';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Ganaste $prizeText!')),
      );
    }
  }

  void _onSpinEnd(PrizeItem prize) async {
    await _updateUserCoins(prize);
    if (mounted) {
      setState(() {
        _isSpinning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '¡Gira para Ganar!',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 300,
              height: 300,
              child: FortuneWheel(
                key: _wheelKey,
                items: _prizes,
                onSpinEnd: _onSpinEnd,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('GIRAR LA RULETA'),
              onPressed: _isSpinning
                  ? null
                  : () {
                      setState(() {
                        _isSpinning = true;
                      });
                      _wheelKey.currentState?.spin();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FortuneWheel extends StatefulWidget {
  final List<PrizeItem> items;
  final Function(PrizeItem) onSpinEnd;

  const FortuneWheel({required this.items, required this.onSpinEnd, Key? key})
      : super(key: key);

  @override
  FortuneWheelState createState() => FortuneWheelState();
}

class FortuneWheelState extends State<FortuneWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Random _random = Random();
  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.decelerate));
  }

  void spin() {
    if (_controller.isAnimating) return;

    final double anglePerItem = 2 * pi / widget.items.length;
    final double randomAngle = _random.nextDouble() * 2 * pi;

    final int randomFullSpins = 5 + _random.nextInt(5);
    final double endAngle =
        _currentAngle - (randomFullSpins * 2 * pi) - randomAngle;

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward(from: 0.0).whenComplete(() {
      _currentAngle = endAngle;

      double effectiveAngle = (-_currentAngle + (anglePerItem / 2));
      double normalizedAngle = effectiveAngle % (2 * pi);
      if (normalizedAngle < 0) {
        normalizedAngle += 2 * pi;
      }

      final int finalIndex = (normalizedAngle / anglePerItem).floor();

      widget.onSpinEnd(widget.items[finalIndex]);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value,
              child: child,
            );
          },
          child: CustomPaint(
            size: const Size.square(300),
            painter: RoulettePainter(items: widget.items),
          ),
        ),
        const RoulettePointer(),
      ],
    );
  }
}

class RoulettePointer extends StatelessWidget {
  const RoulettePointer({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 30),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade800
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoulettePainter extends CustomPainter {
  final List<PrizeItem> items;
  final Paint _paint = Paint();

  RoulettePainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final angle = 2 * pi / items.length;

    for (int i = 0; i < items.length; i++) {
      _paint.color = items[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 - angle / 2 + i * angle,
        angle,
        true,
        _paint,
      );
    }

    _paint.color = Colors.white.withOpacity(0.5);
    _paint.strokeWidth = 2.0;
    for (int i = 0; i < items.length; i++) {
      final lineAngle = -pi / 2 - angle / 2 + i * angle;
      final startPoint = center;
      final endPoint = Offset(
        center.dx + radius * cos(lineAngle),
        center.dy + radius * sin(lineAngle),
      );
      canvas.drawLine(startPoint, endPoint, _paint);
    }

    for (int i = 0; i < items.length; i++) {
      final middleAngle = -pi / 2 - angle / 2 + i * angle + angle / 2;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(middleAngle);

      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.text = TextSpan(
        text: items[i].label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
      );
      textPainter.layout(minWidth: 0, maxWidth: radius * 0.8);

      final textOffset = Offset(
          radius * 0.55 - textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, textOffset);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =======================================================================
// ===== 5. PÁGINA DE CANJEAR (MODIFICADA) =====
// =======================================================================
class ExchangePage extends StatefulWidget {
  const ExchangePage({super.key});

  @override
  State<ExchangePage> createState() => _ExchangePageState();
}

class _ExchangePageState extends State<ExchangePage> {
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _coinsController = TextEditingController();
  double _amountToReceive = 0.0;
  bool _isLoading = false;

  final int _exchangeRate = 10;
  final int _minimumWithdrawal = 100;

  @override
  void initState() {
    super.initState();
    _coinsController.addListener(_calculateAmountToReceive);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  void _calculateAmountToReceive() {
    final coins = int.tryParse(_coinsController.text) ?? 0;
    setState(() {
      _amountToReceive = coins / _exchangeRate;
    });
  }

  Stream<double> _getTotalWithdrawnStream(String userId) {
    return FirebaseFirestore.instance
        .collection('withdrawal_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amountInPesos'] as num).toDouble();
      }
      return total;
    });
  }

  Future<void> _submitWithdrawalRequest(int currentUserCoins) async {
    final coinsToWithdraw = int.tryParse(_coinsController.text) ?? 0;
    final name = _nameController.text.trim();
    final alias = _aliasController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (name.isEmpty || alias.isEmpty || coinsToWithdraw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }
    if (coinsToWithdraw < _minimumWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('El retiro mínimo es de $_minimumWithdrawal monedas.')),
      );
      return;
    }
    if (coinsToWithdraw > currentUserCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No tienes suficientes monedas para este retiro.')),
      );
      return;
    }
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final withdrawalRef =
          FirebaseFirestore.instance.collection('withdrawal_requests').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final currentCoins = (userSnapshot.data()?['coins'] ?? 0) as int;

        if (currentCoins < coinsToWithdraw) {
          throw Exception('Saldo insuficiente.');
        }

        transaction.set(withdrawalRef, {
          'userId': user.uid,
          'userName': name,
          'userAlias': alias,
          'coinsToWithdraw': coinsToWithdraw,
          'amountInPesos': _amountToReceive,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {'coins': currentCoins - coinsToWithdraw});

        transaction.update(userRef, {
          'withdrawalName': name,
          'withdrawalAlias': alias,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('¡Solicitud de retiro enviada con éxito!')),
      );
      _coinsController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la solicitud: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Usuario no encontrado."));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(
              child: Text("Error al cargar tus datos: ${userSnapshot.error}"));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final userCoins = userData?['coins'] ?? 0;
        final savedName = userData?['withdrawalName'] as String?;
        final savedAlias = userData?['withdrawalAlias'] as String?;

        if (_nameController.text.isEmpty && savedName != null) {
          _nameController.text = savedName;
        }
        if (_aliasController.text.isEmpty && savedAlias != null) {
          _aliasController.text = savedAlias;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            color: Theme.of(context).colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Solicitar Retiro',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: _getTotalWithdrawnStream(user.uid),
                          builder: (context, withdrawnSnapshot) {
                            if (withdrawnSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _InfoCard(
                                title: 'Total Retirado',
                                value: '...',
                                color: isDarkMode
                                    ? const Color(0xFF1E5128)
                                    : Colors.green.shade100,
                              );
                            }
                            if (withdrawnSnapshot.hasError) {
                              return _InfoCard(
                                title: 'Total Retirado',
                                value: 'Error',
                                color: isDarkMode
                                    ? const Color(0xFF5D2A2A)
                                    : Colors.red.shade100,
                              );
                            }
                            final totalWithdrawn =
                                withdrawnSnapshot.data ?? 0.0;
                            return _InfoCard(
                              title: 'Total Retirado',
                              value: '\$${totalWithdrawn.toInt()}',
                              color: isDarkMode
                                  ? const Color(0xFF1E5128)
                                  : Colors.green.shade100,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          title: 'Tu Saldo',
                          value: '$userCoins',
                          iconWidget: Image.asset(
                            'assets/monedas.png',
                            width: 24,
                            height: 24,
                            color: isDarkMode ? Colors.white : null,
                          ),
                          color: isDarkMode
                              ? const Color(0xFF614A19)
                              : Colors.amber.shade100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade200
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tasa de Cambio: $_exchangeRate Monedas = \$1\nMínimo de retiro: $_minimumWithdrawal monedas (\$${(_minimumWithdrawal / _exchangeRate).toStringAsFixed(0)})',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.amber.shade700
                              : Colors.amber.shade400,
                          width: 1,
                        )),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDarkMode
                              ? Colors.amber.shade200
                              : Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(TextSpan(
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              children: const [
                                TextSpan(
                                    text: 'Importante: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(
                                    text:
                                        'Revisamos cada solicitud manualmente para garantizar la seguridad. El pago se procesará en un plazo de '),
                                TextSpan(
                                    text: '24 a 48 horas hábiles.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ])),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    context: context,
                    controller: _nameController,
                    label: 'Nombre y Apellido Completo',
                    hint: 'Como figura en tu cuenta',
                    prefixIconWidget: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context: context,
                    controller: _aliasController,
                    label: 'Alias o CBU/CVU',
                    hint: 'Para la transferencia',
                    prefixIconWidget: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final clipboardData =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (clipboardData?.text != null) {
                          _aliasController.text = clipboardData!.text!;
                          _aliasController.selection =
                              TextSelection.fromPosition(TextPosition(
                                  offset: _aliasController.text.length));

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('¡Listo! Texto pegado.'),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                margin: const EdgeInsets.only(
                                  right: 20,
                                  left: 20,
                                  bottom: 20,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                      context: context,
                      controller: _coinsController,
                      label: 'Monedas a Retirar',
                      hint: 'Min. retiro 100',
                      prefixIconWidget: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          'assets/monedas.png',
                          width: 20,
                          height: 20,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      suffixIcon: TextButton(
                        onPressed: () {
                          _coinsController.text = userCoins.toString();
                        },
                        child: const Text('Max'),
                      )),
                  const SizedBox(height: 24),
                  Text(
                    'Recibirás: \$ ${_amountToReceive.toInt()} (ARS)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Solicitar Retiro'),
                        onPressed: () => _submitWithdrawalRequest(userCoins),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    Widget? prefixIconWidget,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5)),
            prefixIcon: prefixIconWidget,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

// ===== WIDGET MODIFICADO PARA NO TENER ÍCONO Y CENTRAR TEXTO =====
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Widget? iconWidget; // El ícono ahora es opcional
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    this.iconWidget, // Se quita el 'required'
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Determina si el color de fondo es claro u oscuro para elegir el color del texto
    final bool isColorDark = color.computeLuminance() < 0.5;
    final Color textColor = isColorDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
              style:
                  TextStyle(color: textColor.withOpacity(0.8), fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Muestra el ícono y el espacio solo si el ícono no es nulo
              if (iconWidget != null)
                IconTheme(
                    data: IconThemeData(color: textColor, size: 24),
                    child: iconWidget!),
              if (iconWidget != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor),
                  // Se centra el texto horizontalmente si no hay ícono
                  textAlign:
                      iconWidget == null ? TextAlign.center : TextAlign.start,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// ===== 6. PÁGINA DE HISTORIAL (CORREGIDA) =====
// =======================================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Le decimos al controlador que nos avise cuando cambia la pestaña para redibujar
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.history_edu_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Tu Historial',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.secondary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Theme.of(context).colorScheme.secondary,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/rueda-de-la-fortuna.png',
                          height: 24,
                          width: 24,
                          // <<--- LÓGICA DE COLOR MEJORADA AQUÍ --->>
                          color: _tabController.index == 0
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondary // Color cuando está seleccionada
                              : (isDarkMode
                                  ? Colors.grey
                                      .shade400 // Color no seleccionada en modo oscuro
                                  : null), // Color original no seleccionada en modo claro
                        ),
                        const SizedBox(height: 4),
                        const Text('Historial de Giros',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off),
                        SizedBox(height: 4),
                        Text('Historial de Retiros',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    SpinHistoryView(),
                    WithdrawalHistoryView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpinHistoryView extends StatelessWidget {
  const SpinHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Inicia sesión para ver tu historial."));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('rouletteHistory')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no hay giros registrados. ¡Ve a jugar!',
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            final dateString = timestamp != null
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year} ${timestamp.toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}"
                : 'Fecha no disponible';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Image.asset(
                  'assets/monedas.png',
                  width: 24,
                  height: 24,
                  color: isDarkMode ? Colors.white : null,
                ),
                title: Text(data['prize'] ?? 'Premio no disponible'),
                subtitle: Text(dateString),
              ),
            );
          },
        );
      },
    );
  }
}

class WithdrawalHistoryView extends StatelessWidget {
  const WithdrawalHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Inicia sesión para ver tu historial."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no se han realizado solicitudes de retiro.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final dateString = timestamp != null
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year}"
                : 'N/A';
            final status = data['status'] ?? 'desconocido';

            IconData statusIcon;
            Color statusColor;
            switch (status) {
              case 'pending':
                statusIcon = Icons.hourglass_empty;
                statusColor = Colors.orange;
                break;
              case 'completed':
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
                break;
              case 'rejected':
                statusIcon = Icons.cancel;
                statusColor = Colors.red;
                break;
              default:
                statusIcon = Icons.help_outline;
                statusColor = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor),
                title: Text('Retiro de ${data['coinsToWithdraw']} monedas'),
                subtitle: Text(
                    'Monto: \$${(data['amountInPesos'] as num).toStringAsFixed(2)} - Estado: $status'),
                trailing: Text(dateString),
              ),
            );
          },
        );
      },
    );
  }
}

// =======================================================================
// ===== 7. PÁGINA DE LOGIN =====
// =======================================================================
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

// =======================================================================
// ===== 8. PÁGINA DE REGISTRO =====
// =======================================================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'coins': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: ${e.message}')),
        );
      }
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

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'name': userCredential.user?.displayName ?? 'Sin Nombre',
          'email': userCredential.user?.email,
          'coins': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar con Google: $e')),
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
              const SizedBox(height: 40),
              const Text(
                'Registrar',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Nombre',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.color
                          ?.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirmar Contraseña',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.color
                          ?.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text('Registrar'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                    height: 18.0),
                label: const Text('Registrarse con Google'),
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
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text.rich(
                  TextSpan(
                    text: '¿Ya tienes cuenta? ',
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withOpacity(0.6)),
                    children: [
                      TextSpan(
                        text: 'Inicia sesión',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
