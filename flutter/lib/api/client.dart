import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform, ValueNotifier;
import 'package:graphql_flutter/graphql_flutter.dart';

/// Override via: flutter run --dart-define=API_URL=http://192.168.x.x:4000/graphql
///
/// Defaults (no override):
///   Web / iOS simulator / desktop  → http://localhost:4000/graphql
///   Android emulator               → http://10.0.2.2:4000/graphql
///   Real device                    → must set API_URL explicitly
const String _override = String.fromEnvironment('API_URL');

String get apiUrl {
  if (_override.isNotEmpty) return _override;

  // Web → always localhost (never 10.0.2.2)
  if (kIsWeb) return 'http://localhost:4000/graphql';

  // Android emulator routes 10.0.2.2 → host machine's localhost
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:4000/graphql';
  }

  // iOS simulator / macOS / Windows / Linux → localhost
  return 'http://localhost:4000/graphql';
}

ValueNotifier<GraphQLClient> createGraphQLClient() {
  debugPrint('🔗 GraphQL endpoint: $apiUrl');
  final httpLink = HttpLink(apiUrl);

  return ValueNotifier(
    GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(store: InMemoryStore()),
    ),
  );
}
