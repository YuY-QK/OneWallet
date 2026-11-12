import 'package:ow_directory/ow_directory.dart';
import 'package:test/test.dart';

/// 一个合法的基准条目；各测试在此基础上构造一处违规。
Map<String, Object?> valid() => {
  'id': 'demo',
  'kind': 'exchange',
  'name': 'Demo',
  'aliases': <String>[],
  'officialDomains': ['demo.com'],
  'links': {'website': 'https://www.demo.com/'},
  'integration': 'none',
  'verifiedAt': '2026-11-11',
  'sources': ['https://www.demo.com/'],
  'notes': '',
};

List<String> check(
  Map<String, Object?> Function(Map<String, Object?> e) mutate, {
  List<Map<String, Object?>> extra = const [],
}) {
  final e = mutate(valid());
  return DirectoryValidator.validate({
    'entries': [e, ...extra],
  });
}

void main() {
  test('基准条目合法', () {
    expect(check((e) => e), isEmpty);
  });

  test('顶层结构不对', () {
    expect(DirectoryValidator.validate([]), isNotEmpty);
    expect(DirectoryValidator.validateJson('{{'), isNotEmpty);
  });

  final cases = <String, Map<String, Object?> Function(Map<String, Object?>)>{
    'id 含大写': (e) => e..['id'] = 'Demo',
    'id 含下划线': (e) => e..['id'] = 'de_mo',
    'id 以连字符结尾': (e) => e..['id'] = 'demo-',
    'name 为空': (e) => e..['name'] = '  ',
    'kind 非法': (e) => e..['kind'] = 'bank',
    'integration 非法': (e) => e..['integration'] = 'maybe',
    'http 链接': (e) => e..['links'] = {'website': 'http://www.demo.com/'},
    '链接含用户名密码': (e) =>
        e..['links'] = {'website': 'https://user:pw@www.demo.com/'},
    '链接含 ref=': (e) =>
        e..['links'] = {'website': 'https://www.demo.com/?ref=abc'},
    '链接含 referral': (e) =>
        e..['links'] = {'website': 'https://www.demo.com/referral/abc'},
    '链接含 utm_': (e) =>
        e..['links'] = {'website': 'https://www.demo.com/?utm_source=x'},
    '链接含 invite': (e) =>
        e..['links'] = {'website': 'https://www.demo.com/invite/abc'},
    '链接含 aff': (e) =>
        e..['links'] = {'website': 'https://www.demo.com/?aff=abc'},
    '域名不归属': (e) => e..['links'] = {'website': 'https://www.evil.com/'},
    '仿冒前缀域名': (e) => e..['links'] = {'website': 'https://notdemo.com/'},
    '子域名伪装': (e) => e..['links'] = {'website': 'https://demo.com.evil.com/'},
    '未知链接键': (e) => e..['links'] = {'weirdKey': 'https://www.demo.com/'},
    'officialDomains 为空': (e) => e..['officialDomains'] = <String>[],
    'officialDomains 带协议': (e) => e..['officialDomains'] = ['https://demo.com'],
    'officialDomains 带路径': (e) => e..['officialDomains'] = ['demo.com/x'],
    'officialDomains 是共享托管域': (e) => e
      ..['officialDomains'] = ['github.io']
      ..['links'] = {'website': 'https://evil.github.io/'},
    '已核对但缺 source': (e) => e..['sources'] = <String>[],
    'source 不是 https': (e) => e..['sources'] = ['http://demo.com'],
    'verifiedAt 格式不对': (e) => e..['verifiedAt'] = '昨天',
    'custody 非法': (e) => e
      ..['kind'] = 'wallet'
      ..['wallet'] = {
        'custody': 'x',
        'exportable': true,
        'families': <String>[],
      },
    'families 非法': (e) => e
      ..['kind'] = 'wallet'
      ..['wallet'] = {
        'custody': 'selfCustody',
        'exportable': null,
        'families': ['dogecoin'],
      },
    '交易所带 wallet 子结构': (e) => e
      ..['wallet'] = {
        'custody': 'selfCustody',
        'exportable': true,
        'families': <String>[],
      },
    'domainExchangeId 非法': (e) => e..['exchange'] = {'domainExchangeId': 'ftx'},
    'explorer 缺 {address}': (e) => e
      ..['kind'] = 'explorer'
      ..['explorer'] = {
        'chainId': 'ethereum',
        'addressUrlTemplate': 'https://www.demo.com/address/',
      },
    'explorer chainId 不存在': (e) => e
      ..['kind'] = 'explorer'
      ..['explorer'] = {
        'chainId': 'dogecoin',
        'addressUrlTemplate': 'https://www.demo.com/address/{address}',
      },
    'explorer 模板域名不归属': (e) => e
      ..['kind'] = 'explorer'
      ..['explorer'] = {
        'chainId': 'ethereum',
        'addressUrlTemplate': 'https://evil.com/address/{address}',
      },
    'explorer 类缺 explorer 子结构': (e) => e..['kind'] = 'explorer',
  };
  for (final c in cases.entries) {
    test('能报出：${c.key}', () {
      expect(check(c.value), isNotEmpty);
    });
  }

  test('能报出：重复 id', () {
    expect(check((e) => e, extra: [valid()]), contains(contains('重复')));
  });

  test('合法的钱包、交易所、浏览器子结构通过', () {
    expect(
      check(
        (e) => e
          ..['kind'] = 'wallet'
          ..['wallet'] = {
            'custody': 'mpc',
            'exportable': null,
            'families': ['evm', 'solana'],
          },
      ),
      isEmpty,
    );
    expect(
      check((e) => e..['exchange'] = {'domainExchangeId': 'okx'}),
      isEmpty,
    );
    expect(
      check(
        (e) => e
          ..['kind'] = 'explorer'
          ..['explorer'] = {
            'chainId': 'tron',
            'addressUrlTemplate': 'https://www.demo.com/#/address/{address}',
          },
      ),
      isEmpty,
    );
  });

  test('未核对的条目可以没有 source', () {
    expect(
      check(
        (e) => e
          ..['verifiedAt'] = null
          ..['sources'] = <String>[],
      ),
      isEmpty,
    );
  });

  test('staff 之类的词不被误判为推广参数', () {
    expect(
      check((e) => e..['links'] = {'website': 'https://www.demo.com/staff'}),
      isEmpty,
    );
  });
}
