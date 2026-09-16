import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../core/ddmmyy.dart';
import '../models/price_range.dart';
import 'boxes.dart';

/// Owns every read and write of the `price_range` box.
/// See [DividendRateController] - the two follow the same shape.
class PriceRangeController extends Notifier<List<PriceRange>> {
  Box<PriceRange> get _box => ref.read(priceRangeBoxProvider);

  @override
  List<PriceRange> build() => _sorted();

  List<PriceRange> _sorted() {
    final records = _box.values.toList()
      ..sort((a, b) {
        final byDate = ddmmyySortKey(
          a.entryDate,
        ).compareTo(ddmmyySortKey(b.entryDate));
        if (byDate != 0) return byDate;
        return a.ccode.compareTo(b.ccode);
      });
    return List<PriceRange>.unmodifiable(records);
  }

  void _refresh() => state = _sorted();

  /// True when another record already uses this company code and date.
  bool isDuplicate({
    required String ccode,
    required String entryDate,
    Object? ignoreKey,
  }) {
    final identity = '${ccode.toUpperCase()}|$entryDate';
    return _box.keys.any((key) {
      if (ignoreKey != null && key == ignoreKey) return false;
      return _box.get(key)?.identityKey == identity;
    });
  }

  Future<void> add({
    required String ccode,
    required String entryDate,
    required int lowVal,
    required int highVal,
  }) async {
    await _box.add(
      PriceRange(
        ccode: ccode.toUpperCase(),
        entryDate: entryDate,
        lowVal: lowVal,
        highVal: highVal,
      ),
    );
    _refresh();
  }

  /// See [DividendRateController.notYetSaved].
  List<PriceRange> notYetSaved(List<PriceRange> incoming) {
    final saved = _box.values.map(_sameValuesKey).toSet();
    return incoming
        .where((record) => !saved.contains(_sameValuesKey(record)))
        .toList();
  }

  static String _sameValuesKey(PriceRange record) =>
      '${record.identityKey}|${record.lowVal}|${record.highVal}';

  /// Stores every record in [records] in one write.
  Future<void> addAll(List<PriceRange> records) async {
    await _box.addAll(records);
    _refresh();
  }

  Future<void> update({
    required Object key,
    required String ccode,
    required String entryDate,
    required int lowVal,
    required int highVal,
  }) async {
    final existing = _box.get(key);
    if (existing == null) return;
    existing
      ..ccode = ccode.toUpperCase()
      ..entryDate = entryDate
      ..lowVal = lowVal
      ..highVal = highVal;
    await existing.save();
    _refresh();
  }

  Future<void> delete(Object key) async {
    await _box.delete(key);
    _refresh();
  }
}

final priceRangeControllerProvider =
    NotifierProvider<PriceRangeController, List<PriceRange>>(
      PriceRangeController.new,
    );
