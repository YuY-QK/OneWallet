import 'package:flutter/material.dart';

import 'ow_colors.dart';
import 'ow_text_styles.dart';

/// 由设计令牌生成 Material 主题。组件代码只通过主题和 [OwColors] 取色。
ThemeData buildOwTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? OwColors.dark : OwColors.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: c.brand, brightness: brightness).copyWith(
        primary: c.brand,
        onPrimary: c.brandInk,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.muted,
        outline: c.line,
        outlineVariant: c.line,
        error: c.down,
        secondaryContainer: c.brandSoft,
        onSecondaryContainer: c.brand,
      );
  const radius = BorderRadius.all(Radius.circular(10));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: OwFonts.sans,
    fontFamilyFallback: OwFonts.fallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: OwTextStyles.title.copyWith(color: c.ink),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: OwTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.brandSoft,
      elevation: 0,
      height: 64,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.brandSoft,
      selectedIconTheme: IconThemeData(color: c.brand),
      unselectedIconTheme: IconThemeData(color: c.muted),
      selectedLabelTextStyle: OwTextStyles.body.copyWith(
        color: c.brand,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: OwTextStyles.body.copyWith(color: c.muted),
    ),
  );
}
