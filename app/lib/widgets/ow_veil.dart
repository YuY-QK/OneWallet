import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';

/// 遮挡块（斜纹底加虚线边框，中间放"验证后查看"按钮）。
class OwVeil extends StatelessWidget {
  const OwVeil({
    super.key,
    required this.onReveal,
    this.message,
    this.buttonText,
  });

  final VoidCallback onReveal;
  final String? message;
  final String? buttonText;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: c.line,
        borderRadius: 10,
        dashWidth: 5,
        dashSpace: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _StripedBackgroundPainter(
            color1: c.surface,
            color2: c.bg,
            stripeWidth: 8,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message ?? '每次查看都需要面容或主密码验证',
                  style: OwTextStyles.caption.copyWith(color: c.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onReveal,
                  child: Text(buttonText ?? '验证后查看'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StripedBackgroundPainter extends CustomPainter {
  const _StripedBackgroundPainter({
    required this.color1,
    required this.color2,
    required this.stripeWidth,
  });

  final Color color1;
  final Color color2;
  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // 先填充底层底色
    final basePaint = Paint()..color = color1;
    canvas.drawRect(Offset.zero & size, basePaint);

    // 绘制 135 度斜条纹
    final stripePaint = Paint()
      ..color = color2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stripeWidth;

    final step = stripeWidth * 2;
    final maxDim = size.width + size.height;

    for (var x = -size.height; x < maxDim; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedBackgroundPainter oldDelegate) {
    return color1 != oldDelegate.color1 ||
        color2 != oldDelegate.color2 ||
        stripeWidth != oldDelegate.stripeWidth;
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashSpace;
        final next = math.min(distance + len, metric.length);
        if (draw) {
          dest.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        borderRadius != oldDelegate.borderRadius ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace;
  }
}
