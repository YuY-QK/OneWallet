import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:ow_domain/ow_domain.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';
import 'formatters.dart';

/// 净值图表刻度格式化（纯函数，Decimal 计算）。
String formatChartScale(Decimal value, {required bool hidden}) {
  if (hidden) return hiddenAmountMask;
  final thousand = Decimal.fromInt(1000);
  final abs = value.abs();
  final sign = value.sign < 0 ? '-' : '';
  if (abs >= thousand) {
    final k = (abs / thousand).toDecimal(scaleOnInfinitePrecision: 2);
    return '$sign${k.toStringAsFixed(1)}k';
  } else if (abs >= Decimal.one) {
    return '$sign${abs.toStringAsFixed(0)}';
  } else {
    return '$sign${abs.toStringAsFixed(2)}';
  }
}

/// 净值曲线图表组件（UI_DESIGN_SYSTEM 第 5 节与 prototype.html 规范）。
///
/// - 折线为 `c.brand` 1.8 像素，下方 `c.brandSoft` 填充。
/// - 只标最高与最低两条刻度线（`c.line`）及左侧金额标注。
/// - 末端实心圆点（半径 3.5，`c.brand`）。
/// - 底部横坐标两侧标注（`c.muted`）。
class OwNetWorthChart extends StatelessWidget {
  const OwNetWorthChart({
    super.key,
    required this.snapshots,
    required this.hidden,
    required this.leftAxisLabel,
    required this.rightAxisLabel,
    this.semanticLabel,
    this.height = 110,
  });

  /// 快照数据列表，按日期升序排列。
  final List<Snapshot> snapshots;

  /// 是否隐藏金额。
  final bool hidden;

  /// 底部横轴左侧标签（如「30 天前」）。
  final String leftAxisLabel;

  /// 底部横轴右侧标签（如「今天」）。
  final String rightAxisLabel;

  /// 辅助功能读屏文案。
  final String? semanticLabel;

  /// 图表高度，默认 110。
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.ow;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            snapshots: snapshots,
            hidden: hidden,
            leftAxisLabel: leftAxisLabel,
            rightAxisLabel: rightAxisLabel,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.snapshots,
    required this.hidden,
    required this.leftAxisLabel,
    required this.rightAxisLabel,
    required this.colors,
  });

  final List<Snapshot> snapshots;
  final bool hidden;
  final String leftAxisLabel;
  final String rightAxisLabel;
  final OwColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.length < 2) return;

    var lo = snapshots.first.totalUsd;
    var hi = snapshots.first.totalUsd;
    for (final s in snapshots) {
      if (s.totalUsd < lo) lo = s.totalUsd;
      if (s.totalUsd > hi) hi = s.totalUsd;
    }

    const plotLeft = 44.0;
    final plotRight = size.width - 6.0;
    const plotTop = 8.0;
    const bottomMargin = 20.0;
    final plotBottom = size.height - bottomMargin;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final linePaint = Paint()
      ..color = colors.line
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final loDouble = lo.toDouble();
    final hiDouble = hi.toDouble();

    // 刻度线与金额标注
    if (lo == hi) {
      final yMid = plotTop + plotHeight / 2;
      canvas.drawLine(
        Offset(plotLeft, yMid),
        Offset(plotRight, yMid),
        linePaint,
      );
      _paintText(
        canvas: canvas,
        text: formatChartScale(hi, hidden: hidden),
        offset: Offset(0, yMid - 6),
        color: colors.muted,
        isMono: true,
      );
    } else {
      canvas.drawLine(
        const Offset(plotLeft, plotTop),
        Offset(plotRight, plotTop),
        linePaint,
      );
      canvas.drawLine(
        Offset(plotLeft, plotBottom),
        Offset(plotRight, plotBottom),
        linePaint,
      );

      _paintText(
        canvas: canvas,
        text: formatChartScale(hi, hidden: hidden),
        offset: const Offset(0, plotTop - 6),
        color: colors.muted,
        isMono: true,
      );
      _paintText(
        canvas: canvas,
        text: formatChartScale(lo, hidden: hidden),
        offset: Offset(0, plotBottom - 6),
        color: colors.muted,
        isMono: true,
      );
    }

    // 绘制填充与折线
    final n = snapshots.length;
    Offset pointAt(int i) {
      final x = plotLeft + plotWidth * i / (n - 1);
      final val = snapshots[i].totalUsd.toDouble();
      final y = (hiDouble == loDouble)
          ? (plotTop + plotHeight / 2)
          : (plotTop +
                plotHeight * (1.0 - (val - loDouble) / (hiDouble - loDouble)));
      return Offset(x, y);
    }

    final fillPath = Path()..moveTo(plotLeft, plotBottom);
    for (var i = 0; i < n; i++) {
      final pt = pointAt(i);
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(pointAt(n - 1).dx, plotBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..color = colors.brandSoft
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePath = Path();
    final p0 = pointAt(0);
    strokePath.moveTo(p0.dx, p0.dy);
    for (var i = 1; i < n; i++) {
      final pt = pointAt(i);
      strokePath.lineTo(pt.dx, pt.dy);
    }

    final strokePaint = Paint()
      ..color = colors.brand
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(strokePath, strokePaint);

    // 末端实心圆点
    final lastPt = pointAt(n - 1);
    final dotPaint = Paint()
      ..color = colors.brand
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, 3.5, dotPaint);

    // 底部横轴标签
    _paintText(
      canvas: canvas,
      text: leftAxisLabel,
      offset: Offset(plotLeft, size.height - bottomMargin + 4),
      color: colors.muted,
      isMono: false,
    );

    final rightPainter = _measureText(
      text: rightAxisLabel,
      color: colors.muted,
      isMono: false,
    );
    rightPainter.paint(
      canvas,
      Offset(plotRight - rightPainter.width, size.height - bottomMargin + 4),
    );
  }

  void _paintText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required Color color,
    required bool isMono,
  }) {
    final painter = _measureText(text: text, color: color, isMono: isMono);
    painter.paint(canvas, offset);
  }

  TextPainter _measureText({
    required String text,
    required Color color,
    required bool isMono,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: isMono ? OwFonts.mono : OwFonts.sans,
          fontFamilyFallback: OwFonts.fallback,
          fontSize: 11,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    if (oldDelegate.hidden != hidden) return true;
    if (oldDelegate.leftAxisLabel != leftAxisLabel) return true;
    if (oldDelegate.rightAxisLabel != rightAxisLabel) return true;
    if (oldDelegate.colors != colors) return true;
    if (oldDelegate.snapshots.length != snapshots.length) return true;
    for (var i = 0; i < snapshots.length; i++) {
      if (oldDelegate.snapshots[i] != snapshots[i]) return true;
    }
    return false;
  }
}
