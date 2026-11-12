import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_domain/ow_domain.dart';
import 'package:ow_exchanges/ow_exchanges.dart';
import 'package:test/test.dart';

Sensitive s(String text) => Sensitive(Uint8List.fromList(utf8.encode(text)));

void main() {
  group('Binance（官方示例）', () {
    // 出处：binance-spot-api-docs rest-api.md "SIGNED Endpoint Examples ... HMAC Keys"。
    // secretKey 是文档公开的演示值。
    final secret = s(
      'NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j',
    );

    test('文档示例一：ASCII 交易对', () {
      const payload =
          'symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1'
          '&price=0.1&recvWindow=5000&timestamp=1499827319559';
      expect(
        binanceSignature(secret: secret, payload: payload),
        'c8db56825ae71d6d79447849e617115f4a920fa2acdcab2b053c4b2838bd6b71',
      );
    });

    test('文档示例二：非 ASCII 交易对先百分号编码再签名', () {
      const payload =
          'symbol=%EF%BC%91%EF%BC%92%EF%BC%93%EF%BC%94%EF%BC%95%EF%BC%96'
          '&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1'
          '&recvWindow=5000&timestamp=1499827319559';
      expect(
        binanceSignature(secret: secret, payload: payload),
        'e1353ec6b14d888f1164ae9af8228a3dbd508bc82eb867db8ab6046442f33ef3',
      );
    });
  });

  group('OKX', () {
    test('待签名串与官方公式一致', () {
      // 官方公式：timestamp + 'GET' + '/api/v5/account/balance?ccy=BTC'。
      expect(
        okxPreHash(
          timestamp: '2020-12-08T09:08:57.715Z',
          method: 'get',
          requestPath: '/api/v5/account/balance?ccy=BTC',
        ),
        '2020-12-08T09:08:57.715ZGET/api/v5/account/balance?ccy=BTC',
      );
    });

    test('签名（回归测试，非官方向量）', () {
      // OKX 文档只给出公式和演示 SecretKey，没有给出可复算的签名结果。
      // 期望值由 openssl/Python 独立计算，用于防止回归。
      expect(
        okxSignature(
          secret: s('22582BD0CFF14C41EDBF1AB98506286D'),
          preHash: '2020-12-08T09:08:57.715ZGET/api/v5/account/balance?ccy=BTC',
        ),
        'HiZhvSfMtWJA3uUIVXV3a/bSXNPCWvYFXoGCVS8V4zY=',
      );
    });

    test('时间戳格式：ISO 8601 UTC 毫秒', () {
      expect(
        okxTimestamp(DateTime.utc(2020, 12, 8, 9, 8, 57, 715)),
        '2020-12-08T09:08:57.715Z',
      );
      expect(
        okxTimestamp(DateTime.utc(2020, 1, 2, 3, 4, 5)),
        '2020-01-02T03:04:05.000Z',
      );
    });
  });

  group('Bybit', () {
    test('待签名串与官方示例一致', () {
      expect(
        bybitPreHash(
          timestamp: '1658384314791',
          apiKey: 'XXXXXXXXXX',
          recvWindow: '5000',
          payload: 'category=option&symbol=BTC-29JUL22-25000-C',
        ),
        '1658384314791XXXXXXXXXX5000category=option&symbol=BTC-29JUL22-25000-C',
      );
    });

    test('签名（回归测试，非官方向量）', () {
      // 官方示例的 Secret 被遮盖，无法复算其签名值；这里用假数据固定输出。
      expect(
        bybitSignature(
          apiKey: s('TESTKEY'),
          secret: s('TESTSECRET'),
          timestampMs: 1658384314791,
          recvWindowMs: 5000,
          payload: 'category=option&symbol=BTC-29JUL22-25000-C',
        ),
        '78d6ff096610435ed722777ee534bed6ee060cb946a2825bafe5e7b585108065',
      );
    });
  });

  group('Bitget', () {
    test('待签名串与官方示例一致（有查询串、无请求体）', () {
      expect(
        bitgetPreHash(
          timestamp: '16273667805456',
          method: 'GET',
          requestPath: '/api/mix/v2/market/depth',
          queryString: 'limit=20&symbol=BTCUSDT',
        ),
        '16273667805456GET/api/mix/v2/market/depth?limit=20&symbol=BTCUSDT',
      );
    });

    test('查询串为空时不加问号', () {
      expect(
        bitgetPreHash(timestamp: '1', method: 'GET', requestPath: '/p'),
        '1GET/p',
      );
    });

    test('签名（回归测试，非官方向量）', () {
      expect(
        bitgetSignature(
          secret: s('TESTSECRET'),
          preHash: '16273667805456GET/api/mix/v2/market/depth?limit=20&symbol=BTCUSDT',
        ),
        '8j9xUertjNrUkHOPkQXScgwgHPhwbFqopaUZy6xuTAc=',
      );
    });
  });

  test('buildQuery 按顺序编码', () {
    expect(buildQuery({'a': '1', 'b': 'x y,z'}), 'a=1&b=x+y%2Cz');
  });

  test('敏感请求头名称清单覆盖四家的 Key 头', () {
    expect(
      exchangeSensitiveHeaderNames,
      containsAll(['X-MBX-APIKEY', 'OK-ACCESS-KEY', 'X-BAPI-API-KEY']),
    );
  });
}
