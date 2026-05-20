import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_log_item.dart';
import '../providers/event_log_provider.dart';
import '../providers/home_status_provider.dart';

class EventsFaceScreen extends StatelessWidget {
  const EventsFaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final statusProvider = context.watch<HomeStatusProvider>();
    final eventProvider = context.watch<EventLogProvider>();
    final status = statusProvider.status;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([statusProvider.refresh(), eventProvider.refresh()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        children: [
          _FaceInsightCard(statusProvider: statusProvider),
          const SizedBox(height: 14),
          if (status == null)
            const SizedBox.shrink()
          else
            _FaceLiveStats(
              label: status.faceLabel,
              confidence: status.faceConfidence,
              distance: status.faceDistance,
              faces: status.faceCount,
            ),
          const SizedBox(height: 14),
          _EventsHeader(eventProvider: eventProvider),
          if (eventProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                'Đang hiển thị cache. ${eventProvider.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          if (eventProvider.events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có sự kiện nào trong bộ nhớ cache.'),
              ),
            )
          else
            ...eventProvider.events.map((event) => _EventCard(event: event)),
        ],
      ),
    );
  }
}

class _FaceInsightCard extends StatelessWidget {
  const _FaceInsightCard({required this.statusProvider});

  final HomeStatusProvider statusProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [const Color(0xFF0D7EA8), const Color(0xFF1F60BB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Face Recognition',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  tooltip: 'Reload embeddings',
                  onPressed: statusProvider.busy
                      ? null
                      : () => statusProvider.reloadFaceEmbeddings(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cập nhật embedding khi bạn thu thêm dữ liệu owner để tăng độ ổn định nhận diện.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FaceBadge(
                  icon: Icons.verified_user_rounded,
                  text: 'Threshold owner: 0.6',
                ),
                _FaceBadge(
                  icon: Icons.model_training_rounded,
                  text: 'Model: face_recognition',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceBadge extends StatelessWidget {
  const _FaceBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceLiveStats extends StatelessWidget {
  const _FaceLiveStats({
    required this.label,
    required this.confidence,
    required this.distance,
    required this.faces,
  });

  final String label;
  final double confidence;
  final double? distance;
  final int faces;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MiniMetric('Nhãn', label, Icons.face_rounded),
      _MiniMetric(
        'Confidence',
        confidence.toStringAsFixed(2),
        Icons.speed_rounded,
      ),
      _MiniMetric(
        'Distance',
        distance?.toStringAsFixed(3) ?? '-',
        Icons.straighten_rounded,
      ),
      _MiniMetric('Faces', faces.toString(), Icons.group_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _MiniMetricTile(metric: metrics[index]),
    );
  }
}

class _MiniMetric {
  const _MiniMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({required this.metric});

  final _MiniMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(metric.icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({required this.eventProvider});

  final EventLogProvider eventProvider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Nhật ký sự kiện gần nhất',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (eventProvider.busy)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventLogItem event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final severityColor = switch (event.severity) {
      'critical' => const Color(0xFFD44545),
      'warning' => const Color(0xFFC77600),
      _ => scheme.primary,
    };
    final icon = switch (event.severity) {
      'critical' => Icons.crisis_alert_rounded,
      'warning' => Icons.warning_amber_rounded,
      _ => Icons.info_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: severityColor.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: severityColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventType,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(event.message),
                    const SizedBox(height: 6),
                    Text(
                      event.createdAt,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
