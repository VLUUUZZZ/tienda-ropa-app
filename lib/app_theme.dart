import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The store's terracotta, as used in the launcher icon.
const Color brandColor = Color(0xFFB5754A);

/// The bundled typeface (see pubspec.yaml).
const String appFontFamily = 'PlusJakartaSans';

/// Corner radii used across the app, so surfaces nest consistently: a
/// card's content uses [md], the card itself [lg], sheets and heroes [xl].
abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 28;
}

/// Shared visual language for the whole app: a warm boutique palette,
/// generous rounded surfaces, pill-shaped actions and one type scale, in
/// light and dark.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Fidelity keeps the primary close to the brand color instead of drifting
  // to a paler tone, so buttons and prices read as terracotta.
  final colorScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final background = isDark ? const Color(0xFF141112) : const Color(0xFFFAF6F2);

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: appFontFamily,
  );
  final t = base.textTheme;
  final textTheme = t
      .copyWith(
        displaySmall: t.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
        labelLarge: t.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      )
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      );

  const pill = StadiumBorder();
  final buttonText = textTheme.labelLarge?.copyWith(fontSize: 16);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: background,
    extensions: [isDark ? StockColors.dark : StockColors.light],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.35 : 0.5,
          ),
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      prefixIconColor: colorScheme.onSurfaceVariant,
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: pill,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: pill,
        side: BorderSide(color: colorScheme.outlineVariant),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: pill,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLowest,
      selectedColor: colorScheme.inverseSurface,
      checkmarkColor: colorScheme.onInverseSurface,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLowest,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      constraints: const BoxConstraints(minHeight: 56),
      textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: textTheme.titleSmall,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 22),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: colorScheme.inversePrimary,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      // ignore: deprecated_member_use
      year2023: false,
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
