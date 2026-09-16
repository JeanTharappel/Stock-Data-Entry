import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:stock_data_entry/data/app_settings.dart';
import 'package:stock_data_entry/data/boxes.dart';
import 'package:stock_data_entry/export/export_service.dart';
import 'package:stock_data_entry/hive_registrar.g.dart';
import 'package:stock_data_entry/import/picked_file.dart';
import 'package:stock_data_entry/models/dividend_rate.dart';
import 'package:stock_data_entry/models/price_range.dart';
import 'package:stock_data_entry/screens/dividend_rate_screen.dart';
import 'package:stock_data_entry/screens/home_shell.dart';
import 'package:stock_data_entry/screens/inquiry_results_page.dart';
import 'package:stock_data_entry/screens/inquiry_screen.dart';
import 'package:stock_data_entry/screens/price_range_screen.dart';
import 'package:stock_data_entry/theme/brutal_skin.dart';
import 'package:stock_data_entry/theme/brutal_theme.dart';
import 'package:stock_data_entry/widgets/brutal_text_field.dart';
import 'package:stock_data_entry/widgets/ddmmyy_field.dart';

/// Builds and drives the real app.
///
/// The pure-Dart tests cover the record rules; these exist to catch anything
/// that only goes wrong once widgets are laid out - a theme that fails an
/// assert, a form that never reaches its controller, an overflowing panel.
void main() {
  late Directory hiveDir;
  late Box<DividendRate> dividendBox;
  late Box<PriceRange> priceBox;
  late Box<String> settingsBox;

  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('stock_data_entry_test');
    Hive.init(hiveDir.path);
    Hive.registerAdapters();
  });

  // Each test gets its own pair of boxes rather than clearing shared ones.
  // Hive serialises writes per box, and the writes these tests trigger are
  // started inside the widget tester's fake-async clock - so a `clear()` or a
  // `close()` queued behind them out here would wait on futures that can never
  // complete. Fresh names sidestep that entirely.
  var caseNumber = 0;

  setUp(() async {
    caseNumber++;
    (dividendBox, priceBox) = await openStockBoxes(
      dividendBoxName: 'dividend_rate_$caseNumber',
      priceBoxName: 'price_range_$caseNumber',
    );
    settingsBox = await Hive.openBox<String>('settings_$caseNumber');
  });

  tearDownAll(() {
    // No `Hive.close()` here, for the reason above. The temp directory is
    // disposable and Windows may still hold the box files open.
    try {
      hiveDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Nothing to do; the OS cleans up its own temp directory.
    }
  });

  /// Lets a change finish and appear on screen.
  ///
  /// Two things make this fiddlier than a plain pump:
  ///
  /// Saving and deleting `await` a write to Hive, which is real file I/O.
  /// Widget tests drive a fake clock, so that write never completes and the
  /// `await` in `_save` never resumes - the record lands in the box (Hive
  /// updates its map synchronously) while the screen still shows the old
  /// count. `runAsync` hands control back to the real event loop so the I/O
  /// can actually finish.
  ///
  /// And this is deliberately not `pumpAndSettle`, which waits for a frame to
  /// go unscheduled. Something here always schedules one - the scrollbars are
  /// pinned visible, a focused field blinks its cursor - so it would sit there
  /// for its full ten-minute budget. Nothing in this app animates, so a fixed
  /// couple of frames is all any change needs.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Taps something and lets the result land on screen.
  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  /// Builds the app the same way `main()` does: one skin feeding both the
  /// Material theme and the BrutalSkin our own widgets read from.
  Future<void> pumpApp(
    WidgetTester tester, {
    BrutalBrightness brightness = BrutalBrightness.light,
    BrutalDensity density = BrutalDensity.comfortable,

    /// Pass false to launch with an untouched settings box, the way a
    /// first-time visitor arrives.
    bool seedSettings = true,

    /// What IMPORT FROM A FILE receives, in place of the browser's file
    /// dialog. Null behaves like the user closing the dialog.
    PickedFile? pickedFile,
  }) async {
    // A tall surface so the whole page is laid out; the default 800x600 test
    // window would report overflow that a real browser never sees.
    tester.view.physicalSize = const Size(1500, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Seed the starting state through the settings box, the same path the
    // app reads on launch. `put` updates Hive's map synchronously, so the
    // first build already sees it; its disk write is not awaited because the
    // fake clock in here would never let it finish.
    if (seedSettings) {
      unawaited(
        settingsBox.put(
          kBrightnessKey,
          brightness == BrutalBrightness.dark ? 'dark' : 'light',
        ),
      );
      unawaited(
        settingsBox.put(
          kDensityKey,
          density == BrutalDensity.compact ? 'compact' : 'roomy',
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dividendRateBoxProvider.overrideWithValue(dividendBox),
          priceRangeBoxProvider.overrideWithValue(priceBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          filePickerProvider.overrideWithValue(() async => pickedFile),
        ],
        child: const _TestApp(),
      ),
    );
    await settle(tester);
  }

  /// The text box belonging to the field whose black label reads [label].
  /// Scoped to one screen because the other tab stays built in the
  /// [IndexedStack] and carries its own COMPANY CODE and DATE fields.
  Finder boxLabelled(Finder screen, String label) => find.descendant(
    of: find.ancestor(
      of: find.descendant(of: screen, matching: find.text(label)),
      matching: find.byType(BrutalTextField),
    ),
    matching: find.byType(TextField),
  );

  final Finder dividendScreen = find.byType(DividendRateScreen);
  final Finder priceScreen = find.byType(PriceRangeScreen);
  final Finder inquiryScreen = find.byType(InquiryScreen);

  /// One of the inquiry tab's two date blocks, by its heading.
  Finder dateBlock(String label) => find.ancestor(
    of: find.descendant(of: inquiryScreen, matching: find.text(label)),
    matching: find.byType(DdmmyyField),
  );

  /// Stores records straight into the boxes, before the app is built. Real
  /// I/O, so it runs outside the fake clock.
  Future<void> seed(
    WidgetTester tester, {
    List<DividendRate> dividends = const <DividendRate>[],
    List<PriceRange> prices = const <PriceRange>[],
  }) async {
    await tester.runAsync(() async {
      await dividendBox.addAll(dividends);
      await priceBox.addAll(prices);
    });
  }

  /// Opens the INQUIRY tab and searches [ccode] between two DDMMYY dates.
  Future<void> search(
    WidgetTester tester, {
    required String ccode,
    String from = '010126',
    String to = '311226',
  }) async {
    Future<void> fillDate(String label, String ddmmyy) async {
      final block = dateBlock(label);
      await tester.enterText(boxLabelled(block, 'DAY'), ddmmyy.substring(0, 2));
      await tester.enterText(
        boxLabelled(block, 'MONTH'),
        ddmmyy.substring(2, 4),
      );
      await tester.enterText(boxLabelled(block, 'YEAR'), ddmmyy.substring(4));
    }

    await press(tester, find.text('INQUIRY'));
    await tester.enterText(boxLabelled(inquiryScreen, 'COMPANY CODE'), ccode);
    await fillDate('FROM DATE', from);
    await fillDate('TO DATE', to);
    await settle(tester);
    await press(tester, find.text('SHOW RECORDS'));
  }

  Future<void> fillDividendForm(
    WidgetTester tester, {
    required String ccode,
    required String day,
    required String month,
    required String year,
    required String rate,
  }) async {
    await tester.enterText(boxLabelled(dividendScreen, 'COMPANY CODE'), ccode);
    await tester.enterText(boxLabelled(dividendScreen, 'DAY'), day);
    await tester.enterText(boxLabelled(dividendScreen, 'MONTH'), month);
    await tester.enterText(boxLabelled(dividendScreen, 'YEAR'), year);
    await tester.enterText(boxLabelled(dividendScreen, 'DIVIDEND RATE'), rate);
    await settle(tester);
  }

  testWidgets('the first screen builds with both tabs and an empty count', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('STOCK DATA ENTRY'), findsOneWidget);
    expect(find.text('DIVIDEND RATE ENTRY'), findsOneWidget);
    expect(find.text('PRICE RANGE ENTRY'), findsOneWidget);
    expect(find.text('YOU HAVE NO RECORDS SAVED YET.'), findsWidgets);
    expect(find.text('ADD A DIVIDEND RATE'), findsOneWidget);
  });

  testWidgets('an impossible date is refused in plain language', (
    tester,
  ) async {
    await pumpApp(tester);
    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '31',
      month: '02',
      year: '26',
      rate: '12.5',
    );

    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(find.text('DATE IS NOT VALID. ENTER AS DD MM YY.'), findsOneWidget);
    expect(dividendBox.length, 0);
  });

  testWidgets('a rate wider than the field is refused', (tester) async {
    await pumpApp(tester);
    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '05',
      month: '08',
      year: '26',
      rate: '123.5',
    );

    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(dividendBox.length, 0);
    expect(find.textContaining('DIVIDEND RATE IS TOO BIG'), findsOneWidget);
  });

  testWidgets('a valid record saves, counts up and lands in the table', (
    tester,
  ) async {
    await pumpApp(tester);
    await fillDividendForm(
      tester,
      ccode: 'acme',
      day: '05',
      month: '08',
      year: '26',
      rate: '12.5',
    );

    // The date readback spells out what the six digits mean.
    expect(find.text('THIS DATE IS: 05 AUGUST 2026'), findsOneWidget);

    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(dividendBox.length, 1);
    // Typed lower case, stored upper case.
    expect(dividendBox.values.first.ccode, 'ACME');
    expect(dividendBox.values.first.entryDate, '050826');
    expect(dividendBox.values.first.divRate, 12.5);

    expect(find.text('YOU HAVE 1 RECORD SAVED.'), findsOneWidget);
    expect(
      find.descendant(of: dividendScreen, matching: find.text('05 AUG 2026')),
      findsOneWidget,
    );
  });

  testWidgets('the same code and date twice raises the duplicate warning', (
    tester,
  ) async {
    await pumpApp(tester);

    for (var attempt = 0; attempt < 2; attempt++) {
      await fillDividendForm(
        tester,
        ccode: 'ACME',
        day: '05',
        month: '08',
        year: '26',
        rate: '12.5',
      );
      await press(
        tester,
        find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
      );
    }

    expect(find.text('THIS RECORD ALREADY EXISTS'), findsOneWidget);

    // Backing out must leave the box untouched.
    await press(tester, find.text('NO, GO BACK'));
    expect(dividendBox.length, 1);
  });

  testWidgets('deleting asks first and only then removes the record', (
    tester,
  ) async {
    await pumpApp(tester);
    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '05',
      month: '08',
      year: '26',
      rate: '12.5',
    );
    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );
    expect(dividendBox.length, 1);

    await press(
      tester,
      find.descendant(
        of: dividendScreen,
        matching: find.text('DELETE THIS ROW'),
      ),
    );

    expect(
      find.text('ARE YOU SURE YOU WANT TO DELETE THIS RECORD?'),
      findsOneWidget,
    );

    // Saying no keeps it.
    await press(tester, find.text('NO, KEEP IT'));
    expect(dividendBox.length, 1);

    await press(
      tester,
      find.descendant(
        of: dividendScreen,
        matching: find.text('DELETE THIS ROW'),
      ),
    );
    await press(tester, find.text('YES, DELETE IT'));

    expect(dividendBox.length, 0);
    expect(find.text('YOU HAVE NO RECORDS SAVED YET.'), findsWidgets);
  });

  testWidgets('the calendar fills in the day, month and year boxes', (
    tester,
  ) async {
    await pumpApp(tester);

    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('OPEN CALENDAR')),
    );
    expect(find.text('PICK A DATE'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    // Pick the 15th of whatever month the calendar opened on.
    await press(
      tester,
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('15'),
      ),
    );

    await press(tester, find.text('USE THIS DATE'));

    expect(find.text('PICK A DATE'), findsNothing);
    final dayField = tester.widget<TextField>(
      boxLabelled(dividendScreen, 'DAY'),
    );
    expect(dayField.controller!.text, '15');
    expect(
      find.descendant(
        of: dividendScreen,
        matching: find.textContaining('THIS DATE IS: 15 '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a first visit opens in the compact layout, in light', (
    tester,
  ) async {
    // Nothing stored yet, so this is what someone sees the very first time.
    await pumpApp(tester, seedSettings: false);

    final skin = BrutalSkin.of(tester.element(find.byType(HomeShell)));
    expect(skin.sizes.isCompact, isTrue);
    expect(skin.colors.isDark, isFalse);

    // And the toggle reflects it, rather than claiming the roomy layout.
    expect(find.text('FIT ON ONE PAGE'), findsOneWidget);
    expect(
      find.descendant(of: dividendScreen, matching: find.text('EXPORT AS CSV')),
      findsOneWidget,
    );
  });

  testWidgets('export buttons are inert and struck through with no records', (
    tester,
  ) async {
    await pumpApp(tester);

    Text exportLabel() => tester.widget<Text>(
      find.descendant(of: dividendScreen, matching: find.text('EXPORT AS CSV')),
    );

    // Nothing saved yet. With only two neutrals there is no grey to fade the
    // button with, so "cannot be pressed" has to be said another way.
    expect(exportLabel().style?.decoration, TextDecoration.lineThrough);
    expect(
      find.text('THERE IS NOTHING TO SAVE YET. ADD A RECORD FIRST.'),
      findsOneWidget,
    );

    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '05',
      month: '08',
      year: '26',
      rate: '12.5',
    );
    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    // Now there is something to export, and the button reads as live again.
    expect(exportLabel().style?.decoration, isNull);
    expect(
      find.text('THERE IS NOTHING TO SAVE YET. ADD A RECORD FIRST.'),
      findsNothing,
    );
  });

  testWidgets('the chosen toggle contrasts with the bar it sits on', (
    tester,
  ) async {
    await pumpApp(tester);
    final skin = BrutalSkin.of(tester.element(find.byType(HomeShell)));

    /// The fill painted behind a toggle's label.
    Color fillBehind(String label) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    // LIGHT is the active choice. It has to stand out FROM the title bar, so
    // it must not be painted the same colour as the bar - which is what a
    // plain primary button would have done here.
    expect(fillBehind('LIGHT'), isNot(skin.colors.fill));
    expect(fillBehind('LIGHT'), skin.colors.onFill);

    // The inactive one blends into the bar and is marked by its outline.
    expect(fillBehind('DARK'), skin.colors.fill);
  });

  testWidgets('the toggles are labelled in words and switch the skin', (
    tester,
  ) async {
    await pumpApp(tester);

    // Both sides of each toggle are always visible with their own word on
    // them - no icon-only switch that shows one state and hides the other.
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
    expect(find.text('BIG TEXT'), findsOneWidget);
    expect(find.text('FIT ON ONE PAGE'), findsOneWidget);

    await press(tester, find.text('DARK'));
    expect(
      BrutalSkin.of(tester.element(find.byType(HomeShell))).colors.isDark,
      isTrue,
    );

    await press(tester, find.text('FIT ON ONE PAGE'));
    expect(
      BrutalSkin.of(tester.element(find.byType(HomeShell))).sizes.isCompact,
      isTrue,
    );
  });

  testWidgets('dark mode still saves and shows a record', (tester) async {
    await pumpApp(tester, brightness: BrutalBrightness.dark);
    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '05',
      month: '08',
      year: '26',
      rate: '12.5',
    );
    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(dividendBox.length, 1);
    expect(find.text('YOU HAVE 1 RECORD SAVED.'), findsOneWidget);
  });

  testWidgets('the compact layout lays out and still saves', (tester) async {
    // A realistic laptop window rather than the tall surface the other cases
    // use - compact mode exists precisely for a screen this short, and any
    // overflow it causes should fail the test.
    await pumpApp(tester, density: BrutalDensity.compact);
    tester.view.physicalSize = const Size(1600, 900);
    await settle(tester);

    expect(find.text('ADD A DIVIDEND RATE'), findsOneWidget);
    expect(find.text('YOUR SAVED DIVIDEND RATES'), findsOneWidget);
    // The export buttons share the screen with the form rather than sitting
    // below the fold.
    expect(
      find.descendant(of: dividendScreen, matching: find.text('EXPORT AS CSV')),
      findsOneWidget,
    );

    await fillDividendForm(
      tester,
      ccode: 'ACME',
      day: '05',
      month: '08',
      year: '26',
      rate: '12.5',
    );
    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(dividendBox.length, 1);
    expect(find.text('YOU HAVE 1 RECORD SAVED.'), findsOneWidget);
  });

  testWidgets('the price range tab swaps in and rejects a high below a low', (
    tester,
  ) async {
    await pumpApp(tester);

    await press(tester, find.text('PRICE RANGE ENTRY'));
    expect(find.text('ADD A PRICE RANGE'), findsOneWidget);

    await tester.enterText(boxLabelled(priceScreen, 'COMPANY CODE'), 'ACME');
    await tester.enterText(boxLabelled(priceScreen, 'DAY'), '05');
    await tester.enterText(boxLabelled(priceScreen, 'MONTH'), '08');
    await tester.enterText(boxLabelled(priceScreen, 'YEAR'), '26');
    await tester.enterText(boxLabelled(priceScreen, 'LOW VALUE'), '250');
    await tester.enterText(boxLabelled(priceScreen, 'HIGH VALUE'), '100');
    await settle(tester);

    await press(
      tester,
      find.descendant(of: priceScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(priceBox.length, 0);
    expect(find.textContaining('HIGH VALUE IS SMALLER'), findsOneWidget);

    // Fixing the high value lets it through.
    await tester.enterText(boxLabelled(priceScreen, 'HIGH VALUE'), '900');
    await settle(tester);
    await press(
      tester,
      find.descendant(of: priceScreen, matching: find.text('SAVE ENTRY')),
    );

    expect(priceBox.length, 1);
    expect(priceBox.values.first.lowVal, 250);
    expect(priceBox.values.first.highVal, 900);
  });

  testWidgets('an inquiry finds only that company inside the dates', (
    tester,
  ) async {
    await seed(
      tester,
      dividends: <DividendRate>[
        DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
        DividendRate(ccode: 'ACME', entryDate: '100326', divRate: 8.0),
        // Wrong year, and wrong company: neither may appear.
        DividendRate(ccode: 'ACME', entryDate: '311225', divRate: 77.7),
        DividendRate(ccode: 'OTHER', entryDate: '050826', divRate: 55.5),
      ],
      prices: <PriceRange>[
        PriceRange(
          ccode: 'ACME',
          entryDate: '070826',
          lowVal: 100,
          highVal: 250,
        ),
      ],
    );
    await pumpApp(tester);
    await search(tester, ccode: 'acme');

    expect(
      find.text('SHOWING ACME FROM 01 JANUARY 2026 TO 31 DECEMBER 2026.'),
      findsOneWidget,
    );
    expect(find.text('SEE DIVIDEND RATES (2 FOUND)'), findsOneWidget);
    expect(find.text('SEE PRICE RANGES (1 FOUND)'), findsOneWidget);

    // Dividend rates open on their own page: date and rate, oldest first.
    await press(tester, find.text('SEE DIVIDEND RATES (2 FOUND)'));
    final dividendPage = find.byType(DividendInquiryPage);
    expect(dividendPage, findsOneWidget);
    Finder onDividendPage(String text) =>
        find.descendant(of: dividendPage, matching: find.text(text));
    expect(onDividendPage('12.5'), findsOneWidget);
    expect(onDividendPage('8.0'), findsOneWidget);
    expect(onDividendPage('77.7'), findsNothing);
    expect(onDividendPage('55.5'), findsNothing);
    expect(
      tester.getTopLeft(onDividendPage('10 MAR 2026')).dy,
      lessThan(tester.getTopLeft(onDividendPage('05 AUG 2026')).dy),
    );

    await press(tester, find.text('GO BACK TO THE SEARCH'));
    expect(dividendPage, findsNothing);

    // Price ranges on theirs: date, low and high.
    await press(tester, find.text('SEE PRICE RANGES (1 FOUND)'));
    final pricePage = find.byType(PriceInquiryPage);
    for (final text in <String>['07 AUG 2026', '100', '250']) {
      expect(
        find.descendant(of: pricePage, matching: find.text(text)),
        findsOneWidget,
      );
    }
  });

  testWidgets('an inquiry refuses a TO date before the FROM date', (
    tester,
  ) async {
    await pumpApp(tester);
    await search(tester, ccode: 'ACME', from: '010126', to: '311225');

    expect(
      find.textContaining('TO DATE IS BEFORE THE FROM DATE'),
      findsOneWidget,
    );
    expect(find.textContaining('SEE DIVIDEND RATES'), findsNothing);
  });

  testWidgets('EDIT on an inquiry result loads it into the entry form', (
    tester,
  ) async {
    await seed(
      tester,
      prices: <PriceRange>[
        PriceRange(
          ccode: 'ACME',
          entryDate: '070826',
          lowVal: 100,
          highVal: 250,
        ),
      ],
    );
    await pumpApp(tester);
    await search(tester, ccode: 'ACME');
    await press(tester, find.text('SEE PRICE RANGES (1 FOUND)'));

    await press(
      tester,
      find.descendant(
        of: find.byType(PriceInquiryPage),
        matching: find.text('EDIT'),
      ),
    );

    // The results page has closed, and the price range tab is showing with
    // the record loaded into its form.
    expect(find.byType(PriceInquiryPage), findsNothing);
    expect(find.text('CHANGE A PRICE RANGE'), findsOneWidget);
    String boxText(String label) => tester
        .widget<TextField>(boxLabelled(priceScreen, label))
        .controller!
        .text;
    expect(boxText('COMPANY CODE'), 'ACME');
    expect(boxText('LOW VALUE'), '100');
    expect(boxText('HIGH VALUE'), '250');

    // Saving changes the stored record rather than adding a second one.
    await tester.enterText(boxLabelled(priceScreen, 'HIGH VALUE'), '300');
    await settle(tester);
    await press(
      tester,
      find.descendant(of: priceScreen, matching: find.text('SAVE CHANGES')),
    );
    expect(priceBox.length, 1);
    expect(priceBox.values.first.highVal, 300);
  });

  testWidgets('DELETE on an inquiry result asks first, then removes it', (
    tester,
  ) async {
    await seed(
      tester,
      dividends: <DividendRate>[
        DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
      ],
    );
    await pumpApp(tester);

    // Have the record open in the entry form, to check the form lets go of it.
    await press(
      tester,
      find.descendant(of: dividendScreen, matching: find.text('EDIT')),
    );
    expect(find.text('CHANGE A DIVIDEND RATE'), findsOneWidget);

    await search(tester, ccode: 'ACME');
    await press(tester, find.text('SEE DIVIDEND RATES (1 FOUND)'));
    final dividendPage = find.byType(DividendInquiryPage);
    final deleteButton = find.descendant(
      of: dividendPage,
      matching: find.text('DELETE THIS ROW'),
    );

    await press(tester, deleteButton);
    expect(
      find.text('ARE YOU SURE YOU WANT TO DELETE THIS RECORD?'),
      findsOneWidget,
    );
    await press(tester, find.text('NO, KEEP IT'));
    expect(dividendBox.length, 1);

    await press(tester, deleteButton);
    await press(tester, find.text('YES, DELETE IT'));
    expect(dividendBox.length, 0);

    // The page stays open and says so, and the search tab's count follows.
    expect(
      find.descendant(
        of: dividendPage,
        matching: find.textContaining('NO RECORDS FOUND'),
      ),
      findsOneWidget,
    );
    await press(tester, find.text('GO BACK TO THE SEARCH'));
    expect(find.text('SEE DIVIDEND RATES (NONE FOUND)'), findsOneWidget);

    // And the entry form is no longer changing a record that is gone.
    await press(tester, find.text('DIVIDEND RATE ENTRY'));
    expect(find.text('ADD A DIVIDEND RATE'), findsOneWidget);
    expect(
      find.text('THE RECORD YOU WERE CHANGING HAS BEEN DELETED.'),
      findsOneWidget,
    );
  });

  testWidgets('the inquiry tab and its results lay out when compact', (
    tester,
  ) async {
    await pumpApp(tester, density: BrutalDensity.compact);
    tester.view.physicalSize = const Size(1600, 900);
    await settle(tester);

    await search(tester, ccode: 'ACME');
    expect(find.text('SEE DIVIDEND RATES (NONE FOUND)'), findsOneWidget);

    await press(tester, find.text('SEE DIVIDEND RATES (NONE FOUND)'));
    expect(
      find.textContaining('THERE ARE NO DIVIDEND RATES FOR ACME'),
      findsOneWidget,
    );
  });

  testWidgets('importing a backup asks first and skips what is already saved', (
    tester,
  ) async {
    final backup = <DividendRate>[
      DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
      DividendRate(ccode: 'ACME', entryDate: '100326', divRate: 8.0),
      DividendRate(ccode: 'ZED', entryDate: '010126', divRate: 3.5),
    ];
    // One of the three is already saved.
    await seed(
      tester,
      dividends: <DividendRate>[
        DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
      ],
    );
    await pumpApp(
      tester,
      pickedFile: PickedFile(
        name: 'dividend_rate_backup.xlsx',
        bytes: ExportService.dividendRateBytes(backup, ExportFormat.xlsx),
      ),
    );
    final importButton = find.descendant(
      of: dividendScreen,
      matching: find.text('IMPORT FROM A FILE'),
    );

    // Saying no leaves the box alone.
    await press(tester, importButton);
    expect(find.text('DO YOU WANT TO ADD 2 RECORDS?'), findsOneWidget);
    expect(
      find.textContaining('ALREADY SAVED, WILL BE SKIPPED: 1'),
      findsOneWidget,
    );
    await press(tester, find.text('NO, CANCEL'));
    expect(dividendBox.length, 1);
    expect(
      find.text('NOTHING WAS IMPORTED. YOU CHOSE TO CANCEL.'),
      findsOneWidget,
    );

    await press(tester, importButton);
    await press(tester, find.text('YES, ADD THEM'));
    expect(dividendBox.length, 3);
    expect(find.text('YOU HAVE 3 RECORDS SAVED.'), findsOneWidget);
    expect(
      find.text(
        'ADDED 2 RECORDS FROM dividend_rate_backup.xlsx. '
        '1 RECORD WAS ALREADY SAVED AND WAS SKIPPED.',
      ),
      findsOneWidget,
    );

    // The same file again adds nothing.
    await press(tester, importButton);
    expect(find.text('YES, ADD THEM'), findsNothing);
    expect(dividendBox.length, 3);
    expect(
      find.text(
        'EVERY RECORD IN dividend_rate_backup.xlsx IS ALREADY SAVED. '
        'NOTHING WAS ADDED.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a file with problems imports nothing and says why', (
    tester,
  ) async {
    await pumpApp(
      tester,
      pickedFile: PickedFile(
        name: 'price_range.csv',
        bytes: ExportService.dividendRateBytes(<DividendRate>[
          DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
        ], ExportFormat.csv),
      ),
    );
    await press(tester, find.text('PRICE RANGE ENTRY'));
    await press(
      tester,
      find.descendant(
        of: priceScreen,
        matching: find.text('IMPORT FROM A FILE'),
      ),
    );

    expect(find.text('YES, ADD THEM'), findsNothing);
    expect(priceBox.length, 0);
    expect(
      find.descendant(
        of: priceScreen,
        matching: find.textContaining(
          'IMPORT IT ON THE DIVIDEND RATE ENTRY TAB',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing the file dialog without choosing does nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    final importButton = find.descendant(
      of: dividendScreen,
      matching: find.text('IMPORT FROM A FILE'),
    );
    await press(tester, importButton);

    expect(find.text('IMPORT THESE RECORDS?'), findsNothing);
    expect(dividendBox.length, 0);
    // And the button still works afterwards.
    expect(
      tester.widget<Text>(importButton).style?.decoration,
      isNot(TextDecoration.lineThrough),
    );
  });
}

/// The app as `main()` assembles it: one skin, watched from the provider, fed
/// to both the Material theme and the BrutalSkin. Watching rather than pinning
/// is what lets a test press a toggle and see the whole app change.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(brutalSkinProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(skin),
      home: const HomeShell(),
      builder: (context, child) =>
          BrutalSkin(data: skin, child: child ?? const SizedBox.shrink()),
    );
  }
}
