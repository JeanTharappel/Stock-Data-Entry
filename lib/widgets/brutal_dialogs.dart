import 'package:flutter/material.dart';

import '../core/ddmmyy.dart';
import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';
import 'brutal_button.dart';

/// Modals used by the app.
///
/// All of them open and close instantly - `transitionDuration` is zero, so
/// there is no fade or slide that could disorient the reader. They are also
/// not barrier-dismissible: a click on the background must never quietly
/// answer a question the user was asked.

Future<T?> _showBrutalModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  double maxWidth = 760,
}) {
  // Captured here because the dialog is a separate route and would otherwise
  // sit outside the BrutalSkin that wraps the app's own widget tree.
  final skin = BrutalSkin.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'DIALOG',
    barrierColor: const Color(0xCC000000),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) {
      return BrutalSkin(
        data: skin,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(skin.sizes.gap),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                color: skin.colors.paper,
                elevation: 0,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A yes/no question with two large, clearly worded buttons.
///
/// Returns `true` only when the confirm button is pressed. Used for deleting a
/// record and for the duplicate-record warning - there is no swipe-to-delete
/// and no unconfirmed destructive action anywhere.
Future<bool> showBrutalConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  String? detail,
  NoticeKind kind = NoticeKind.error,
  BrutalButtonStyle confirmStyle = BrutalButtonStyle.danger,
}) async {
  final result = await _showBrutalModal<bool>(
    context: context,
    builder: (dialogContext) {
      final skin = BrutalSkin.of(dialogContext);
      return Container(
        decoration: BoxDecoration(border: skin.borderThick),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BrutalSectionHeader(title),
            Padding(
              padding: EdgeInsets.all(skin.sizes.panelPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BrutalNotice(
                    message: message,
                    kind: kind,
                    textStyle: skin.text.header,
                  ),
                  if (detail != null) ...<Widget>[
                    const BrutalGap(),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: skin.border,
                        color: skin.colors.stripe,
                      ),
                      padding: EdgeInsets.all(skin.sizes.gap),
                      child: Text(detail, style: skin.text.bodyBold),
                    ),
                  ],
                  BrutalGap(skin.sizes.gapLarge),
                  // Cancel comes first and is the safe choice; the destructive
                  // button is on the right and is the only red thing here.
                  Wrap(
                    spacing: skin.sizes.gap,
                    runSpacing: skin.sizes.gap,
                    children: <Widget>[
                      BrutalButton(
                        label: cancelLabel,
                        style: BrutalButtonStyle.secondary,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                      BrutalButton(
                        label: confirmLabel,
                        style: confirmStyle,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

/// The earliest and latest dates a 2-digit year can represent under the
/// windowing rule in `ddmmyy.dart`.
final DateTime kEarliestDate = DateTime(1970, 1, 1);
final DateTime kLatestDate = DateTime(2069, 12, 31);

/// A large month calendar in its own modal.
///
/// Returns the chosen date, or `null` if cancelled. Typing into the DAY /
/// MONTH / YEAR boxes remains the primary way to enter a date; this is the
/// assist for anyone who would rather point at a day.
Future<DateTime?> showBrutalCalendar({
  required BuildContext context,
  DateTime? initialDate,
}) {
  final start = initialDate ?? DateTime.now();
  final clamped = start.isBefore(kEarliestDate)
      ? kEarliestDate
      : (start.isAfter(kLatestDate) ? kLatestDate : start);

  return _showBrutalModal<DateTime>(
    context: context,
    maxWidth: 620,
    builder: (dialogContext) => _BrutalCalendarBody(initialDate: clamped),
  );
}

class _BrutalCalendarBody extends StatefulWidget {
  const _BrutalCalendarBody({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_BrutalCalendarBody> createState() => _BrutalCalendarBodyState();
}

class _BrutalCalendarBodyState extends State<_BrutalCalendarBody> {
  late DateTime _selected = widget.initialDate;

  /// Flutter's calendar is built around fixed pixel sizes, so the only way to
  /// grow the day cells and the month arrows together - hit targets included -
  /// is to scale the whole widget.
  ///
  /// The base box must be wide enough for the calendar to lay out without
  /// clipping before it is scaled: seven day columns plus the month header,
  /// and the three-column year grid it switches to.
  static const double _baseWidth = 380;
  static const double _baseHeight = 380;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final scale = skin.sizes.isCompact ? 1.0 : 1.35;

    return Container(
      decoration: BoxDecoration(border: skin.borderThick),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BrutalSectionHeader('PICK A DATE'),
          Padding(
            padding: EdgeInsets.all(skin.sizes.panelPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'TAP A DAY NUMBER TO CHOOSE IT.\n'
                  'USE THE ARROWS AT THE TOP TO GO BACK OR FORWARD A MONTH.',
                  style: skin.text.body,
                ),
                const BrutalGap(),
                Container(
                  decoration: BoxDecoration(border: skin.border),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _baseWidth * scale,
                    height: _baseHeight * scale,
                    // FittedBox rather than Transform.scale: Transform passes
                    // its own constraints straight through, so the inner
                    // SizedBox was handed a tight width it could not shrink
                    // below and the scaled result spilled past the box and got
                    // clipped. FittedBox measures the child unconstrained
                    // first, then scales what it measured.
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _baseWidth,
                        height: _baseHeight,
                        child: CalendarDatePicker(
                          initialDate: _selected,
                          firstDate: kEarliestDate,
                          lastDate: kLatestDate,
                          onDateChanged: (value) =>
                              setState(() => _selected = value),
                        ),
                      ),
                    ),
                  ),
                ),
                const BrutalGap(),
                BrutalNotice(
                  message:
                      'YOU PICKED: ${spellOutDdmmyy(formatDdmmyy(_selected))}',
                  kind: NoticeKind.info,
                  textStyle: skin.text.count,
                ),
                BrutalGap(skin.sizes.gapLarge),
                Wrap(
                  spacing: skin.sizes.gap,
                  runSpacing: skin.sizes.gap,
                  children: <Widget>[
                    BrutalButton(
                      label: 'CANCEL',
                      style: BrutalButtonStyle.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    BrutalButton(
                      label: 'USE THIS DATE',
                      onPressed: () => Navigator.of(context).pop(_selected),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
