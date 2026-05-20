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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              _ConnectionBanner(provider: provider),
              const SizedBox(height: 14),
              if (status == null)
                const _EmptyStatus()
              else ...[
                _HeroSummary(status: status),
                const SizedBox(height: 14),
                _QuickActions(status: status, provider: provider),
                const SizedBox(height: 14),
                _SafetyPanel(status: status),
                const SizedBox(height: 14),
                _TelemetryGrid(status: status),
              ],
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
    final scheme = Theme.of(context).colorScheme;
    final online = provider.error == null;
    final color = online ? const Color(0xFF0B8F64) : const Color(0xFFC96A00);
    final text = online
        ? provider.busy
              ? 'Đang đồng bộ dữ liệu...'
              : 'Kết nối ổn định'
        : 'Mất kết nối: ${provider.error}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.wifi_tethering_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Làm mới',
            onPressed: provider.busy ? null : provider.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatus extends StatelessWidget {
  const _EmptyStatus();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text('Đang chờ dữ liệu trạng thái từ backend...'),
          ],
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.status});

  final SystemStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final securityLabel = switch (status.faceLabel) {
      'owner' => 'Chủ nhà',
      'stranger' => 'Người lạ',
      _ => 'Không có khuôn mặt',
    };
    final doorUnlocked = status.doorState == 'unlocked';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.94),
            const Color(0xFF0C8A96),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                doorUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                doorUnlocked ? 'Cửa đang mở' : 'Cửa đang khóa',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlowChip(
                icon: status.gasAlert
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                text: status.gasAlert ? 'Gas cảnh báo' : 'Gas an toàn',
              ),
              _GlowChip(icon: Icons.face_rounded, text: securityLabel),
              _GlowChip(
                icon: status.isDark
                    ? Icons.dark_mode_rounded
                    : Icons.wb_sunny_rounded,
                text: status.isDark ? 'Trời tối' : 'Trời sáng',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowChip extends StatelessWidget {
  const _GlowChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.status, required this.provider});

  final SystemStatus status;
  final HomeStatusProvider provider;

  @override
  Widget build(BuildContext context) {
    final doorUnlocked = status.doorState == 'unlocked';
    final lightOn = status.lightState == 'on';

    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'Khóa cửa',
            subtitle: doorUnlocked ? 'Hiện đang mở' : 'Hiện đang khóa',
            icon: doorUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
            actionText: doorUnlocked ? 'Đóng cửa' : 'Mở cửa',
            onPressed: provider.busy
                ? null
                : () => provider.setDoor(doorUnlocked ? 'close' : 'open'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            title: 'Đèn phòng',
            subtitle: lightOn ? 'Đang bật' : 'Đang tắt',
            icon: lightOn
                ? Icons.lightbulb_rounded
                : Icons.lightbulb_outline_rounded,
            actionText: lightOn ? 'Tắt đèn' : 'Bật đèn',
            onPressed: provider.busy
                ? null
                : () => provider.setLight(lightOn ? 'off' : 'on'),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onPressed,
                child: Text(actionText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({required this.status});

  final SystemStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An toàn hệ thống',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SafetyRow(
              label: 'Nồng độ gas',
              value: status.gasValue.toStringAsFixed(0),
              statusLabel: status.gasAlert ? 'Cảnh báo' : 'Ổn định',
              statusColor: status.gasAlert
                  ? const Color(0xFFD14343)
                  : const Color(0xFF1A9E69),
            ),
            const SizedBox(height: 10),
            _SafetyRow(
              label: 'Môi trường sáng',
              value: status.lightValue.toStringAsFixed(0),
              statusLabel: status.isDark ? 'Tối' : 'Sáng',
              statusColor: status.isDark
                  ? const Color(0xFF5D5FC6)
                  : const Color(0xFF15A388),
            ),
            const SizedBox(height: 10),
            _SafetyRow(
              label: 'Nhận diện khuôn mặt',
              value: status.faceLabel,
              statusLabel: 'Conf ${status.faceConfidence.toStringAsFixed(2)}',
              statusColor: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.label,
    required this.value,
    required this.statusLabel,
    required this.statusColor,
  });

  final String label;
  final String value;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TelemetryGrid extends StatelessWidget {
  const _TelemetryGrid({required this.status});

  final SystemStatus status;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTileData(
        'Face distance',
        status.faceDistance?.toStringAsFixed(3) ?? '-',
        Icons.straighten,
      ),
      _MetricTileData(
        'Số khuôn mặt',
        status.faceCount.toString(),
        Icons.groups_rounded,
      ),
      _MetricTileData('Nguồn dữ liệu', status.source, Icons.memory_rounded),
      _MetricTileData(
        'Auto light',
        status.lightAutoSuppressed ? 'Manual' : 'Auto',
        Icons.tungsten_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.45,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _MetricTile(data: tiles[index]),
    );
  }
}

class _MetricTileData {
  const _MetricTileData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricTileData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(data.icon, color: scheme.primary),
            Text(
              data.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
