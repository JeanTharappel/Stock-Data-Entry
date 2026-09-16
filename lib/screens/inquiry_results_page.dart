import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ddmmyy.dart';
import '../core/inquiry.dart';
import '../core/record_spec.dart';
import '../data/dividend_rate_controller.dart';
import '../data/navigation.dart';
import '../data/price_range_controller.dart';
import '../theme/brutal_skin.dart';
import '../widgets/brutal_blocks.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_table.dart';
import 'entry_screen_layout.dart';
import 'record_deletion.dart';

/// The dividend rates found by an inquiry: date and rate only.
///
/// EDIT does not open a form here. It closes this page and loads the record
/// into the DIVIDEND RATE ENTRY tab, so there is still only one form that can
/// change a dividend rate.
class DividendInquiryPage extends ConsumerWidget {
  const DividendInquiryPage({super.key, required this.criteria});

  final InquiryCriteria criteria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, so a deleted row disappears from the list at once.
    final records = ref
        .watch(dividendRateControllerProvider)
        .where((r) => criteria.matches(ccode: r.ccode, entryDate: r.entryDate))
        .toList();

    return InquiryResultsPage(
      title: 'DIVIDEND RATES',
      criteria: criteria,
      recordCount: records.length,
      table: BrutalTable(
        bordered: false,
        columns: const <BrutalColumn>[
          BrutalColumn('DATE', 250),
          BrutalColumn('DIVIDEND RATE', 200, alignRight: true),
        ],
        rows: <BrutalRowData>[
          for (final record in records)
            BrutalRowData(
              cells: <String>[
                shortSpellOutDdmmyy(record.entryDate),
                record.divRate.toStringAsFixed(DividendRateSpec.rateDecimals),
              ],
              onEdit: () {
                Navigator.of(context).pop();
                ref
                    .read(editRequestProvider.notifier)
                    .request(HomeTab.dividendEntry, record.key!);
              },
              onDelete: () =>
                  confirmAndDeleteDividendRate(context, ref, record),
            ),
        ],
        emptyMessage: 'THERE ARE NO DIVIDEND RATES FOR ${criteria.describe()}.',
      ),
    );
  }
}

/// The price ranges found by an inquiry: date, low value and high value.
/// See [DividendInquiryPage] for how EDIT and DELETE behave.
class PriceInquiryPage extends ConsumerWidget {
  const PriceInquiryPage({super.key, required this.criteria});

  final InquiryCriteria criteria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref
        .watch(priceRangeControllerProvider)
        .where((r) => criteria.matches(ccode: r.ccode, entryDate: r.entryDate))
        .toList();

    return InquiryResultsPage(
      title: 'PRICE RANGES',
      criteria: criteria,
      recordCount: records.length,
      table: BrutalTable(
        bordered: false,
        columns: const <BrutalColumn>[
          BrutalColumn('DATE', 230),
          BrutalColumn('LOW VALUE', 150, alignRight: true),
          BrutalColumn('HIGH VALUE', 150, alignRight: true),
        ],
        rows: <BrutalRowData>[
          for (final record in records)
            BrutalRowData(
              cells: <String>[
                shortSpellOutDdmmyy(record.entryDate),
                record.lowVal.toString(),
                record.highVal.toString(),
              ],
              onEdit: () {
                Navigator.of(context).pop();
                ref
                    .read(editRequestProvider.notifier)
                    .request(HomeTab.priceEntry, record.key!);
              },
              onDelete: () => confirmAndDeletePriceRange(context, ref, record),
            ),
        ],
        emptyMessage: 'THERE ARE NO PRICE RANGES FOR ${criteria.describe()}.',
      ),
    );
  }
}

/// The page both result lists sit on: a GO BACK button, a line saying what was
/// searched for and how much was found, then the table.
///
/// Laid out the same two ways as the entry tabs: in BIG TEXT the whole page
/// scrolls; in FIT ON ONE PAGE the table takes the leftover height and scrolls
/// inside itself.
class InquiryResultsPage extends StatefulWidget {
  const InquiryResultsPage({
    super.key,
    required this.title,
    required this.criteria,
    required this.recordCount,
    required this.table,
  });

  final String title;
  final InquiryCriteria criteria;
  final int recordCount;
  final Widget table;

  @override
  State<InquiryResultsPage> createState() => _InquiryResultsPageState();
}

class _InquiryResultsPageState extends State<InquiryResultsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final compact = skin.sizes.isCompact;

    final found = switch (widget.recordCount) {
      0 => 'NO RECORDS FOUND',
      1 => '1 RECORD FOUND',
      final count => '$count RECORDS FOUND',
    };

    final top = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: BrutalButton(
          label: 'GO BACK TO THE SEARCH',
          icon: Icons.arrow_back,
          style: BrutalButtonStyle.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      BrutalGap(skin.sizes.gap),
      BrutalNotice(
        message: '${widget.criteria.describe()}: $found.',
        kind: NoticeKind.info,
        textStyle: skin.text.count,
      ),
      BrutalGap(compact ? skin.sizes.gap : skin.sizes.gapSection),
    ];

    final block = EntryTableBlock(
      title: widget.title,
      note: compact ? null : 'THE OLDEST DATE IS AT THE TOP.',
      table: widget.table,
    );

    return Scaffold(
      backgroundColor: skin.colors.page,
      body: SafeArea(
        child: compact
            ? BrutalPageWidth(
                padding: EdgeInsets.symmetric(
                  horizontal: skin.sizes.pageGutter,
                  vertical: skin.sizes.gap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ...top,
                    Expanded(child: block),
                  ],
                ),
              )
            : Scrollbar(
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
                        ...top,
                        block,
                        BrutalGap(skin.sizes.gapSection),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
