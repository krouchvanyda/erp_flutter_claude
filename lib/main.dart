import 'package:flutter/material.dart';

import 'core/config/flavor.dart';

/// Plain `flutter run`: flavor comes from `--flavor` (dev when none).
Future<void> main() => bootstrap(Flavor.current);

/// Shared start-up for every entry point (main_dev / main_uat / main_prod).
Future<void> bootstrap(Flavor flavor) async {
  Flavor.pin(flavor);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HelloApp());
}

class HelloApp extends StatelessWidget {
  const HelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final flavor = Flavor.current;
    return MaterialApp(
      title: flavor.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            '${flavor.appName}\n${flavor.apiBaseUrl}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
