import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Import explícito para asegurar la visibilidad de TextDirection

// Importa el archivo de opciones generado
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Spin2WinApp());
}

// --- Modelo para los Premios ---
class PrizeItem {
  final String label;
  final int value; // Cantidad de monedas
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spin2Win',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFFDFBF3), // Color de fondo como en la imagen
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.amber,
        ).copyWith(
          secondary: const Color(0xFFF9693B), // Naranja del botón
          surface: const Color(0xFFFFFFFF), // Blanco para las tarjetas
          onSurface: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8E1),
          elevation: 1,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFDFBF3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
           enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          prefixIconColor: Colors.grey.shade600,
          hintStyle: TextStyle(color: Colors.grey.shade400), // Estilo para el hint text
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFF9693B), // Naranja para los enlaces
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// =======================================================================
// ===== 2. MANEJO DE AUTENTICACIÓN (LOGIN/LOGOUT) =====
// =======================================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
// ===== 3. PÁGINA PRINCIPAL (CONTENEDOR DE JUEGO, CANJE, HISTORIAL) =====
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Si por alguna razón no hay usuario, mostramos una pantalla de carga para evitar errores.
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // El StreamBuilder escuchará los cambios en el documento del usuario en tiempo real.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        
        // Mientras carga la información inicial, mostramos la UI base con un indicador de carga en el AppBar.
        // Esto es mejor que una pantalla en blanco.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Spin2Win'),
              actions: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)),
                ),
              ]
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Si hay un error con la conexión a Firebase, lo mostramos.
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        
        // Obtenemos las monedas del snapshot. Si no existe el documento o el campo, el valor por defecto es 0.
        final userCoins = (snapshot.data?.data() as Map<String, dynamic>?)?['coins'] ?? 0;

        // Creamos la lista de widgets para la navegación, pasando las monedas actualizadas.
        final List<Widget> widgetOptions = [
          const HomePage(),
          ExchangePage(userCoins: userCoins), // Ahora siempre tendrá el valor más reciente.
          const HistoryPage(),
        ];

        // Construimos la interfaz completa con los datos actualizados del StreamBuilder.
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.casino_outlined, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(
                  'Spin2Win',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Text(
                      '$userCoins', // ¡Este texto se actualizará automáticamente!
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
          body: Center(
            child: widgetOptions.elementAt(_selectedIndex),
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.casino),
                label: 'Jugar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz),
                label: 'Canjear',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            onTap: _onItemTapped,
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

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
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
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 300,
              height: 300,
              child: FortuneWheel(
                key: _wheelKey,
                items: _prizes,
                onSpinEnd: (prize) {
                  _updateUserCoins(prize);
                },
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('GIRAR LA RULETA'),
              onPressed: () {
                _wheelKey.currentState?.spin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), 
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
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

  const FortuneWheel({required this.items, required this.onSpinEnd, Key? key}) : super(key: key);

  @override
  FortuneWheelState createState() => FortuneWheelState();
}

class FortuneWheelState extends State<FortuneWheel> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(parent: _controller, curve: Curves.decelerate)
    );
  }

  void spin() {
    if (_controller.isAnimating) return;

    final double anglePerItem = 2 * pi / widget.items.length;
    final double randomAngle = _random.nextDouble() * 2 * pi;

    final int randomFullSpins = 5 + _random.nextInt(5);
    final double endAngle = _currentAngle - (randomFullSpins * 2 * pi) - randomAngle;

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart)
    );

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
        final lineAngle = -pi/2 - angle/2 + i*angle;
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
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
      );
      textPainter.layout(minWidth: 0, maxWidth: radius * 0.8);
      
      final textOffset = Offset(radius * 0.55 - textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, textOffset);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =======================================================================
// ===== 5. PÁGINA DE CANJEAR =====
// =======================================================================
class ExchangePage extends StatefulWidget {
  final int userCoins;
  const ExchangePage({super.key, required this.userCoins});

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
  final int _minimumWithdrawal = 10000;

  @override
  void initState() {
    super.initState();
    _coinsController.addListener(_calculateAmountToReceive);
  }

  void _calculateAmountToReceive() {
    final coins = int.tryParse(_coinsController.text) ?? 0;
    setState(() {
      _amountToReceive = coins / _exchangeRate;
    });
  }

  Future<void> _submitWithdrawalRequest() async {
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
        SnackBar(content: Text('El retiro mínimo es de $_minimumWithdrawal monedas.')),
      );
      return;
    }
    if (coinsToWithdraw > widget.userCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes suficientes monedas para este retiro.')),
      );
      return;
    }
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final withdrawalRef = FirebaseFirestore.instance.collection('withdrawal_requests').doc();

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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Solicitud de retiro enviada con éxito!')),
      );
      _nameController.clear();
      _aliasController.clear();
      _coinsController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la solicitud: $e')),
      );
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Solicitar Retiro',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      title: 'Tu Saldo',
                      value: '${widget.userCoins}',
                      icon: Icons.monetization_on,
                      color: Colors.amber.shade100,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoCard(
                      title: 'Total Retirado',
                      value: '\$0.00',
                      icon: Icons.history,
                      color: Colors.green.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tasa de Cambio: $_exchangeRate Monedas = \$1\nMínimo de retiro: $_minimumWithdrawal monedas (\$${(_minimumWithdrawal / _exchangeRate).toStringAsFixed(2)})',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'Nombre y Apellido Completo',
                hint: 'Como figura en tu cuenta',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _aliasController,
                label: 'Alias o CBU/CVU',
                hint: 'Para la transferencia',
                icon: Icons.vpn_key_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _coinsController,
                label: 'Monedas a Retirar',
                hint: 'ej: 10000',
                keyboardType: TextInputType.number,
                suffixIcon: TextButton(
                  onPressed: () {
                    _coinsController.text = widget.userCoins.toString();
                  },
                  child: const Text('Max'),
                )
              ),
              const SizedBox(height: 24),
              Text(
                'Recibirás (aprox.): \$${_amountToReceive.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Solicitar Retiro'),
                  onPressed: _submitWithdrawalRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: Colors.grey.shade800),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// ===== 6. PÁGINA DE HISTORIAL =====
// =======================================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.history_edu_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Tu Historial',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.secondary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: theme.colorScheme.secondary,
                tabs: const [
                  Tab(icon: Icon(Icons.casino_outlined), text: 'Historial de Giros'),
                  Tab(icon: Icon(Icons.history_toggle_off), text: 'Historial de Retiros'),
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
    if (user == null) return const Center(child: Text("Inicia sesión para ver tu historial."));

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
            // Formato de fecha simple sin el paquete intl
            final dateString = timestamp != null
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year} ${timestamp.toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}"
                : 'Fecha no disponible';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.star_border_purple500_outlined),
                title: Text(data['prize'] ?? 'Premio no disponible'),
                subtitle: Text('${data['coins'] ?? 0} Monedas Ganadas'),
                trailing: Text(dateString),
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
    if (user == null) return const Center(child: Text("Inicia sesión para ver tu historial."));

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
            // Formato de fecha simple sin el paquete intl
            final dateString = timestamp != null
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year}"
                : 'N/A';
            final status = data['status'] ?? 'desconocido';
            
            IconData statusIcon;
            Color statusColor;
            switch(status) {
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
                subtitle: Text('Monto: \$${(data['amountInPesos'] as num).toStringAsFixed(2)} - Estado: $status'),
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
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if(mounted) setState(() => _isLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión con Google: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
        if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
        if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¡Bienvenido de Nuevo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sesión para girar la rueda de la fortuna',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo Electrónico',
                      hint: 'tu@ejemplo.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      hint: '********',
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Iniciar Sesión'),
                            onPressed: _signInWithEmail,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)
                              )
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('O CONTINÚA CON', style: TextStyle(color: Colors.grey.shade500)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png', height: 18.0),
                            label: const Text('Iniciar sesión con Google'),
                            onPressed: _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)
                              )
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('¿No tienes una cuenta?', style: TextStyle(color: Colors.grey.shade600)),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterPage()));
                          },
                          child: const Text('Regístrate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
        ),
      ],
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
  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Crear documento de usuario en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'coins': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop(); // Volver a la página de login
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Crear una Cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡Únete a nosotros y comienza a ganar hoy!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo Electrónico',
                      hint: 'tu@ejemplo.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      hint: '********',
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Contraseña',
                      hint: '********',
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Registrarse'),
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('¿Ya tienes una cuenta?', style: TextStyle(color: Colors.grey.shade600)),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Inicia Sesión'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
        ),
      ],
    );
  }
}
