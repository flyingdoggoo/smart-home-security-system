import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/system_status.dart';
import '../providers/home_status_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeStatusProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ConnectionBanner(provider: provider),
              const SizedBox(height: 12),
              if (status == null)
                const _EmptyStatus()
              else
                _StatusGrid(status: status, provider: provider),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.provider});

  final HomeStatusProvider provider;

  @override
  Widget build(BuildContext context) {
    final color = provider.error == null ? Colors.green : Colors.orange;
    final text = provider.error == null
        ? provider.busy
            ? 'Refreshing...'
            : 'Online'
        : 'Offline: ${provider.error}';

    return Card(
      child: ListTile(
        leading: Icon(Icons.wifi_tethering, color: color),
        title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Refresh',
          onPressed: provider.busy ? null : provider.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class _EmptyStatus extends StatelessWidget {
  const _EmptyStatus();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Waiting for backend status...')),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.status, required this.provider});

  final SystemStatus status;
  final HomeStatusProvider provider;

  @override
  Widget build(BuildContext context) {
    final doorUnlocked = status.doorState == 'unlocked';
    final lightOn = status.lightState == 'on';
    final items = [
      _StatusItem(
        'Door',
        status.doorState,
        Icons.door_front_door_outlined,
        actionLabel: doorUnlocked ? 'Lock' : 'Unlock',
        actionIcon: doorUnlocked ? Icons.lock : Icons.lock_open,
        onPressed: provider.busy
            ? null
            : () => provider.setDoor(doorUnlocked ? 'close' : 'open'),
      ),
      _StatusItem(
        'Light',
        status.lightState,
        lightOn ? Icons.lightbulb : Icons.lightbulb_outline,
        actionLabel: lightOn ? 'Turn off' : 'Turn on',
        actionIcon: lightOn ? Icons.lightbulb_outline : Icons.lightbulb,
        onPressed: provider.busy
            ? null
            : () => provider.setLight(lightOn ? 'off' : 'on'),
      ),
      _StatusItem('Gas', status.gasAlert ? 'alert' : status.gasValue.toStringAsFixed(0),
          Icons.local_fire_department_outlined),
      _StatusItem('Ambient', status.isDark ? 'dark' : 'bright', Icons.dark_mode_outlined),
      _StatusItem('Light raw', status.lightValue.toStringAsFixed(0), Icons.sensors_outlined),
      _StatusItem('Auto lockout', status.lightAutoSuppressed ? 'manual' : 'ready',
          Icons.tungsten_outlined),
      _StatusItem('Face', status.faceLabel, Icons.face_retouching_natural),
      _StatusItem('Confidence', status.faceConfidence.toStringAsFixed(2), Icons.speed_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _StatusTile(item: items[index]),
    );
  }
}

class _StatusItem {
  const _StatusItem(
    this.label,
    this.value,
    this.icon, {
    this.actionLabel,
    this.actionIcon,
    this.onPressed,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onPressed;
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(item.icon),
            Text(item.label, style: Theme.of(context).textTheme.labelMedium),
            Flexible(
              child: Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (item.actionLabel != null && item.actionIcon != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: item.onPressed,
                  icon: Icon(item.actionIcon, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.actionLabel!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
