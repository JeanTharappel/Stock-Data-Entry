import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ddmmyy.dart';
import '../core/inquiry.dart';
import '../core/record_spec.dart';
import '../core/validators.dart';
import '../data/dividend_rate_controller.dart';
import '../data/price_range_controller.dart';
import '../theme/brutal_skin.dart';
import '../theme/brutal_theme.dart';
import '../widgets/brutal_blocks.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_text_field.dart';
import '../widgets/ddmmyy_field.dart';
import 'entry_screen_layout.dart';
import 'inquiry_results_page.dart';

/// The ways to look records up:
///
/// * one company, either for a whole year or between two dates, in both files
/// * one calendar month, dividend rates only, every company
///
/// This tab only asks the questions. Every answer opens on its own page, so
/// each list has the whole screen to itself, and all of them are read-only -
/// records are changed on the entry tabs.
class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final TextEditingController _ccodeController = TextEditingController();
  final DdmmyyController _fromController = DdmmyyController();
  final DdmmyyController _toController = DdmmyyController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _monthYearController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// The results column's own scroll position, used in the compact layout.
  final ScrollController _resultsScrollController = ScrollController();

  String? _ccodeError;
  String? _yearError;
  String? _fromError;
  String? _toError;
  String? _monthError;
  String? _monthYearError;

  /// Same rule as the entry forms: errors stay hidden until the first press of
  /// SHOW RECORDS, then follow along live.
  bool _submitted = false;

  /// The last search that passed validation, or null before the first one.
  /// Kept separately from the boxes so the results never change just because
  /// someone started typing a new search.
  InquiryCriteria? _criteria;

  @override
  void dispose() {
    _ccodeController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _monthYearController.dispose();
    _scrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  /// The company code, which both ways of searching need.
  String? _validateCcode() => Validators.ccode(
    _ccodeController.text,
    maxLength: DividendRateSpec.ccodeWidth,
  );

  bool _validate() {
    final ccodeError = Validators.ccode(
      _ccodeController.text,
      // Both record types share the width; either spec would do.
      maxLength: DividendRateSpec.ccodeWidth,
    );
    final fromError = Validators.dateParts(
      day: _fromController.dayText,
      month: _fromController.monthText,
      year: _fromController.yearText,
      fieldName: 'FROM DATE',
    );
    // The order check only makes sense once both dates are real on their own.
    var toError = Validators.dateParts(
      day: _toController.dayText,
      month: _toController.monthText,
      year: _toController.yearText,
      fieldName: 'TO DATE',
    );
    if (fromError == null && toError == null) {
      toError = Validators.toNotBeforeFrom(
        from: _fromController.ddmmyy,
        to: _toController.ddmmyy,
      );
    }

    setState(() {
      _ccodeError = ccodeError;
      _fromError = fromError;
      _toError = toError;
    });

    return ccodeError == null && fromError == null && toError == null;
  }

  /// Whether each way of searching has enough in its boxes to be pressed.
  ///
  /// Only emptiness disables a button. A year of 13, or the 31st of February,
  /// leaves it live so that pressing it explains what is wrong - a struck-out
  /// button cannot say anything.
  bool get _yearReady => _yearController.text.trim().isNotEmpty;

  bool get _datesReady =>
      !_fromController.isEmpty &&
      !_toController.isEmpty &&
      _fromController.dayText.isNotEmpty &&
      _fromController.monthText.isNotEmpty &&
      _fromController.yearText.isNotEmpty &&
      _toController.dayText.isNotEmpty &&
      _toController.monthText.isNotEmpty &&
      _toController.yearText.isNotEmpty;

  /// The year box in words, e.g. `2026`, or empty if it is not a year yet.
  /// The same readback the date boxes have, for the same reason: nobody
  /// should have to know that 99 means 1999 and 26 means 2026.
  String get _yearInWords {
    final value = _yearController.text.trim();
    if (value.isEmpty || value.length > 2) return '';
    final year = int.tryParse(value);
    return year == null ? '' : '${expandYear(year)}';
  }

  void _revalidateIfSubmitted() {
    setState(() => _yearError = null);
    if (_submitted) {
      _validate();
    } else {
      // Still rebuild so the spelled-out date readbacks stay current.
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  void _search() {
    setState(() => _submitted = true);
    if (!_validate()) {
      setState(() => _criteria = null);
      return;
    }
    setState(() {
      _criteria = InquiryCriteria(
        ccode: _ccodeController.text,
        fromDate: _fromController.ddmmyy!,
        toDate: _toController.ddmmyy!,
      );
    });
  }

  /// The whole-year search. The year fills in the two dates, so from here on
  /// there is only one kind of search to follow.
  void _searchYear() {
    final ccodeError = _validateCcode();
    final yearError = Validators.yearTwoDigits(_yearController.text);
    setState(() {
      _submitted = true;
      _ccodeError = ccodeError;
      _yearError = yearError;
      // The date boxes are not part of this search, so any complaint about
      // them is stale the moment the year button is pressed.
      _fromError = null;
      _toError = null;
    });
    if (ccodeError != null || yearError != null) {
      setState(() => _criteria = null);
      return;
    }
    setState(() {
      _criteria = InquiryCriteria.forYear(
        ccode: _ccodeController.text,
        twoDigitYear: int.parse(_yearController.text.trim()),
      );
    });
  }

  void _clear() {
    _ccodeController.clear();
    _yearController.clear();
    _fromController.clear();
    _toController.clear();
    setState(() {
      _submitted = false;
      _ccodeError = null;
      _yearError = null;
      _fromError = null;
      _toError = null;
      _criteria = null;
    });
  }

  /// The month search. Its answer is a single list, so it opens straight
  /// away rather than reporting a count first the way the company search
  /// does with its two files.
  void _searchMonth() {
    final monthError = Validators.monthNumber(_monthController.text);
    final yearError = Validators.yearTwoDigits(_monthYearController.text);
    setState(() {
      _monthError = monthError;
      _monthYearError = yearError;
    });
    if (monthError != null || yearError != null) return;

    _open(
      DividendMonthPage(
        month: MonthInquiry(
          month: int.parse(_monthController.text.trim()),
          twoDigitYear: int.parse(_monthYearController.text.trim()),
        ),
      ),
    );
  }

  void _clearMonth() {
    _monthController.clear();
    _monthYearController.clear();
    setState(() {
      _monthError = null;
      _monthYearError = null;
    });
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildCompanyForm(skin),
        BrutalGap(
          skin.sizes.isCompact ? skin.sizes.gap : skin.sizes.gapSection,
        ),
        _buildMonthForm(skin),
      ],
    );
    final results = _buildResults(skin);

    if (skin.sizes.isCompact) {
      // Side by side, like the entry tabs: the question on the left, the
      // answer on the right.
      return BrutalPageWidth(
        padding: EdgeInsets.symmetric(
          horizontal: skin.sizes.pageGutter,
          vertical: skin.sizes.gap,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: form,
              ),
            ),
            SizedBox(width: skin.sizes.gap),
            Expanded(
              child: SingleChildScrollView(
                controller: _resultsScrollController,
                child: results,
              ),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: BrutalPageWidth(
          padding: EdgeInsets.symmetric(
            horizontal: skin.sizes.pageGutter,
            vertical: skin.sizes.gapLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              form,
              BrutalGap(skin.sizes.gapSection),
              results,
              BrutalGap(skin.sizes.gapSection),
            ],
          ),
        ),
      ),
    );
  }

  /// One company, between two dates, in both files.
  Widget _buildCompanyForm(BrutalSkinData skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('LOOK UP ONE COMPANY'),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_submitted && _criteria == null) ...<Widget>[
                BrutalNotice(
                  message:
                      'NOTHING WAS LOOKED UP. PLEASE FIX THE PARTS MARKED IN '
                      'RED BELOW.',
                  textStyle: skin.text.error,
                ),
                BrutalGap(skin.sizes.gapLarge),
              ],

              SizedBox(
                width: skin.sizes.fieldWidth,
                child: BrutalTextField(
                  label: 'COMPANY CODE',
                  hint:
                      'THE COMPANY TO LOOK UP. UP TO '
                      '${DividendRateSpec.ccodeWidth} LETTERS OR NUMBERS.',
                  controller: _ccodeController,
                  maxLength: DividendRateSpec.ccodeWidth,
                  errorText: _ccodeError,
                  inputFormatters: const <TextInputFormatter>[
                    UpperCaseTextFormatter(),
                  ],
                  onChanged: (_) => _revalidateIfSubmitted(),
                ),
              ),
              BrutalGap(skin.sizes.gapLarge),

              // Two ways to say which records, one under the other, both
              // indented so they read as belonging to the company code above
              // rather than following on from it. Whichever button is pressed
              // decides which boxes are read, so there is no mode to set
              // first and nothing is hidden from view.
              Padding(
                padding: EdgeInsets.only(left: skin.sizes.gapLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _WaySeparator(label: 'A WHOLE YEAR'),
                    BrutalGap(skin.sizes.gapSmall),
                    Wrap(
                      spacing: skin.sizes.gap,
                      runSpacing: skin.sizes.gap,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: <Widget>[
                        SizedBox(
                          width: skin.sizes.datePartWidth,
                          child: BrutalTextField(
                            label: 'YEAR',
                            hint: 'E.G. 26',
                            controller: _yearController,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {
                              // The readback and the button's own state both
                              // follow what is in the box.
                              _yearError = null;
                            }),
                            onSubmitted: (_) => _searchYear(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: BrutalButton(
                            label: 'SHOW THE WHOLE YEAR',
                            icon: Icons.search,
                            compact: skin.sizes.isCompact,
                            onPressed: _yearReady ? _searchYear : null,
                          ),
                        ),
                      ],
                    ),
                    if (_yearInWords.isNotEmpty) ...<Widget>[
                      BrutalGap(skin.sizes.gapSmall),
                      _Readback('THIS YEAR IS: $_yearInWords'),
                    ],
                    if (_yearError != null) ...<Widget>[
                      BrutalGap(skin.sizes.gapSmall),
                      BrutalNotice(message: _yearError!),
                    ],
                    BrutalGap(skin.sizes.gapLarge),

                    // One or the other, never both - said between the two
                    // blocks, where it is read before either of them.
                    const _OrDivider(),
                    BrutalGap(skin.sizes.gapLarge),

                    _WaySeparator(label: 'BETWEEN TWO DATES'),
                    BrutalGap(skin.sizes.gapSmall),

                    DdmmyyField(
                      label: 'FROM DATE',
                      controller: _fromController,
                      errorText: _fromError,
                      onChanged: _revalidateIfSubmitted,
                    ),
                    BrutalGap(skin.sizes.gapLarge),

                    DdmmyyField(
                      label: 'TO DATE',
                      controller: _toController,
                      errorText: _toError,
                      onChanged: _revalidateIfSubmitted,
                    ),
                    BrutalGap(skin.sizes.gapLarge),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: BrutalButton(
                        label: 'SHOW BETWEEN THESE DATES',
                        icon: Icons.search,
                        compact: skin.sizes.isCompact,
                        onPressed: _datesReady ? _search : null,
                      ),
                    ),
                  ],
                ),
              ),
              BrutalGap(skin.sizes.gapSection),

              // Not indented: this one empties the whole search, so it sits
              // at the panel's own left edge with the company code.
              Align(
                alignment: Alignment.centerLeft,
                child: BrutalButton(
                  label: 'CLEAR THE SEARCH',
                  style: BrutalButtonStyle.secondary,
                  onPressed: _clear,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One month, dividend rates only.
  Widget _buildMonthForm(BrutalSkinData skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('LOOK UP A MONTH'),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!skin.sizes.isCompact) ...<Widget>[
                Text(
                  'SHOWS THE DIVIDEND RATES FOR EVERY COMPANY IN ONE MONTH. '
                  'PRICE RANGES ARE NOT INCLUDED.',
                  style: skin.text.body,
                ),
                BrutalGap(skin.sizes.gapLarge),
              ],
              Wrap(
                spacing: skin.sizes.gap,
                runSpacing: skin.sizes.gap,
                children: <Widget>[
                  SizedBox(
                    width: skin.sizes.datePartWidth,
                    child: BrutalTextField(
                      label: 'MONTH',
                      hint: 'E.G. 08',
                      controller: _monthController,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  SizedBox(
                    width: skin.sizes.datePartWidth,
                    child: BrutalTextField(
                      label: 'YEAR',
                      hint: 'E.G. 26',
                      controller: _monthYearController,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (_) => _searchMonth(),
                    ),
                  ),
                ],
              ),
              if (_monthError != null) ...<Widget>[
                BrutalGap(skin.sizes.gapSmall),
                BrutalNotice(message: _monthError!),
              ],
              if (_monthYearError != null) ...<Widget>[
                BrutalGap(skin.sizes.gapSmall),
                BrutalNotice(message: _monthYearError!),
              ],
              BrutalGap(skin.sizes.gapSection),
              Wrap(
                spacing: skin.sizes.gap,
                runSpacing: skin.sizes.gap,
                children: <Widget>[
                  BrutalButton(
                    label: 'SHOW DIVIDEND RATES FOR THIS MONTH',
                    icon: Icons.search,
                    onPressed: _searchMonth,
                  ),
                  BrutalButton(
                    label: 'CLEAR THE MONTH',
                    style: BrutalButtonStyle.secondary,
                    onPressed: _clearMonth,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BrutalSkinData skin) {
    final criteria = _criteria;
    if (criteria == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BrutalSectionHeader('WHAT WAS FOUND FOR THE COMPANY'),
          BrutalPanel(
            child: Text(
              'TYPE A COMPANY CODE. THEN EITHER TYPE A YEAR AND PRESS SHOW '
              'THE WHOLE YEAR, OR TYPE THE TWO DATES AND PRESS SHOW BETWEEN '
              'THESE DATES.',
              style: skin.text.bodyBold,
            ),
          ),
        ],
      );
    }

    // Watched, not read once, so the counts stay right after a record is
    // changed or deleted from one of the results pages.
    final dividendCount = ref
        .watch(dividendRateControllerProvider)
        .where((r) => criteria.matches(ccode: r.ccode, entryDate: r.entryDate))
        .length;
    final priceCount = ref
        .watch(priceRangeControllerProvider)
        .where((r) => criteria.matches(ccode: r.ccode, entryDate: r.entryDate))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('WHAT WAS FOUND FOR THE COMPANY'),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BrutalNotice(
                message: 'SHOWING ${criteria.describe()}.',
                kind: NoticeKind.info,
                textStyle: skin.text.bodyBold,
              ),
              BrutalGap(skin.sizes.gapLarge),
              if (!skin.sizes.isCompact) ...<Widget>[
                Text(
                  'EACH LIST OPENS ON ITS OWN PAGE. PRESS GO BACK ON THAT '
                  'PAGE TO RETURN HERE.',
                  style: skin.text.body,
                ),
                BrutalGap(skin.sizes.gap),
              ],
              BrutalButton(
                label: 'SEE DIVIDEND RATES (${_found(dividendCount)})',
                expand: true,
                onPressed: () => _open(DividendInquiryPage(criteria: criteria)),
              ),
              BrutalGap(skin.sizes.gap),
              BrutalButton(
                label: 'SEE PRICE RANGES (${_found(priceCount)})',
                expand: true,
                onPressed: () => _open(PriceInquiryPage(criteria: criteria)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _found(int count) => switch (count) {
    0 => 'NONE FOUND',
    _ => '$count FOUND',
  };
}

/// A heading inside a panel, marking one of the two ways to search.
///
/// A rule across the panel with its label at the left - enough to group the
/// boxes under it without looking like another section of the page.
class _WaySeparator extends StatelessWidget {
  const _WaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(label, style: skin.text.fieldLabel),
        SizedBox(width: skin.sizes.gapSmall),
        Expanded(
          child: Container(height: skin.sizes.border, color: skin.colors.ink),
        ),
      ],
    );
  }
}

/// The word OR on a rule, between the two ways of searching.
///
/// Said here rather than inside the second heading, so it is read before
/// either set of boxes and the choice cannot be missed.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    Widget rule() => Expanded(
      child: Container(height: skin.sizes.border, color: skin.colors.ink),
    );

    return Row(
      children: <Widget>[
        rule(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: skin.sizes.gap),
          child: Text('OR', style: skin.text.fieldLabel),
        ),
        rule(),
      ],
    );
  }
}

/// A plain statement of what was typed, in the same block the date fields use
/// for theirs - so both readbacks on this panel look like one another.
class _Readback extends StatelessWidget {
  const _Readback(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: skin.border,
          color: skin.colors.stripe,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: skin.sizes.gap,
          vertical: skin.sizes.gapSmall,
        ),
        child: Text(text, style: skin.text.bodyBold),
      ),
    );
  }
}
