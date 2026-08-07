import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';

/// A labelled text input.
///
///   * the label is a plain heading ABOVE the box - it never floats, shrinks
///     or animates into the border
///   * the box meets the density's minimum height and carries a solid border
///   * focus is unmistakable: the border thickens and the label block inverts
///   * an error appears as a solid red block underneath, not as a tooltip or
///     a thin coloured underline
class BrutalTextField extends StatefulWidget {
  const BrutalTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;

  /// A short plain-English note under the label, e.g. "UP TO 10 LETTERS".
  /// Hidden in the compact layout, where room matters more.
  final String? hint;

  /// When non-null, the field is in an error state and this text is shown in
  /// a red block below it.
  final String? errorText;

  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<BrutalTextField> createState() => _BrutalTextFieldState();
}

class _BrutalTextFieldState extends State<BrutalTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(BrutalTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final hasError = widget.errorText != null;
    final showHint = widget.hint != null && !skin.sizes.isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Label block. Inverts on focus so the active field is obvious even
        // from across the room.
        Container(
          color: _focused ? skin.colors.fill : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: _focused ? 8 : 0,
            vertical: 4,
          ),
          child: Text(
            widget.label,
            style: _focused ? skin.text.fieldLabelOnFill : skin.text.fieldLabel,
          ),
        ),
        if (showHint) ...<Widget>[
          const SizedBox(height: 4),
          Text(widget.hint!, style: skin.text.body),
        ],
        SizedBox(height: skin.sizes.gapSmall),

        Container(
          constraints: BoxConstraints(minHeight: skin.sizes.touchTarget),
          decoration: BoxDecoration(
            color: skin.colors.paper,
            border: skin.borderOf(
              width: _focused ? skin.sizes.borderThick : skin.sizes.border,
              color: hasError ? skin.colors.danger : skin.colors.ink,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            style: skin.text.fieldValue,
            textAlign: widget.textAlign,
            cursorWidth: 4,
            cursorColor: skin.colors.ink,
            keyboardType: widget.keyboardType,
            inputFormatters: <TextInputFormatter>[
              if (widget.maxLength != null)
                LengthLimitingTextInputFormatter(widget.maxLength),
              ...?widget.inputFormatters,
            ],
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: false,
              // The counter is 12px text; the character limit is stated in the
              // hint above the field instead.
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: skin.sizes.gapSmall,
                vertical: skin.sizes.gapSmall,
              ),
            ),
          ),
        ),

        if (hasError) ...<Widget>[
          SizedBox(height: skin.sizes.gapSmall),
          BrutalNotice(message: widget.errorText!),
        ],
      ],
    );
  }
}
