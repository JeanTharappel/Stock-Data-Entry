import 'package:flutter/material.dart';

/// The design system, resolved at runtime.
///
/// Colours and sizes used to be compile-time constants. They are values now
/// because two of them are the reader's choice: light or dark, and comfortable
/// or compact. Widgets ask [BrutalSkin.of] for the current pair rather than
/// reaching for a constant, so both toggles reach the whole app at once.
///
/// What does not change with either setting:
///   * flat colours - no gradients, no shadows, no blur
///   * structure shown with thick borders, never with elevation
///   * text and background always at high contrast, never grey on grey
///   * nothing below 16px, nothing lighter than weight 400
///   * every button carries a word, never an icon alone
///   * no motion beyond an instant swap

// ---------------------------------------------------------------------------
// PALETTE
// ---------------------------------------------------------------------------

/// Which way round the world is.
enum BrutalBrightness { light, dark }

/// A flat, high-contrast colour set. Every foreground/background pair here
/// clears WCAG AA for body text, and most clear AAA.
@immutable
class BrutalPalette {
  const BrutalPalette({
    required this.brightness,
    required this.ink,
    required this.paper,
    required this.page,
    required this.fill,
    required this.onFill,
    required this.stripe,
    required this.danger,
    required this.onDanger,
    required this.warning,
    required this.onWarning,
    required this.success,
    required this.onSuccess,
    required this.disabled,
  });

  /// Black on white. The default.
  ///
  /// Exactly two neutrals: `#000000` and `#FFFFFF`. No off-white page, no grey
  /// row shading, no grey disabled fill - a shade of grey is a third colour,
  /// and the whole point here is that every edge is a hard black/white step.
  /// Separation comes from borders, which is what they are for.
  const BrutalPalette.light()
    : brightness = BrutalBrightness.light,
      ink = const Color(0xFF000000),
      paper = const Color(0xFFFFFFFF),
      page = const Color(0xFFFFFFFF),
      fill = const Color(0xFF000000),
      onFill = const Color(0xFFFFFFFF),
      stripe = const Color(0xFFFFFFFF),
      danger = const Color(0xFFB00000),
      onDanger = const Color(0xFFFFFFFF),
      warning = const Color(0xFFFFE600),
      onWarning = const Color(0xFF000000),
      success = const Color(0xFF00662E),
      onSuccess = const Color(0xFFFFFFFF),
      disabled = const Color(0xFFFFFFFF);

  /// The same two neutrals, swapped over.
  const BrutalPalette.dark()
    : brightness = BrutalBrightness.dark,
      ink = const Color(0xFFFFFFFF),
      paper = const Color(0xFF000000),
      page = const Color(0xFF000000),
      fill = const Color(0xFFFFFFFF),
      onFill = const Color(0xFF000000),
      stripe = const Color(0xFF000000),
      danger = const Color(0xFFD32020),
      onDanger = const Color(0xFF000000),
      warning = const Color(0xFFFFE600),
      onWarning = const Color(0xFF000000),
      success = const Color(0xFF3DDC84),
      onSuccess = const Color(0xFF000000),
      disabled = const Color(0xFF000000);

  final BrutalBrightness brightness;

  /// Text and borders.
  final Color ink;

  /// The inside of panels and input fields.
  final Color paper;

  /// Behind everything.
  final Color page;

  /// Solid blocks: section headers, the active tab, primary buttons.
  final Color fill;

  /// Text sitting on [fill].
  final Color onFill;

  /// Secondary block fills - the date readback, a dialog's detail box. Equal
  /// to [paper] in both palettes, since the two-colour rule leaves no third
  /// neutral to shade with; those blocks are marked out by their border.
  final Color stripe;

  final Color danger;
  final Color onDanger;
  final Color warning;
  final Color onWarning;
  final Color success;
  final Color onSuccess;

  /// A button that cannot be pressed. With only two neutrals it cannot be
  /// greyed out, so it drops to [paper] with [ink] text - clearly not the
  /// filled, ready-to-press state, and still perfectly readable. The reason it
  /// is unavailable is always spelled out in a notice beside it.
  final Color disabled;

  bool get isDark => brightness == BrutalBrightness.dark;
}

// ---------------------------------------------------------------------------
// DENSITY
// ---------------------------------------------------------------------------

/// How much room the interface takes.
enum BrutalDensity {
  /// Large type, generous spacing, one column, page scrolls.
  comfortable,

  /// The default. Everything on one screen: two columns, smaller type,
  /// tighter spacing. Still never smaller than 16px text.
  compact,
}

/// Sizes for one [BrutalDensity].
@immutable
class BrutalMetrics {
  const BrutalMetrics({
    required this.density,
    required this.border,
    required this.borderThick,
    required this.touchTarget,
    required this.rowHeight,
    required this.gapSmall,
    required this.gap,
    required this.gapLarge,
    required this.gapSection,
    required this.maxContentWidth,
    required this.pageGutter,
    required this.fieldWidth,
    required this.datePartWidth,
    required this.titleBarPadding,
    required this.panelPadding,
    required this.tabBasebar,
  });

  const BrutalMetrics.comfortable()
    : density = BrutalDensity.comfortable,
      border = 3,
      borderThick = 6,
      touchTarget = 60,
      rowHeight = 64,
      gapSmall = 12,
      gap = 20,
      gapLarge = 32,
      gapSection = 48,
      maxContentWidth = 1120,
      pageGutter = 40,
      fieldWidth = 340,
      datePartWidth = 150,
      titleBarPadding = 12,
      panelPadding = 32,
      tabBasebar = 8;

  const BrutalMetrics.compact()
    : density = BrutalDensity.compact,
      border = 2,
      borderThick = 4,
      touchTarget = 46,
      rowHeight = 44,
      gapSmall = 6,
      gap = 10,
      gapLarge = 14,
      gapSection = 18,
      maxContentWidth = 1700,
      pageGutter = 28,
      fieldWidth = 240,
      datePartWidth = 104,
      titleBarPadding = 6,
      panelPadding = 14,
      tabBasebar = 4;

  final BrutalDensity density;
  final double border;
  final double borderThick;
  final double touchTarget;
  final double rowHeight;
  final double gapSmall;
  final double gap;
  final double gapLarge;
  final double gapSection;
  final double maxContentWidth;

  /// Empty space down the left and right of every page, so nothing runs up
  /// against the edge of the window.
  final double pageGutter;

  /// Width of a single form field, so fields pack two or three to a row.
  final double fieldWidth;

  /// Width of one of the DAY / MONTH / YEAR boxes.
  final double datePartWidth;

  final double titleBarPadding;
  final double panelPadding;

  /// Height of the solid bar under the active tab.
  final double tabBasebar;

  bool get isCompact => density == BrutalDensity.compact;
}

// ---------------------------------------------------------------------------
// TEXT
// ---------------------------------------------------------------------------

/// Text styles for one palette/density pair. Regular (400) through heavy
/// (800) only, and nothing under 16px in either density.
@immutable
class BrutalTextStyles {
  const BrutalTextStyles(this.palette, this.metrics);

  final BrutalPalette palette;
  final BrutalMetrics metrics;

  bool get _c => metrics.isCompact;

  TextStyle get appTitle => TextStyle(
    fontSize: _c ? 20 : 26,
    fontWeight: FontWeight.w800,
    color: palette.onFill,
    height: 1.2,
    letterSpacing: 0.5,
  );

  /// Section headers, e.g. "ADD A DIVIDEND RATE". Always on a solid block.
  TextStyle get header => TextStyle(
    fontSize: _c ? 18 : 26,
    fontWeight: FontWeight.w800,
    color: palette.ink,
    height: 1.25,
    letterSpacing: 0.5,
  );

  TextStyle get headerOnFill => header.copyWith(color: palette.onFill);

  TextStyle get tabLabel => TextStyle(
    fontSize: _c ? 17 : 21,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0.4,
  );

  TextStyle get tabHint => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1,
  );

  /// The label that sits ABOVE every form field.
  TextStyle get fieldLabel => TextStyle(
    fontSize: _c ? 16 : 20,
    fontWeight: FontWeight.w700,
    color: palette.ink,
    height: 1.3,
    letterSpacing: 0.3,
  );

  TextStyle get fieldLabelOnFill => fieldLabel.copyWith(color: palette.onFill);

  /// The text the reader types into a field.
  TextStyle get fieldValue => TextStyle(
    fontSize: _c ? 18 : 24,
    fontWeight: FontWeight.w600,
    color: palette.ink,
    height: 1.2,
  );

  TextStyle get body => TextStyle(
    fontSize: _c ? 16 : 19,
    fontWeight: FontWeight.w500,
    color: palette.ink,
    height: _c ? 1.3 : 1.45,
  );

  TextStyle get bodyBold => body.copyWith(fontWeight: FontWeight.w700);

  /// Button captions. Always a whole word or phrase, never an icon alone.
  TextStyle get button => TextStyle(
    fontSize: _c ? 16 : 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0.5,
  );

  /// Validation messages, sitting on a solid danger block.
  TextStyle get error => TextStyle(
    fontSize: _c ? 16 : 19,
    fontWeight: FontWeight.w700,
    color: palette.onDanger,
    height: 1.35,
    letterSpacing: 0.2,
  );

  TextStyle get tableHeader => TextStyle(
    fontSize: _c ? 16 : 18,
    fontWeight: FontWeight.w800,
    color: palette.onFill,
    height: 1.2,
    letterSpacing: 0.4,
  );

  TextStyle get tableCell => TextStyle(
    fontSize: _c ? 16 : 19,
    fontWeight: FontWeight.w600,
    color: palette.ink,
    height: 1.3,
  );

  /// The "YOU HAVE 14 RECORDS SAVED" line.
  TextStyle get count => TextStyle(
    fontSize: _c ? 17 : 24,
    fontWeight: FontWeight.w800,
    color: palette.onFill,
    height: 1.3,
    letterSpacing: 0.4,
  );
}

// ---------------------------------------------------------------------------
// THE SKIN ITSELF
// ---------------------------------------------------------------------------

@immutable
class BrutalSkinData {
  BrutalSkinData({required this.colors, required this.sizes})
    : text = BrutalTextStyles(colors, sizes);

  factory BrutalSkinData.resolve({
    required BrutalBrightness brightness,
    required BrutalDensity density,
  }) => BrutalSkinData(
    colors: brightness == BrutalBrightness.dark
        ? const BrutalPalette.dark()
        : const BrutalPalette.light(),
    sizes: density == BrutalDensity.compact
        ? const BrutalMetrics.compact()
        : const BrutalMetrics.comfortable(),
  );

  final BrutalPalette colors;
  final BrutalMetrics sizes;
  final BrutalTextStyles text;

  /// A standard block border.
  Border get border => Border.all(color: colors.ink, width: sizes.border);

  /// The border for outermost panels and focused fields.
  Border get borderThick =>
      Border.all(color: colors.ink, width: sizes.borderThick);

  Border borderOf({required double width, Color? color}) =>
      Border.all(color: color ?? colors.ink, width: width);

  /// Two skins are the same when both settings match; the palette and metrics
  /// are fully determined by that pair.
  @override
  bool operator ==(Object other) =>
      other is BrutalSkinData &&
      other.colors.brightness == colors.brightness &&
      other.sizes.density == sizes.density;

  @override
  int get hashCode => Object.hash(colors.brightness, sizes.density);
}

/// Hands the current skin to every widget below it.
class BrutalSkin extends InheritedWidget {
  const BrutalSkin({super.key, required this.data, required super.child});

  final BrutalSkinData data;

  static BrutalSkinData of(BuildContext context) {
    final skin = context.dependOnInheritedWidgetOfExactType<BrutalSkin>();
    assert(skin != null, 'No BrutalSkin found above this widget.');
    return skin!.data;
  }

  @override
  bool updateShouldNotify(BrutalSkin oldWidget) => data != oldWidget.data;
}
