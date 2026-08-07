import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'data/app_settings.dart';
import 'data/boxes.dart';
import 'hive_registrar.g.dart';
import 'screens/home_shell.dart';
import 'theme/brutal_skin.dart';
import 'theme/brutal_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On the web this backs onto IndexedDB, so records survive a page reload
  // and a browser restart.
  await Hive.initFlutter();
  Hive.registerAdapters();

  // Every box is opened up front and handed to the providers, so no widget
  // ever has to wait for storage or deal with a closed box.
  final (dividendBox, priceBox) = await openStockBoxes();
  final settingsBox = await openSettingsBox();

  runApp(
    ProviderScope(
      overrides: <Override>[
        dividendRateBoxProvider.overrideWithValue(dividendBox),
        priceRangeBoxProvider.overrideWithValue(priceBox),
        settingsBoxProvider.overrideWithValue(settingsBox),
      ],
      child: const StockDataEntryApp(),
    ),
  );
}

class StockDataEntryApp extends ConsumerWidget {
  const StockDataEntryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One skin drives both worlds: the Material theme, which styles the
    // widgets we do not draw ourselves, and the BrutalSkin our own widgets
    // read from.
    final skin = ref.watch(brutalSkinProvider);

    return MaterialApp(
      title: 'Stock Data Entry',
      debugShowCheckedModeBanner: false,
      theme: buildBrutalTheme(skin),
      home: const HomeShell(),
      builder: (context, child) {
        // Respect a larger browser or OS text size, but never let it shrink
        // text below the sizes the design guarantees.
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: BrutalSkin(
            data: skin,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
