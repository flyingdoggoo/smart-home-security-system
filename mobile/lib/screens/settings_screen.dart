import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/network_config_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = context.watch<NetworkConfigProvider>().serverUrl;
    if (_controller.text != url) {
      _controller.text = url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NetworkConfigProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isError = provider.message?.toLowerCase().contains('failed') ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF3E6EDC), const Color(0xFF2A9AC4)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Network Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dùng địa chỉ backend trong cùng mạng Wi-Fi để app điều khiển thiết bị ổn định.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Android Emulator',
                    value: 'http://10.0.2.2:8000',
                    onTap: _applyPreset,
                  ),
                  _PresetChip(
                    label: 'LAN localhost',
                    value: 'http://127.0.0.1:8000',
                    onTap: _applyPreset,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend URL',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://10.246.248.2:8000',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => provider.setServerUrl(_controller.text),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Lưu'),
                    ),
                    OutlinedButton.icon(
                      onPressed: provider.testing
                          ? null
                          : provider.testConnection,
                      icon: provider.testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                      label: const Text('Kiểm tra kết nối'),
                    ),
                    TextButton.icon(
                      onPressed: provider.resetServerUrl,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Khôi phục mặc định'),
                    ),
                  ],
                ),
                if (provider.message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (isError ? scheme.error : scheme.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isError ? scheme.error : scheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(provider.message!)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist nhanh',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                const _ChecklistRow(
                  text: 'Backend chạy với host 0.0.0.0 và port 8000',
                ),
                const _ChecklistRow(
                  text: 'Điện thoại và server cùng một Wi-Fi/hotspot',
                ),
                const _ChecklistRow(
                  text: 'ESP main và ESP cam đang online trong cùng mạng',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _applyPreset(String value) {
    _controller.text = value;
    context.read<NetworkConfigProvider>().setServerUrl(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.flash_on_rounded, size: 16),
      label: Text(label),
      onPressed: () => onTap(value),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
