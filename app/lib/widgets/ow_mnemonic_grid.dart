import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import '../theme/ow_text_styles.dart';

/// 助记词词格网格（三列，每格带序号，等宽字体）。
class OwMnemonicGrid extends StatelessWidget {
  const OwMnemonicGrid({super.key, required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final c = context.ow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 12) / 3;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < words.length; i++)
              SizedBox(
                width: cellWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}',
                        style: OwTextStyles.mono.copyWith(
                          color: c.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          words[i],
                          overflow: TextOverflow.ellipsis,
                          style: OwTextStyles.mono.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
