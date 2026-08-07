import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../theme/brutal_skin.dart';

/// Box holding the reader's display choices. Plain strings, so it needs no
/// adapter of its own.
const String kSettingsBoxName = 'app_settings';

/// Keys inside [kSettingsBoxName]. Public so a test can seed a starting
/// state without driving the toggles first.
const String kBrightnessKey = 'brightness';
const String kDensityKey = 'density';

Future<Box<String>> openSettingsBox() => Hive.openBox<String>(kSettingsBoxName);

final settingsBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError(
    'settingsBoxProvider must be overridden in ProviderScope',
  ),
);

/// The two display choices, held together because one skin is built from both.
@immutable
class AppSettings {
  const AppSettings({required this.brightness, required this.density});

  final BrutalBrightness brightness;
  final BrutalDensity density;

  AppSettings copyWith({
    BrutalBrightness? brightness,
    BrutalDensity? density,
  }) => AppSettings(
    brightness: brightness ?? this.brightness,
    density: density ?? this.density,
  );
}

/// Remembers how the reader likes the app to look.
///
/// The choice is written to Hive as it is made, so someone who needs dark mode
/// or the compact layout does not have to pick it again on every visit.
class AppSettingsController extends Notifier<AppSettings> {
  Box<String> get _box => ref.read(settingsBoxProvider);

  @override
  AppSettings build() => AppSettings(
    brightness: _box.get(kBrightnessKey) == 'dark'
        ? BrutalBrightness.dark
        : BrutalBrightness.light,
    // Compact is what a first-time visitor gets: the whole screen at once,
    // nothing below the fold. Written the other way round from the brightness
    // check above so that an absent setting lands on compact rather than on
    // the roomy layout.
    density: _box.get(kDensityKey) == 'roomy'
        ? BrutalDensity.comfortable
        : BrutalDensity.compact,
  );

  void setBrightness(BrutalBrightness value) {
    state = state.copyWith(brightness: value);
    _box.put(kBrightnessKey, value == BrutalBrightness.dark ? 'dark' : 'light');
  }

  void setDensity(BrutalDensity value) {
    state = state.copyWith(density: value);
    _box.put(kDensityKey, value == BrutalDensity.compact ? 'compact' : 'roomy');
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// The resolved skin. Built here rather than in a widget's `build` so the same
/// instance is reused until a setting actually changes.
final brutalSkinProvider = Provider<BrutalSkinData>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return BrutalSkinData.resolve(
    brightness: settings.brightness,
    density: settings.density,
  );
});
