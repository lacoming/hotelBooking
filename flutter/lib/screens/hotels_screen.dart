import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_documents.dart';
import '../app_settings.dart';
import '../l10n.dart';
import 'rooms_screen.dart';

class HotelsScreen extends StatelessWidget {
  const HotelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final isDark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'hotels')),
        actions: [
          // Locale toggle
          TextButton(
            onPressed: settings.toggleLocale,
            child: Text(
              settings.locale == 'en' ? 'RU' : 'EN',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: settings.toggleTheme,
          ),
        ],
      ),
      body: Query(
        options: QueryOptions(
          document: hotelsQuery,
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
        builder: (result, {refetch, fetchMore}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.hasException) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tr(context, 'error')}: ${result.exception}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: refetch,
                      child: Text(tr(context, 'retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          final hotels = result.data!['hotels'] as List;

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: hotels.length + 1, // +1 for refresh button
              itemBuilder: (context, i) {
                if (i == hotels.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => refetch?.call(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(tr(context, 'refresh')),
                    ),
                  );
                }

                final hotel = hotels[i];
                final rooms = hotel['rooms'] as List;
                return _HotelCard(
                  hotelId: hotel['id'] as String,
                  hotelName: hotel['name'] as String,
                  roomCount: rooms.length,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Hotel card ──────────────────────────────────────────────

class _HotelCard extends StatelessWidget {
  final String hotelId;
  final String hotelName;
  final int roomCount;

  const _HotelCard({
    required this.hotelId,
    required this.hotelName,
    required this.roomCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RoomsScreen(hotelId: hotelId, hotelName: hotelName),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotelName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$roomCount ${tr(context, 'rooms').toLowerCase()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
