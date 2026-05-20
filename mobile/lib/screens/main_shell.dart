import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_log_item.dart';
import '../providers/event_log_provider.dart';
import '../providers/home_status_provider.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final screens = const [HomeScreen(), EventsFaceScreen(), SettingsScreen()];
    final serverUrl = context.watch<NetworkConfigProvider>().serverUrl;

    return Consumer<EventLogProvider>(
      builder: (context, events, _) {
        _scheduleStrangerDialog(events);
        final hasSecurityAlert = events.events.any(
          (event) => event.isStrangerAlert,
        );

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Home Guardian'),
                Text(
                  serverUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton.filledTonal(
                  onPressed: () => _refreshCurrentTab(context),
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'Refresh now',
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.08),
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: screens[_index],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: hasSecurityAlert,
                      smallSize: 8,
                      backgroundColor: scheme.error,
                      child: const Icon(Icons.fact_check_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: hasSecurityAlert,
                      smallSize: 8,
                      backgroundColor: scheme.error,
                      child: const Icon(Icons.fact_check),
                    ),
                    label: 'Events',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshCurrentTab(BuildContext context) async {
    if (_index == 0) {
      await Future.wait([
        context.read<HomeStatusProvider>().refresh(),
        context.read<EventLogProvider>().refresh(),
      ]);
      return;
    }
    if (_index == 1) {
      await Future.wait([
        context.read<HomeStatusProvider>().refresh(),
        context.read<EventLogProvider>().refresh(),
      ]);
      return;
    }
    await context.read<NetworkConfigProvider>().initialize();
  }

  void _scheduleStrangerDialog(EventLogProvider provider) {
    if (_dialogShowing) {
      return;
    }
    final alert = provider.consumePendingStrangerAlert();
    if (alert == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showStrangerDialog(alert),
    );
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
          icon: const Icon(Icons.warning_amber_rounded, size: 30),
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
