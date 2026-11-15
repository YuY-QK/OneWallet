import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_platform/ow_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late DeviceHardwareKeyStore store;

  setUp(() {
    channel = const MethodChannel('ow.platform/hardware_key_store');
    store = DeviceHardwareKeyStore(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isAvailable_通道返回true时_返回true', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return true;
          return null;
        });

    expect(await store.isAvailable(), isTrue);
  });

  test('isAvailable_通道抛MissingPluginException时_返回false', () async {
    expect(await store.isAvailable(), isFalse);
  });

  test('wrap_成功返回包裹密文', () async {
    final plaintext = Uint8List.fromList([1, 2, 3, 4]);
    final wrapped = Uint8List.fromList([9, 8, 7, 6]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'wrap') {
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['alias'], 'test.key');
            expect(args['plaintext'], plaintext);
            return wrapped;
          }
          return null;
        });

    final res = await store.wrap('test.key', plaintext);
    expect(res, isA<Ok<Uint8List>>());
    expect((res as Ok<Uint8List>).value, wrapped);
  });

  test('wrap_不支持硬件密钥时返回UnsupportedFailure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'UNSUPPORTED',
            message: 'No secure hardware',
          );
        });

    final res = await store.wrap('test.key', Uint8List(16));
    expect(res, isA<Err<Uint8List>>());
    expect((res as Err<Uint8List>).failure, isA<UnsupportedFailure>());
  });

  test('wrap_MissingPluginException时返回UnsupportedFailure', () async {
    final res = await store.wrap('test.key', Uint8List(16));
    expect(res, isA<Err<Uint8List>>());
    expect((res as Err<Uint8List>).failure, isA<UnsupportedFailure>());
  });

  test('unwrap_成功返回原始明文', () async {
    final wrapped = Uint8List.fromList([9, 8, 7, 6]);
    final plaintext = Uint8List.fromList([1, 2, 3, 4]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'unwrap') {
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['alias'], 'test.key');
            expect(args['wrapped'], wrapped);
            expect(args['reason'], '解锁保险库');
            return plaintext;
          }
          return null;
        });

    final res = await store.unwrap('test.key', wrapped, reason: '解锁保险库');
    expect(res, isA<Ok<Uint8List>>());
    expect((res as Ok<Uint8List>).value, plaintext);
  });

  test('unwrap_生物识别变更或取消时返回BiometricUnavailableFailure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'KEY_PERMANENTLY_INVALIDATED',
            message: 'Biometric enrollment changed',
          );
        });

    final res = await store.unwrap('test.key', Uint8List(16), reason: '解锁保险库');
    expect(res, isA<Err<Uint8List>>());
    expect((res as Err<Uint8List>).failure, isA<BiometricUnavailableFailure>());
  });

  test('delete_调用通道不抛异常', () async {
    var deleted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'delete') {
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['alias'], 'test.key');
            deleted = true;
          }
          return null;
        });

    await store.delete('test.key');
    expect(deleted, isTrue);
  });
}
