import 'package:flutter/widgets.dart';
import 'package:ow_platform/ow_platform.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/bootstrap_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BootstrapHost(
      bootstrap: () => bootstrapApp(
        secrets: SecureSecretStore(),
        opener: SqlCipherDatabaseOpener(),
      ),
    ),
  );
}
