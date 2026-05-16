import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_log_item.dart';
import '../services/api_service.dart';

class EventLogProvider extends ChangeNotifier {
  static const pollingInterval = Duration(seconds: 3);
  static const eventLimit = 20;
  static const _cacheKey = 'cached_events_v1';

  String? _serverUrl;
  ApiService? _api;
  Timer? _timer;
  List<EventLogItem> _events = const [];
  final Set<int> _seenStrangerIds = <int>{};
  final List<EventLogItem> _pendingStrangerAlerts = <EventLogItem>[];
  Future<void>? _initializing;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  List<EventLogItem> get events => _events;
  bool get busy => _busy;
  String? get error => _error;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final running = _initializing;
    if (running != null) {
      return running;
    }
    _initializing = _loadCache();
    return _initializing!;
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          _events = decoded
              .whereType<Map>()
              .map((item) => EventLogItem.fromJson(Map<String, dynamic>.from(item)))
              .take(eventLimit)
              .toList(growable: false);
          _seenStrangerIds.addAll(_events.where((e) => e.isStrangerAlert).map((e) => e.id));
        }
      }
    } catch (error) {
      _error = 'Failed loading event cache: $error';
    } finally {
      _initialized = true;
      _initializing = null;
      notifyListeners();
    }
  }

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
    if (!_initialized) {
      await initialize();
    }
    final api = _api;
    if (api == null || _busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      final latest = await api.getEvents(limit: eventLimit);
      for (final event in latest) {
        if (event.isStrangerAlert && !_seenStrangerIds.contains(event.id)) {
          _pendingStrangerAlerts.add(event);
          _seenStrangerIds.add(event.id);
        }
      }
      _events = latest.take(eventLimit).toList(growable: false);
      await _saveCache();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  EventLogItem? consumePendingStrangerAlert() {
    if (_pendingStrangerAlerts.isEmpty) {
      return null;
    }
    return _pendingStrangerAlerts.removeAt(0);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_events.take(eventLimit).map((e) => e.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
