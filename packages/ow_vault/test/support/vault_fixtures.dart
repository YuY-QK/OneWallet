import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';

/// BIP39 官方测试向量里的公开助记词，不对应任何真实资产。
const abandon =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
const legal =
    'legal winner thank year wave sausage worth useful legal winner '
    'thank yellow';

/// 明显的假私钥：32 个 0x11。
Uint8List fakePrivateKey([int byte = 0x11]) =>
    Uint8List.fromList(List.filled(32, byte));

/// 测试用的极小 Argon2id 参数，加快测试。
final fastParams = KdfParams(memKib: 8, iterations: 1);

Sensitive sensitive(String text) => Sensitive(utf8.encode(text));

String textOf(Sensitive value) => value.use(utf8.decode);

MnemonicSecret mnemonicSecret(String words, {String? passphrase}) =>
    MnemonicSecret(
      mnemonic: sensitive(words),
      passphrase: passphrase == null ? null : sensitive(passphrase),
    );

PrivateKeySecret privateKeySecret([int byte = 0x11]) => PrivateKeySecret(
  family: ChainFamily.evm,
  key: Sensitive(fakePrivateKey(byte)),
);

/// 内存中的假存储。可让下一次写入在保存前或保存后抛出异常，或让读取抛出异常。
final class MemoryVaultStorage implements VaultStorage {
  Uint8List? bytes;
  int writes = 0;
  bool failBeforeStore = false;
  bool failAfterStore = false;
  bool failRead = false;

  @override
  Future<Uint8List?> read() async {
    if (failRead) throw Exception('读取失败（测试）');
    final b = bytes;
    return b == null ? null : Uint8List.fromList(b);
  }

  @override
  Future<void> writeAtomic(Uint8List data) async {
    // 让出一次事件循环，使并发写入有机会交错（如果没有串行化的话）。
    await Future<void>.delayed(Duration.zero);
    if (failBeforeStore) throw Exception('写入失败（测试）');
    bytes = Uint8List.fromList(data);
    writes++;
    if (failAfterStore) throw Exception('写入后收尾失败（测试）');
  }

  @override
  Future<void> delete() async => bytes = null;

  /// 当前文件的 JSON。
  Map<String, Object?> get json =>
      jsonDecode(utf8.decode(bytes!)) as Map<String, Object?>;

  set json(Map<String, Object?> value) =>
      bytes = utf8.encode(jsonEncode(value));

  /// 第 [index] 个条目（可修改的副本，改完用 [json] 写回）。
  static Map<String, Object?> itemOf(Map<String, Object?> json, int index) =>
      (json['items']! as List<Object?>)[index]! as Map<String, Object?>;
}

/// 取出 `Ok` 的值，不是 `Ok` 时抛出（测试用）。
T okValue<T>(Result<T> result) =>
    result.when(ok: (v) => v, err: (f) => throw StateError('期望 Ok，实际为 $f'));

/// 取出 `Err` 的失败，不是 `Err` 时抛出（测试用）。
Failure errOf<T>(Result<T> result) =>
    result.when(ok: (_) => throw StateError('期望 Err，实际为 Ok'), err: (f) => f);
