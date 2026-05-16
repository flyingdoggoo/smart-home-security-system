class EventLogItem {
  const EventLogItem({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.message,
    required this.payload,
    required this.createdAt,
  });

  factory EventLogItem.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return EventLogItem(
      id: _asInt(json['id']),
      eventType: json['event_type']?.toString() ?? 'event',
      severity: json['severity']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  final int id;
  final String eventType;
  final String severity;
  final String message;
  final Map<String, dynamic> payload;
  final String createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType,
      'severity': severity,
      'message': message,
      'payload': payload,
      'created_at': createdAt,
    };
  }

  bool get isStrangerAlert => eventType == 'stranger_alert';

  static int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
