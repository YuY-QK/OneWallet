import 'package:blockchain_utils/blockchain_utils.dart' hide Err, Ok, Result;
import 'package:ow_chains/ow_chains.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:test/test.dart';

// 合法样例均为公开的众所周知地址或测试向量：
// EVM 取 EIP-55 文档；Bitcoin 取 BIP173/BIP350/BIP86 与比特币维基；
// Solana 取系统程序、Token 程序、USDC 铸币；Tron 取 USDT 合约与黑洞地址。
const eip55Mixed = [
  '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
  '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
  '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
  '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb',
];
const eip55AllCaps = [
  '0x52908400098527886E0F7030069857D2E4169EE7',
  '0x8617E340B3D01FA5F11F306F4090FD50E238070D',
];
const eip55AllLower = [
  '0xde709f2102306220921060314715629080e2fb77',
  '0x27b1fdb04752bbc536007a920d24acb045561c26',
];

const btcP2pkh = '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2';
const btcGenesis = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
const btcP2sh = '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy';
const btcP2wpkh = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
const btcP2wsh =
    'bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3';
const btcTaproot =
    'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr';
const btcTaprootBip350 =
    'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0';

const solSystem = '11111111111111111111111111111111';
const solToken = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
const solUsdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const solWsol = 'So11111111111111111111111111111111111111112';

const tronUsdt = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
const tronBlackHole = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';

/// 以下为用 blockchain_utils 构造的"校验和正确但规则不符"的样例。
// 版本字节 0x06 的 Base58Check，以 3 开头。
const btcWrongVersion = '3Sarqj5MB6UiVhNzYp64sm7qgjATV7X288';
// 版本字节 0x42 的 Base58Check，以 T 开头、长 34。
const tronWrongVersion = 'Tas3vExdmvHHZhkC1z5ByHT3Szd491AdKz';
// BIP350 无效向量：v0 却用了 Bech32m 校验；v1 却用了 Bech32 校验。
const segwitV0Bech32m = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kemeawh';
const segwitV1Bech32 =
    'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd';
// v1 但见证程序只有 20 字节（校验和正确）。
const segwitV1Short = 'bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kj9wkru';
// 测试网。
const testnetSegwit = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

String flip(String s, int i) {
  final c = s[i];
  final repl = c == 'a' ? 'b' : 'a';
  return s.replaceRange(i, i + 1, repl);
}

void main() {
  const checksum = ChainAddressChecksum();
  const codec = AddressCodec(checksum: checksum);

  bool v(String a, ChainFamily f) => checksum.verify(a, f);

  group('EVM', () {
    test('EIP55文档地址_大小写混合且正确_通过', () {
      for (final a in eip55Mixed) {
        expect(v(a, ChainFamily.evm), isTrue, reason: a);
      }
    });

    test('全大写与全小写_视为无校验和_通过', () {
      for (final a in [...eip55AllCaps, ...eip55AllLower]) {
        expect(v(a, ChainFamily.evm), isTrue, reason: a);
      }
    });

    test('大小写混合但校验和错误_拒绝', () {
      // 翻转一个字母的大小写。
      const good = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
      final bad = good.replaceRange(3, 4, 'A');
      expect(bad, isNot(good));
      expect(v(bad, ChainFamily.evm), isFalse);
    });

    test('toEip55_往返', () {
      for (final a in [...eip55Mixed, ...eip55AllCaps]) {
        expect(checksum.toEip55(a.toLowerCase()), a);
      }
    });

    test('toEip55_格式不对_抛ArgumentError', () {
      expect(() => checksum.toEip55('0x1234'), throwsArgumentError);
      expect(() => checksum.toEip55('nonsense'), throwsArgumentError);
    });
  });

  group('Bitcoin', () {
    test('四种前缀的合法地址_通过', () {
      for (final a in [
        btcP2pkh,
        btcGenesis,
        btcP2sh,
        btcP2wpkh,
        btcP2wsh,
        btcTaproot,
        btcTaprootBip350,
      ]) {
        expect(v(a, ChainFamily.bitcoin), isTrue, reason: a);
      }
    });

    test('全大写bech32_通过', () {
      expect(v(btcP2wpkh.toUpperCase(), ChainFamily.bitcoin), isTrue);
      expect(v(btcTaproot.toUpperCase(), ChainFamily.bitcoin), isTrue);
    });

    test('大小写混用的bech32_拒绝', () {
      final mixed = 'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3t4';
      expect(v(mixed, ChainFamily.bitcoin), isFalse);
      expect(
        v('BC1QW508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', ChainFamily.bitcoin),
        isFalse,
      );
    });

    test('Base58Check校验和错误_拒绝', () {
      expect(v(flip(btcP2pkh, 10), ChainFamily.bitcoin), isFalse);
      expect(
        v(btcP2pkh.replaceRange(33, 34, '3'), ChainFamily.bitcoin),
        isFalse,
      );
      expect(v(flip(btcP2sh, 5), ChainFamily.bitcoin), isFalse);
    });

    test('版本字节不符_拒绝', () {
      expect(v(btcWrongVersion, ChainFamily.bitcoin), isFalse);
    });

    test('bech32校验和错误_拒绝', () {
      expect(
        v('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5', ChainFamily.bitcoin),
        isFalse,
      );
      expect(v(flip(btcTaproot, 20), ChainFamily.bitcoin), isFalse);
    });

    test('编码类型与见证版本不符_拒绝', () {
      expect(v(segwitV0Bech32m, ChainFamily.bitcoin), isFalse);
      expect(v(segwitV1Bech32, ChainFamily.bitcoin), isFalse);
      expect(v(segwitV1Short, ChainFamily.bitcoin), isFalse);
    });

    test('HRP不是bc_拒绝', () {
      expect(v(testnetSegwit, ChainFamily.bitcoin), isFalse);
    });

    test('畸形输入_返回false不抛异常', () {
      for (final s in ['', '1', '3', 'bc1q', '1111', 'bc1', '0']) {
        expect(v(s, ChainFamily.bitcoin), isFalse, reason: s);
      }
    });
  });

  group('Solana', () {
    test('合法地址_通过', () {
      for (final a in [solSystem, solToken, solUsdc, solWsol]) {
        expect(v(a, ChainFamily.solana), isTrue, reason: a);
      }
    });

    test('解码后不是32字节_拒绝', () {
      final b31 = Base58Encoder.encode(List.filled(31, 7));
      expect(v(b31, ChainFamily.solana), isFalse); // 31 字节
      final b33 = Base58Encoder.encode([1, ...List.filled(32, 7)]);
      expect(v(b33, ChainFamily.solana), isFalse); // 33 字节
      expect(v('1' * 31, ChainFamily.solana), isFalse);
    });

    test('含非Base58字符_拒绝', () {
      expect(v('0${solUsdc.substring(1)}', ChainFamily.solana), isFalse);
    });
  });

  group('Tron', () {
    test('合法地址_通过', () {
      expect(v(tronUsdt, ChainFamily.tron), isTrue);
      expect(v(tronBlackHole, ChainFamily.tron), isTrue);
    });

    test('校验和错误_拒绝', () {
      expect(v(flip(tronUsdt, 20), ChainFamily.tron), isFalse);
    });

    test('版本字节不是0x41_拒绝', () {
      expect(v(tronWrongVersion, ChainFamily.tron), isFalse);
    });
  });

  group('AddressCodec 接入', () {
    test('isValid_各家族合法与非法', () {
      expect(codec.isValid(eip55Mixed.first, ChainFamily.evm), isTrue);
      expect(
        codec.isValid(
          eip55Mixed.first.replaceRange(3, 4, 'A'),
          ChainFamily.evm,
        ),
        isFalse,
      );
      expect(codec.isValid(btcP2wpkh, ChainFamily.bitcoin), isTrue);
      expect(codec.isValid(flip(btcP2pkh, 10), ChainFamily.bitcoin), isFalse);
      expect(codec.isValid(solUsdc, ChainFamily.solana), isTrue);
      expect(codec.isValid(tronUsdt, ChainFamily.tron), isTrue);
    });

    test('display_EVM转EIP55', () {
      expect(
        codec.display(eip55Mixed.first.toLowerCase(), ChainFamily.evm),
        eip55Mixed.first,
      );
    });

    test('全大写bech32_接受并规范化为小写', () {
      final upper = btcP2wpkh.toUpperCase();
      expect(codec.isValid(upper, ChainFamily.bitcoin), isTrue);
      expect(AddressCodec.normalize(upper, ChainFamily.bitcoin), btcP2wpkh);
      final upperTr = btcTaproot.toUpperCase();
      expect(codec.isValid(' $upperTr ', ChainFamily.bitcoin), isTrue);
      expect(AddressCodec.normalize(upperTr, ChainFamily.bitcoin), btcTaproot);
    });

    test('大小写混用的bech32_isValid拒绝', () {
      expect(
        codec.isValid(
          'Bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
          ChainFamily.bitcoin,
        ),
        isFalse,
      );
      expect(
        codec.isValid(
          'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3t4',
          ChainFamily.bitcoin,
        ),
        isFalse,
      );
    });

    test('detect_各家族合法地址', () {
      expect(codec.detect(eip55Mixed.first), ChainFamily.evm);
      expect(codec.detect(eip55AllLower.first), ChainFamily.evm);
      expect(codec.detect(tronUsdt), ChainFamily.tron);
      for (final a in [btcP2pkh, btcP2sh, btcP2wpkh, btcTaproot]) {
        expect(codec.detect(a), ChainFamily.bitcoin, reason: a);
      }
      expect(codec.detect(btcP2wpkh.toUpperCase()), ChainFamily.bitcoin);
      expect(codec.detect(solUsdc), ChainFamily.solana);
    });

    test('detect_格式上属于Bitcoin的Solana地址_识别为solana', () {
      // 系统程序地址是 32 个 '1'：格式上满足 Bitcoin（1 开头、长 32），
      // 静态的 detectFamily 会误判，detect 用校验和纠正。
      expect(AddressCodec.detectFamily(solSystem), ChainFamily.bitcoin);
      expect(codec.detect(solSystem), ChainFamily.solana);
      // 32 字节、前 24 字节为零的值，同属此类。
      final leadingZeros = Base58Encoder.encode([
        ...List.filled(24, 0),
        ...List.filled(8, 7),
      ]);
      expect(leadingZeros.startsWith('1'), isTrue);
      expect(codec.detect(leadingZeros), ChainFamily.solana);
    });

    test('detect_T开头的Solana地址_识别为solana', () {
      expect(solToken.startsWith('T'), isTrue);
      expect(codec.detect(solToken), ChainFamily.solana);
      // 34 位、T 开头的 Base58 串解码不是 32 字节：Tron 校验和不过，也不是 Solana。
      expect(codec.detect(flip(tronUsdt, 5)), isNull);
    });

    test('detect_格式对但校验和错_返回null', () {
      expect(codec.detect(flip(tronUsdt, 20)), isNull);
      expect(codec.detect(flip(btcP2pkh, 10)), isNull);
      expect(codec.detect(eip55Mixed.first.replaceRange(3, 4, 'A')), isNull);
      expect(codec.detect('hello'), isNull);
      expect(codec.detect(''), isNull);
    });

    test('detect_未注入校验和_退化为detectFamily', () {
      const plain = AddressCodec();
      expect(plain.detect(solSystem), AddressCodec.detectFamily(solSystem));
      expect(plain.detect(tronUsdt), ChainFamily.tron);
    });
  });
}
