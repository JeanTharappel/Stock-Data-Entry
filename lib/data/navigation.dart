import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs along the top of the app, in the order they are shown.
enum HomeTab {
  dividendEntry('DIVIDEND RATE ENTRY'),
  priceEntry('PRICE RANGE ENTRY'),
  inquiry('INQUIRY');

  const HomeTab(this.label);

  final String label;
}

/// Which tab is showing. Held here rather than inside the home shell so any
/// screen can ask for a tab to be shown.
class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.dividendEntry;

  void show(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);
