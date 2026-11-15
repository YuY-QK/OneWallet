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

  group('Account 复制与相等的其余分支', () {
    final exchange = Account(
      id: 'acc-2',
      type: AccountType.exchange,
      name: '交易所账户',
      colorIndex: 3,
      createdAt: DateTime.utc(2026, 1, 5),
      exchange: ExchangeId.binance,
    );

    test('copyWith_显式传null_清除钱包来源与交易所', () {
      final a = wallet(vaultItemId: 'vault-1');
      expect(a.copyWith(walletSource: null).walletSource, isNull);
      expect(exchange.copyWith(exchange: null).exchange, isNull);
    });

    test('copyWith_替换钱包来源与备份状态', () {
      final a = wallet();
      final b = a.copyWith(
        walletSource: WalletSource.uniswap,
        backup: const BackupStatus(keyless: true),
      );
      expect(b.walletSource, WalletSource.uniswap);
      expect(b.backup.keyless, isTrue);
      expect(b.backupLevel, BackupLevel.keyless);
    });

    test('copyWith_不传可空字段_保留原值', () {
      final a = wallet(vaultItemId: 'vault-1');
      final b = a.copyWith(colorIndex: 5, note: '备注');
      expect(b.colorIndex, 5);
      expect(b.note, '备注');
      expect(b.vaultItemId, 'vault-1');
      expect(b.walletSource, WalletSource.metamask);
      expect(b.createdAt, a.createdAt);
      expect(b.type, AccountType.wallet);
      expect(b.id, 'acc-1');
    });

    test('Account_任一字段不同_不相等', () {
      final base = wallet(vaultItemId: 'vault-1');
      expect(base.copyWith(colorIndex: 1), isNot(base));
      expect(base.copyWith(note: '备注'), isNot(base));
      expect(base.copyWith(walletSource: WalletSource.other), isNot(base));
      expect(base.copyWith(vaultItemId: null), isNot(base));
      expect(
        base.copyWith(backup: const BackupStatus(keyless: true)),
        isNot(base),
      );
      expect(exchange.copyWith(exchange: ExchangeId.okx), isNot(exchange));
    });

    test('Account_字段相同_相等且哈希相同', () {
      expect(exchange, exchange.copyWith());
      expect(exchange.hashCode, exchange.copyWith().hashCode);
    });

    test('toString_含id与账户类型', () {
      expect(wallet().toString(), 'Account(acc-1, AccountType.wallet)');
      expect(exchange.toString(), 'Account(acc-2, AccountType.exchange)');
    });
  });

  group('WalletSourceMapping 与 Account 钱包来源派生', () {
    test('WalletSourceMapping_已知五种来源_双向映射一致', () {
      const pairs = [
        ('uniswap-wallet', WalletSource.uniswap),
        ('metamask', WalletSource.metamask),
        ('okx-web3-wallet', WalletSource.okxWeb3),
        ('bitget-wallet', WalletSource.bitgetWallet),
        ('trust-wallet', WalletSource.trustWallet),
      ];
      for (final (id, source) in pairs) {
        expect(WalletSourceMapping.toWalletSource(id), source);
        expect(WalletSourceMapping.toDirectoryId(source), id);
      }
    });

    test('WalletSourceMapping_未知与其他映射规则', () {
      expect(WalletSourceMapping.toWalletSource('phantom'), WalletSource.other);
      expect(
        WalletSourceMapping.toWalletSource('unknown-wallet'),
        WalletSource.other,
      );
      expect(WalletSourceMapping.toWalletSource(null), WalletSource.other);
      expect(WalletSourceMapping.toDirectoryId(WalletSource.other), isNull);
      expect(WalletSourceMapping.toDirectoryId(null), isNull);
    });

    test('Account.wallet_传入已知id_自动派生walletSource', () {
      final a = Account.wallet(
        id: 'acc-w',
        name: '钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSourceId: 'okx-web3-wallet',
      );
      expect(a.walletSourceId, 'okx-web3-wallet');
      expect(a.walletSource, WalletSource.okxWeb3);
      expect(a.type, AccountType.wallet);
    });

    test('Account.wallet_传入未知目录id_派生other', () {
      final a = Account.wallet(
        id: 'acc-w2',
        name: '钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSourceId: 'phantom',
      );
      expect(a.walletSourceId, 'phantom');
      expect(a.walletSource, WalletSource.other);
    });

    test('Account.wallet_传入null_表示其他且派生other', () {
      final a = Account.wallet(
        id: 'acc-w3',
        name: '钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSourceId: null,
      );
      expect(a.walletSourceId, isNull);
      expect(a.walletSource, WalletSource.other);
    });

    test('Account_仅传入walletSource_反推walletSourceId', () {
      final a = Account(
        id: 'acc-w4',
        type: AccountType.wallet,
        name: '备份恢复钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSource: WalletSource.trustWallet,
      );
      expect(a.walletSourceId, 'trust-wallet');
      expect(a.walletSource, WalletSource.trustWallet);

      final other = Account(
        id: 'acc-w5',
        type: AccountType.wallet,
        name: '备份恢复其他钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSource: WalletSource.other,
      );
      expect(other.walletSourceId, isNull);
      expect(other.walletSource, WalletSource.other);
    });

    test('Account.copyWith_更新walletSourceId_同步派生walletSource', () {
      final a = Account.wallet(
        id: 'acc-w6',
        name: '钱包',
        colorIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        walletSourceId: 'metamask',
      );
      final b = a.copyWith(walletSourceId: 'bitget-wallet');
      expect(b.walletSourceId, 'bitget-wallet');
      expect(b.walletSource, WalletSource.bitgetWallet);

      final c = b.copyWith(walletSourceId: 'rabby');
      expect(c.walletSourceId, 'rabby');
      expect(c.walletSource, WalletSource.other);
    });

    test('Account.exchange_工厂方法构造_属性正确', () {
      final acc = Account.exchange(
        id: 'acc-ex1',
        name: 'Binance 主账户',
        colorIndex: 3,
        createdAt: DateTime.utc(2026, 1, 1),
        exchange: ExchangeId.binance,
        note: '只读观察',
      );
      expect(acc.id, 'acc-ex1');
      expect(acc.type, AccountType.exchange);
      expect(acc.name, 'Binance 主账户');
      expect(acc.colorIndex, 3);
      expect(acc.exchange, ExchangeId.binance);
      expect(acc.note, '只读观察');
      expect(acc.walletSourceId, isNull);
      expect(acc.walletSource, isNull);
      expect(acc.vaultItemId, isNull);
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
