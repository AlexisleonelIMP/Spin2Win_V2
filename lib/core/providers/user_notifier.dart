import 'package:flutter/material.dart';

class UserNotifier extends ChangeNotifier {
  int _coins = 0;
  int get coins => _coins;

  // Metodo para establecer las monedas iniciales
  void setInitialCoins(int coins) {
    _coins = coins;
    notifyListeners();
  }

  // Metodo para actualizar las monedas después de un giro
  void updateCoins(int newCoinValue) {
    _coins = newCoinValue;
    notifyListeners(); // Notifica a los widgets que escuchan para que se redibujen
  }
}