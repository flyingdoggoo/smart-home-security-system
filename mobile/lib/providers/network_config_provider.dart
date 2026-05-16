import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class NetworkConfigProvider extends ChangeNotifier {
  static const defaultServerUrl = 'http://10.0.2.2:8000';
  static const _serverUrlKey = 'server_url';

  String _serverUrl = defaultServerUrl;
  bool _initialized = false;
  bool _testing = false;
  String? _message;

  String get serverUrl => _serverUrl;
  bool get initialized => _initialized;
  bool get testing => _testing;
  String? get message => _message;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverUrlKey) ?? defaultServerUrl;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setServerUrl(String value) async {
    final normalized = _normalize(value);
    if (normalized.isEmpty) {
      _message = 'Server URL is required.';
      notifyListeners();
      return;
    }
    _serverUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalized);
    _message = 'Saved server URL.';
    notifyListeners();
  }

  Future<void> resetServerUrl() async {
    _serverUrl = defaultServerUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    _message = 'Reset to Android emulator default.';
    notifyListeners();
  }

  Future<bool> testConnection() async {
    _testing = true;
    _message = null;
    notifyListeners();
    try {
      await ApiService(_serverUrl).testConnection();
      _message = 'Connection OK.';
      return true;
    } catch (error) {
      _message = 'Connection failed: $error';
      return false;
    } finally {
      _testing = false;
      notifyListeners();
    }
  }

  String _normalize(String value) => value.trim().replaceAll(RegExp(r'/+$'), '');
}
