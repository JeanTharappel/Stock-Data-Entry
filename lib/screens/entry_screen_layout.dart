import 'package:flutter/material.dart';

import '../theme/brutal_skin.dart';
import '../widgets/brutal_blocks.dart';

/// Arranges the five blocks both entry screens are made of.
///
/// The two densities lay them out quite differently:
///
/// * **Comfortable** stacks everything in one wide column and lets the page
///   scroll. Big type, lots of room, nothing to hunt for.
/// * **Compact** puts the form and the import button in a left column and the
///   table with the export buttons in a right one, so the whole screen is visible at once without
///   scrolling the page. The table takes whatever height is left over and
///   scrolls inside itself when there are more rows than fit - the one thing
///   a fixed-height layout cannot avoid once the list grows.
class EntryScreenLayout extends StatelessWidget {
  const EntryScreenLayout({
    super.key,
    required this.scrollController,
    required this.recordCount,
    required this.form,
    required this.table,
    required this.export,
    required this.importSection,
  });

  final ScrollController scrollController;
  final int recordCount;
  final Widget form;
  final Widget table;
  final Widget export;
  final Widget importSection;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return skin.sizes.isCompact ? _compact(skin) : _comfortable(skin);
  }

  Widget _comfortable(BrutalSkinData skin) {
    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        child: BrutalPageWidth(
          padding: EdgeInsets.symmetric(
            horizontal: skin.sizes.pageGutter,
            vertical: skin.sizes.gapLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BrutalRecordCount(count: recordCount),
              BrutalGap(skin.sizes.gapSection),
              form,
              BrutalGap(skin.sizes.gapSection),
              table,
              BrutalGap(skin.sizes.gapSection),
              export,
              BrutalGap(skin.sizes.gapSection),
              importSection,
              BrutalGap(skin.sizes.gapSection),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compact(BrutalSkinData skin) {
    return BrutalPageWidth(
      padding: EdgeInsets.symmetric(
        horizontal: skin.sizes.pageGutter,
        vertical: skin.sizes.gap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Left: the count, the form and the import button. Scrolls on its
          // own only if the window is too short for them. Import sits here
          // rather than under the exports so it does not take height from
          // the table.
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  BrutalRecordCount(count: recordCount),
                  BrutalGap(skin.sizes.gap),
                  form,
                  BrutalGap(skin.sizes.gap),
                  importSection,
                ],
              ),
            ),
          ),
          SizedBox(width: skin.sizes.gap),
          // Right: the table takes the leftover height, exports sit under it
          // where they are always reachable. Equal flex to the left column so
          // the seam between the two lines up with the seam between the tabs.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: table),
                BrutalGap(skin.sizes.gap),
                export,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies the page's shared horizontal geometry: the same maximum width and
/// the same side padding, wherever it is used.
///
/// The tab bar and the screen body both go through this, which is what makes
/// the gap between the two tabs sit directly above the gap between the two
/// columns. Change the margin in one place and both still line up.
class BrutalPageWidth extends StatelessWidget {
  const BrutalPageWidth({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    return Padding(
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: skin.sizes.pageGutter),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: skin.sizes.maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

/// A titled block wrapping the records table.
class EntryTableBlock extends StatelessWidget {
  const EntryTableBlock({
    super.key,
    required this.title,
    required this.table,
    this.note,
  });

  final String title;
  final Widget table;

  /// A plain-English line above the table. Dropped in the compact layout.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);

    // One outline for the whole block, drawn here. The table is told not to
    // draw its own - a panel border plus a table border a few pixels apart
    // looks like a border with a stray line beside it.
    final body = Container(
      decoration: BoxDecoration(
        color: skin.colors.paper,
        border: skin.borderThick,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (note != null)
            Padding(
              padding: EdgeInsets.all(skin.sizes.gap),
              child: Text(note!, style: skin.text.body),
            ),
          // In the compact layout the block is given a fixed height, so the
          // table has to take what is left rather than size to its rows.
          if (skin.sizes.isCompact) Expanded(child: table) else table,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: skin.sizes.isCompact ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        BrutalSectionHeader(title),
        if (skin.sizes.isCompact) Expanded(child: body) else body,
      ],
    );
  }
}
