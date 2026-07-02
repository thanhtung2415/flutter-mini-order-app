import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  String? _error;

  String? get error => _error;

  void login(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      _error = 'Vui long nhap email va mat khau';
    } else {
      _error = null;
    }
    notifyListeners();
  }
}
