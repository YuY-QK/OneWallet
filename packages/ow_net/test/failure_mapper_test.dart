import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

RequestOptions _options() => RequestOptions(
  path: 'https://api.example.com/v1/x?apikey=abcdefghijkl&signature=deadbeef',
);

DioException _bad(int status) => DioException.badResponse(
  statusCode: status,
  requestOptions: _options(),
  response: Response<String>(
    requestOptions: _options(),
    statusCode: status,
    data: 'body-marker',
  ),
);

void _expectClean(Failure f, {String host = 'api.example.com'}) {
  final detail = f.detail ?? '';
  expect(detail, contains(host));
  for (final bad in [
    '?',
    'apikey',
    'abcdefghijkl',
    'signature',
    'deadbeef',
    'body-marker',
  ]) {
    expect(detail, isNot(contains(bad)), reason: bad);
  }
}

void main() {
  group('mapHttpFailure_状态码', () {
    test('429_RateLimited', () {
      final f = mapHttpFailure(_bad(429));
      expect(f, isA<RateLimitedFailure>());
      expect(f.detail, contains('429'));
      _expectClean(f);
    });

    test('401_Unauthorized', () {
      final f = mapHttpFailure(_bad(401));
      expect(f, isA<UnauthorizedFailure>());
      _expectClean(f);
    });

    test('403_Unauthorized', () {
      final f = mapHttpFailure(_bad(403));
      expect(f, isA<UnauthorizedFailure>());
      _expectClean(f);
    });

    test('500_ServiceDown', () {
      final f = mapHttpFailure(_bad(500));
      expect(f, isA<ServiceDownFailure>());
      expect(f.detail, contains('500'));
      _expectClean(f);
    });

    test('503_ServiceDown', () {
      final f = mapHttpFailure(_bad(503));
      expect(f, isA<ServiceDownFailure>());
      _expectClean(f);
    });

    test('404_Unknown', () {
      final f = mapHttpFailure(_bad(404));
      expect(f, isA<UnknownFailure>());
      _expectClean(f);
    });
  });

  group('mapHttpFailure_网络', () {
    test('连接超时_Network', () {
      final f = mapHttpFailure(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 15),
          requestOptions: _options(),
        ),
      );
      expect(f, isA<NetworkFailure>());
      _expectClean(f);
    });

    test('接收超时与发送超时_Network', () {
      expect(
        mapHttpFailure(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 15),
            requestOptions: _options(),
          ),
        ),
        isA<NetworkFailure>(),
      );
      expect(
        mapHttpFailure(
          DioException.sendTimeout(
            timeout: const Duration(seconds: 15),
            requestOptions: _options(),
          ),
        ),
        isA<NetworkFailure>(),
      );
    });

    test('连接错误_Network', () {
      final f = mapHttpFailure(
        DioException.connectionError(
          requestOptions: _options(),
          reason: 'https://api.example.com/v1/x?apikey=abcdefghijkl',
        ),
      );
      expect(f, isA<NetworkFailure>());
      _expectClean(f);
    });

    test('底层SocketException_Network', () {
      final f = mapHttpFailure(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.unknown,
          error: const SocketException(
            'failed host lookup: ?apikey=abcdefghijkl',
          ),
        ),
      );
      expect(f, isA<NetworkFailure>());
      _expectClean(f);
    });

    test('其他未知异常_Unknown', () {
      expect(
        mapHttpFailure(
          DioException(
            requestOptions: _options(),
            type: DioExceptionType.unknown,
            error: StateError('x'),
          ),
        ),
        isA<UnknownFailure>(),
      );
      expect(mapHttpFailure(StateError('x')), isA<UnknownFailure>());
    });
  });

  test('mapHttpStatus_边界', () {
    expect(mapHttpStatus(499, 'h'), isA<UnknownFailure>());
    expect(mapHttpStatus(599, 'h'), isA<ServiceDownFailure>());
    expect(mapHttpStatus(600, 'h'), isA<UnknownFailure>());
  });
}
