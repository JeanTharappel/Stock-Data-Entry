import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings.dart';
import '../data/navigation.dart';
import '../theme/brutal_skin.dart';
import '../widgets/brutal_button.dart';
import 'dividend_rate_screen.dart';
import 'entry_screen_layout.dart';
import 'inquiry_screen.dart';
import 'price_range_screen.dart';

/// The app frame: a title bar carrying the two display toggles, a row of tab
/// buttons, and the active screen underneath.
///
/// The active tab lives in [homeTabProvider] rather than here, so the inquiry
/// results can switch to an entry tab when EDIT is pressed.
///
/// The screens live in an [IndexedStack], so switching tabs is an instant swap
/// with no transition, and whatever was typed into the other form is still
/// there on the way back.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final activeTab = ref.watch(homeTabProvider);
    return Scaffold(
      backgroundColor: skin.colors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _titleBar(skin),
            _tabBar(skin, activeTab),
            Expanded(
              child: IndexedStack(
                // Children in the same order as HomeTab.values.
                index: activeTab.index,
                children: const <Widget>[
                  DividendRateScreen(),
                  PriceRangeScreen(),
                  InquiryScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Title on the left, the two display toggles on the right. Deliberately
  /// shallow - this bar is chrome, and every pixel it takes is a pixel the
  /// data does not get.
  Widget _titleBar(BrutalSkinData skin) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Container(
      color: skin.colors.fill,
      child: BrutalPageWidth(
        padding: EdgeInsets.symmetric(
          horizontal: skin.sizes.gap,
          vertical: skin.sizes.titleBarPadding,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: skin.sizes.gap,
          runSpacing: skin.sizes.gapSmall,
          children: <Widget>[
            Text('STOCK DATA ENTRY', style: skin.text.appTitle),
            Wrap(
              spacing: skin.sizes.gapLarge,
              runSpacing: skin.sizes.gapSmall,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                BrutalChoice<BrutalBrightness>(
                  // These sit on the filled title bar, so they need their own
                  // outline to be visible against it.
                  onSolid: true,
                  label: 'Colour scheme',
                  value: settings.brightness,
                  options: const <(BrutalBrightness, String)>[
                    (BrutalBrightness.light, 'LIGHT'),
                    (BrutalBrightness.dark, 'DARK'),
                  ],
                  onChanged: controller.setBrightness,
                ),
                BrutalChoice<BrutalDensity>(
                  onSolid: true,
                  label: 'How much fits on screen',
                  value: settings.density,
                  options: const <(BrutalDensity, String)>[
                    (BrutalDensity.comfortable, 'BIG TEXT'),
                    (BrutalDensity.compact, 'FIT ON ONE PAGE'),
                  ],
                  onChanged: controller.setDensity,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A single row that never wraps: the tabs share the width equally and
  /// stay side by side at any window size. IntrinsicHeight keeps them the same
  /// height if one label wraps onto two lines and the other does not, so the
  /// pair always reads as one strip.
  Widget _tabBar(BrutalSkinData skin, HomeTab activeTab) {
    return Container(
      decoration: BoxDecoration(
        color: skin.colors.paper,
        border: Border(
          bottom: BorderSide(
            color: skin.colors.ink,
            width: skin.sizes.borderThick,
          ),
        ),
      ),
      // Same horizontal geometry as the screen body below, so the tab strip
      // lines up with the edges of the page. No padding at the bottom, so the active tab's base bar lands on the bar's
      // bottom border and the two read as one solid edge.
      child: BrutalPageWidth(
        padding: EdgeInsets.fromLTRB(
          skin.sizes.gap,
          skin.sizes.gapSmall,
          skin.sizes.gap,
          0,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final tab in HomeTab.values) ...<Widget>[
                if (tab.index > 0) SizedBox(width: skin.sizes.gap),
                Expanded(
                  child: _TabButton(
                    label: tab.label,
                    selected: activeTab == tab,
                    onPressed: () =>
                        ref.read(homeTabProvider.notifier).show(tab),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab button.
///
/// Which tab you are on is signalled three ways at once, so it never rests on
/// one cue alone: the active tab is a solid block with inverted text while the
/// inactive one is plain, the active tab carries a thick bar along its base
/// joining it to the page below, and each tab says in words whether it is the
/// one showing.
class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = BrutalSkin.of(context);
    final label = widget.label;
    final selected = widget.selected;

    // Hovering an inactive tab fills it the same way every other button in
    // the app inverts under the pointer. It cannot be mistaken for the active
    // tab: that one also keeps the solid bar along its base and says SHOWING
    // NOW rather than TAP TO SWITCH.
    final filled = selected || _hovered;
    final foreground = filled ? skin.colors.onFill : skin.colors.ink;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: skin.sizes.touchTarget,
                  ),
                  decoration: BoxDecoration(
                    color: filled ? skin.colors.fill : skin.colors.paper,
                    border: skin.borderThick,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: skin.sizes.gap,
                    vertical: skin.sizes.gapSmall / 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: skin.text.tabLabel.copyWith(color: foreground),
                      ),
                      Text(
                        selected ? 'SHOWING NOW' : 'TAP TO SWITCH',
                        textAlign: TextAlign.center,
                        style: skin.text.tabHint.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
              // The active tab grows a solid base that runs into the page
              // below it, the way a physical file tab joins its folder.
              Container(
                height: skin.sizes.tabBasebar,
                color: selected ? skin.colors.ink : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
