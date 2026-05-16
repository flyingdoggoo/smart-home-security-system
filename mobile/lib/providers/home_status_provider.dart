import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/system_status.dart';
import '../services/api_service.dart';

class HomeStatusProvider extends ChangeNotifier {
  static const pollingInterval = Duration(seconds: 2);

  String? _serverUrl;
  ApiService? _api;
  Timer? _timer;
  SystemStatus? _status;
  bool _busy = false;
  String? _error;

  SystemStatus? get status => _status;
  bool get busy => _busy;
  String? get error => _error;
  bool get online => _error == null && _status != null;

  void updateServerUrl(String serverUrl) {
    if (_serverUrl == serverUrl) {
      return;
    }
    _serverUrl = serverUrl;
    _api = ApiService(serverUrl);
    _timer?.cancel();
    _timer = Timer.periodic(pollingInterval, (_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null || _busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      _status = await api.getStatus();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setDoor(String action) async {
    await _runCommand(() => _api!.setDoor(action));
  }

  Future<void> setLight(String action) async {
    await _runCommand(() => _api!.setLight(action));
  }

  Future<void> reloadFaceEmbeddings() async {
    await _runCommand(() => _api!.reloadFaceEmbeddings(), refreshAfter: false);
  }

  Future<void> _runCommand(
    Future<void> Function() command, {
    bool refreshAfter = true,
  }) async {
    final api = _api;
    if (api == null || _busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await command();
      _error = null;
      if (refreshAfter) {
        _status = await api.getStatus();
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
