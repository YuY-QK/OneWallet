import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../support/backup_fixtures.dart';
import '../support/vault_fixtures.dart';

/// 互操作（M5-02 验收）：Dart 生成的备份文件由独立工具
/// tools/backup_decrypt/owbak_decrypt.py（Python + PyNaCl）解开，输出与原载荷逐字段比对。
///
/// 需要 python3 与 PyNaCl；检测不到时跳过并说明原因（CI 中会先 `pip install pynacl`）。
void main() {
  const tool = '../../tools/backup_decrypt/owbak_decrypt.py';
  final skip = _skipReason();
  late SodiumVaultCrypto crypto;
  late Directory dir;

  setUpAll(() async {
    crypto = await SodiumVaultCrypto.load();
    dir = await Directory.systemTemp.createTemp('owbak_interop_');
  });
  tearDownAll(() async => dir.delete(recursive: true));

  Future<File> write(Uint8List bytes, [String name = 'b.owbak']) async =>
      File('${dir.path}/$name').writeAsBytes(bytes);

  Future<File> sample() async => write(
    await BackupCodec.encode(
      payload: samplePayload(withCredentials: true),
      password: sensitive(backupPassword),
      crypto: crypto,
      params: fastParams,
      createdAt: t0,
      appVersion: '1.0.0+1',
    ),
  );

  Future<ProcessResult> runTool(
    File file, {
    String password = backupPassword,
    List<String> extra = const [],
  }) async {
    final p = await Process.start('python3', [
      tool,
      file.path,
      '--password-stdin',
      ...extra,
    ]);
    p.stdin.add(utf8.encode('$password\n'));
    await p.stdin.close();
    final out = p.stdout.transform(utf8.decoder).join();
    final err = p.stderr.transform(utf8.decoder).join();
    return ProcessResult(p.pid, await p.exitCode, await out, await err);
  }

  test('Dart生成_Python解密_输出与原载荷逐字段相同', () async {
    final r = await runTool(await sample());
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final json = jsonDecode(r.stdout as String) as Map<String, Object?>;
    expect(json, _expectedJson(samplePayload(withCredentials: true)));
  }, skip: skip);

  test('仓库中的版本1样本_Python也能解开', () async {
    final r = await runTool(File('test/fixtures/backup_v1_sample.owbak'));
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final json = jsonDecode(r.stdout as String) as Map<String, Object?>;
    expect(json, _expectedJson(samplePayload(withCredentials: true)));
  }, skip: skip);

  test('错误密码_非零退出且标准输出为空', () async {
    final r = await runTool(await sample(), password: 'wrong-password');
    expect(r.exitCode, 1);
    expect(r.stdout, isEmpty);
    expect(r.stderr, contains('密码不正确'));
    expect(r.stderr, isNot(contains('Traceback')));
  }, skip: skip);

  test('篡改任一字节_非零退出且标准输出为空', () async {
    final original = await (await sample()).readAsBytes();
    for (final index in [0, 4, 12, original.length ~/ 2, original.length - 1]) {
      final bytes = Uint8List.fromList(original)..[index] ^= 0x01;
      final r = await runTool(await write(bytes, 't$index.owbak'));
      expect(r.exitCode, isNot(0), reason: '偏移 $index');
      expect(r.stdout, isEmpty, reason: '偏移 $index');
    }
  }, skip: skip);

  test('--mnemonics-only_逐条打印名称与助记词', () async {
    final r = await runTool(await sample(), extra: ['--mnemonics-only']);
    expect(r.exitCode, 0);
    final lines = (r.stdout as String).trim().split('\n');
    expect(lines, [
      '测试助记词（带附加密码）：$abandon',
      '  附加密码（第 25 个词）：TREZOR',
      'legal：$legal',
      '二进制私钥（evm 私钥）：${'11' * 32}（十六进制）',
      '文本私钥（evm 私钥）：$fakeTextPrivateKey',
    ]);
  }, skip: skip);

  test('--out_写入仅本人可读的文件_不打印内容_不覆盖已有文件', () async {
    final out = '${dir.path}/out.json';
    final file = await sample();
    final r = await runTool(file, extra: ['--out', out]);
    expect(r.exitCode, 0);
    expect(r.stdout, isEmpty);
    expect(r.stderr, contains('用完请立即删除'));
    final stat = await File(out).stat();
    expect(stat.mode & 0x1ff, 0x180); // 0600
    expect(
      jsonDecode(await File(out).readAsString()),
      isA<Map<String, Object?>>(),
    );
    final again = await runTool(file, extra: ['--out', out]);
    expect(again.exitCode, isNot(0));
  }, skip: skip);
}

String? _skipReason() {
  try {
    final r = Process.runSync('python3', ['-c', 'import nacl.bindings']);
    return r.exitCode == 0
        ? null
        : '跳过：python3 中没有 PyNaCl（pip install pynacl 后可运行互操作测试）';
  } on ProcessException {
    return '跳过：找不到 python3（安装 Python 3 与 PyNaCl 后可运行互操作测试）';
  }
}

String _t(DateTime t) => t.toUtc().toIso8601String();

String _text(Sensitive s) => s.use(utf8.decode);

String _hex(Sensitive s) =>
    s.use((b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join());

/// 按 FORMAT.md 第 5 节，从 [p] 直接写出期望的载荷 JSON（不经过 PayloadWriter）。
/// 样本里二进制私钥（32 个 0x11）写十六进制，其余密钥内容写文本。
Map<String, Object?> _expectedJson(BackupPayload p) => {
  'format': 'onewallet-backup',
  'payload_version': 1,
  'exported_at': _t(p.exportedAt),
  'accounts': [
    for (final a in p.accounts)
      {
        'id': a.id,
        'type': a.type.name,
        'name': a.name,
        'color_index': a.colorIndex,
        'note': a.note,
        'wallet_source': a.walletSource?.name,
        'exchange': a.exchange?.name,
        'vault_item_id': a.vaultItemId,
        'backup': {
          'offline_backed_up': a.backup.offlineBackedUp,
          'offline_verified_at': a.backup.offlineVerifiedAt == null
              ? null
              : _t(a.backup.offlineVerifiedAt!),
          'keyless': a.backup.keyless,
        },
        'created_at': _t(a.createdAt),
      },
  ],
  'addresses': [
    for (final a in p.addresses)
      {
        'id': a.id,
        'account_id': a.accountId,
        'family': a.family.name,
        'address': a.address,
        'enabled_chains': [...a.enabledChainIds]..sort(),
        'scheme': a.scheme?.name,
        'derivation_index': a.derivationIndex,
        'note': a.note,
      },
  ],
  'vault_items': [
    for (final i in p.vaultItems)
      {
        'id': i.id,
        'name': i.name,
        'kind': i.kind == VaultItemKind.mnemonic ? 'mnemonic' : 'private_key',
        'created_at': _t(i.createdAt),
        'linked_account_ids': p.linkedAccountIds(i.id),
        ...switch (i.secret) {
          MnemonicSecret(:final mnemonic, :final passphrase) => {
            'mnemonic': _text(mnemonic),
            if (passphrase != null) 'passphrase': _text(passphrase),
          },
          PrivateKeySecret(:final family, :final key) =>
            i.id == 'item-key-hex'
                ? {
                    'encoding': 'hex',
                    'family': family.name,
                    'private_key': _hex(key),
                  }
                : {'family': family.name, 'private_key': _text(key)},
        },
      },
  ],
  'settings': {
    'quote': p.settings.quote.name,
    'hide_small': p.settings.hideSmall,
    'theme': p.settings.theme.name,
    'auto_lock': p.settings.autoLock.name,
  },
  'exchange_credentials': [
    for (final c in p.exchangeCredentials!)
      {
        'account_id': c.accountId,
        'api_key': _text(c.credentials.apiKey),
        'api_secret': _text(c.credentials.apiSecret),
        'passphrase': _text(c.credentials.passphrase!),
      },
  ],
};
