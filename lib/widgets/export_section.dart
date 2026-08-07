import 'package:flutter/material.dart';

import '../export/export_service.dart';
import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';
import 'brutal_button.dart';

/// The three export buttons plus the result message.
///
/// Each button says in words what it produces, and the note under the heading
/// explains what each file is for - nobody should have to know what "XLSX"
/// means to pick the right one. The note is dropped in the compact layout,
/// where the buttons have to earn their room.
class ExportSection extends StatefulWidget {
  const ExportSection({
    super.key,
    required this.recordCount,
    required this.onExport,
  });

  final int recordCount;

  /// Runs the export. Throwing is fine - the message block reports the error.
  final Future<void> Function(ExportFormat format) onExport;

  @override
  State<ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends State<ExportSection> {
  String? _message;
  NoticeKind _messageKind = NoticeKind.success;
  bool _busy = false;

  Future<void> _run(ExportFormat format) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onExport(format);
      if (!mounted) return;
      setState(() {
        _messageKind = NoticeKind.success;
        _message =
            'YOUR ${format.label} FILE HAS BEEN SAVED TO YOUR DOWNLOADS FOLDER.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messageKind = NoticeKind.error;
        _message = 'THE FILE COULD NOT BE SAVED. PLEASE TRY AGAIN.';
      });
      debugPrint('Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final hasRecords = widget.recordCount > 0;
    final enabled = hasRecords && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BrutalSectionHeader('SAVE A COPY OF THIS DATA'),
        BrutalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!skin.sizes.isCompact) ...<Widget>[
                Text(
                  'CHOOSE A FILE TYPE. THE FILE GOES TO YOUR DOWNLOADS FOLDER.\n\n'
                  'CSV  -  OPENS IN A SPREADSHEET.\n'
                  'XLSX  -  AN EXCEL WORKBOOK.\n'
                  'TXT  -  PLAIN TEXT IN THE ORIGINAL FIXED-WIDTH LAYOUT.',
                  style: skin.text.body,
                ),
                BrutalGap(skin.sizes.gapLarge),
              ],
              Wrap(
                spacing: skin.sizes.gap,
                runSpacing: skin.sizes.gap,
                children: <Widget>[
                  BrutalButton(
                    label: 'EXPORT AS CSV',
                    icon: Icons.table_chart,
                    compact: skin.sizes.isCompact,
                    onPressed: enabled ? () => _run(ExportFormat.csv) : null,
                  ),
                  BrutalButton(
                    label: 'EXPORT AS XLSX',
                    icon: Icons.grid_on,
                    compact: skin.sizes.isCompact,
                    onPressed: enabled ? () => _run(ExportFormat.xlsx) : null,
                  ),
                  BrutalButton(
                    label: 'EXPORT AS TXT',
                    icon: Icons.description,
                    compact: skin.sizes.isCompact,
                    onPressed: enabled ? () => _run(ExportFormat.txt) : null,
                  ),
                ],
              ),
              if (!hasRecords) ...<Widget>[
                const BrutalGap(),
                BrutalNotice(
                  message: 'THERE IS NOTHING TO SAVE YET. ADD A RECORD FIRST.',
                  kind: NoticeKind.warning,
                  textStyle: skin.text.bodyBold,
                ),
              ],
              if (_message != null) ...<Widget>[
                const BrutalGap(),
                BrutalNotice(message: _message!, kind: _messageKind),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
