import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/bootstrap/asset_catalog_gate.dart';
import 'package:onewallet/bootstrap/providers.dart';
import 'package:ow_domain/ow_domain.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('币种目录加载完成后才进入应用，库中的币种可被识别', (tester) async {
    const token = ContractToken(
      'ethereum',
      '0x8888888888888888888888888888888888888888',
    );
    final repo = FakeAssetRepository()
      ..assets['FOO'] = const Asset(
        id: 'FOO',
        symbol: 'FOO',
        name: 'Foo',
        priceId: 'foo-coin',
      )
      ..contractMap[token] = 'FOO';
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetRepositoryProvider.overrideWithValue(repo)],
        child: AssetCatalogGate(
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const Directionality(
                textDirection: TextDirection.ltr,
                child: Text('进入应用'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('进入应用'), findsOneWidget);
    expect(captured.read(assetCatalogProvider).resolve(token)?.id, 'FOO');
  });
}
