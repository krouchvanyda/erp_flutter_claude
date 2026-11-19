import 'package:flutter/material.dart';

/// Plain `flutter run`.
Future<void> main() => bootstrap();

/// Shared start-up for every entry point (main_dev / main_uat / main_prod).
/// Step 1 will add flavor, DI, theme and router here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HelloApp());
}

class HelloApp extends StatelessWidget {
  const HelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Hello — clean slate')),
      ),
    );
  }
}
