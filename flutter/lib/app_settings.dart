import 'package:flutter/material.dart';

class AppSettings extends InheritedWidget {
  final String locale; // 'en' or 'ru'
  final ThemeMode themeMode;
  final VoidCallback toggleLocale;
  final VoidCallback toggleTheme;

  const AppSettings({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.toggleLocale,
    required this.toggleTheme,
    required super.child,
  });

  static AppSettings of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppSettings>()!;
  }

  @override
  bool updateShouldNotify(AppSettings oldWidget) {
    return locale != oldWidget.locale || themeMode != oldWidget.themeMode;
  }
}
