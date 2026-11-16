import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../../bootstrap/foundation_providers.dart';
import '../../../../bootstrap/read_model_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/ow_colors.dart';
import '../../../../theme/ow_text_styles.dart';
import '../../../../widgets/ow_card.dart';
import '../../../../widgets/ow_net_worth_chart.dart';
import '../../../../widgets/ow_segmented.dart';

/// 净值曲线的时间范围。
enum NetWorthRange { days7, days30, days90, all }

/// 净值曲线选中的时间范围（默认 30 天）。
final netWorthRangeProvider =
    NotifierProvider.autoDispose<NetWorthRangeController, NetWorthRange>(
      NetWorthRangeController.new,
    );

class NetWorthRangeController extends Notifier<NetWorthRange> {
  @override
  NetWorthRange build() => NetWorthRange.days30;

  void setRange(NetWorthRange range) => state = range;
}

/// 根据所选时间范围监听快照数据。
final netWorthSnapshotsProvider = StreamProvider.autoDispose<List<Snapshot>>((
  ref,
) {
  final range = ref.watch(netWorthRangeProvider);
  final nowUtc = ref.watch(clockProvider).nowUtc();
  final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final fromUtc = switch (range) {
    NetWorthRange.days7 => todayUtc.subtract(const Duration(days: 6)),
    NetWorthRange.days30 => todayUtc.subtract(const Duration(days: 29)),
    NetWorthRange.days90 => todayUtc.subtract(const Duration(days: 89)),
    NetWorthRange.all => DateTime.utc(2000, 1, 1),
  };
  return ref.watch(snapshotRepositoryProvider).watchRange(fromUtc, todayUtc);
});

/// P02 净值曲线卡片。
class NetWorthCard extends ConsumerWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.ow;
    final hidden = ref.watch(hideAmountsProvider);
    final range = ref.watch(netWorthRangeProvider);
    final snapshotsAsync = ref.watch(netWorthSnapshotsProvider);
    final nowUtc = ref.watch(clockProvider).nowUtc();
    final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    return OwCard(
      key: const ValueKey('net_worth_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: snapshotsAsync.when(
              data: (snapshots) {
                if (snapshots.length < 2) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l.overviewChartEmpty,
                        key: const ValueKey('net_worth_chart_empty'),
                        style: OwTextStyles.caption.copyWith(color: c.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final leftLabel = switch (range) {
                  NetWorthRange.days7 => l.overviewChartDaysAgo(7),
                  NetWorthRange.days30 => l.overviewChartDaysAgo(30),
                  NetWorthRange.days90 => l.overviewChartDaysAgo(90),
                  NetWorthRange.all => () {
                    final days = todayUtc
                        .difference(snapshots.first.date)
                        .inDays;
                    return days > 0
                        ? l.overviewChartDaysAgo(days)
                        : '${snapshots.first.date.month}-${snapshots.first.date.day}';
                  }(),
                };

                final semanticLabel = switch (range) {
                  NetWorthRange.days7 => l.overviewChartAriaLabel(7),
                  NetWorthRange.days30 => l.overviewChartAriaLabel(30),
                  NetWorthRange.days90 => l.overviewChartAriaLabel(90),
                  NetWorthRange.all => l.overviewChartAriaLabelAll,
                };

                return OwNetWorthChart(
                  key: const ValueKey('net_worth_chart'),
                  snapshots: snapshots,
                  hidden: hidden,
                  leftAxisLabel: leftLabel,
                  rightAxisLabel: l.overviewChartToday,
                  semanticLabel: semanticLabel,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => Center(
                child: Text(
                  l.overviewChartEmpty,
                  key: const ValueKey('net_worth_chart_empty'),
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OwSegmented<NetWorthRange>(
            key: const ValueKey('net_worth_range_segmented'),
            segments: [
              OwSegment(
                value: NetWorthRange.days7,
                label: l.overviewChartRange7d,
              ),
              OwSegment(
                value: NetWorthRange.days30,
                label: l.overviewChartRange30d,
              ),
              OwSegment(
                value: NetWorthRange.days90,
                label: l.overviewChartRange90d,
              ),
              OwSegment(
                value: NetWorthRange.all,
                label: l.overviewChartRangeAll,
              ),
            ],
            value: range,
            onChanged: (r) =>
                ref.read(netWorthRangeProvider.notifier).setRange(r),
          ),
        ],
      ),
    );
  }
}
