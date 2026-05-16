class SystemStatus {
  const SystemStatus({
    required this.doorState,
    required this.lightState,
    required this.gasValue,
    required this.gasAlert,
    required this.lightValue,
    required this.isDark,
    required this.lightAutoSuppressed,
    required this.faceLabel,
    required this.faceConfidence,
    required this.faceDistance,
    required this.faceCount,
    required this.source,
    required this.lastUpdated,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      doorState: json['door_state']?.toString() ?? 'locked',
      lightState: json['light_state']?.toString() ?? 'off',
      gasValue: _asDouble(json['gas_value']),
      gasAlert: _asBool(json['gas_alert']),
      lightValue: _asDouble(json['light_value'] ?? json['light_raw']),
      isDark: _asBool(json['is_dark'] ?? json['dark']),
      lightAutoSuppressed: _asBool(
        json['light_auto_suppressed'] ?? json['manual_light_override'],
      ),
      faceLabel: json['face_label']?.toString() ?? 'no_face',
      faceConfidence: _asDouble(json['face_confidence']),
      faceDistance: json['face_distance'] == null ? null : _asDouble(json['face_distance']),
      faceCount: _asInt(json['face_count']),
      source: json['source']?.toString() ?? 'unknown',
      lastUpdated: json['last_updated']?.toString() ?? '',
    );
  }

  final String doorState;
  final String lightState;
  final double gasValue;
  final bool gasAlert;
  final double lightValue;
  final bool isDark;
  final bool lightAutoSuppressed;
  final String faceLabel;
  final double faceConfidence;
  final double? faceDistance;
  final int faceCount;
  final String source;
  final String lastUpdated;

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
