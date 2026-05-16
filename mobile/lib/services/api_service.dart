import 'dart:convert';
import 'dart:io';

import '../models/event_log_item.dart';
import '../models/system_status.dart';

class ApiService {
  ApiService(this.serverUrl);

  final String serverUrl;

  Future<SystemStatus> getStatus() async {
    final json = await _getJson('/api/v1/status');
    return SystemStatus.fromJson(json);
  }

  Future<List<EventLogItem>> getEvents({int limit = 20}) async {
    final json = await _getJson('/api/v1/events?limit=$limit');
    final rows = json['events'];
    if (rows is! List) {
      return const [];
    }
    return rows
        .whereType<Map>()
        .map((item) => EventLogItem.fromJson(Map<String, dynamic>.from(item)))
        .take(limit)
        .toList(growable: false);
  }

  Future<void> setDoor(String action) => _post('/actions/door/$action');

  Future<void> setLight(String action) => _post('/actions/light/$action');

  Future<void> reloadFaceEmbeddings() => _post('/api/v1/face/reload');

  Future<bool> testConnection() async {
    await getStatus();
    return true;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _send('GET', path);
    final decoded = jsonDecode(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {'data': decoded};
  }

  Future<void> _post(String path) async {
    await _send('POST', path);
  }

  Future<String> _send(String method, String path) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .openUrl(method, Uri.parse('${serverUrl.replaceAll(RegExp(r'/+$'), '')}$path'))
          .timeout(const Duration(seconds: 5));
      request.headers.contentType = ContentType.json;
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('HTTP ${response.statusCode}: $body');
      }
      return body.isEmpty ? '{}' : body;
    } finally {
      client.close(force: true);
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
