import 'package:flutter/foundation.dart';

class AuthTokenStore extends ChangeNotifier {
  String _bearerToken = '';

  String get bearerToken => _bearerToken;

  bool get hasToken => _bearerToken.isNotEmpty;

  void setToken(String token) {
    _bearerToken = token.trim();
    notifyListeners();
  }
}
