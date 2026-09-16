import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/picked_file.dart';
import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';
import 'brutal_button.dart';
import 'brutal_dialogs.dart';

/// What importing a chosen file would do, worked out before anything is saved
/// so the user can be asked first.
class ImportPlan {
  const ImportPlan({
    required this.problems,
    required this.inFile,
    required this.toAdd,
    required this.apply,
  });

  /// Anything wrong with the file. If there is anything here, nothing is
  /// imported.
  final List<String> problems;

  /// How many records the file holds.
  final int inFile;

  /// How many of them are not already saved.
  final int toAdd;

  /// Saves the [toAdd] new records.
  final Future<void> Function() apply;

  int get alreadySaved => inFile - toAdd;
}

/// The IMPORT FROM A FILE button plus its result message.
///
/// Importing only ever adds. Records already saved with the same values are
/// skipped, and nothing saved is changed or deleted, so loading a backup can
/// never make things worse than they were.
class ImportSection extends ConsumerStatefulWidget {
  const ImportSection({super.key, required this.prepare});

  /// Reads the chosen file and works out what importing it would do.
  final ImportPlan Function(PickedFile file) prepare;

  @override
  ConsumerState<ImportSection> createState() => _ImportSectionState();
}

class _ImportSectionState extends ConsumerState<ImportSection> {
  /// The most problems listed at once. A file that is wrong on every line
  /// would otherwise produce a wall of text nobody can act on.
  static const int _maxProblemsShown = 5;

  String? _message;
  NoticeKind _messageKind = NoticeKind.success;
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _message = null);

    // Not marked busy while the dialog is open: some browsers never say when
    // it was closed without choosing, and the button must not stay dead.
    final PickedFile? file;
    try {
      file = await ref.read(filePickerProvider)();
    } catch (error) {
      debugPrint('Choosing a file failed: $error');
      _show(
        NoticeKind.error,
        'THE FILE COULD NOT BE OPENED. PLEASE TRY AGAIN.',
      );
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _importFile(file);
    } catch (error) {
      debugPrint('Import failed: $error');
      _show(
        NoticeKind.error,
        'SOMETHING WENT WRONG. NOTHING WAS IMPORTED. PLEASE TRY AGAIN.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile(PickedFile file) async {
    final plan = widget.prepare(file);

    if (plan.problems.isNotEmpty) {
      final shown = plan.problems.take(_maxProblemsShown).join('\n');
      final hidden = plan.problems.length - _maxProblemsShown;
      _show(
        NoticeKind.error,
        'NOTHING WAS IMPORTED FROM ${file.name}.\n\n$shown'
        '${hidden > 0 ? '\n...AND ${_count(hidden, 'MORE PROBLEM')}.' : ''}',
      );
      return;
    }

    if (plan.toAdd == 0) {
      _show(
        NoticeKind.info,
        'EVERY RECORD IN ${file.name} IS ALREADY SAVED. NOTHING WAS ADDED.',
      );
      return;
    }

    final confirmed = await showBrutalConfirm(
      context: context,
      title: 'IMPORT THESE RECORDS?',
      message: 'DO YOU WANT TO ADD ${_count(plan.toAdd, 'RECORD')}?',
      detail:
          'FILE: ${file.name}\n'
          'RECORDS IN THE FILE: ${plan.inFile}\n'
          'NEW, WILL BE ADDED: ${plan.toAdd}\n'
          'ALREADY SAVED, WILL BE SKIPPED: ${plan.alreadySaved}\n\n'
          'NOTHING YOU HAVE ALREADY SAVED WILL BE CHANGED OR DELETED.',
      confirmLabel: 'YES, ADD THEM',
      cancelLabel: 'NO, CANCEL',
      kind: NoticeKind.info,
      confirmStyle: BrutalButtonStyle.primary,
    );
    if (!mounted) return;
    if (!confirmed) {
      _show(NoticeKind.warning, 'NOTHING WAS IMPORTED. YOU CHOSE TO CANCEL.');
      return;
    }

    await plan.apply();
    final skipped = switch (plan.alreadySaved) {
      0 => '',
      1 => ' 1 RECORD WAS ALREADY SAVED AND WAS SKIPPED.',
      final count => ' $count RECORDS WERE ALREADY SAVED AND WERE SKIPPED.',
    };
    _show(
      NoticeKind.success,
      'ADDED ${_count(plan.toAdd, 'RECORD')} FROM ${file.name}.$skipped',
    );
  }

  void _show(NoticeKind kind, String message) {
    if (!mounted) return;
    setState(() {
      _messageKind = kind;
      _message = message;
    });
  }

  static String _count(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 'S'}';

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('LOAD RECORDS FROM A FILE'),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!skin.sizes.isCompact) ...<Widget>[
                Text(
                  'CHOOSE A CSV, XLSX OR TXT FILE THAT THIS APP SAVED.\n\n'
                  'YOU WILL BE ASKED BEFORE ANYTHING IS ADDED. RECORDS YOU '
                  'ALREADY HAVE ARE SKIPPED, AND NOTHING SAVED IS CHANGED OR '
                  'DELETED.',
                  style: skin.text.body,
                ),
                BrutalGap(skin.sizes.gapLarge),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: BrutalButton(
                  label: 'IMPORT FROM A FILE',
                  icon: Icons.upload_file,
                  compact: skin.sizes.isCompact,
                  onPressed: _busy ? null : _run,
                ),
              ),
              if (_message != null) ...<Widget>[
                const BrutalGap(),
                BrutalNotice(
                  message: _message!,
                  kind: _messageKind,
                  textStyle: _messageKind == NoticeKind.error
                      ? skin.text.error
                      : skin.text.bodyBold,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
