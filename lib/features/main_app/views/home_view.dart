import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart'; // <-- IMPORT QUE FALTABA

import '../../../core/models/prize_item.dart';
import '../../../core/providers/user_notifier.dart'; // <-- IMPORT QUE FALTABA
import '../widgets/fortune_wheel.dart';

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

  Future<void> _spinAndGetPrize() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    String message = 'Ocurrió un error inesperado.';

    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('spinTheWheel');
      final result = await callable.call();

      final prizeData = result.data['prize'];
      final String prizeLabel = prizeData['label'];
      final int prizeValue = prizeData['value'];

      final int prizeIndex = _prizes.indexWhere((p) => p.label == prizeLabel);

      if (prizeIndex != -1) {
        await _wheelKey.currentState?.spinTo(prizeIndex);

        message = prizeValue > 0
            ? '¡Ganaste $prizeValue monedas!'
            : '¡Mejor suerte la próxima vez!';
      } else {
        message = 'Error: Premio no encontrado.';
      }

    } on FirebaseFunctionsException catch (error) {
      message = 'Error: ${error.message}';
    } catch (error) {
      message = 'Ocurrió un error inesperado.';
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final updatedCoins = (userDoc.data()?['coins'] ?? 0) as int;
          Provider.of<UserNotifier>(context, listen: false).updateCoins(updatedCoins);
        }

        setState(() {
          _isSpinning = false;
        });
      }
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
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('GIRAR LA RULETA'),
              onPressed: _isSpinning ? null : _spinAndGetPrize,
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