import 'package:flutter/material.dart';

const kVerde = Color(0xFF1B6B47);
const kVerdeEscuro = Color(0xFF124A31);
const kVerdeClaro = Color(0xFFE4F0E9);
const kAmbar = Color(0xFFD98E04);
const kVermelho = Color(0xFFC0392B);
const kFundo = Color(0xFFF3F4F3);
const kTexto = Color(0xFF1C2420);
const kTextoSecundario = Color(0xFF6B756F);
const kBorda = Color(0xFFE2E6E3);

const _claro = ColorScheme(
  brightness: Brightness.light,
  primary: kVerde,
  onPrimary: Colors.white,
  primaryContainer: kVerdeClaro,
  onPrimaryContainer: kVerdeEscuro,
  secondary: kAmbar,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFF1D6),
  onSecondaryContainer: Color(0xFF5A3B00),
  tertiary: Color(0xFF2C5F8A),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFE1ECF6),
  onTertiaryContainer: Color(0xFF12314B),
  error: kVermelho,
  onError: Colors.white,
  errorContainer: Color(0xFFFCE4E1),
  onErrorContainer: Color(0xFF7A1F16),
  surface: Colors.white,
  onSurface: kTexto,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF8F9F8),
  surfaceContainer: kFundo,
  surfaceContainerHigh: Color(0xFFEDEFEE),
  surfaceContainerHighest: Color(0xFFE7EAE8),
  onSurfaceVariant: kTextoSecundario,
  outline: Color(0xFFB9C0BC),
  outlineVariant: kBorda,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF2E3532),
  onInverseSurface: Colors.white,
  inversePrimary: Color(0xFF9CD3B5),
  surfaceTint: Colors.transparent,
);

const _escuro = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF7CC29C),
  onPrimary: Color(0xFF0B2E1E),
  primaryContainer: Color(0xFF1F4A36),
  onPrimaryContainer: Color(0xFFD5EBDD),
  secondary: Color(0xFFF0B84C),
  onSecondary: Color(0xFF3A2600),
  secondaryContainer: Color(0xFF4A3300),
  onSecondaryContainer: Color(0xFFFFE2A8),
  tertiary: Color(0xFF8FBCE3),
  onTertiary: Color(0xFF0E2A42),
  tertiaryContainer: Color(0xFF1E4262),
  onTertiaryContainer: Color(0xFFD3E5F5),
  error: Color(0xFFF08A7E),
  onError: Color(0xFF4A0F09),
  errorContainer: Color(0xFF6E241B),
  onErrorContainer: Color(0xFFFFDAD5),
  surface: Color(0xFF161A18),
  onSurface: Color(0xFFE6E9E7),
  surfaceContainerLowest: Color(0xFF101312),
  surfaceContainerLow: Color(0xFF1B201D),
  surfaceContainer: Color(0xFF202523),
  surfaceContainerHigh: Color(0xFF2A302D),
  surfaceContainerHighest: Color(0xFF353B38),
  onSurfaceVariant: Color(0xFFA9B2AD),
  outline: Color(0xFF7A837E),
  outlineVariant: Color(0xFF3A4340),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFE6E9E7),
  onInverseSurface: Color(0xFF1C2420),
  inversePrimary: kVerde,
  surfaceTint: Colors.transparent,
);

ThemeData _tema(ColorScheme s) {
  final escuro = s.brightness == Brightness.dark;
  final borda = s.outlineVariant;
  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    scaffoldBackgroundColor: escuro ? s.surfaceContainerLowest : kFundo,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: s.onSurface),
      shape: Border(bottom: BorderSide(color: borda)),
    ),
    cardTheme: CardThemeData(
      color: s.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borda)),
    ),
    dividerTheme: DividerThemeData(color: borda, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borda)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borda)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: s.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: s.error)),
      labelStyle: TextStyle(color: s.onSurfaceVariant),
      hintStyle: TextStyle(color: s.onSurfaceVariant.withValues(alpha: .8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: borda),
        foregroundColor: s.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: s.primary, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.surface,
      selectedColor: s.primary,
      side: BorderSide(color: borda),
      labelStyle: TextStyle(fontSize: 13, color: s.onSurface),
      secondaryLabelStyle: const TextStyle(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: s.primaryContainer,
      height: 64,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: st.contains(WidgetState.selected) ? s.primary : s.onSurfaceVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(color: st.contains(WidgetState.selected) ? s.onPrimaryContainer : s.onSurfaceVariant, size: 24),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: s.inverseSurface,
      contentTextStyle: TextStyle(color: s.onInverseSurface, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: s.onSurface),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: s.onSurfaceVariant,
      titleTextStyle: TextStyle(fontSize: 15, color: s.onSurface),
      subtitleTextStyle: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: s.primary, thumbColor: s.primary, inactiveTrackColor: borda),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      extendedTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: s.onSurface, height: 1.25),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: s.onSurface),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
      bodyLarge: TextStyle(fontSize: 16, color: s.onSurface, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: s.onSurface, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.onSurfaceVariant),
      labelSmall: TextStyle(fontSize: 11, color: s.onSurfaceVariant),
    ),
  );
}

final temaClaro = _tema(_claro);
final temaEscuro = _tema(_escuro);
