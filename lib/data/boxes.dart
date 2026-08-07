import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../models/dividend_rate.dart';
import '../models/price_range.dart';

/// Hive box names. On the web these become IndexedDB object stores.
const String kDividendRateBoxName = 'dividend_rate';
const String kPriceRangeBoxName = 'price_range';

/// Opens both boxes. Called once from `main()` before the app is built.
///
/// The names are parameters only so tests can give each case its own pair of
/// boxes; the app always uses the defaults.
Future<(Box<DividendRate>, Box<PriceRange>)> openStockBoxes({
  String dividendBoxName = kDividendRateBoxName,
  String priceBoxName = kPriceRangeBoxName,
}) async {
  final dividendBox = await Hive.openBox<DividendRate>(dividendBoxName);
  final priceBox = await Hive.openBox<PriceRange>(priceBoxName);
  return (dividendBox, priceBox);
}

/// Overridden in `main()` with the already-opened box, so no widget ever has
/// to deal with an unopened box or an async gap.
final dividendRateBoxProvider = Provider<Box<DividendRate>>(
  (ref) => throw UnimplementedError(
    'dividendRateBoxProvider must be overridden in ProviderScope',
  ),
);

final priceRangeBoxProvider = Provider<Box<PriceRange>>(
  (ref) => throw UnimplementedError(
    'priceRangeBoxProvider must be overridden in ProviderScope',
  ),
);
