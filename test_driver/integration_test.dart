import 'package:integration_test/integration_test_driver.dart';

/// Driver for `flutter drive`.
///
/// Writes the map the test assigns to `binding.reportData` into
/// `integration_response_data.json` next to the project root, which is what
/// `docs/performance/plan.md` records as the device baseline.
Future<void> main() => integrationDriver();
