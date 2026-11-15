import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../theme/ow_colors.dart';

/// 6 位 PIN 码指示点，支持错误抖动动画。
class PinDots extends StatefulWidget {
  const PinDots({
    super.key,
    required this.length,
    this.total = 6,
    this.shake = false,
    this.onShakeEnd,
  });

  /// 已输入的位数（0 ~ total）。
  final int length;

  /// 总位数，默认 6。
  final int total;

  /// 是否触发抖动动画。
  final bool shake;

  /// 抖动完成后的回调。
  final VoidCallback? onShakeEnd;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        widget.onShakeEnd?.call();
      }
    });
    if (widget.shake) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = sin(_controller.value * pi * 4) * 12;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.total, (i) {
          final isFilled = i < widget.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? colors.brand : Colors.transparent,
              border: Border.all(
                color: isFilled
                    ? colors.brand
                    : colors.muted.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}
