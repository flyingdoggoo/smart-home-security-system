import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/event_log_provider.dart';
import 'providers/home_status_provider.dart';
import 'providers/network_config_provider.dart';
import 'screens/main_shell.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkConfigProvider()),
        ChangeNotifierProxyProvider<NetworkConfigProvider, HomeStatusProvider>(
          create: (_) => HomeStatusProvider(),
          update: (_, network, provider) =>
              (provider ?? HomeStatusProvider())..updateServerUrl(network.serverUrl),
        ),
        ChangeNotifierProxyProvider<NetworkConfigProvider, EventLogProvider>(
          create: (_) => EventLogProvider(),
          update: (_, network, provider) =>
              (provider ?? EventLogProvider())..updateServerUrl(network.serverUrl),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Home Guardian',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1769aa)),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}
