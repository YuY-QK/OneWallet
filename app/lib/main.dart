import 'package:flutter/widgets.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_platform/ow_platform.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/bootstrap_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final secrets = SecureSecretStore();
  final opener = SqlCipherDatabaseOpener();
  final vaultStorage = FileVaultStorage();
  final wipeAllData = WipeAllData(
    databaseDeleter: opener,
    vaultStorage: vaultStorage,
    secrets: secrets,
  );
  runApp(
    BootstrapHost(
      bootstrap: () => bootstrapApp(secrets: secrets, opener: opener),
      wipeAllData: wipeAllData,
    ),
  );
}
