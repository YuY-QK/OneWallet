import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:ow_vault/private_key_format.dart';

import 'vault_access.dart';
import 'vault_credential.dart';

/// 派生地址的结果条目。
final class DerivedAddress {
  const DerivedAddress({
    required this.family,
    required this.address,
    this.scheme,
    this.index,
    required this.alreadyWatched,
  });

  final ChainFamily family;

  /// 地址（按各家族的规范化形式）。
  final String address;

  /// 派生方案（私钥条目为 null）。
  final DerivationScheme? scheme;

  /// 派生序号（私钥条目为 null）。
  final int? index;

  /// 该地址是否已在本地任意账户中被观察。
  final bool alreadyWatched;

  @override
  bool operator ==(Object other) =>
      other is DerivedAddress &&
      other.family == family &&
      other.address == address &&
      other.scheme == scheme &&
      other.index == index &&
      other.alreadyWatched == alreadyWatched;

  @override
  int get hashCode =>
      Object.hash(family, address, scheme, index, alreadyWatched);

  @override
  String toString() =>
      'DerivedAddress(${family.name}, $address, scheme: $scheme, index: $index, watched: $alreadyWatched)';
}

final class _MnemonicDeriveArgs {
  const _MnemonicDeriveArgs({
    required this.mnemonicBytes,
    required this.passphraseBytes,
    required this.scheme,
    required this.startIndex,
    required this.count,
  });

  final Uint8List mnemonicBytes;
  final Uint8List? passphraseBytes;
  final DerivationScheme scheme;
  final int startIndex;
  final int count;
}

final class _PrivateKeyDeriveArgs {
  const _PrivateKeyDeriveArgs({
    required this.keyBytes,
    required this.family,
    this.scheme,
  });

  final Uint8List keyBytes;
  final ChainFamily family;
  final DerivationScheme? scheme;
}

List<String> _deriveMnemonicInIsolate(_MnemonicDeriveArgs args) {
  final mnemonicStr = utf8.decode(args.mnemonicBytes);
  final passphraseStr = args.passphraseBytes != null
      ? utf8.decode(args.passphraseBytes!)
      : '';
  final seedRes = AddressDeriver.seedFromMnemonic(
    mnemonicStr,
    passphrase: passphraseStr,
  );
  if (seedRes case Err(:final failure)) {
    throw failure;
  }
  final seed = seedRes.valueOrNull!;
  try {
    final list = <String>[];
    for (var i = 0; i < args.count; i++) {
      list.add(
        AddressDeriver.deriveAddress(
          seed: seed,
          scheme: args.scheme,
          index: args.startIndex + i,
        ),
      );
    }
    return list;
  } finally {
    for (var i = 0; i < seed.length; i++) {
      seed[i] = 0;
    }
  }
}

String _derivePrivateKeyInIsolate(_PrivateKeyDeriveArgs args) {
  final keyStr = utf8.decode(args.keyBytes);
  final sens = Sensitive(Uint8List.fromList(utf8.encode(keyStr)));
  try {
    return PrivateKeyFormat.addressOf(
      args.family,
      sens,
      bitcoinScheme: args.scheme,
    );
  } finally {
    sens.wipe();
  }
}

Future<List<String>> _runMnemonicDerive(_MnemonicDeriveArgs args) {
  return Isolate.run(() => _deriveMnemonicInIsolate(args));
}

Future<String> _runPrivateKeyDerive(_PrivateKeyDeriveArgs args) {
  return Isolate.run(() => _derivePrivateKeyInIsolate(args));
}

/// 派生地址（规格 4.5 节）。
final class DeriveAddresses {
  DeriveAddresses({required this.vaultAccess, required this.addressRepo});

  final VaultAccess vaultAccess;
  final AddressRepository addressRepo;

  Future<Result<List<DerivedAddress>>> call({
    required String itemId,
    required VaultCredential credential,
    required DerivationScheme scheme,
    required int startIndex,
    required int count,
  }) async {
    if (startIndex < 0 || count < 1 || count > 20) {
      return const Err(ValidationFailure('invalid_range'));
    }

    return vaultAccess.withSession(credential, (session) async {
      final readRes = await session.readItem(itemId);
      if (readRes case Err(:final failure)) {
        return Err(failure);
      }
      final secret = readRes.valueOrNull!;

      try {
        switch (secret) {
          case MnemonicSecret(:final mnemonic, :final passphrase):
            final family = scheme.family;
            final mnemonicBytes = mnemonic.use(Uint8List.fromList);
            final passphraseBytes = passphrase?.use(Uint8List.fromList);

            final List<String> addressStrings;
            try {
              final args = _MnemonicDeriveArgs(
                mnemonicBytes: mnemonicBytes,
                passphraseBytes: passphraseBytes,
                scheme: scheme,
                startIndex: startIndex,
                count: count,
              );
              addressStrings = await _runMnemonicDerive(args);
            } finally {
              mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
              passphraseBytes?.fillRange(0, passphraseBytes.length, 0);
            }

            final result = <DerivedAddress>[];
            for (var i = 0; i < count; i++) {
              final addr = addressStrings[i];
              final normalized = AddressCodec.normalize(addr, family);
              final watched = await addressRepo.find(family, normalized);
              result.add(
                DerivedAddress(
                  family: family,
                  address: normalized,
                  scheme: scheme,
                  index: startIndex + i,
                  alreadyWatched: watched != null,
                ),
              );
            }
            return Ok(result);

          case PrivateKeySecret(:final family, :final key):
            if (scheme.family != family) {
              return const Err(ValidationFailure('scheme_family_mismatch'));
            }
            final keyBytes = key.use(Uint8List.fromList);
            final String rawAddr;
            try {
              final args = _PrivateKeyDeriveArgs(
                keyBytes: keyBytes,
                family: family,
                scheme: scheme,
              );
              rawAddr = await _runPrivateKeyDerive(args);
            } on ArgumentError {
              return const Err(ValidationFailure('unsupported_scheme_for_key'));
            } finally {
              keyBytes.fillRange(0, keyBytes.length, 0);
            }

            final normalized = AddressCodec.normalize(rawAddr, family);
            final watched = await addressRepo.find(family, normalized);
            return Ok([
              DerivedAddress(
                family: family,
                address: normalized,
                scheme: null,
                index: null,
                alreadyWatched: watched != null,
              ),
            ]);
        }
      } finally {
        secret.wipe();
      }
    }, allowBiometric: true);
  }
}
