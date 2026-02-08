import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'api/client.dart';
import 'app_settings.dart';
import 'screens/hotels_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();

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
          home: const HotelsScreen(),
        ),
      ),
    );
  }
}
