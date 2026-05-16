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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend URL', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Use your laptop LAN IP for physical phone testing.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Server URL',
                    hintText: 'http://192.168.1.23:8000',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => provider.setServerUrl(_controller.text),
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: provider.testing ? null : provider.testConnection,
                      icon: provider.testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check),
                      label: const Text('Test'),
                    ),
                    TextButton.icon(
                      onPressed: provider.resetServerUrl,
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
                if (provider.message != null) ...[
                  const SizedBox(height: 12),
                  Text(provider.message!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Same-network mode: backend must listen on 0.0.0.0:8000 and the phone must be on the same WiFi/LAN.',
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
