import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/cache.dart';
import 'ui/app_theme.dart';
import 'ui/copy.dart';
import 'ui/search_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hot restart drops the plugin registrant's factory. The native sqflite
  // plugin is still attached, so point the Dart side at it again.
  databaseFactoryOrNull ??= databaseFactorySqflitePlugin;
  final cache = await AppCache.open();
  runApp(HaryanaApp(cache: cache));
}

class HaryanaApp extends StatefulWidget {
  const HaryanaApp({super.key, this.cache});

  final AppCache? cache;

  @override
  State<HaryanaApp> createState() => _HaryanaAppState();
}

class _HaryanaAppState extends State<HaryanaApp> {
  ThemeMode _mode = ThemeMode.system;
  bool _hindi = false;

  void _toggle() {
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final dark = switch (_mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformDark,
    };
    setState(() => _mode = dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return LocaleHost(
      hindi: _hindi,
      toggle: () => setState(() => _hindi = !_hindi),
      child: ThemeHost(
      mode: _mode,
      toggle: _toggle,
      child: MaterialApp(
        title: 'Haryana Roadways',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _mode,
        home: SearchPage(cache: widget.cache),
      ),
    ),
    );
  }
}
