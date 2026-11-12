import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

// 指纹为明显的构造样例，不是真实的带密钥哈希。
final _fingerprint = 'f' * 16;

VaultItemMeta mnemonic({
  String id = 'vault-1',
  String name = '主助记词',
  int? wordCount = 12,
  bool hasPassphrase = false,
  DateTime? createdAt,
}) => VaultItemMeta(
  id: id,
  name: name,
  kind: VaultItemKind.mnemonic,
  wordCount: wordCount,
  hasPassphrase: hasPassphrase,
  fingerprint: _fingerprint,
  createdAt: createdAt ?? DateTime.utc(2026, 2, 1),
);

VaultItemMeta privateKey({
  String id = 'vault-2',
  String name = '测试私钥',
  ChainFamily family = ChainFamily.evm,
}) => VaultItemMeta(
  id: id,
  name: name,
  kind: VaultItemKind.privateKey,
  family: family,
  hasPassphrase: false,
  fingerprint: _fingerprint,
  createdAt: DateTime.utc(2026, 2, 2),
);

void main() {
  group('VaultItemMeta', () {
    test('VaultItemMeta_助记词条目_字段可读', () {
      final m = mnemonic(hasPassphrase: true);
      expect(m.id, 'vault-1');
      expect(m.name, '主助记词');
      expect(m.kind, VaultItemKind.mnemonic);
      expect(m.wordCount, 12);
      expect(m.family, isNull);
      expect(m.hasPassphrase, isTrue);
      expect(m.fingerprint, _fingerprint);
      expect(m.createdAt, DateTime.utc(2026, 2, 1));
    });

    test('VaultItemMeta_私钥条目_助记词字数为null_所属链家族有值', () {
      final m = privateKey(family: ChainFamily.tron);
      expect(m.kind, VaultItemKind.privateKey);
      expect(m.wordCount, isNull);
      expect(m.family, ChainFamily.tron);
    });

    test('copyWith_改名_只替换名称', () {
      final original = mnemonic(hasPassphrase: true);
      final renamed = original.copyWith(name: '新名字');
      expect(renamed.name, '新名字');
      expect(renamed.id, original.id);
      expect(renamed.kind, original.kind);
      expect(renamed.wordCount, original.wordCount);
      expect(renamed.family, original.family);
      expect(renamed.hasPassphrase, original.hasPassphrase);
      expect(renamed.fingerprint, original.fingerprint);
      expect(renamed.createdAt, original.createdAt);
      expect(renamed, isNot(original));
    });

    test('copyWith_不传参数_得到相等的副本', () {
      final original = privateKey();
      final copy = original.copyWith();
      expect(copy, original);
      expect(copy.name, original.name);
      expect(copy.hashCode, original.hashCode);
    });

    test('VaultItemMeta_字段相同_相等且哈希相同', () {
      final a = mnemonic();
      final b = mnemonic();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('VaultItemMeta_任一字段不同_不相等', () {
      final base = mnemonic();
      expect(mnemonic(id: 'vault-9'), isNot(base));
      expect(mnemonic(name: '别的名字'), isNot(base));
      expect(mnemonic(wordCount: 24), isNot(base));
      expect(mnemonic(wordCount: null), isNot(base));
      expect(mnemonic(hasPassphrase: true), isNot(base));
      expect(mnemonic(createdAt: DateTime.utc(2026, 2, 3)), isNot(base));
      expect(
        VaultItemMeta(
          id: 'vault-1',
          name: '主助记词',
          kind: VaultItemKind.mnemonic,
          wordCount: 12,
          hasPassphrase: false,
          fingerprint: 'e' * 16,
          createdAt: DateTime.utc(2026, 2, 1),
        ),
        isNot(base),
      );
      expect(
        VaultItemMeta(
          id: 'vault-1',
          name: '主助记词',
          kind: VaultItemKind.privateKey,
          family: ChainFamily.evm,
          hasPassphrase: false,
          fingerprint: _fingerprint,
          createdAt: DateTime.utc(2026, 2, 1),
        ),
        isNot(base),
      );
      expect(privateKey(family: ChainFamily.solana), isNot(privateKey()));
    });

    test('toString_含id与条目类型', () {
      expect(mnemonic().toString(), 'VaultItemMeta(vault-1, mnemonic)');
      expect(privateKey().toString(), 'VaultItemMeta(vault-2, privateKey)');
    });
  });
}
