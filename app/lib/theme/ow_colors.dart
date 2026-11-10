import 'package:flutter/material.dart';

/// 设计令牌。取值见 docs/UI_DESIGN_SYSTEM_v1.0.md 第 2 节。
@immutable
class OwColors extends ThemeExtension<OwColors> {
  const OwColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.brand,
    required this.brandInk,
    required this.brandSoft,
    required this.up,
    required this.upSoft,
    required this.down,
    required this.downSoft,
    required this.warn,
    required this.warnSoft,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color brand;
  final Color brandInk;
  final Color brandSoft;
  final Color up;
  final Color upSoft;
  final Color down;
  final Color downSoft;
  final Color warn;
  final Color warnSoft;

  static const light = OwColors(
    bg: Color(0xFFF1F3F7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF16202E),
    muted: Color(0xFF5E6B7D),
    line: Color(0xFFDCE2EA),
    brand: Color(0xFF1F3A5F),
    brandInk: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFE6ECF4),
    up: Color(0xFF1B7F52),
    upSoft: Color(0xFFE2F2EA),
    down: Color(0xFFC2362B),
    downSoft: Color(0xFFFBE7E4),
    warn: Color(0xFFA8690F),
    warnSoft: Color(0xFFFAEFD9),
  );

  static const dark = OwColors(
    bg: Color(0xFF0E141C),
    surface: Color(0xFF17202B),
    ink: Color(0xFFE6ECF3),
    muted: Color(0xFF93A1B3),
    line: Color(0xFF263241),
    brand: Color(0xFF8DB4E2),
    brandInk: Color(0xFF0E141C),
    brandSoft: Color(0xFF1D2A3A),
    up: Color(0xFF4CC38A),
    upSoft: Color(0xFF173326),
    down: Color(0xFFF0766B),
    downSoft: Color(0xFF3A1D1A),
    warn: Color(0xFFE0A84A),
    warnSoft: Color(0xFF382B12),
  );

  @override
  OwColors copyWith() => this;

  @override
  OwColors lerp(ThemeExtension<OwColors>? other, double t) {
    if (other is! OwColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OwColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      brand: mix(brand, other.brand),
      brandInk: mix(brandInk, other.brandInk),
      brandSoft: mix(brandSoft, other.brandSoft),
      up: mix(up, other.up),
      upSoft: mix(upSoft, other.upSoft),
      down: mix(down, other.down),
      downSoft: mix(downSoft, other.downSoft),
      warn: mix(warn, other.warn),
      warnSoft: mix(warnSoft, other.warnSoft),
    );
  }
}

extension OwColorsContext on BuildContext {
  OwColors get ow => Theme.of(this).extension<OwColors>()!;
}
