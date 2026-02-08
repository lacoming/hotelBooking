import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/client.dart';
import 'app_settings.dart';
import 'screens/hotels_screen.dart';
import 'screens/overview_screen.dart';
import 'theme.dart';

/// Desktop platforms get the "light overview" home screen.
bool get _isDesktop {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    default:
      return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
  await initializeDateFormatting();

  runApp(const MiniBookingApp());
}

class MiniBookingApp extends StatefulWidget {
  const MiniBookingApp({super.key});

  @override
  State<MiniBookingApp> createState() => _MiniBookingAppState();
}

class _MiniBookingAppState extends State<MiniBookingApp> {
  String _locale = 'en';
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleLocale() {
    setState(() {
      _locale = _locale == 'en' ? 'ru' : 'en';
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: createGraphQLClient(),
      child: AppSettings(
        locale: _locale,
        themeMode: _themeMode,
        toggleLocale: _toggleLocale,
        toggleTheme: _toggleTheme,
        child: MaterialApp(
          title: 'Mini Booking',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _themeMode,
          home: _isDesktop
              ? const OverviewScreen()
              : const HotelsScreen(),
        ),
      ),
    );
  }
}
