import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isBlackAndWhite = false;

  bool get isBlackAndWhite => _isBlackAndWhite;

  void toggleTheme() {
    _isBlackAndWhite = !_isBlackAndWhite;
    notifyListeners();
  }
}
