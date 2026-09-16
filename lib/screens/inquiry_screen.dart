import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Looks up every record for one company between two dates.
///
/// This tab only asks the question. The answers open on their own pages - one
/// for dividend rates, one for price ranges - so each list has the whole
/// screen to itself.
class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final TextEditingController _ccodeController = TextEditingController();
  final DdmmyyController _fromController = DdmmyyController();
  final DdmmyyController _toController = DdmmyyController();
  final ScrollController _scrollController = ScrollController();

  /// The results column's own scroll position, used in the compact layout.
  final ScrollController _resultsScrollController = ScrollController();

  String? _ccodeError;
  String? _fromError;
  String? _toError;

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
    _scrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

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

  void _revalidateIfSubmitted() {
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

  void _clear() {
    _ccodeController.clear();
    _fromController.clear();
    _toController.clear();
    setState(() {
      _submitted = false;
      _ccodeError = null;
      _fromError = null;
      _toError = null;
      _criteria = null;
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
    final form = _buildForm(skin);
    final results = _buildResults(skin);

    if (skin.sizes.isCompact) {
      // Side by side, like the entry tabs: the question on the left, the
      // answer on the right.
      return BrutalPageWidth(
        padding: EdgeInsets.all(skin.sizes.gap),
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
            horizontal: skin.sizes.gap,
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

  Widget _buildForm(BrutalSkinData skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('LOOK UP A COMPANY'),
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
                  onSubmitted: (_) => _search(),
                ),
              ),
              BrutalGap(skin.sizes.gapLarge),

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
              BrutalGap(skin.sizes.gapSection),

              Wrap(
                spacing: skin.sizes.gap,
                runSpacing: skin.sizes.gap,
                children: <Widget>[
                  BrutalButton(
                    label: 'SHOW RECORDS',
                    icon: Icons.search,
                    onPressed: _search,
                  ),
                  BrutalButton(
                    label: 'CLEAR THE SEARCH',
                    style: BrutalButtonStyle.secondary,
                    onPressed: _clear,
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
          const BrutalSectionHeader('WHAT WAS FOUND'),
          BrutalPanel(
            child: Text(
              'TYPE A COMPANY CODE AND THE TWO DATES, THEN PRESS SHOW '
              'RECORDS.',
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
        const BrutalSectionHeader('WHAT WAS FOUND'),
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
