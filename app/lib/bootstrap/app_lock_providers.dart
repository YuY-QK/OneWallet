import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';

import 'foundation_providers.dart';
import 'usecase_providers.dart';
import 'vault_providers.dart';

/// 应用锁 PIN 错误次数与锁定限制器。
final appLockLimiterProvider = Provider<AttemptLimiter>(
  (ref) => AttemptLimiter(
    store: ref.watch(secretStoreProvider),
    clock: ref.watch(clockProvider),
    keyPrefix: 'ow.app.pin',
  ),
);

/// 设置应用锁 PIN 码用例。
final setUpPinProvider = FutureProvider<SetUpPin>((ref) async {
  final crypto = await ref.watch(vaultCryptoProvider.future);
  return SetUpPin(
    store: ref.watch(secretStoreProvider),
    crypto: crypto,
    limiter: ref.watch(appLockLimiterProvider),
  );
});

/// 校验应用锁 PIN 码用例。
final verifyPinProvider = FutureProvider<VerifyPin>((ref) async {
  final crypto = await ref.watch(vaultCryptoProvider.future);
  return VerifyPin(
    store: ref.watch(secretStoreProvider),
    crypto: crypto,
    limiter: ref.watch(appLockLimiterProvider),
  );
});

/// 修改应用锁 PIN 码用例。
final changePinProvider = FutureProvider<ChangePin>((ref) async {
  final verify = await ref.watch(verifyPinProvider.future);
  final setUp = await ref.watch(setUpPinProvider.future);
  return ChangePin(verifyPin: verify, setUpPin: setUp);
});

/// 应用锁状态机。
final appLockStateMachineProvider = FutureProvider<AppLockStateMachine>((
  ref,
) async {
  final verify = await ref.watch(verifyPinProvider.future);
  final machine = AppLockStateMachine(
    store: ref.watch(secretStoreProvider),
    limiter: ref.watch(appLockLimiterProvider),
    verifyPin: verify,
    clock: ref.watch(clockProvider),
    onLock: () {
      // 锁定时清除内存中的资产状态与未决数据
      ref.invalidate(portfolioSummaryProvider);
    },
  );
  ref.onDispose(machine.dispose);
  await machine.initialize();
  return machine;
});

/// 当前应用锁状态流。
final appLockStateStreamProvider = StreamProvider<AppLockState>((ref) async* {
  final machine = await ref.watch(appLockStateMachineProvider.future);
  yield machine.current;
  yield* machine.stream;
});
