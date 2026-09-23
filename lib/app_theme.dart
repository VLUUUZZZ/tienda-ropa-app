import 'package:flutter/material.dart';

/// The store's terracotta, as used in the launcher icon.
const Color brandColor = Color(0xFFB5754A);

/// Shared visual language for the whole app: a warm boutique palette,
/// rounded surfaces with a hairline border, and one type scale so every
/// screen reads the same.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Fidelity keeps the primary close to the brand color instead of drifting
  // to a paler tone, so buttons and prices read as terracotta.
  final colorScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'Roboto',
  );
  final textTheme = base.textTheme
      .copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      );

  final rounded14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF161314)
        : const Color(0xFFFBF4EF),
    extensions: [isDark ? StockColors.dark : StockColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: isDark
          ? const Color(0xFF161314)
          : const Color(0xFFFBF4EF),
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.6 : 0.7,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: rounded14,
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: rounded14,
        side: BorderSide(color: colorScheme.outlineVariant),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 3,
      extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onPrimaryContainer,
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Colors for stock levels, so "agotado" and "poca existencia" look the same
/// on every screen. Red alone is not enough for status: every use pairs the
/// color with an icon or a word.
@immutable
class StockColors extends ThemeExtension<StockColors> {
  const StockColors({
    required this.low,
    required this.onLow,
    required this.lowContainer,
    required this.onLowContainer,
  });

  /// Amber: contrasts with both the terracotta brand and the error red.
  final Color low;
  final Color onLow;
  final Color lowContainer;
  final Color onLowContainer;

  static const light = StockColors(
    low: Color(0xFF8A5A00),
    onLow: Color(0xFFFFFFFF),
    lowContainer: Color(0xFFFFE8B8),
    onLowContainer: Color(0xFF5A3A00),
  );

  static const dark = StockColors(
    low: Color(0xFFF5BF48),
    onLow: Color(0xFF412D00),
    lowContainer: Color(0xFF5D4200),
    onLowContainer: Color(0xFFFFDEA3),
  );

  static StockColors of(BuildContext context) =>
      Theme.of(context).extension<StockColors>() ?? light;

  @override
  StockColors copyWith({
    Color? low,
    Color? onLow,
    Color? lowContainer,
    Color? onLowContainer,
  }) => StockColors(
    low: low ?? this.low,
    onLow: onLow ?? this.onLow,
    lowContainer: lowContainer ?? this.lowContainer,
    onLowContainer: onLowContainer ?? this.onLowContainer,
  );

  @override
  StockColors lerp(StockColors? other, double t) {
    if (other == null) return this;
    return StockColors(
      low: Color.lerp(low, other.low, t)!,
      onLow: Color.lerp(onLow, other.onLow, t)!,
      lowContainer: Color.lerp(lowContainer, other.lowContainer, t)!,
      onLowContainer: Color.lerp(onLowContainer, other.onLowContainer, t)!,
    );
  }
}
