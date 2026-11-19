import 'core/config/flavor.dart';
import 'main.dart' show bootstrap;

/// Entry point for the `dev` flavor:
/// `flutter run --flavor dev -t lib/main_dev.dart`
Future<void> main() => bootstrap(Flavor.dev);
