import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/prize_item.dart';
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