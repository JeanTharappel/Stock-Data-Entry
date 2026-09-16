import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs along the top of the app, in the order they are shown.
enum HomeTab {
  dividendEntry('DIVIDEND RATE ENTRY'),
  priceEntry('PRICE RANGE ENTRY'),
  inquiry('INQUIRY');

  const HomeTab(this.label);

  final String label;
}

/// Which tab is showing. Held here rather than inside the home shell so that
/// another screen - the inquiry results - can send the user to an entry tab.
class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.dividendEntry;

  void show(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

/// A request to load one saved record into an entry tab's form.
///
/// Deliberately not a const or a record type: two presses of EDIT on the same
/// row must still be two distinct requests, or the second would be ignored as
/// "no change".
class EditRequest {
  EditRequest({required this.tab, required this.key});

  /// The entry tab that owns the record.
  final HomeTab tab;

  /// The record's storage key.
  final Object key;
}

/// Carries EDIT presses from outside an entry screen to that screen's form.
///
/// The entry screens listen to this. The form code stays in one place - the
/// inquiry pages never build a form of their own, they just ask for this one.
class EditRequestController extends Notifier<EditRequest?> {
  @override
  EditRequest? build() => null;

  /// Switches to [tab] and asks it to load the record stored under [key].
  void request(HomeTab tab, Object key) {
    ref.read(homeTabProvider.notifier).show(tab);
    state = EditRequest(tab: tab, key: key);
  }
}

final editRequestProvider =
    NotifierProvider<EditRequestController, EditRequest?>(
      EditRequestController.new,
    );
