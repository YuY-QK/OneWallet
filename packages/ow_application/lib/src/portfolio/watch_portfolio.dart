import 'package:decimal/decimal.dart';
import 'package:ow_domain/ow_domain.dart';

import '../util/stream_combine.dart';

/// 小额阈值换算所用的币种：以 USDT 的价格近似 1 USD。
const String usdProxyAssetId = 'USDT';

/// 总览所需的汇总结果流（P02、PRD R7–R12）。
///
/// 组合账户、持仓、当前计价货币的价格、设置与手动隐藏的代币；
/// 任一上游流变化都会重新计算并发出新的 [PortfolioSummary]。
/// 计算本身由 [PortfolioCalculator.summarize] 完成。
final class WatchPortfolio {
  const WatchPortfolio({
    required this._accounts,
    required this._holdings,
    required this._prices,
    required this._settings,
    required this._tokenVisibility,
  });

  final AccountRepository _accounts;
  final HoldingRepository _holdings;
  final PriceRepository _prices;
  final SettingsRepository _settings;
  final TokenVisibilityRepository _tokenVisibility;

  /// 返回汇总结果流。上游仓储的异常（程序缺陷）以流错误转发。
  ///
  /// 手动隐藏的代币集合经 `TokenVisibilityRepository.watchHidden()` 订阅：
  /// 手动隐藏或显示代币后，总览立即发出新摘要。
  Stream<PortfolioSummary> call() {
    // 设置与价格成对推送：切换计价货币时，不会出现新设置配旧货币价格的组合。
    final settingsWithPrices = switchLatest(
      _settings.watch(),
      (AppSettings s) => _prices.watch(s.quote).map((p) => (s, p)),
    );
    final settingsPricesHidden = combineLatest2(
      settingsWithPrices,
      _tokenVisibility.watchHidden(),
      (sp, hidden) => (sp.$1, sp.$2, hidden),
    );
    return combineLatest3(
      _accounts.watchAll(),
      _holdings.watchAll(),
      settingsPricesHidden,
      (accounts, holdings, sph) {
        final (settings, prices, hidden) = sph;
        return PortfolioCalculator.summarize(
          accounts: accounts,
          holdings: holdings,
          prices: prices,
          hideSmall: settings.hideSmall,
          smallThreshold: smallThresholdFor(settings.quote, prices),
          hiddenTokens: hidden,
        );
      },
    );
  }

  /// "1 USD 折合 [quote]" 的值，作为小额隐藏的阈值（R11）。
  ///
  /// USD 为 1；CNY 用 USDT 的 CNY 价格近似。[prices] 中没有 USDT 价格时退回 1，
  /// 即以 1 CNY 为阈值（比 1 USD 略严，只会少隐藏、不会多隐藏）。
  static Decimal smallThresholdFor(Quote quote, Map<String, Price> prices) =>
      switch (quote) {
        Quote.usd => Decimal.one,
        Quote.cny => prices[usdProxyAssetId]?.price ?? Decimal.one,
      };
}
