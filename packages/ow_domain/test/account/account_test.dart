import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

Account wallet({
  String? vaultItemId,
  BackupStatus backup = const BackupStatus(),
}) => Account(
  id: 'acc-1',
  type: AccountType.wallet,
  name: '测试钱包',
  colorIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  walletSource: WalletSource.metamask,
  vaultItemId: vaultItemId,
  backup: backup,
);

void main() {
  group('Account.backupLevel', () {
    // PRD R34、R35：有无 vaultItemId × offlineBackedUp × keyless 的全部 8 种组合。
    const cases = <(bool, bool, bool, BackupLevel)>[
      // (已入库, 已离线备份, 无助记词, 预期)
      (false, false, false, BackupLevel.none),
      (false, false, true, BackupLevel.keyless),
      (false, true, false, BackupLevel.offlineOnly),
      (false, true, true, BackupLevel.offlineOnly),
      (true, false, false, BackupLevel.inVault),
      (true, false, true, BackupLevel.inVault),
      (true, true, false, BackupLevel.inVaultAndOffline),
      (true, true, true, BackupLevel.inVaultAndOffline),
    ];

    for (final (inVault, offline, keyless, level) in cases) {
      test('backupLevel_入库$inVault离线$offline无助记词${keyless}_为${level.name}', () {
        final account = wallet(
          vaultItemId: inVault ? 'vault-1' : null,
          backup: BackupStatus(offlineBackedUp: offline, keyless: keyless),
        );
        expect(account.backupLevel, level);
      });
    }

    test('backupLevel_离线核对日期_不影响状态', () {
      final account = wallet(
        backup: BackupStatus(offlineVerifiedAt: DateTime.utc(2026, 5, 1)),
      );
      expect(account.backupLevel, BackupLevel.none);
    });

    test('backupLevel_解除保险库关联_由已入库回到未备份', () {
      final linked = wallet(vaultItemId: 'vault-1');
      expect(linked.backupLevel, BackupLevel.inVault);
      final unlinked = linked.copyWith(vaultItemId: null);
      expect(unlinked.vaultItemId, isNull);
      expect(unlinked.backupLevel, BackupLevel.none);
    });
  });

  group('Account 值语义', () {
    test('copyWith_不传参数_得到相等的副本', () {
      final a = wallet(vaultItemId: 'vault-1');
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
    });

    test('copyWith_改名_其余字段不变', () {
      final a = wallet(vaultItemId: 'vault-1');
      final b = a.copyWith(name: '新名字');
      expect(b.name, '新名字');
      expect(b.vaultItemId, 'vault-1');
      expect(b.walletSource, WalletSource.metamask);
      expect(b, isNot(a));
    });

    test('BackupStatus_copyWith_可清除核对日期', () {
      final s = BackupStatus(
        offlineBackedUp: true,
        offlineVerifiedAt: DateTime.utc(2026, 5, 1),
      );
      expect(s.copyWith(offlineVerifiedAt: null).offlineVerifiedAt, isNull);
      expect(s.copyWith().offlineVerifiedAt, DateTime.utc(2026, 5, 1));
      expect(s.copyWith(), s);
    });
  });

  group('WatchAddress', () {
    WatchAddress address(Set<String> chains) => WatchAddress(
      id: 'addr-1',
      accountId: 'acc-1',
      family: ChainFamily.evm,
      address: '0x${'0' * 40}',
      enabledChainIds: chains,
    );

    test('WatchAddress_链集合顺序不同_相等且哈希相同', () {
      final a = address({'ethereum', 'base'});
      final b = address({'base', 'ethereum'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(address({'ethereum'})));
    });

    test('WatchAddress_链集合_不可修改且不受外部修改影响', () {
      final source = {'ethereum'};
      final a = address(source);
      source.add('base');
      expect(a.enabledChainIds, {'ethereum'});
      expect(() => a.enabledChainIds.add('bsc'), throwsUnsupportedError);
    });
  });
}
