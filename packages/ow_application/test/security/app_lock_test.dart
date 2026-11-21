import 'dart:convert';
import 'dart:typed_data';

import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';
import 'package:ow_vault/ow_vault.dart';
import 'package:test/test.dart';

import '../fakes/fake_services.dart';
import '../fakes/fake_vault.dart';

void main() {
  late MemorySecretStore secretStore;
  late CountingVaultCrypto crypto;
  late FakeClock clock;
  late AttemptLimiter limiter;
  late SetUpPin setUpPin;
  late VerifyPin verifyPin;
  late ChangePin changePin;

  Sensitive sensitivePin(String pin) =>
      Sensitive(Uint8List.fromList(utf8.encode(pin)));

  setUpAll(() async {
    final sodiumCrypto = await SodiumVaultCrypto.load();
    crypto = CountingVaultCrypto(sodiumCrypto);
  });

  setUp(() {
    secretStore = MemorySecretStore();
    clock = FakeClock(DateTime.utc(2026, 11, 15, 10, 0, 0));
    limiter = AttemptLimiter(
      store: secretStore,
      clock: clock,
      keyPrefix: 'ow.app.pin',
    );
    setUpPin = SetUpPin(
      store: secretStore,
      crypto: crypto,
      limiter: limiter,
      kdfParams: testKdfParams,
    );
    verifyPin = VerifyPin(store: secretStore, crypto: crypto, limiter: limiter);
    changePin = ChangePin(verifyPin: verifyPin, setUpPin: setUpPin);
  });

  group('SetUpPin', () {
    test('非法PIN格式_非6位或非数字_返回ValidationFailure', () async {
      for (final bad in ['12345', '1234567', 'abcdef', '12 456', '']) {
        final pin = sensitivePin(bad);
        final res = await setUpPin(pin);
        expect(res, isA<Err<void>>());
        expect((res as Err<void>).failure, isA<ValidationFailure>());
        pin.wipe();
      }
    });

    test('合法6位PIN_写入SecretStore并返回Ok', () async {
      final pin = sensitivePin('123456');
      final res = await setUpPin(pin);
      pin.wipe();

      expect(res, isA<Ok<void>>());
      final raw = await secretStore.read('ow.app.pin.hash');
      expect(raw, isNotNull);
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      expect(json['salt'], isNotEmpty);
      expect(json['hash'], isNotEmpty);
      expect(json['memKib'], testKdfParams.memKib);
      expect(json['iterations'], testKdfParams.iterations);
    });

    test('已设置PIN时再次设置_未指定overwrite返回pin_already_set', () async {
      final pin1 = sensitivePin('123456');
      await setUpPin(pin1);
      pin1.wipe();

      final pin2 = sensitivePin('654321');
      final res = await setUpPin(pin2);
      pin2.wipe();

      expect(res, isA<Err<void>>());
      final failure = (res as Err<void>).failure as ValidationFailure;
      expect(failure.detail, 'pin_already_set');
    });

    test('已设置PIN时再次设置_指定overwrite成功覆盖', () async {
      final pin1 = sensitivePin('123456');
      await setUpPin(pin1);
      pin1.wipe();

      final pin2 = sensitivePin('654321');
      final res = await setUpPin(pin2, overwrite: true);
      pin2.wipe();

      expect(res, isA<Ok<void>>());
      final verifyOld = await verifyPin(sensitivePin('123456'));
      expect(verifyOld, isA<Err<void>>());
      final verifyNew = await verifyPin(sensitivePin('654321'));
      expect(verifyNew, isA<Ok<void>>());
    });
  });

  group('VerifyPin 与 错误锁定验收', () {
    test('未设置PIN时验证_返回pin_not_set', () async {
      final res = await verifyPin(sensitivePin('123456'));
      expect(res, isA<Err<void>>());
      expect((res as Err<void>).failure, isA<ValidationFailure>());
    });

    test('正确PIN验证通过_清零累计失败次数', () async {
      await setUpPin(sensitivePin('123456'));

      // 错 2 次
      await verifyPin(sensitivePin('000000'));
      await verifyPin(sensitivePin('000000'));
      expect(await limiter.check(), equals(const Unlocked(2)));

      // 对 1 次
      final okRes = await verifyPin(sensitivePin('123456'));
      expect(okRes, isA<Ok<void>>());
      expect(await limiter.check(), equals(const Unlocked(0)));
    });

    test('验收：连错5次锁1分钟，之后每次翻倍，上限1小时', () async {
      await setUpPin(sensitivePin('123456'));

      // 1 ~ 4 次：返回 WrongPasswordFailure，不锁定
      for (var i = 1; i <= 4; i++) {
        final res = await verifyPin(sensitivePin('000000'));
        expect(res, isA<Err<void>>());
        expect((res as Err<void>).failure, isA<WrongPasswordFailure>());
        expect(await limiter.check(), equals(Unlocked(i)));
      }

      // 第 5 次：锁定 1 分钟
      final res5 = await verifyPin(sensitivePin('000000'));
      expect(res5, isA<Err<void>>());
      final f5 = (res5 as Err<void>).failure;
      expect(f5, isA<LockedOutFailure>());
      final until5 = (f5 as LockedOutFailure).until;
      expect(until5, equals(clock.nowUtc().add(const Duration(minutes: 1))));

      // 锁定期间尝试（即使输入正确密码）：直接返回 LockedOutFailure，不计算哈希
      final callsBefore = crypto.argon2idCalls;
      final lockedRes = await verifyPin(sensitivePin('123456'));
      expect(lockedRes, isA<Err<void>>());
      expect((lockedRes as Err<void>).failure, isA<LockedOutFailure>());
      expect(crypto.argon2idCalls, equals(callsBefore));

      // 推进时钟 1 分钟：解锁
      clock.advance(const Duration(minutes: 1));
      expect(await limiter.check(), equals(const Unlocked(5)));

      // 第 6 次失败：锁定 2 分钟 (2^1 = 2)
      final res6 = await verifyPin(sensitivePin('000000'));
      expect(res6, isA<Err<void>>());
      final f6 = (res6 as Err<void>).failure as LockedOutFailure;
      expect(f6.until, equals(clock.nowUtc().add(const Duration(minutes: 2))));

      // 推进时钟 2 分钟后第 7 次：锁定 4 分钟 (2^2 = 4)
      clock.advance(const Duration(minutes: 2));
      final res7 = await verifyPin(sensitivePin('000000'));
      final f7 = (res7 as Err<void>).failure as LockedOutFailure;
      expect(f7.until, equals(clock.nowUtc().add(const Duration(minutes: 4))));

      // 依次翻倍测试：8, 16, 32, 60(上限)
      final expectedMinutes = [8, 16, 32, 60, 60];
      for (final minutes in expectedMinutes) {
        clock.advance(
          Duration(
            minutes: (await limiter.check() as Locked).until
                .difference(clock.nowUtc())
                .inMinutes,
          ),
        );
        final r = await verifyPin(sensitivePin('000000'));
        final f = (r as Err<void>).failure as LockedOutFailure;
        expect(f.until.difference(clock.nowUtc()).inMinutes, equals(minutes));
      }
    });

    test('验收：重启后锁定仍在', () async {
      await setUpPin(sensitivePin('123456'));

      // 触发第 5 次锁定
      for (var i = 0; i < 5; i++) {
        await verifyPin(sensitivePin('000000'));
      }
      final lockedState = await limiter.check() as Locked;
      final expectedUntil = lockedState.until;

      // 模拟重启：全新实例加载同一 SecretStore
      final newLimiter = AttemptLimiter(
        store: secretStore,
        clock: clock,
        keyPrefix: 'ow.app.pin',
      );
      final newVerify = VerifyPin(
        store: secretStore,
        crypto: crypto,
        limiter: newLimiter,
      );

      final state = await newLimiter.check();
      expect(state, isA<Locked>());
      expect((state as Locked).until, equals(expectedUntil));

      final verifyRes = await newVerify(sensitivePin('123456'));
      expect(verifyRes, isA<Err<void>>());
      final failure = (verifyRes as Err<void>).failure as LockedOutFailure;
      expect(failure.until, equals(expectedUntil));
    });

    test('验收：把系统时间往回调不能提前解锁', () async {
      await setUpPin(sensitivePin('123456'));
      for (var i = 0; i < 5; i++) {
        await verifyPin(sensitivePin('000000'));
      }
      final lockedState = await limiter.check() as Locked;
      expect(
        lockedState.until,
        equals(clock.nowUtc().add(const Duration(minutes: 1))),
      );

      // 恶意将系统时间回调 10 分钟
      clock.now = clock.now.subtract(const Duration(minutes: 10));

      // 验证时检测到时钟倒拨，保留剩余时长，不能提前解锁
      final res = await verifyPin(sensitivePin('123456'));
      expect(res, isA<Err<void>>());
      final failure = (res as Err<void>).failure as LockedOutFailure;
      expect(failure.until.isAfter(clock.nowUtc()), isTrue);
    });
  });

  group('ChangePin', () {
    test('旧PIN错误_修改失败且失败记入limiter', () async {
      await setUpPin(sensitivePin('123456'));

      final res = await changePin(
        oldPin: sensitivePin('999999'),
        newPin: sensitivePin('654321'),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err<void>).failure, isA<WrongPasswordFailure>());
      expect(await limiter.check(), equals(const Unlocked(1)));
    });

    test('新PIN格式不合法_修改失败', () async {
      await setUpPin(sensitivePin('123456'));

      final res = await changePin(
        oldPin: sensitivePin('123456'),
        newPin: sensitivePin('bad'),
      );
      expect(res, isA<Err<void>>());
      expect((res as Err<void>).failure, isA<ValidationFailure>());
    });

    test('旧PIN正确且新PIN合法_修改成功', () async {
      await setUpPin(sensitivePin('123456'));

      final res = await changePin(
        oldPin: sensitivePin('123456'),
        newPin: sensitivePin('654321'),
      );
      expect(res, isA<Ok<void>>());

      // 旧PIN失效
      final verifyOld = await verifyPin(sensitivePin('123456'));
      expect(verifyOld, isA<Err<void>>());

      // 新PIN生效
      final verifyNew = await verifyPin(sensitivePin('654321'));
      expect(verifyNew, isA<Ok<void>>());
    });
  });

  group('AppLockStateMachine', () {
    late AppLockStateMachine stateMachine;
    var lockCallbackCount = 0;
    var unlockCallbackCount = 0;

    setUp(() {
      lockCallbackCount = 0;
      unlockCallbackCount = 0;
      stateMachine = AppLockStateMachine(
        store: secretStore,
        limiter: limiter,
        verifyPin: verifyPin,
        clock: clock,
        onLock: () async => lockCallbackCount++,
        onUnlock: () async => unlockCallbackCount++,
      );
    });

    tearDown(() {
      stateMachine.dispose();
    });

    test('未设置PIN时初始化_状态为AppLockUninitialized', () async {
      final state = await stateMachine.initialize();
      expect(state, equals(const AppLockUninitialized()));
      expect(stateMachine.current, equals(const AppLockUninitialized()));
    });

    test('已设置PIN时初始化_状态为AppLockLocked', () async {
      await setUpPin(sensitivePin('123456'));
      final state = await stateMachine.initialize();
      expect(state, equals(const AppLockLocked()));
      expect(stateMachine.current, equals(const AppLockLocked()));
    });

    test('正确输入PIN解锁_状态变为AppLockUnlocked且触发onUnlock', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();

      final states = <AppLockState>[];
      final sub = stateMachine.stream.listen(states.add);

      final res = await stateMachine.unlockWithPin(sensitivePin('123456'));
      expect(res, isA<Ok<void>>());
      expect(stateMachine.current, equals(const AppLockUnlocked()));
      expect(unlockCallbackCount, 1);
      expect(states, [const AppLockUnlocked()]);

      await sub.cancel();
    });

    test('手动锁定lock_状态变为AppLockLocked且触发onLock', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();
      await stateMachine.unlockWithPin(sensitivePin('123456'));

      expect(stateMachine.current, equals(const AppLockUnlocked()));

      await stateMachine.lock();
      expect(stateMachine.current, equals(const AppLockLocked()));
      expect(lockCallbackCount, 1);
    });

    test('生物识别解锁_状态变为AppLockUnlocked且触发onUnlock', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();

      await stateMachine.unlockWithBiometric();
      expect(stateMachine.current, equals(const AppLockUnlocked()));
      expect(unlockCallbackCount, 1);
    });

    test('连错5次PIN_状态机变为AppLockLocked带lockedUntil', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();

      for (var i = 0; i < 4; i++) {
        await stateMachine.unlockWithPin(sensitivePin('000000'));
        expect(stateMachine.current, equals(const AppLockLocked()));
      }

      final res5 = await stateMachine.unlockWithPin(sensitivePin('000000'));
      expect(res5, isA<Err<void>>());
      expect(stateMachine.current, isA<AppLockLocked>());
      final locked = stateMachine.current as AppLockLocked;
      expect(
        locked.lockedUntil,
        equals(clock.nowUtc().add(const Duration(minutes: 1))),
      );
    });

    test('后台超时重锁规则R19_immediately_after1Min_after5Min', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();
      await stateMachine.unlockWithPin(sensitivePin('123456'));

      // 1. AutoLock.after1Min，切到后台 30 秒后回来 -> 不锁定
      stateMachine.handleAppPaused();
      clock.advance(const Duration(seconds: 30));
      await stateMachine.handleAppResumed(AutoLock.after1Min);
      expect(stateMachine.current, equals(const AppLockUnlocked()));

      // 2. AutoLock.after1Min，切到后台 61 秒后回来 -> 锁定并触发 onLock
      stateMachine.handleAppPaused();
      clock.advance(const Duration(seconds: 61));
      await stateMachine.handleAppResumed(AutoLock.after1Min);
      expect(stateMachine.current, equals(const AppLockLocked()));
      expect(lockCallbackCount, 1);

      // 解锁后测 AutoLock.immediately
      await stateMachine.unlockWithPin(sensitivePin('123456'));
      stateMachine.handleAppPaused();
      clock.advance(const Duration(seconds: 1));
      await stateMachine.handleAppResumed(AutoLock.immediately);
      expect(stateMachine.current, equals(const AppLockLocked()));
      expect(lockCallbackCount, 2);

      // 解锁后测 AutoLock.after5Min
      await stateMachine.unlockWithPin(sensitivePin('123456'));
      stateMachine.handleAppPaused();
      clock.advance(const Duration(minutes: 4));
      await stateMachine.handleAppResumed(AutoLock.after5Min);
      expect(stateMachine.current, equals(const AppLockUnlocked()));

      stateMachine.handleAppPaused();
      clock.advance(const Duration(minutes: 5, seconds: 1));
      await stateMachine.handleAppResumed(AutoLock.after5Min);
      expect(stateMachine.current, equals(const AppLockLocked()));
      expect(lockCallbackCount, 3);
    });

    test('runExternal外部界面进行期间切到后台不计时间_默认立即锁定回来也不锁定', () async {
      await setUpPin(sensitivePin('123456'));
      await stateMachine.initialize();
      await stateMachine.unlockWithPin(sensitivePin('123456'));

      // 处于 runExternal 期间（模拟系统生物识别/系统分享/文件选择）
      await stateMachine.runExternal(() async {
        expect(stateMachine.isExternalOperationInProgress, isTrue);
        // 系统弹窗导致应用进入后台
        stateMachine.handleAppPaused();
        clock.advance(const Duration(seconds: 10));
        // 回到前台
        await stateMachine.handleAppResumed(AutoLock.immediately);
        expect(stateMachine.current, equals(const AppLockUnlocked()));
      });

      // 外部界面已结束
      expect(stateMachine.isExternalOperationInProgress, isFalse);
      expect(stateMachine.current, equals(const AppLockUnlocked()));

      // 回到前台处理完后再次直接resume不应锁定（_pausedAt已清空）
      await stateMachine.handleAppResumed(AutoLock.immediately);
      expect(stateMachine.current, equals(const AppLockUnlocked()));

      // 外部界面结束后，真正切到后台再回来 -> 仍然锁定
      stateMachine.handleAppPaused();
      clock.advance(const Duration(seconds: 1));
      await stateMachine.handleAppResumed(AutoLock.immediately);
      expect(stateMachine.current, equals(const AppLockLocked()));
    });
  });
}
