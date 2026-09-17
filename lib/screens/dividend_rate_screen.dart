import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ddmmyy.dart';
import '../core/record_spec.dart';
import '../core/validators.dart';
import '../data/dividend_rate_controller.dart';
import '../export/export_service.dart';
import '../import/import_service.dart';
import '../models/dividend_rate.dart';
import '../theme/brutal_skin.dart';
import '../theme/brutal_theme.dart';
import '../widgets/brutal_blocks.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_dialogs.dart';
import '../widgets/brutal_table.dart';
import '../widgets/brutal_text_field.dart';
import '../widgets/ddmmyy_field.dart';
import '../widgets/export_section.dart';
import '../widgets/import_section.dart';
import 'entry_screen_layout.dart';
import 'record_deletion.dart';

/// Entry and management of DIVIDEND-RATE records.
class DividendRateScreen extends ConsumerStatefulWidget {
  const DividendRateScreen({super.key});

  @override
  ConsumerState<DividendRateScreen> createState() => _DividendRateScreenState();
}

class _DividendRateScreenState extends ConsumerState<DividendRateScreen> {
  final TextEditingController _ccodeController = TextEditingController();
  final DdmmyyController _dateController = DdmmyyController();
  final TextEditingController _rateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _ccodeError;
  String? _dateError;
  String? _rateError;

  /// The box key of the record being changed, or null when adding a new one.
  Object? _editingKey;

  /// Errors stay hidden until the first save attempt, then update live so the
  /// user can watch a problem disappear as they fix it.
  bool _submitted = false;

  String? _statusMessage;
  NoticeKind _statusKind = NoticeKind.success;

  bool get _isEditing => _editingKey != null;

  @override
  void dispose() {
    _ccodeController.dispose();
    _dateController.dispose();
    _rateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool _validate() {
    final ccodeError = Validators.ccode(
      _ccodeController.text,
      maxLength: DividendRateSpec.ccodeWidth,
    );
    final dateError = Validators.dateParts(
      day: _dateController.dayText,
      month: _dateController.monthText,
      year: _dateController.yearText,
    );
    final rateError = Validators.divRate(_rateController.text);

    setState(() {
      _ccodeError = ccodeError;
      _dateError = dateError;
      _rateError = rateError;
    });

    return ccodeError == null && dateError == null && rateError == null;
  }

  void _revalidateIfSubmitted() {
    if (_submitted) {
      _validate();
    } else {
      // Still rebuild so the spelled-out date readback stays current.
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _statusMessage = null;
    });

    if (!_validate()) {
      setState(() {
        _statusKind = NoticeKind.error;
        _statusMessage =
            'NOTHING WAS SAVED. PLEASE FIX THE PARTS MARKED IN RED BELOW.';
      });
      return;
    }

    final controller = ref.read(dividendRateControllerProvider.notifier);
    final ccode = _ccodeController.text.trim().toUpperCase();
    final entryDate = _dateController.ddmmyy!;
    final rate = double.parse(_rateController.text.trim());

    if (controller.isDuplicate(
      ccode: ccode,
      entryDate: entryDate,
      ignoreKey: _editingKey,
    )) {
      final proceed = await showBrutalConfirm(
        context: context,
        title: 'THIS RECORD ALREADY EXISTS',
        message:
            'YOU ALREADY HAVE A DIVIDEND RATE SAVED FOR THIS COMPANY '
            'CODE ON THIS DATE.',
        detail:
            'COMPANY CODE: $ccode\n'
            'DATE: ${spellOutDdmmyy(entryDate)}\n\n'
            'DO YOU WANT TO SAVE A SECOND ONE ANYWAY?',
        confirmLabel: 'YES, SAVE IT ANYWAY',
        cancelLabel: 'NO, GO BACK',
        kind: NoticeKind.warning,
        confirmStyle: BrutalButtonStyle.primary,
      );
      if (!proceed) {
        if (!mounted) return;
        setState(() {
          _statusKind = NoticeKind.warning;
          _statusMessage = 'NOTHING WAS SAVED. YOU CHOSE TO GO BACK.';
        });
        return;
      }
    }

    if (_isEditing) {
      await controller.update(
        key: _editingKey!,
        ccode: ccode,
        entryDate: entryDate,
        divRate: rate,
      );
    } else {
      await controller.add(ccode: ccode, entryDate: entryDate, divRate: rate);
    }

    if (!mounted) return;
    final wasEditing = _isEditing;
    _clearForm();
    setState(() {
      _statusKind = NoticeKind.success;
      _statusMessage = wasEditing
          ? 'YOUR CHANGES TO $ccode HAVE BEEN SAVED.'
          : 'SAVED. $ccode FOR ${spellOutDdmmyy(entryDate)} '
                'IS NOW IN YOUR LIST.';
    });
  }

  void _clearForm() {
    _ccodeController.clear();
    _dateController.clear();
    _rateController.clear();
    setState(() {
      _editingKey = null;
      _submitted = false;
      _ccodeError = null;
      _dateError = null;
      _rateError = null;
    });
  }

  void _startEditing(DividendRate record) {
    _ccodeController.text = record.ccode;
    _dateController.setFromDdmmyy(record.entryDate);
    _rateController.text = record.divRate.toStringAsFixed(
      DividendRateSpec.rateDecimals,
    );
    setState(() {
      _editingKey = record.key;
      _submitted = false;
      _ccodeError = null;
      _dateError = null;
      _rateError = null;
      _statusKind = NoticeKind.info;
      _statusMessage =
          'YOU ARE NOW CHANGING THE RECORD FOR ${record.ccode} ON '
          '${spellOutDdmmyy(record.entryDate)}. '
          'CHANGE WHAT YOU NEED, THEN PRESS SAVE CHANGES.';
    });
    // Bring the form back into view; the row that was pressed may be far
    // down. Guarded because the controller has no view attached until the
    // page has been laid out at least once.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _confirmDelete(DividendRate record) async {
    // If this was the record in the form, the listener in build clears it.
    final deleted = await confirmAndDeleteDividendRate(context, ref, record);
    if (!deleted || !mounted) return;
    setState(() {
      _statusKind = NoticeKind.success;
      _statusMessage = 'THE RECORD FOR ${record.ccode} HAS BEEN DELETED.';
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Deleting the row that is loaded into the form would leave it editing a
    // record that no longer exists, and saving would quietly do nothing. So
    // the form lets go of it as soon as it is gone.
    ref.listen<List<DividendRate>>(dividendRateControllerProvider, (
      _,
      records,
    ) {
      if (!_isEditing || records.any((record) => record.key == _editingKey)) {
        return;
      }
      _clearForm();
      setState(() {
        _statusKind = NoticeKind.info;
        _statusMessage = 'THE RECORD YOU WERE CHANGING HAS BEEN DELETED.';
      });
    });

    final records = ref.watch(dividendRateControllerProvider);
    final highlighted = _editingKey == null
        ? null
        : records.indexWhere((record) => record.key == _editingKey);

    return EntryScreenLayout(
      scrollController: _scrollController,
      recordCount: records.length,
      form: _buildForm(),
      table: _buildTable(records, highlighted == -1 ? null : highlighted),
      export: ExportSection(
        recordCount: records.length,
        onExport: (format) =>
            ExportService.exportDividendRates(records, format),
      ),
      importSection: ImportSection(
        prepare: (file) {
          final read = ImportService.readDividendRates(file);
          final controller = ref.read(dividendRateControllerProvider.notifier);
          final fresh = controller.notYetSaved(read.records);
          return ImportPlan(
            problems: read.problems,
            inFile: read.records.length,
            toAdd: fresh.length,
            apply: () => controller.addAll(fresh),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    final skin = BrutalSkin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BrutalSectionHeader(
          _isEditing ? 'CHANGE A DIVIDEND RATE' : 'ADD A DIVIDEND RATE',
        ),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_statusMessage != null) ...<Widget>[
                BrutalNotice(
                  message: _statusMessage!,
                  kind: _statusKind,
                  textStyle: _statusKind == NoticeKind.error
                      ? skin.text.error
                      : skin.text.bodyBold,
                ),
                BrutalGap(skin.sizes.gapLarge),
              ],

              // Wrap so the two single-line fields sit side by side when there
              // is room, and stack when there is not.
              Wrap(
                spacing: skin.sizes.gapLarge,
                runSpacing: skin.sizes.gapLarge,
                children: <Widget>[
                  SizedBox(
                    width: skin.sizes.fieldWidth,
                    child: BrutalTextField(
                      label: 'COMPANY CODE',
                      hint:
                          'UP TO ${DividendRateSpec.ccodeWidth} LETTERS OR '
                          'NUMBERS. IT WILL BE PUT IN CAPITALS FOR YOU.',
                      controller: _ccodeController,
                      maxLength: DividendRateSpec.ccodeWidth,
                      errorText: _ccodeError,
                      inputFormatters: const <TextInputFormatter>[
                        UpperCaseTextFormatter(),
                      ],
                      onChanged: (_) => _revalidateIfSubmitted(),
                    ),
                  ),
                  SizedBox(
                    width: skin.sizes.fieldWidth,
                    child: BrutalTextField(
                      label: 'DIVIDEND RATE',
                      hint:
                          'UP TO ${DividendRateSpec.maxRate.toStringAsFixed(1)}'
                          '. ONE NUMBER AFTER THE DOT, FOR EXAMPLE 12.5',
                      controller: _rateController,
                      errorText: _rateError,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => _revalidateIfSubmitted(),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                ],
              ),
              BrutalGap(skin.sizes.gapLarge),

              DdmmyyField(
                controller: _dateController,
                errorText: _dateError,
                onChanged: _revalidateIfSubmitted,
              ),
              BrutalGap(skin.sizes.gapSection),

              Wrap(
                spacing: skin.sizes.gap,
                runSpacing: skin.sizes.gap,
                children: <Widget>[
                  BrutalButton(
                    label: _isEditing ? 'SAVE CHANGES' : 'SAVE ENTRY',
                    icon: Icons.check,
                    onPressed: _save,
                  ),
                  BrutalButton(
                    label: _isEditing
                        ? 'STOP CHANGING THIS RECORD'
                        : 'CLEAR THE FORM',
                    style: BrutalButtonStyle.secondary,
                    onPressed: () {
                      _clearForm();
                      setState(() {
                        _statusKind = NoticeKind.info;
                        _statusMessage = 'THE FORM IS EMPTY AGAIN.';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<DividendRate> records, int? highlightedIndex) {
    final skin = BrutalSkin.of(context);
    return EntryTableBlock(
      title: 'YOUR SAVED DIVIDEND RATES',
      note: skin.sizes.isCompact ? null : 'THE OLDEST DATE IS AT THE TOP.',
      table: BrutalTable(
        // EntryTableBlock draws the outline around the whole block.
        bordered: false,
        highlightedRowIndex: highlightedIndex,
        columns: const <BrutalColumn>[
          BrutalColumn('COMPANY CODE', 220),
          BrutalColumn('DATE', 250),
          BrutalColumn('DIVIDEND RATE', 200, alignRight: true),
        ],
        rows: <BrutalRowData>[
          for (final record in records)
            BrutalRowData(
              cells: <String>[
                record.ccode,
                shortSpellOutDdmmyy(record.entryDate),
                record.divRate.toStringAsFixed(DividendRateSpec.rateDecimals),
              ],
              onEdit: () => _startEditing(record),
              onDelete: () => _confirmDelete(record),
            ),
        ],
        emptyMessage:
            'YOU HAVE NOT SAVED ANY DIVIDEND RATES YET.\n'
            'FILL IN THE FORM AND PRESS SAVE ENTRY.',
      ),
    );
  }
}
