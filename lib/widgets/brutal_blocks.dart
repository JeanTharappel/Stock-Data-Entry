import 'package:flutter/material.dart';

import '../theme/brutal_skin.dart';

/// Layout primitives: flat rectangles with thick borders. Structure is shown
/// by borders and fills only - nothing here casts a shadow or floats.

/// A panel with a thick border. The standard container for a section.
class BrutalPanel extends StatelessWidget {
  const BrutalPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: skin.colors.paper,
        border: skin.borderThick,
      ),
      padding: padding ?? EdgeInsets.all(skin.sizes.panelPadding),
      child: child,
    );
  }
}

/// A solid bar with inverted text. Used for section titles so the eye can
/// find the top of each block instantly.
class BrutalSectionHeader extends StatelessWidget {
  const BrutalSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Container(
      width: double.infinity,
      color: skin.colors.fill,
      padding: EdgeInsets.symmetric(
        horizontal: skin.sizes.gap,
        vertical: skin.sizes.gapSmall + (skin.sizes.isCompact ? 0 : 4),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: skin.text.headerOnFill)),
          ?trailing,
        ],
      ),
    );
  }
}

/// The kind of message a [BrutalNotice] is showing. Each resolves to one flat
/// fill and one text colour - never a tint or a muted tone.
enum NoticeKind {
  /// Validation problems and destructive warnings.
  error,

  /// "This might not be what you meant."
  warning,

  /// "That worked."
  success,

  /// Plain statements of fact, e.g. the record count.
  info,
}

extension on NoticeKind {
  Color background(BrutalPalette colors) => switch (this) {
    NoticeKind.error => colors.danger,
    NoticeKind.warning => colors.warning,
    NoticeKind.success => colors.success,
    NoticeKind.info => colors.fill,
  };

  Color foreground(BrutalPalette colors) => switch (this) {
    NoticeKind.error => colors.onDanger,
    NoticeKind.warning => colors.onWarning,
    NoticeKind.success => colors.onSuccess,
    NoticeKind.info => colors.onFill,
  };
}

/// A full-width block of message text. Big, solid, impossible to miss - this
/// replaces tooltips, snackbar hints and subtle underlines throughout.
class BrutalNotice extends StatelessWidget {
  const BrutalNotice({
    super.key,
    required this.message,
    this.kind = NoticeKind.error,
    this.textStyle,
  });

  final String message;
  final NoticeKind kind;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: skin.sizes.isCompact ? 38 : 56),
        decoration: BoxDecoration(
          color: kind.background(skin.colors),
          border: skin.border,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: skin.sizes.gap,
          vertical: skin.sizes.gapSmall,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: (textStyle ?? skin.text.error).copyWith(
            color: kind.foreground(skin.colors),
          ),
        ),
      ),
    );
  }
}

/// The "YOU HAVE 14 RECORDS SAVED" block that sits on each screen.
class BrutalRecordCount extends StatelessWidget {
  const BrutalRecordCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final message = switch (count) {
      0 => 'YOU HAVE NO RECORDS SAVED YET.',
      1 => 'YOU HAVE 1 RECORD SAVED.',
      _ => 'YOU HAVE $count RECORDS SAVED.',
    };
    return BrutalNotice(
      message: message,
      kind: NoticeKind.info,
      textStyle: skin.text.count,
    );
  }
}

/// Fixed spacing, so gaps come from the scale rather than by eye.
class BrutalGap extends StatelessWidget {
  const BrutalGap([this.size, this.axis = Axis.vertical]) : super(key: null);

  const BrutalGap.horizontal([this.size])
    : axis = Axis.horizontal,
      super(key: null);

  /// Defaults to the current density's standard gap.
  final double? size;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final resolved = size ?? BrutalSkin.of(context).sizes.gap;
    return SizedBox(
      height: axis == Axis.vertical ? resolved : null,
      width: axis == Axis.horizontal ? resolved : null,
    );
  }
}
