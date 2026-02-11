import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_documents.dart';
import '../app_settings.dart';
import '../l10n.dart';
import 'room_screen.dart';

/// Desktop-oriented "light" overview: all hotels + rooms with Free/Busy status.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final isDark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'overview')),
        actions: [
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
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
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

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              ...hotels.map((hotel) {
                final rooms = hotel['rooms'] as List;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel['name'] as String,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ...rooms.map((room) => _RoomTile(
                              room: room,
                              hotelTimezone: (hotel['timezone'] as String?) ?? 'Europe/Moscow',
                            )),
                      ],
                    ),
                  ),
                );
              }),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ElevatedButton.icon(
                  onPressed: () => refetch?.call(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(tr(context, 'refresh')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Room tile with Free/Busy badge ─────────────────────────

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final String hotelTimezone;

  const _RoomTile({required this.room, required this.hotelTimezone});

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get _tomorrow {
    final t = DateTime.now().add(const Duration(days: 1));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final roomId = room['id'] as String;
    final roomName = room['name'] as String;
    final cap = room['capacity'];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomScreen(
                    roomId: roomId,
                    roomName: roomName,
                    hotelTimezone: hotelTimezone,
                  ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (cap != null)
                      Text(
                        '${tr(context, 'capacity')}: $cap',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              _AvailabilityBadge(
                  roomId: roomId, today: _today, tomorrow: _tomorrow),
              const SizedBox(width: 8),
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

// ─── Availability badge ─────────────────────────────────────

class _AvailabilityBadge extends StatelessWidget {
  final String roomId;
  final String today;
  final String tomorrow;

  const _AvailabilityBadge({
    required this.roomId,
    required this.today,
    required this.tomorrow,
  });

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: roomAvailabilityQuery,
        variables: {'roomId': roomId, 'from': today, 'to': tomorrow},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading && result.data == null) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (result.hasException || result.data == null) {
          return const Icon(Icons.help_outline, size: 18, color: Colors.grey);
        }

        final available =
            result.data!['roomAvailability']['available'] as bool;

        final badgeColor = available ? Colors.green : Colors.blue;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: badgeColor,
              ),
              const SizedBox(width: 4),
              Text(
                tr(context, available ? 'free_today' : 'busy_today'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
