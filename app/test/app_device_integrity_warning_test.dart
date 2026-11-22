import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/app.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_domain/ow_domain.dart';

import 'support/fakes.dart';

final class _StubDeviceIntegrity implements DeviceIntegrity {
  const _StubDeviceIntegrity({required this.compromised});
  final bool compromised;

  @override
  Future<bool> looksCompromised() async => compromised;
}

void main() {
  testWidgets('设备完整性_检测到异常时_启动弹出提示弹窗且可确认关闭不阻止使用', (tester) async {
    final rig = TestRig();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...rig.overrides,
          deviceIntegrityProvider.overrideWithValue(
            const _StubDeviceIntegrity(compromised: true),
          ),
        ],
        child: const OneWalletApp(initialLocation: '/overview'),
      ),
    );
    await tester.pumpAndSettle();

    // 确认弹出了告警弹窗
    expect(find.text('设备安全风险提示'), findsOneWidget);
    expect(find.text('我知道了'), findsOneWidget);
    expect(
      find.text('检测到当前设备环境存在异常（可能已被 root、越狱或处于调试状态），系统沙盒与硬件保护可能失效。请谨慎使用。'),
      findsOneWidget,
    );

    // 点击「我知道了」关闭弹窗
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    // 弹窗消失，主应用正常显示，不阻止使用
    expect(find.text('设备安全风险提示'), findsNothing);
    expect(find.byType(OneWalletApp), findsOneWidget);
  });

  testWidgets('设备完整性_正常环境_启动不弹出任何告警弹窗', (tester) async {
    final rig = TestRig();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...rig.overrides,
          deviceIntegrityProvider.overrideWithValue(
            const _StubDeviceIntegrity(compromised: false),
          ),
        ],
        child: const OneWalletApp(initialLocation: '/overview'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设备安全风险提示'), findsNothing);
  });
}
