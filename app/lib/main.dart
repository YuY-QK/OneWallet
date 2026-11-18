import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ow_application/ow_application.dart';
import 'package:ow_platform/ow_platform.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/bootstrap_host.dart';
import 'features/backup/application/backup_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(DefaultBackupFileHandler.cleanTempExportDir());
  final secrets = SecureSecretStore();
  final opener = SqlCipherDatabaseOpener();
  final vaultStorage = FileVaultStorage();
  final hwKeyStore = DeviceHardwareKeyStore();
  final wipeAllData = WipeAllData(
    databaseDeleter: opener,
    vaultStorage: vaultStorage,
    secrets: secrets,
    hardwareKeyStore: hwKeyStore,
  );
  runApp(
    BootstrapHost(
      bootstrap: () => bootstrapApp(secrets: secrets, opener: opener),
      wipeAllData: wipeAllData,
    ),
  );
}
