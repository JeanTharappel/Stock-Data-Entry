import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ddmmyy.dart';
import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';
import 'brutal_button.dart';
import 'brutal_dialogs.dart';
import 'brutal_text_field.dart';

/// Holds the three parts of a `DDMMYY` date as separate editable fields.
///
/// Typing two digits at a time into three labelled boxes is far easier than
/// interpreting a single 6-character string, and it maps exactly onto how the
/// value is stored.
class DdmmyyController {
  DdmmyyController();

  final TextEditingController day = TextEditingController();
  final TextEditingController month = TextEditingController();
  final TextEditingController year = TextEditingController();

  String get dayText => day.text.trim();
  String get monthText => month.text.trim();
  String get yearText => year.text.trim();

  /// The 6-character storage value, or `null` if the parts are not a real date.
  String? get ddmmyy {
    final composed = composeDdmmyy(dayText, monthText, yearText);
    return parseDdmmyy(composed) == null ? null : composed;
  }

  DateTime? get date =>
      parseDdmmyy(composeDdmmyy(dayText, monthText, yearText));

  bool get isEmpty => dayText.isEmpty && monthText.isEmpty && yearText.isEmpty;

  void setFromDate(DateTime value) {
    day.text = value.day.toString().padLeft(2, '0');
    month.text = value.month.toString().padLeft(2, '0');
    year.text = (value.year % 100).toString().padLeft(2, '0');
  }

  void setFromDdmmyy(String value) {
    if (value.length != 6) return;
    day.text = value.substring(0, 2);
    month.text = value.substring(2, 4);
    year.text = value.substring(4, 6);
  }

  void clear() {
    day.clear();
    month.clear();
    year.clear();
  }

  void dispose() {
    day.dispose();
    month.dispose();
    year.dispose();
  }
}

/// The date entry block: three numeric boxes, a calendar button, a plain
/// readback of what was entered, and one shared error block.
class DdmmyyField extends StatelessWidget {
  const DdmmyyField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.label = 'DATE',
  });

  final DdmmyyController controller;

  /// The heading above the three boxes.
  final String label;

  /// Called on every keystroke and after the calendar closes, so the screen
  /// can re-run validation and refresh the readback line.
  final VoidCallback onChanged;

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final compact = skin.sizes.isCompact;
    final spelled = spellOutDdmmyy(
      composeDdmmyy(
        controller.dayText,
        controller.monthText,
        controller.yearText,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: skin.text.fieldLabel),
        if (!compact) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'TYPE THE DAY, THE MONTH AND THE LAST TWO NUMBERS OF THE YEAR.',
            style: skin.text.body,
          ),
        ],
        BrutalGap(skin.sizes.gapSmall),

        Wrap(
          spacing: skin.sizes.gap,
          runSpacing: skin.sizes.gap,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: <Widget>[
            _DatePart(
              label: 'DAY',
              hint: 'E.G. 05',
              controller: controller.day,
              onChanged: onChanged,
            ),
            _DatePart(
              label: 'MONTH',
              hint: 'E.G. 08',
              controller: controller.month,
              onChanged: onChanged,
            ),
            _DatePart(
              label: 'YEAR',
              hint: 'E.G. 26',
              controller: controller.year,
              onChanged: onChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BrutalButton(
                label: compact ? 'CALENDAR' : 'OPEN CALENDAR',
                icon: Icons.calendar_month,
                compact: compact,
                style: BrutalButtonStyle.secondary,
                onPressed: () async {
                  final picked = await showBrutalCalendar(
                    context: context,
                    initialDate: controller.date,
                  );
                  if (picked == null) return;
                  controller.setFromDate(picked);
                  onChanged();
                },
              ),
            ),
          ],
        ),

        // Readback. Confirms in words what the six digits actually mean.
        if (spelled.isNotEmpty) ...<Widget>[
          BrutalGap(skin.sizes.gapSmall),
          Container(
            decoration: BoxDecoration(
              border: skin.border,
              color: skin.colors.stripe,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: skin.sizes.gap,
              vertical: skin.sizes.gapSmall,
            ),
            child: Text('THIS DATE IS: $spelled', style: skin.text.bodyBold),
          ),
        ],

        if (errorText != null) ...<Widget>[
          BrutalGap(skin.sizes.gapSmall),
          BrutalNotice(message: errorText!),
        ],
      ],
    );
  }
}

/// One of the three fixed-width numeric boxes.
class _DatePart extends StatelessWidget {
  const _DatePart({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return SizedBox(
      width: skin.sizes.datePartWidth,
      child: BrutalTextField(
        label: label,
        hint: hint,
        controller: controller,
        maxLength: 2,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
