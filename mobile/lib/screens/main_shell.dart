import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_log_item.dart';
import '../providers/event_log_provider.dart';
import '../providers/network_config_provider.dart';
import 'events_face_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkConfigProvider>().initialize();
      context.read<EventLogProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      EventsFaceScreen(),
      SettingsScreen(),
    ];

    return Consumer<EventLogProvider>(
      builder: (context, events, _) {
        _scheduleStrangerDialog(events);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Home Guardian'),
            centerTitle: false,
          ),
          body: screens[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Events',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleStrangerDialog(EventLogProvider provider) {
    if (_dialogShowing) {
      return;
    }
    final alert = provider.consumePendingStrangerAlert();
    if (alert == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStrangerDialog(alert));
  }

  Future<void> _showStrangerDialog(EventLogItem alert) async {
    if (!mounted) {
      return;
    }
    _dialogShowing = true;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Stranger detected'),
          content: Text('${alert.message}\n\n${alert.createdAt}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    _dialogShowing = false;
    if (mounted) {
      setState(() {});
    }
  }
}
