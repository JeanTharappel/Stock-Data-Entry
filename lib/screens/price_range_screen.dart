import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ddmmyy.dart';
import '../core/record_spec.dart';
import '../core/validators.dart';
import '../data/price_range_controller.dart';
import '../export/export_service.dart';
import '../import/import_service.dart';
import '../models/price_range.dart';
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

/// Entry and management of PRICE-RANGE records.
class PriceRangeScreen extends ConsumerStatefulWidget {
  const PriceRangeScreen({super.key});

  @override
  ConsumerState<PriceRangeScreen> createState() => _PriceRangeScreenState();
}

class _PriceRangeScreenState extends ConsumerState<PriceRangeScreen> {
  final TextEditingController _ccodeController = TextEditingController();
  final DdmmyyController _dateController = DdmmyyController();
  final TextEditingController _lowController = TextEditingController();
  final TextEditingController _highController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _ccodeError;
  String? _dateError;
  String? _lowError;
  String? _highError;

  Object? _editingKey;
  bool _submitted = false;

  String? _statusMessage;
  NoticeKind _statusKind = NoticeKind.success;

  bool get _isEditing => _editingKey != null;

  @override
  void dispose() {
    _ccodeController.dispose();
    _dateController.dispose();
    _lowController.dispose();
    _highController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool _validate() {
    final ccodeError = Validators.ccode(
      _ccodeController.text,
      maxLength: PriceRangeSpec.ccodeWidth,
    );
    final dateError = Validators.dateParts(
      day: _dateController.dayText,
      month: _dateController.monthText,
      year: _dateController.yearText,
    );
    final lowError = Validators.priceValue(
      _lowController.text,
      fieldName: 'LOW VALUE',
    );
    // The comparison only makes sense once both numbers are valid on their own.
    var highError = Validators.priceValue(
      _highController.text,
      fieldName: 'HIGH VALUE',
    );
    if (lowError == null && highError == null) {
      highError = Validators.highNotBelowLow(
        low: _lowController.text,
        high: _highController.text,
      );
    }

    setState(() {
      _ccodeError = ccodeError;
      _dateError = dateError;
      _lowError = lowError;
      _highError = highError;
    });

    return ccodeError == null &&
        dateError == null &&
        lowError == null &&
        highError == null;
  }

  void _revalidateIfSubmitted() {
    if (_submitted) {
      _validate();
    } else {
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

    final controller = ref.read(priceRangeControllerProvider.notifier);
    final ccode = _ccodeController.text.trim().toUpperCase();
    final entryDate = _dateController.ddmmyy!;
    final low = int.parse(_lowController.text.trim());
    final high = int.parse(_highController.text.trim());

    if (controller.isDuplicate(
      ccode: ccode,
      entryDate: entryDate,
      ignoreKey: _editingKey,
    )) {
      final proceed = await showBrutalConfirm(
        context: context,
        title: 'THIS RECORD ALREADY EXISTS',
        message:
            'YOU ALREADY HAVE A PRICE RANGE SAVED FOR THIS COMPANY '
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
        lowVal: low,
        highVal: high,
      );
    } else {
      await controller.add(
        ccode: ccode,
        entryDate: entryDate,
        lowVal: low,
        highVal: high,
      );
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
    _lowController.clear();
    _highController.clear();
    setState(() {
      _editingKey = null;
      _submitted = false;
      _ccodeError = null;
      _dateError = null;
      _lowError = null;
      _highError = null;
    });
  }

  void _startEditing(PriceRange record) {
    _ccodeController.text = record.ccode;
    _dateController.setFromDdmmyy(record.entryDate);
    _lowController.text = record.lowVal.toString();
    _highController.text = record.highVal.toString();
    setState(() {
      _editingKey = record.key;
      _submitted = false;
      _ccodeError = null;
      _dateError = null;
      _lowError = null;
      _highError = null;
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

  Future<void> _confirmDelete(PriceRange record) async {
    // If this was the record in the form, the listener in build clears it.
    final deleted = await confirmAndDeletePriceRange(context, ref, record);
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
    // See DividendRateScreen.build - this listener does the same job here.
    ref.listen<List<PriceRange>>(priceRangeControllerProvider, (_, records) {
      if (!_isEditing || records.any((record) => record.key == _editingKey)) {
        return;
      }
      _clearForm();
      setState(() {
        _statusKind = NoticeKind.info;
        _statusMessage = 'THE RECORD YOU WERE CHANGING HAS BEEN DELETED.';
      });
    });

    final records = ref.watch(priceRangeControllerProvider);
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
        onExport: (format) => ExportService.exportPriceRanges(records, format),
      ),
      importSection: ImportSection(
        prepare: (file) {
          final read = ImportService.readPriceRanges(file);
          final controller = ref.read(priceRangeControllerProvider.notifier);
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
          _isEditing ? 'CHANGE A PRICE RANGE' : 'ADD A PRICE RANGE',
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

              SizedBox(
                width: skin.sizes.fieldWidth,
                child: BrutalTextField(
                  label: 'COMPANY CODE',
                  hint:
                      'UP TO ${PriceRangeSpec.ccodeWidth} LETTERS OR NUMBERS. '
                      'IT WILL BE PUT IN CAPITALS FOR YOU.',
                  controller: _ccodeController,
                  maxLength: PriceRangeSpec.ccodeWidth,
                  errorText: _ccodeError,
                  inputFormatters: const <TextInputFormatter>[
                    UpperCaseTextFormatter(),
                  ],
                  onChanged: (_) => _revalidateIfSubmitted(),
                ),
              ),
              BrutalGap(skin.sizes.gapLarge),

              DdmmyyField(
                controller: _dateController,
                errorText: _dateError,
                onChanged: _revalidateIfSubmitted,
              ),
              BrutalGap(skin.sizes.gapLarge),

              // Low and high sit side by side because they are read as a pair,
              // and wrap onto separate lines when the window is narrow.
              Wrap(
                spacing: skin.sizes.gapLarge,
                runSpacing: skin.sizes.gapLarge,
                children: <Widget>[
                  SizedBox(
                    width: skin.sizes.fieldWidth,
                    child: BrutalTextField(
                      label: 'LOW VALUE',
                      hint:
                          'THE LOWEST PRICE. A WHOLE NUMBER UP TO '
                          '${PriceRangeSpec.maxValue}.',
                      controller: _lowController,
                      maxLength: PriceRangeSpec.valueWidth,
                      errorText: _lowError,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => _revalidateIfSubmitted(),
                    ),
                  ),
                  SizedBox(
                    width: skin.sizes.fieldWidth,
                    child: BrutalTextField(
                      label: 'HIGH VALUE',
                      hint:
                          'THE HIGHEST PRICE. IT CANNOT BE SMALLER THAN THE '
                          'LOW VALUE.',
                      controller: _highController,
                      maxLength: PriceRangeSpec.valueWidth,
                      errorText: _highError,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => _revalidateIfSubmitted(),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                ],
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

  Widget _buildTable(List<PriceRange> records, int? highlightedIndex) {
    final skin = BrutalSkin.of(context);
    return EntryTableBlock(
      title: 'YOUR SAVED PRICE RANGES',
      note: skin.sizes.isCompact ? null : 'THE OLDEST DATE IS AT THE TOP.',
      table: BrutalTable(
        // EntryTableBlock draws the outline around the whole block.
        bordered: false,
        highlightedRowIndex: highlightedIndex,
        columns: const <BrutalColumn>[
          BrutalColumn('COMPANY CODE', 200),
          BrutalColumn('DATE', 230),
          BrutalColumn('LOW VALUE', 150, alignRight: true),
          BrutalColumn('HIGH VALUE', 150, alignRight: true),
        ],
        rows: <BrutalRowData>[
          for (final record in records)
            BrutalRowData(
              cells: <String>[
                record.ccode,
                shortSpellOutDdmmyy(record.entryDate),
                record.lowVal.toString(),
                record.highVal.toString(),
              ],
              onEdit: () => _startEditing(record),
              onDelete: () => _confirmDelete(record),
            ),
        ],
        emptyMessage:
            'YOU HAVE NOT SAVED ANY PRICE RANGES YET.\n'
            'FILL IN THE FORM AND PRESS SAVE ENTRY.',
      ),
    );
  }
}
