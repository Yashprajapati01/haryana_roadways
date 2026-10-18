import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'copy.dart';
import 'fa.dart';

/// Transit-app rules: one strong route blue, solid colour cards, large times.
/// Light pages sit on a blue wash so white cards and fields read as surfaces.
/// Dark pages stay near-black. Baloo 2 covers Latin and Devanagari.
class AppTheme {
  static const brand = Color(0xFF1D4ED8);
  static const brandDeep = Color(0xFF1E3A8A);
  static const go = Color(0xFF16A34A);
  static const stopped = Color(0xFF6B7280);
  static const onColor = Color(0xFFFFFFFF);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static Color card(Brightness brightness) =>
      brightness == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF171A21);

  static Color field(Brightness brightness) =>
      brightness == Brightness.light ? const Color(0xFFE7F0FF) : const Color(0xFF1F232B);

  static Color paper(Brightness brightness) =>
      brightness == Brightness.light ? const Color(0xFFD9E6F8) : const Color(0xFF0F1115);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final ink = light ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: light ? brand : const Color(0xFF93B4FF),
      onPrimary: light ? onColor : brandDeep,
      secondary: go,
      onSecondary: onColor,
      error: const Color(0xFFDC2626),
      onError: onColor,
      surface: paper(brightness),
      onSurface: ink,
      onSurfaceVariant: light ? const Color(0xFF3E5578) : const Color(0xFF9CA3AF),
      outline: light ? const Color(0xFFC5D6EE) : const Color(0xFF2A2F3A),
      outlineVariant: light ? const Color(0xFFD5E3F6) : const Color(0xFF1F232B),
    );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
    );
    final type = GoogleFonts.baloo2TextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: type,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: ink,
        surfaceTintColor: const Color(0x00000000),
        centerTitle: false,
        titleTextStyle: GoogleFonts.baloo2(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field(brightness),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: brand,
          foregroundColor: onColor,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card(brightness),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(minTileHeight: 48),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

class ThemeHost extends InheritedWidget {
  const ThemeHost({
    super.key,
    required this.mode,
    required this.toggle,
    required super.child,
  });

  final ThemeMode mode;
  final VoidCallback toggle;

  static ThemeHost of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<ThemeHost>();
    assert(host != null, 'ThemeHost missing above this page');
    return host!;
  }

  @override
  bool updateShouldNotify(ThemeHost oldWidget) => mode != oldWidget.mode;
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? LocaleHost.copyOf(context).lightTheme : LocaleHost.copyOf(context).darkTheme,
      onPressed: ThemeHost.of(context).toggle,
      icon: Icon(dark ? Fa.sun : Fa.moon, size: 20),
    );
  }
}
