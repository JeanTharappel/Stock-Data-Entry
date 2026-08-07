import 'package:flutter/material.dart';

import '../theme/brutal_skin.dart';
import 'brutal_blocks.dart';
import 'brutal_button.dart';

/// One column of a [BrutalTable].
class BrutalColumn {
  const BrutalColumn(this.label, this.width, {this.alignRight = false});

  final String label;
  final double width;
  final bool alignRight;
}

/// One row of a [BrutalTable]. [cells] must line up with the column list.
class BrutalRowData {
  const BrutalRowData({
    required this.cells,
    required this.onEdit,
    required this.onDelete,
  });

  final List<String> cells;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
}

/// A flat data table.
///
///   * column headings are inverted text on a solid bar
///   * rows meet the density's minimum height with a solid rule between them
///   * alternate rows use one flat shade - no stripes, no gradients
///   * every row ends with EDIT and DELETE buttons that say so in words;
///     there are no icon-only row actions and nothing swipes away
///
/// The table scrolls sideways as one piece on a narrow window rather than
/// squeezing the text down, and scrolls up and down inside itself when the
/// caller bounds its height.
class BrutalTable extends StatefulWidget {
  const BrutalTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    this.actionsWidth = 560,
    this.compactActionsWidth = 330,
    this.highlightedRowIndex,
    this.bordered = true,
  });

  final List<BrutalColumn> columns;
  final List<BrutalRowData> rows;
  final String emptyMessage;

  /// Room for the EDIT and DELETE THIS ROW buttons. Spelled-out button labels
  /// are wide, so this needs real headroom.
  final double actionsWidth;
  final double compactActionsWidth;

  /// The row currently loaded into the form for editing, drawn with a thick
  /// bar down its left edge so it is obvious which record is changing.
  final int? highlightedRowIndex;

  /// Draw the table's own outline. Set false when the caller already draws a
  /// border around it - two borders a few pixels apart read as one border
  /// with a stray thin line beside it, not as two blocks.
  final bool bordered;

  @override
  State<BrutalTable> createState() => _BrutalTableState();
}

class _BrutalTableState extends State<BrutalTable> {
  /// Each scroll direction needs its own controller. Without one the Scrollbar
  /// reaches for the PrimaryScrollController, which belongs to whatever is
  /// scrolling behind it, and paints against the wrong position.
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);

    if (widget.rows.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(border: widget.bordered ? skin.border : null),
        padding: EdgeInsets.all(skin.sizes.gapLarge),
        child: Text(widget.emptyMessage, style: skin.text.bodyBold),
      );
    }

    // Column widths are in pixels, but the text inside them grows if the
    // reader has turned their browser or system text size up. Scaling every
    // column by the same factor keeps the words inside their cells; the table
    // simply gets wider and scrolls sideways.
    final scale = MediaQuery.textScalerOf(context).scale(20) / 20;
    final columnScale = scale * (skin.sizes.isCompact ? 0.82 : 1.0);
    final actionsWidth =
        (skin.sizes.isCompact
            ? widget.compactActionsWidth
            : widget.actionsWidth) *
        scale;
    // The edge padding inside the header and each row has to be counted, or
    // the cells add up to more room than the table actually offers them.
    final edge = skin.sizes.gapSmall;
    final totalWidth =
        widget.columns.fold<double>(
          0,
          (sum, column) => sum + column.width * columnScale,
        ) +
        actionsWidth +
        edge * 2;

    return Container(
      decoration: BoxDecoration(border: widget.bordered ? skin.border : null),
      child: Scrollbar(
        controller: _horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Scrollbar(
              controller: _vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(skin, columnScale, actionsWidth, edge),
                    for (var i = 0; i < widget.rows.length; i++)
                      _row(
                        skin,
                        i,
                        widget.rows[i],
                        columnScale,
                        actionsWidth,
                        edge,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BrutalSkinData skin,
    double scale,
    double actionsWidth,
    double edge,
  ) {
    return Container(
      color: skin.colors.fill,
      padding: EdgeInsets.symmetric(
        vertical: skin.sizes.gapSmall,
        horizontal: edge,
      ),
      child: Row(
        children: <Widget>[
          for (final column in widget.columns)
            SizedBox(
              width: column.width * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  column.label,
                  textAlign: column.alignRight
                      ? TextAlign.right
                      : TextAlign.left,
                  style: skin.text.tableHeader,
                ),
              ),
            ),
          SizedBox(
            width: actionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                skin.sizes.isCompact ? 'ACTIONS' : 'WHAT DO YOU WANT TO DO?',
                style: skin.text.tableHeader,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BrutalSkinData skin,
    int index,
    BrutalRowData row,
    double scale,
    double actionsWidth,
    double edge,
  ) {
    final isHighlighted = index == widget.highlightedRowIndex;
    return Container(
      constraints: BoxConstraints(minHeight: skin.sizes.rowHeight),
      decoration: BoxDecoration(
        color: index.isEven ? skin.colors.paper : skin.colors.stripe,
        border: Border(
          top: BorderSide(color: skin.colors.ink, width: skin.sizes.border),
          left: BorderSide(
            color: skin.colors.ink,
            width: isHighlighted ? 10 : 0,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: skin.sizes.gapSmall / 2,
        horizontal: edge,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: widget.columns[i].width * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  i < row.cells.length ? row.cells[i] : '',
                  textAlign: widget.columns[i].alignRight
                      ? TextAlign.right
                      : TextAlign.left,
                  style: skin.text.tableCell,
                ),
              ),
            ),
          SizedBox(
            width: actionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              // Flexible rather than fixed: if a large text setting makes the
              // labels wider than the column, they wrap inside their buttons
              // instead of spilling out of the row.
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: BrutalButton(
                      label: 'EDIT',
                      compact: true,
                      style: BrutalButtonStyle.secondary,
                      onPressed: row.onEdit,
                    ),
                  ),
                  const BrutalGap.horizontal(),
                  Flexible(
                    child: BrutalButton(
                      label: skin.sizes.isCompact
                          ? 'DELETE'
                          : 'DELETE THIS ROW',
                      compact: true,
                      style: BrutalButtonStyle.danger,
                      onPressed: row.onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
