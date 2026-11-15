import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onewallet/features/accounts/presentation/widgets/address_sheet.dart';
import 'package:onewallet/widgets/ow_chip.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _evmAddr = '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed';
const _evmShort = '0x5aAe…eAed';
const _btcAddr = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const _btcShort = 'bc1qar…5mdq';
const _solAddr = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
const _solShort = '7xKXtg…gAsU';
const _trxAddr = 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE';
const _trxShort = 'TQn9Y2…bLSE';

TestRig _rig() {
  final rig = TestRig();
  final w1 = rig.addWallet('w1', 'Uni 钱包', source: WalletSource.uniswap);
  final w2 = rig.addWallet('w2', '冷钱包', source: WalletSource.metamask);

  rig.addAddress(
    'a1',
    w1.id,
    _evmAddr,
    family: ChainFamily.evm,
    scheme: DerivationScheme.evmStandard,
    derivationIndex: 0,
  );
  rig.addAddress(
    'a2',
    w1.id,
    _solAddr,
    family: ChainFamily.solana,
    note: '日常使用',
  );
  rig.addAddress(
    'a3',
    w2.id,
    _btcAddr,
    family: ChainFamily.bitcoin,
    note: '长期持有',
  );
  rig.addAddress('a4', w2.id, _trxAddr, family: ChainFamily.tron);

  return rig;
}

void main() {
  group('P10 地址簿', () {
    testWidgets('空状态_没有任何地址时展示暂无地址', (tester) async {
      await pumpApp(tester, TestRig(), location: '/accounts/addresses');
      expect(find.text('暂无地址'), findsOneWidget);
      expect(find.text('添加钱包账户后，此处将集中管理你的所有地址'), findsOneWidget);
    });

    testWidgets('正常列表展示_显示缩略地址、所属账户、链、备注与派生标记', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      // 缩略地址
      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_solShort), findsOneWidget);
      expect(find.text(_btcShort), findsOneWidget);
      expect(find.text(_trxShort), findsOneWidget);

      // 副标题信息：账户名、链、保险库派生、备注
      expect(find.textContaining('Uni 钱包'), findsWidgets);
      expect(find.textContaining('冷钱包'), findsWidgets);
      expect(find.textContaining('保险库派生'), findsOneWidget);
      expect(find.textContaining('备注：日常使用'), findsOneWidget);
      expect(find.textContaining('备注：长期持有'), findsOneWidget);

      // 底部提示
      expect(
        find.text('粘贴一个完整地址，可以查它是不是你的。没有匹配时会显示「不在你的地址簿中」。'),
        findsOneWidget,
      );
    });

    testWidgets('顶部分段控件_点击切换回账户列表', (tester) async {
      final router = await pumpApp(
        tester,
        _rig(),
        location: '/accounts/addresses',
      );

      // 点击分段控件中的 "账户" 选项
      final segmentFinder = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('OwSegmented'),
        ),
        matching: find.text('账户'),
      );
      await tester.tap(segmentFinder);
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts');
    });

    testWidgets('链家族筛选标签_切换筛选只展示对应链的地址', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      // 切换到 EVM
      await tester.tap(find.widgetWithText(OwChip, 'EVM'));
      await tester.pumpAndSettle();
      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_btcShort), findsNothing);
      expect(find.text(_solShort), findsNothing);

      // 切换到 Bitcoin
      await tester.tap(find.widgetWithText(OwChip, 'Bitcoin'));
      await tester.pumpAndSettle();
      expect(find.text(_evmShort), findsNothing);
      expect(find.text(_btcShort), findsOneWidget);

      // 切换回全部链
      await tester.tap(find.widgetWithText(OwChip, '全部链'));
      await tester.pumpAndSettle();
      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_btcShort), findsOneWidget);
    });

    testWidgets('地址片段搜索_匹配部分地址且不标为精确匹配', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '5aae',
      );
      await tester.pumpAndSettle();

      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_btcShort), findsNothing);
      expect(find.text('是你的地址'), findsNothing);
    });

    testWidgets('完整地址精确搜索_标记为是你的地址且排在首位', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      // 输入完整地址（大写形式模拟粘贴）
      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '  ${_evmAddr.toUpperCase()}  ',
      );
      await tester.pumpAndSettle();

      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text('是你的地址'), findsOneWidget);
    });

    testWidgets('账户名搜索_匹配对应账户下的地址', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '冷钱包',
      );
      await tester.pumpAndSettle();

      expect(find.text(_btcShort), findsOneWidget);
      expect(find.text(_trxShort), findsOneWidget);
      expect(find.text(_evmShort), findsNothing);
    });

    testWidgets('备注搜索_匹配备注文本', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '长期持有',
      );
      await tester.pumpAndSettle();

      expect(find.text(_btcShort), findsOneWidget);
      expect(find.text(_evmShort), findsNothing);
    });

    testWidgets('搜索无结果_明确展示「不在你的地址簿中」', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '0x9999999999999999999999999999999999999999',
      );
      await tester.pumpAndSettle();

      expect(find.text('不在你的地址簿中'), findsOneWidget);
      expect(find.text('未在你的地址簿中找到此地址或相关信息'), findsOneWidget);
    });

    testWidgets('清空搜索输入框_恢复展示全部地址', (tester) async {
      await pumpApp(tester, _rig(), location: '/accounts/addresses');

      await tester.enterText(
        find.byKey(const Key('address_book_search_field')),
        '5aae',
      );
      await tester.pumpAndSettle();
      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_btcShort), findsNothing);

      // 点击清空按钮
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_evmShort), findsOneWidget);
      expect(find.text(_btcShort), findsOneWidget);
    });

    testWidgets('点击地址行_弹出地址操作面板并支持编辑备注', (tester) async {
      final rig = _rig();
      await pumpApp(tester, rig, location: '/accounts/addresses');

      await tester.tap(find.text(_evmShort));
      await tester.pumpAndSettle();

      // 弹出 AddressSheet
      expect(find.byType(AddressSheet), findsOneWidget);
      expect(find.text('添加备注'), findsOneWidget);

      // 点击添加/编辑备注
      await tester.tap(find.text('添加备注'));
      await tester.pumpAndSettle();

      // 弹窗输入新备注
      expect(find.text('编辑备注'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '主打测试地址');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 面板刷新并展示新备注
      expect(find.text('主打测试地址'), findsOneWidget);
      final saved = await rig.addresses.byId('a1');
      expect(saved?.note, '主打测试地址');
    });

    testWidgets('右上角添加按钮_导航到添加账户页', (tester) async {
      final router = await pumpApp(
        tester,
        _rig(),
        location: '/accounts/addresses',
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/accounts/add');
    });
  });
}
