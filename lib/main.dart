import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
import '../../../main.dart';

// Importaciones de tu proyecto
import 'core/models/prize_item.dart'; // RUTA CORREGIDA
import 'core/theme/app_theme.dart'; // TEMA IMPORTADO
import 'firebase_options.dart';
import 'features/splash/screens/loading_screen.dart';

// La función main ahora es lo único que queda al principio
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(), // Esta clase ahora viene de app_theme.dart
      child: const Spin2WinApp(),
    ),
  );
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
          // AHORA SOLO USAMOS LAS VARIABLES IMPORTADAS
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.themeMode,
          home: const LoadingScreen(),
        );
      },
    );
  }
}




// =======================================================================
// ===== 4. PÁGINA DE JUEGO (RULETA) =====
// =======================================================================




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
                          color: _tabController.index == 0
                              ? Theme.of(context).colorScheme.secondary
                              : (isDarkMode ? Colors.grey.shade400 : null),
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

// =======================================================================
// ===== 8. PÁGINA DE REGISTRO =====
// =======================================================================
