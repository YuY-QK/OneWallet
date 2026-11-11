import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

// 测试地址均为公开的众所周知地址或明显的构造样例：
// EVM 取 EIP-55 文档示例与 USDT 合约；Bitcoin 取比特币维基与 BIP173/BIP86 示例；
// Solana 取系统程序、Token 程序与 USDC 铸币地址；Tron 取 USDT 合约。
const evmEip55 = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const evmUsdt = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const btcP2pkh = '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2';
const btcP2sh = '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy';
const btcP2wpkh = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
const btcP2wsh =
    'bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3';
const btcTaproot =
    'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr';
const solTokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
const solUsdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const solSystemProgram = '11111111111111111111111111111111';
const tronUsdt = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';

/// 记录调用并按预设结果返回的校验和替身。
final class FakeChecksum implements AddressChecksum {
  FakeChecksum({this.result = true});

  final bool result;
  final calls = <(String, ChainFamily)>[];

  @override
  bool verify(String address, ChainFamily family) {
    calls.add((address, family));
    return result;
  }

  @override
  String toEip55(String normalizedEvmAddress) => 'EIP55:$normalizedEvmAddress';
}

/// 只认指定家族的校验和替身。
final class _OnlyFamily implements AddressChecksum {
  _OnlyFamily(this.family);

  final ChainFamily family;

  @override
  bool verify(String address, ChainFamily f) => f == family;

  @override
  String toEip55(String normalizedEvmAddress) => normalizedEvmAddress;
}

void main() {
  const codec = AddressCodec();

  group('detectFamily', () {
    test('detectFamily_EVM地址_识别为evm', () {
      expect(AddressCodec.detectFamily(evmEip55), ChainFamily.evm);
      expect(AddressCodec.detectFamily(evmUsdt.toLowerCase()), ChainFamily.evm);
      expect(AddressCodec.detectFamily('0x${'A' * 40}'), ChainFamily.evm);
    });

    test('detectFamily_Bitcoin四种前缀_识别为bitcoin', () {
      for (final a in [btcP2pkh, btcP2sh, btcP2wpkh, btcP2wsh, btcTaproot]) {
        expect(AddressCodec.detectFamily(a), ChainFamily.bitcoin, reason: a);
      }
    });

    test('detectFamily_Solana地址_识别为solana', () {
      expect(AddressCodec.detectFamily(solUsdcMint), ChainFamily.solana);
      // T 开头但长度 43，不是 Tron。
      expect(AddressCodec.detectFamily(solTokenProgram), ChainFamily.solana);
    });

    test('detectFamily_Tron地址_识别为tron而不是solana', () {
      expect(AddressCodec.detectFamily(tronUsdt), ChainFamily.tron);
    });

    test('detectFamily_1开头且落在Bitcoin长度区间_优先识别为bitcoin', () {
      // 系统程序地址同时满足两者的格式，按约定顺序归为 Bitcoin。
      expect(AddressCodec.detectFamily(solSystemProgram), ChainFamily.bitcoin);
    });

    test('detectFamily_首尾空白_忽略', () {
      expect(AddressCodec.detectFamily('  $tronUsdt\n'), ChainFamily.tron);
    });

    test('detectFamily_无法识别的输入_返回null', () {
      for (final a in [
        '',
        '   ',
        'hello',
        '0x${'a' * 39}', // 少一位
        '0x${'a' * 41}', // 多一位
        '0x${'g' * 40}', // 非十六进制
        '0X${'a' * 40}', // 前缀大写
        'bc1z${'0' * 38}', // 未知见证版本（用 0 避免同时满足 Solana 格式）
        'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3t4', // 大小写混用的 bech32
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3tb', // 含 b，不在 bech32 字符集
        '0OIl${'1' * 30}', // 含 Base58 排除的字符
        'a' * 31, // 短于 Solana 下限
        'a' * 45, // 长于 Solana 上限
      ]) {
        expect(AddressCodec.detectFamily(a), isNull, reason: a);
      }
    });
  });

  group('isValid 格式判断', () {
    test('isValid_EVM_合法与非法', () {
      expect(codec.isValid(evmEip55, ChainFamily.evm), isTrue);
      expect(codec.isValid(evmUsdt.toLowerCase(), ChainFamily.evm), isTrue);
      expect(codec.isValid(' $evmUsdt ', ChainFamily.evm), isTrue);
      expect(codec.isValid('0x${'a' * 39}', ChainFamily.evm), isFalse);
      expect(codec.isValid(evmEip55.substring(2), ChainFamily.evm), isFalse);
      expect(codec.isValid(tronUsdt, ChainFamily.evm), isFalse);
    });

    test('isValid_Bitcoin_合法与非法', () {
      for (final a in [btcP2pkh, btcP2sh, btcP2wpkh, btcP2wsh, btcTaproot]) {
        expect(codec.isValid(a, ChainFamily.bitcoin), isTrue, reason: a);
      }
      for (final a in [
        '2${btcP2pkh.substring(1)}', // 前缀不是 1 或 3
        '1${'a' * 24}', // 长度 25，短于下限
        '1${'a' * 35}', // 长度 36，长于上限
        btcP2wpkh.substring(0, 41), // bc1q 长度 41
        'bc1q${'q' * 48}', // bc1q 长度 52
        btcTaproot.substring(0, 42), // bc1p 长度 42
        'Bc1q${btcP2wpkh.substring(4)}', // 大小写混用
        'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3t4', // 大小写混用
        'BC1P${btcTaproot.substring(4)}', // 大小写混用
        evmEip55,
      ]) {
        expect(codec.isValid(a, ChainFamily.bitcoin), isFalse, reason: a);
      }
    });

    test('isValid_Bitcoin全大写bech32_接受', () {
      for (final a in [btcP2wpkh, btcP2wsh, btcTaproot]) {
        expect(codec.isValid(a.toUpperCase(), ChainFamily.bitcoin), isTrue);
      }
      expect(
        AddressCodec.detectFamily(btcTaproot.toUpperCase()),
        ChainFamily.bitcoin,
      );
    });

    test('isValid_Solana_合法与非法', () {
      for (final a in [solUsdcMint, solTokenProgram, solSystemProgram]) {
        expect(codec.isValid(a, ChainFamily.solana), isTrue, reason: a);
      }
      for (final a in [
        'a' * 31,
        'a' * 45,
        '0${solUsdcMint.substring(1)}', // 含 0
        'O${solUsdcMint.substring(1)}', // 含 O
        evmEip55,
      ]) {
        expect(codec.isValid(a, ChainFamily.solana), isFalse, reason: a);
      }
    });

    test('isValid_Tron_合法与非法', () {
      expect(codec.isValid(tronUsdt, ChainFamily.tron), isTrue);
      for (final a in [
        tronUsdt.substring(0, 33), // 短一位
        '${tronUsdt}1', // 长一位
        'A${tronUsdt.substring(1)}', // 不是 T 开头
        'T${'0' * 33}', // 含 0
        solTokenProgram,
      ]) {
        expect(codec.isValid(a, ChainFamily.tron), isFalse, reason: a);
      }
    });
  });

  group('isValid 注入校验和', () {
    test('isValid_格式通过_调用校验和并以其结果为准', () {
      final ok = FakeChecksum();
      expect(
        AddressCodec(checksum: ok).isValid(' $tronUsdt', ChainFamily.tron),
        isTrue,
      );
      expect(ok.calls, [(tronUsdt, ChainFamily.tron)]);

      final bad = FakeChecksum(result: false);
      expect(
        AddressCodec(checksum: bad).isValid(evmEip55, ChainFamily.evm),
        isFalse,
      );
    });

    test('isValid_格式不通过_不调用校验和', () {
      final checksum = FakeChecksum();
      expect(
        AddressCodec(checksum: checksum).isValid('hello', ChainFamily.solana),
        isFalse,
      );
      expect(checksum.calls, isEmpty);
    });
  });

  group('detect', () {
    test('detect_未注入校验和_等同detectFamily', () {
      for (final a in [evmEip55, btcP2pkh, solSystemProgram, tronUsdt, 'x']) {
        expect(codec.detect(a), AddressCodec.detectFamily(a), reason: a);
      }
    });

    test('detect_注入校验和_返回第一个格式与校验和都通过的家族', () {
      // 校验和只认 solana：Tron、Bitcoin 格式匹配但被跳过。
      final c = AddressCodec(checksum: _OnlyFamily(ChainFamily.solana));
      expect(c.detect(solSystemProgram), ChainFamily.solana);
      // Tron 地址格式上也满足 Solana，校验和只认 solana 时归为 solana。
      expect(c.detect(tronUsdt), ChainFamily.solana);
      expect(c.detect(evmEip55), isNull);
      expect(c.detect(btcP2pkh), ChainFamily.solana);
    });

    test('detect_校验和全部不通过_返回null', () {
      final c = AddressCodec(checksum: FakeChecksum(result: false));
      expect(c.detect(evmEip55), isNull);
      expect(c.detect(solUsdcMint), isNull);
    });

    test('detect_格式都不匹配_不调用校验和', () {
      final fake = FakeChecksum();
      expect(AddressCodec(checksum: fake).detect('hello'), isNull);
      expect(fake.calls, isEmpty);
    });
  });

  group('normalize', () {
    test('normalize_EVM_去空白并转小写', () {
      expect(
        AddressCodec.normalize('  $evmEip55\n', ChainFamily.evm),
        evmEip55.toLowerCase(),
      );
    });

    test('normalize_其余家族_只去空白不改大小写', () {
      expect(
        AddressCodec.normalize(' $btcP2pkh ', ChainFamily.bitcoin),
        btcP2pkh,
      );
      expect(
        AddressCodec.normalize('\t$solUsdcMint', ChainFamily.solana),
        solUsdcMint,
      );
      expect(AddressCodec.normalize('$tronUsdt ', ChainFamily.tron), tronUsdt);
    });

    test('normalize_Bitcoin全大写bech32_转小写，混用与Base58不动', () {
      expect(
        AddressCodec.normalize(
          ' ${btcP2wpkh.toUpperCase()} ',
          ChainFamily.bitcoin,
        ),
        btcP2wpkh,
      );
      expect(
        AddressCodec.normalize(btcTaproot.toUpperCase(), ChainFamily.bitcoin),
        btcTaproot,
      );
      const mixed = 'Bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
      expect(AddressCodec.normalize(mixed, ChainFamily.bitcoin), mixed);
    });
  });

  group('display', () {
    test('display_EVM且注入校验和_转为EIP55', () {
      final codec = AddressCodec(checksum: FakeChecksum());
      final normalized = evmEip55.toLowerCase();
      expect(codec.display(normalized, ChainFamily.evm), 'EIP55:$normalized');
    });

    test('display_未注入校验和或非EVM_原样返回', () {
      final normalized = evmEip55.toLowerCase();
      expect(codec.display(normalized, ChainFamily.evm), normalized);
      final withChecksum = AddressCodec(checksum: FakeChecksum());
      expect(withChecksum.display(tronUsdt, ChainFamily.tron), tronUsdt);
      expect(withChecksum.display('0x12', ChainFamily.evm), '0x12');
    });
  });

  group('shorten', () {
    test('shorten_各家族地址_前6后4', () {
      expect(AddressCodec.shorten(evmUsdt), '0xdAC1…1ec7');
      expect(AddressCodec.shorten(btcP2wpkh), 'bc1qw5…f3t4');
      expect(AddressCodec.shorten(solUsdcMint), 'EPjFWd…Dt1v');
      expect(AddressCodec.shorten(tronUsdt), 'TR7NHq…Lj6t');
    });

    test('shorten_不超过11个字符_原样返回', () {
      expect(AddressCodec.shorten(''), '');
      expect(AddressCodec.shorten('abcdefghijk'), 'abcdefghijk');
      expect(AddressCodec.shorten('abcdefghijkl'), 'abcdef…ijkl');
    });
  });
}
