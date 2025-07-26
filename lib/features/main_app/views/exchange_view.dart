import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/user_notifier.dart';
import '../../../shared/widgets/info_card.dart';
import '../../../shared/widgets/custom_text_field.dart';

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }
    if (coinsToWithdraw < _minimumWithdrawal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('El retiro mínimo es de $_minimumWithdrawal monedas.')),
      );
      return;
    }
    if (coinsToWithdraw > currentUserCoins) {
      if (!mounted) return;
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

        final newCoinTotal = currentCoins - coinsToWithdraw;

        transaction.set(withdrawalRef, {
          'userId': user.uid,
          'userName': name,
          'userAlias': alias,
          'coinsToWithdraw': coinsToWithdraw,
          'amountInPesos': _amountToReceive,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {'coins': newCoinTotal});

        transaction.update(userRef, {
          'withdrawalName': name,
          'withdrawalAlias': alias,
        });

        // **LÍNEA CLAVE AÑADIDA AQUÍ**
        // Actualizamos el estado local inmediatamente después de la transacción
        if (mounted) {
          Provider.of<UserNotifier>(context, listen: false).updateCoins(newCoinTotal);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Solicitud de retiro enviada con éxito!')),
        );
      }
      _coinsController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la solicitud: $e')),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Usuario no encontrado."));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
                child:
                Text("Error al cargar tus datos: ${userSnapshot.error}"));
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

          return Card(
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
                              return InfoCard(
                                title: 'Total Retirado',
                                value: '...',
                                color: isDarkMode
                                    ? const Color(0xFF1E5128)
                                    : Colors.green.shade100,
                              );
                            }
                            if (withdrawnSnapshot.hasError) {
                              return InfoCard(
                                title: 'Total Retirado',
                                value: 'Error',
                                color: isDarkMode
                                    ? const Color(0xFF5D2A2A)
                                    : Colors.red.shade100,
                              );
                            }
                            final totalWithdrawn =
                                withdrawnSnapshot.data ?? 0.0;
                            return InfoCard(
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
                        child: InfoCard(
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
                      color: isDarkMode
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.blue.shade800
                            : Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: isDarkMode
                              ? Colors.blue.shade200
                              : Colors.blue.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              children: [
                                const TextSpan(text: 'Tasa de Cambio: '),
                                TextSpan(
                                    text: '$_exchangeRate Monedas = \$1\n',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const TextSpan(text: 'Mínimo de retiro: '),
                                TextSpan(
                                    text:
                                    '$_minimumWithdrawal monedas (\$${(_minimumWithdrawal / _exchangeRate).toStringAsFixed(0)})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                                    'Revisamos cada solicitud manualmente. El pago se procesará en un plazo de '),
                                TextSpan(
                                    text: '24 a 48 horas hábiles.',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: '\n\n'),
                                TextSpan(
                                    text: 'Responsabilidad del Usuario: ',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(
                                    text:
                                    'Asegúrate de que el Nombre y Alias/CBU/CVU sean 100% correctos. '),
                                TextSpan(
                                    text:
                                    'Spin2Win no se hace responsable por transferencias enviadas a datos incorrectos.',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                              ])),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Nombre y Apellido Completo',
                    hint: 'Como figura en tu cuenta',
                    prefixIconWidget: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _aliasController,
                    label: 'Alias o CBU/CVU',
                    hint: 'Para la transferencia',
                    prefixIconWidget: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final clipboardData =
                        await Clipboard.getData(Clipboard.kTextPlain);

                        if (clipboardData != null && clipboardData.text != null && mounted) {
                          _aliasController.text = clipboardData.text!;
                          _aliasController.selection =
                              TextSelection.fromPosition(TextPosition(
                                  offset: _aliasController.text.length));

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text('¡Listo! Texto pegado.'),
                              ]),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              margin: const EdgeInsets.only(
                                  right: 20, left: 20, bottom: 20),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
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
          );
        },
      ),
    );
  }
}