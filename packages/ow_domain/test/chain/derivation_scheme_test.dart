import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DerivationScheme.pathFor', () {
    test('pathFor_常用方案_替换序号后与规格路径一致', () {
      expect(DerivationScheme.evmStandard.pathFor(0), "m/44'/60'/0'/0/0");
      expect(DerivationScheme.evmLedgerLive.pathFor(2), "m/44'/60'/2'/0/0");
      expect(DerivationScheme.btcNativeSegwit.pathFor(1), "m/84'/0'/0'/0/1");
      expect(DerivationScheme.btcTaproot.pathFor(1), "m/86'/0'/0'/0/1");
      expect(DerivationScheme.btcNestedSegwit.pathFor(3), "m/49'/0'/0'/0/3");
      expect(DerivationScheme.btcLegacy.pathFor(4), "m/44'/0'/0'/0/4");
      expect(DerivationScheme.solanaStandard.pathFor(5), "m/44'/501'/5'/0'");
      expect(DerivationScheme.solanaLegacy.pathFor(6), "m/44'/501'/6'");
      expect(DerivationScheme.tronStandard.pathFor(0), "m/44'/195'/0'/0/0");
    });

    test('pathFor_多位序号_整段替换', () {
      expect(DerivationScheme.evmStandard.pathFor(123), "m/44'/60'/0'/0/123");
    });

    test('pathFor_负数序号_抛出ArgumentError', () {
      for (final scheme in DerivationScheme.values) {
        expect(
          () => scheme.pathFor(-1),
          throwsArgumentError,
          reason: scheme.name,
        );
      }
    });

    test('pathFor_每个方案_模板都含序号占位符', () {
      for (final scheme in DerivationScheme.values) {
        expect(scheme.pathTemplate, contains('{i}'), reason: scheme.name);
        expect(scheme.pathFor(0), isNot(contains('{i}')), reason: scheme.name);
      }
    });
  });

  group('DerivationScheme.forFamily', () {
    test('forFamily_evm_返回两种方案且保持声明顺序', () {
      expect(DerivationScheme.forFamily(ChainFamily.evm), [
        DerivationScheme.evmStandard,
        DerivationScheme.evmLedgerLive,
      ]);
    });

    test('forFamily_bitcoin_返回四种方案', () {
      expect(DerivationScheme.forFamily(ChainFamily.bitcoin), [
        DerivationScheme.btcNativeSegwit,
        DerivationScheme.btcTaproot,
        DerivationScheme.btcNestedSegwit,
        DerivationScheme.btcLegacy,
      ]);
    });

    test('forFamily_solana_与tron_各自返回对应方案', () {
      expect(DerivationScheme.forFamily(ChainFamily.solana), [
        DerivationScheme.solanaStandard,
        DerivationScheme.solanaLegacy,
      ]);
      expect(DerivationScheme.forFamily(ChainFamily.tron), [
        DerivationScheme.tronStandard,
      ]);
    });

    test('forFamily_每个方案_恰好归属一个家族且每个家族都有方案', () {
      for (final family in ChainFamily.values) {
        final schemes = DerivationScheme.forFamily(family);
        expect(schemes, isNotEmpty, reason: family.name);
        for (final scheme in schemes) {
          expect(scheme.family, family, reason: scheme.name);
        }
      }
      final total = [
        for (final family in ChainFamily.values)
          ...DerivationScheme.forFamily(family),
      ];
      expect(total, hasLength(DerivationScheme.values.length));
    });
  });
}
