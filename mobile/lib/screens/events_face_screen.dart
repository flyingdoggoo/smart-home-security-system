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
        await Future.wait([
          statusProvider.refresh(),
          eventProvider.refresh(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Face recognition',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload embeddings',
                        onPressed: statusProvider.busy
                            ? null
                            : () => statusProvider.reloadFaceEmbeddings(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Label: ${status?.faceLabel ?? 'unknown'}'),
                  Text('Confidence: ${status?.faceConfidence.toStringAsFixed(2) ?? '-'}'),
                  Text('Distance: ${status?.faceDistance?.toStringAsFixed(3) ?? '-'}'),
                  Text('Faces: ${status?.faceCount ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Latest 20 events', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (eventProvider.busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (eventProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Showing cached events. ${eventProvider.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          if (eventProvider.events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No events cached yet.'),
              ),
            )
          else
            ...eventProvider.events.map((event) => _EventCard(event: event)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventLogItem event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.severity) {
      'critical' => Colors.red,
      'warning' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Card(
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 14),
        title: Text(event.eventType),
        subtitle: Text(
          '${event.message}\n${event.createdAt}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
      ),
    );
  }
}
