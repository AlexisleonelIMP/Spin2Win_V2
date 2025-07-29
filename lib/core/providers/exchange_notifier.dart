import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeNotifier extends ChangeNotifier {
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _coinsController = TextEditingController();

  double _amountToReceive = 0.0;
  bool _isLoading = false;

  final int _exchangeRate = 10;
  final int _minimumWithdrawal = 100;

  // Getters
  TextEditingController get nameController => _nameController;
  TextEditingController get aliasController => _aliasController;
  TextEditingController get coinsController => _coinsController;
  double get amountToReceive => _amountToReceive;
  bool get isLoading => _isLoading;
  int get exchangeRate => _exchangeRate;
  int get minimumWithdrawal => _minimumWithdrawal;

  ExchangeNotifier() {
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
    _amountToReceive = coins / _exchangeRate;
    notifyListeners();
  }

  void setMaxCoins(int coins) {
    _coinsController.text = coins.toString();
  }

  void setInitialData(String? name, String? alias) {
    if (_nameController.text.isEmpty && name != null) {
      _nameController.text = name;
    }
    if (_aliasController.text.isEmpty && alias != null) {
      _aliasController.text = alias;
    }
  }

  // MÉTODO MODIFICADO PARA DEVOLVER EL NUEVO SALDO
  Future<Map<String, dynamic>> submitWithdrawalRequest(int currentUserCoins) async {
    final coinsToWithdraw = int.tryParse(_coinsController.text) ?? 0;
    final name = _nameController.text.trim();
    final alias = _aliasController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (name.isEmpty || alias.isEmpty || coinsToWithdraw <= 0) {
      return {'success': false, 'message': 'Por favor, completa todos los campos.'};
    }
    if (coinsToWithdraw < _minimumWithdrawal) {
      return {'success': false, 'message': 'El retiro mínimo es de $_minimumWithdrawal monedas.'};
    }
    if (coinsToWithdraw > currentUserCoins) {
      return {'success': false, 'message': 'No tienes suficientes monedas para este retiro.'};
    }
    if (user == null) {
      return {'success': false, 'message': 'Usuario no encontrado.'};
    }

    _isLoading = true;
    notifyListeners();

    try {
      int newCoinTotal = 0;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userSnapshot = await transaction.get(userRef);
        final currentCoins = (userSnapshot.data()?['coins'] ?? 0) as int;

        if (currentCoins < coinsToWithdraw) {
          throw Exception('Saldo insuficiente.');
        }

        newCoinTotal = currentCoins - coinsToWithdraw;

        final withdrawalRef = FirebaseFirestore.instance.collection('withdrawal_requests').doc();
        transaction.set(withdrawalRef, {
          'userId': user.uid, 'userName': name, 'userAlias': alias,
          'coinsToWithdraw': coinsToWithdraw, 'amountInPesos': _amountToReceive,
          'status': 'pending', 'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {'coins': newCoinTotal});
        transaction.update(userRef, {'withdrawalName': name, 'withdrawalAlias': alias});
      });

      _coinsController.clear();
      return {'success': true, 'message': '¡Solicitud de retiro enviada con éxito!', 'newBalance': newCoinTotal};
    } catch (e) {
      return {'success': false, 'message': 'Error al enviar la solicitud: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}