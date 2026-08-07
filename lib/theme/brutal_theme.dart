import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brutal_skin.dart';

/// Material plumbing built from a [BrutalSkinData].
///
/// The app draws almost everything itself, so this exists mainly to make the
/// widgets we do not write - the calendar, the text cursor, scrollbars - obey
/// the same palette and the same "no motion, no elevation" rules.

/// Swaps pages with no animation at all - no fade, no slide.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Every slot of Material's text theme, given an explicit size and weight.
///
/// Widgets we do not style directly - the calendar's day numbers, its month
/// header, tooltips - render through these slots, so filling all fifteen is
/// how the "nothing below 16px, nothing lighter than 400" rule reaches the
/// parts of the app we did not write.
///
/// Spelled out rather than derived with `TextTheme.apply(fontSizeDelta: ...)`:
/// some slots of the inherited theme carry a null `fontSize`, and `apply`
/// asserts when asked to adjust a size that is not there.
TextTheme _buildTextTheme(BrutalSkinData skin) {
  final ink = skin.colors.ink;
  final compact = skin.sizes.isCompact;

  TextStyle heavy(double size) => TextStyle(
    fontSize: compact ? size * 0.75 : size,
    fontWeight: FontWeight.w800,
    color: ink,
    height: 1.25,
  );
  TextStyle strong(double size) => TextStyle(
    fontSize: compact ? size * 0.8 : size,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.3,
  );
  TextStyle plain(double size) => TextStyle(
    // 16 is the hard floor everywhere in this app, compact included.
    fontSize: compact ? (size * 0.85).clamp(16, size) : size,
    fontWeight: FontWeight.w500,
    color: ink,
    height: 1.4,
  );

  return TextTheme(
    displayLarge: heavy(44),
    displayMedium: heavy(40),
    displaySmall: heavy(34),
    headlineLarge: heavy(32),
    headlineMedium: heavy(28),
    headlineSmall: heavy(26),
    titleLarge: strong(24),
    titleMedium: strong(22),
    titleSmall: strong(20),
    bodyLarge: plain(20),
    bodyMedium: plain(19),
    bodySmall: plain(17),
    labelLarge: strong(20),
    labelMedium: strong(18),
    labelSmall: strong(17),
  );
}

ThemeData buildBrutalTheme(BrutalSkinData skin) {
  final colors = skin.colors;

  final base = ThemeData(
    useMaterial3: true,
    brightness: colors.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: colors.page,
    canvasColor: colors.paper,
    // Material's ripple is a soft animated flourish; a hard colour flip on
    // press is easier to perceive and cannot be mistaken for motion.
    splashFactory: NoSplash.splashFactory,
    // Roboto ships with Flutter and is a plain sans-serif. The fallbacks keep
    // us on a system sans if it is ever unavailable.
    fontFamilyFallback: const <String>['Segoe UI', 'Helvetica', 'Arial'],
    textTheme: _buildTextTheme(skin),
    colorScheme: ColorScheme(
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      primary: colors.ink,
      onPrimary: colors.paper,
      secondary: colors.ink,
      onSecondary: colors.paper,
      surface: colors.paper,
      onSurface: colors.ink,
      error: colors.danger,
      onError: colors.onDanger,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
      },
    ),
  );

  return base.copyWith(
    dividerTheme: DividerThemeData(
      color: colors.ink,
      thickness: skin.sizes.border,
      space: skin.sizes.border,
    ),
    // Nothing floats: every surface is a bordered rectangle.
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.paper,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: colors.paper,
      shape: const RoundedRectangleBorder(),
    ),
    // The scroll thumb has to be visible and grabbable, not a hairline. The
    // track behind it is switched off: it drew its own outline down the inside
    // of every scrolling block, which read as a second thin border running
    // alongside the real one.
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(true),
      thickness: WidgetStateProperty.all(skin.sizes.isCompact ? 10 : 14),
      radius: Radius.zero,
      thumbColor: WidgetStateProperty.all(colors.ink),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      trackBorderColor: WidgetStateProperty.all(Colors.transparent),
      trackVisibility: WidgetStateProperty.all(false),
    ),
  );
}

/// Formatter that turns everything typed into capitals as it is typed.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => TextEditingValue(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
    composing: TextRange.empty,
  );
}
