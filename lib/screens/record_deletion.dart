import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ddmmyy.dart';
import '../core/record_spec.dart';
import '../data/dividend_rate_controller.dart';
import '../data/price_range_controller.dart';
import '../models/dividend_rate.dart';
import '../models/price_range.dart';
import '../widgets/brutal_dialogs.dart';

/// The "are you sure?" step before a record is deleted, shared by every screen
/// with a DELETE button so the question always reads the same.
///
/// Each returns true only if the user said yes and the record is now gone.

Future<bool> confirmAndDeleteDividendRate(
  BuildContext context,
  WidgetRef ref,
  DividendRate record,
) async {
  final confirmed = await showBrutalConfirm(
    context: context,
    title: 'DELETE THIS RECORD?',
    message: 'ARE YOU SURE YOU WANT TO DELETE THIS RECORD?',
    detail:
        'COMPANY CODE: ${record.ccode}\n'
        'DATE: ${spellOutDdmmyy(record.entryDate)}\n'
        'DIVIDEND RATE: '
        '${record.divRate.toStringAsFixed(DividendRateSpec.rateDecimals)}\n\n'
        'THIS CANNOT BE UNDONE.',
    confirmLabel: 'YES, DELETE IT',
    cancelLabel: 'NO, KEEP IT',
  );
  if (!confirmed || !context.mounted) return false;
  await ref.read(dividendRateControllerProvider.notifier).delete(record.key!);
  return true;
}

Future<bool> confirmAndDeletePriceRange(
  BuildContext context,
  WidgetRef ref,
  PriceRange record,
) async {
  final confirmed = await showBrutalConfirm(
    context: context,
    title: 'DELETE THIS RECORD?',
    message: 'ARE YOU SURE YOU WANT TO DELETE THIS RECORD?',
    detail:
        'COMPANY CODE: ${record.ccode}\n'
        'DATE: ${spellOutDdmmyy(record.entryDate)}\n'
        'LOW VALUE: ${record.lowVal}\n'
        'HIGH VALUE: ${record.highVal}\n\n'
        'THIS CANNOT BE UNDONE.',
    confirmLabel: 'YES, DELETE IT',
    cancelLabel: 'NO, KEEP IT',
  );
  if (!confirmed || !context.mounted) return false;
  await ref.read(priceRangeControllerProvider.notifier).delete(record.key!);
  return true;
}
