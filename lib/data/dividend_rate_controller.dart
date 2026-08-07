import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../core/ddmmyy.dart';
import '../models/dividend_rate.dart';
import 'boxes.dart';

/// Owns every read and write of the `dividend_rate` box.
///
/// The exposed state is always sorted by date (oldest first, then by company
/// code) so the on-screen table and every export share one ordering.
class DividendRateController extends Notifier<List<DividendRate>> {
  Box<DividendRate> get _box => ref.read(dividendRateBoxProvider);

  @override
  List<DividendRate> build() => _sorted();

  List<DividendRate> _sorted() {
    final records = _box.values.toList()
      ..sort((a, b) {
        final byDate = ddmmyySortKey(
          a.entryDate,
        ).compareTo(ddmmyySortKey(b.entryDate));
        if (byDate != 0) return byDate;
        return a.ccode.compareTo(b.ccode);
      });
    return List<DividendRate>.unmodifiable(records);
  }

  void _refresh() => state = _sorted();

  /// True when another record already uses this company code and date.
  ///
  /// [ignoreKey] is the box key of the record currently being edited, so a
  /// record is never reported as a duplicate of itself.
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
    required double divRate,
  }) async {
    await _box.add(
      DividendRate(
        ccode: ccode.toUpperCase(),
        entryDate: entryDate,
        divRate: divRate,
      ),
    );
    _refresh();
  }

  Future<void> update({
    required Object key,
    required String ccode,
    required String entryDate,
    required double divRate,
  }) async {
    final existing = _box.get(key);
    if (existing == null) return;
    existing
      ..ccode = ccode.toUpperCase()
      ..entryDate = entryDate
      ..divRate = divRate;
    await existing.save();
    _refresh();
  }

  Future<void> delete(Object key) async {
    await _box.delete(key);
    _refresh();
  }
}

final dividendRateControllerProvider =
    NotifierProvider<DividendRateController, List<DividendRate>>(
      DividendRateController.new,
    );
