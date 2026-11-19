import 'core/config/flavor.dart';
import 'main.dart' show bootstrap;

/// Entry point for the `prod` flavor:
/// `flutter run --flavor prod -t lib/main_prod.dart`
Future<void> main() => bootstrap(Flavor.prod);
