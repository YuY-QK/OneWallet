import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

// 地址为明显的构造样例。
final _address = '0x${'a' * 40}';

WatchAddress watch({
  String id = 'addr-1',
  String accountId = 'acc-1',
  ChainFamily family = ChainFamily.evm,
  Set<String> chains = const {'ethereum', 'base'},
  DerivationScheme? scheme,
  int? derivationIndex,
  String note = '',
}) => WatchAddress(
  id: id,
  accountId: accountId,
  family: family,
  address: _address,
  enabledChainIds: chains,
  scheme: scheme,
  derivationIndex: derivationIndex,
  note: note,
);

void main() {
  group('WatchAddress 字段', () {
    test('WatchAddress_手动添加的地址_派生信息为null且备注默认为空', () {
      final a = watch();
      expect(a.id, 'addr-1');
      expect(a.accountId, 'acc-1');
      expect(a.family, ChainFamily.evm);
      expect(a.address, _address);
      expect(a.enabledChainIds, {'ethereum', 'base'});
      expect(a.scheme, isNull);
      expect(a.derivationIndex, isNull);
      expect(a.note, '');
    });

    test('WatchAddress_由保险库派生_记录方案与序号', () {
      final a = watch(scheme: DerivationScheme.evmStandard, derivationIndex: 2);
      expect(a.scheme, DerivationScheme.evmStandard);
      expect(a.derivationIndex, 2);
    });
  });

  group('WatchAddress.copyWith', () {
    test('copyWith_不传参数_得到相等的副本', () {
      final a = watch(
        scheme: DerivationScheme.evmLedgerLive,
        derivationIndex: 1,
        note: '备注',
      );
      final copy = a.copyWith();
      expect(copy, a);
      expect(copy.hashCode, a.hashCode);
    });

    test('copyWith_改备注_其余字段不变', () {
      final a = watch(scheme: DerivationScheme.evmStandard, derivationIndex: 0);
      final b = a.copyWith(note: '冷钱包');
      expect(b.note, '冷钱包');
      expect(b.id, a.id);
      expect(b.accountId, a.accountId);
      expect(b.family, a.family);
      expect(b.address, a.address);
      expect(b.enabledChainIds, a.enabledChainIds);
      expect(b.scheme, DerivationScheme.evmStandard);
      expect(b.derivationIndex, 0);
      expect(b, isNot(a));
    });

    test('copyWith_改启用的链_只替换链集合', () {
      final a = watch();
      final b = a.copyWith(enabledChainIds: {'bsc'});
      expect(b.enabledChainIds, {'bsc'});
      expect(b.note, a.note);
      expect(b.address, a.address);
      expect(b, isNot(a));
    });

    test('copyWith_备注设为空字符串_备注被清空', () {
      expect(watch(note: '旧备注').copyWith(note: '').note, '');
    });
  });

  group('WatchAddress 值相等', () {
    test('WatchAddress_字段相同_相等且哈希相同', () {
      final a = watch(scheme: DerivationScheme.btcTaproot, derivationIndex: 3);
      final b = watch(scheme: DerivationScheme.btcTaproot, derivationIndex: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('WatchAddress_任一字段不同_不相等', () {
      final base = watch(
        scheme: DerivationScheme.evmStandard,
        derivationIndex: 0,
        note: '备注',
      );
      expect(
        watch(
          id: 'addr-2',
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 0,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(
          accountId: 'acc-2',
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 0,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(
          family: ChainFamily.bitcoin,
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 0,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(
          chains: {'ethereum'},
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 0,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(
          scheme: DerivationScheme.evmLedgerLive,
          derivationIndex: 0,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 1,
          note: '备注',
        ),
        isNot(base),
      );
      expect(
        watch(scheme: DerivationScheme.evmStandard, derivationIndex: 0),
        isNot(base),
      );
      expect(
        watch(
          scheme: DerivationScheme.evmStandard,
          derivationIndex: 0,
          note: '其他',
        ),
        isNot(base),
      );
    });

    test('WatchAddress_启用的链集合元素顺序不同_相等且哈希相同', () {
      final a = watch(chains: {'ethereum', 'base', 'bsc'});
      final b = watch(chains: {'bsc', 'base', 'ethereum'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString_含id与家族', () {
      expect(watch().toString(), 'WatchAddress(addr-1, ChainFamily.evm)');
    });
  });
}
