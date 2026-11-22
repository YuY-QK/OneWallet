import 'package:integration_test/integration_test.dart';

import '../test/integration/add_evm_wallet_flow_test.dart' as test_flow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test_flow.main();
}
