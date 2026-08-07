import 'package:flutter/material.dart';

import '../theme/brutal_skin.dart';

/// How a [BrutalButton] is filled. Every variant is a flat colour pair with a
/// border; pressing inverts the fill rather than animating a ripple.
enum BrutalButtonStyle {
  /// The main action on a block: solid fill, inverted text.
  primary,

  /// A secondary action: paper background, ink text.
  secondary,

  /// Deleting: solid red.
  danger,
}

/// A large rectangular button.
///
/// [label] is required and always shown, so there is no such thing as an
/// icon-only button in this app. [icon] is optional decoration beside the
/// words, never a replacement for them.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = BrutalButtonStyle.primary,
    this.expand = false,
    this.compact = false,
    this.onSolid = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BrutalButtonStyle style;

  /// Set when the button sits on a block already filled with `colors.fill` -
  /// the title bar. There the usual roles are backwards: a primary button
  /// would be filled with the same colour as the bar behind it and vanish,
  /// while the secondary one would be the block that stands out. On a solid
  /// bar the two swap over, so the chosen option is the contrasting block and
  /// the other blends into the bar with only its outline to mark it. The
  /// outline is drawn in `onFill` too, since an `ink` border on an `ink` bar
  /// is invisible.
  final bool onSolid;

  /// Stretch to fill the available width.
  final bool expand;

  /// Tighter padding for buttons inside a table row or a toolbar. Still meets
  /// the density's minimum height and keeps the full text label.
  final bool compact;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final colors = skin.colors;
    final enabled = widget.onPressed != null;

    final (Color resting, Color restingText) = switch (widget.style) {
      BrutalButtonStyle.danger => (colors.danger, colors.onDanger),
      BrutalButtonStyle.primary =>
        widget.onSolid
            ? (colors.onFill, colors.fill)
            : (colors.fill, colors.onFill),
      BrutalButtonStyle.secondary =>
        widget.onSolid
            ? (colors.fill, colors.onFill)
            : (colors.paper, colors.ink),
    };

    // Hovering and pressing both swap the two colours over. A hard flip is
    // easier to perceive than a ripple, cannot be mistaken for motion, and
    // says "the pointer is on this" without relying on a subtle tint.
    //
    // They also thicken the border, and that part is not decoration. With only
    // two neutrals to work with, an inverted primary button lands on exactly
    // the same pixels as a resting secondary one and as a disabled one - three
    // different states, one appearance. The heavier border is what separates
    // "you are on this" from "this is an outlined button" and from "this
    // cannot be pressed", which keeps its thin border and strikes out its
    // label instead.
    final inverted = enabled && (_pressed || _hovered);
    final background = !enabled
        ? (widget.onSolid ? colors.fill : colors.disabled)
        : (inverted ? restingText : resting);
    final foreground = !enabled
        ? (widget.onSolid ? colors.onFill : colors.ink)
        : (inverted ? resting : restingText);

    final horizontalPadding = widget.compact
        ? skin.sizes.gap
        : skin.sizes.gapLarge;

    final child = Container(
      constraints: BoxConstraints(
        minHeight: skin.sizes.touchTarget,
        minWidth: widget.compact ? 0 : (skin.sizes.isCompact ? 100 : 140),
      ),
      decoration: BoxDecoration(
        color: background,
        border: skin.borderOf(
          width: (_focused || inverted)
              ? skin.sizes.borderThick
              : skin.sizes.border,
          color: widget.onSolid ? colors.onFill : colors.ink,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: skin.sizes.gapSmall,
      ),
      // No `alignment:` here on purpose. A Container given an alignment but no
      // width grows to fill whatever width it is offered, which would make
      // every button in a Wrap full-width and push each onto its own line.
      // The Row below does the centring instead.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(
              widget.icon,
              size: skin.sizes.isCompact ? 20 : 28,
              color: foreground,
            ),
            SizedBox(width: skin.sizes.gapSmall),
          ],
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: skin.text.button.copyWith(
                color: foreground,
                // The only colour-free way left to say "not available". The
                // reason is always spelled out in a notice beside the button.
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationColor: foreground,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: child)
              : child,
        ),
      ),
    );
  }
}

/// A pair of buttons acting as a two-way switch, e.g. LIGHT / DARK.
///
/// Both choices are always visible with their own word on them, and the one
/// in force is the filled one. That is deliberately not a checkbox or a
/// sliding switch: those show one state and leave you to work out the other.
class BrutalChoice<T> extends StatelessWidget {
  const BrutalChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.onSolid = false,
  });

  /// Spoken label for screen readers; the buttons carry the visible words.
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// See [BrutalButton.onSolid]. Set for the toggles in the title bar.
  final bool onSolid;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < options.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: skin.sizes.gapSmall),
            BrutalButton(
              label: options[i].$2,
              compact: true,
              onSolid: onSolid,
              style: options[i].$1 == value
                  ? BrutalButtonStyle.primary
                  : BrutalButtonStyle.secondary,
              onPressed: () => onChanged(options[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}
