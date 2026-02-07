import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'api/client.dart';
import 'screens/hotels_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();

  runApp(const MiniBookingApp());
}

class MiniBookingApp extends StatelessWidget {
  const MiniBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: createGraphQLClient(),
      child: MaterialApp(
        title: 'Mini Booking',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const HotelsScreen(),
      ),
    );
  }
}
