import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_documents.dart';
import '../app_settings.dart';
import '../l10n.dart';
import 'room_screen.dart';

class RoomsScreen extends StatelessWidget {
  final String hotelId;
  final String hotelName;

  const RoomsScreen({
    super.key,
    required this.hotelId,
    required this.hotelName,
  });

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final isDark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(hotelName),
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
          document: hotelQuery,
          variables: {'id': hotelId},
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
        builder: (result, {refetch, fetchMore}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.hasException) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tr(context, 'error')}: ${result.exception}',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: refetch,
                    child: Text(tr(context, 'retry')),
                  ),
                ],
              ),
            );
          }

          final hotel = result.data!['hotel'];
          if (hotel == null) {
            return Center(child: Text(tr(context, 'error')));
          }
          final rooms = hotel['rooms'] as List;
          final hotelTimezone = (hotel['timezone'] as String?) ?? 'Europe/Moscow';

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: rooms.length + 1,
              itemBuilder: (context, i) {
                if (i == rooms.length) {
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
                return _RoomTile(room: rooms[i], hotelTimezone: hotelTimezone);
              },
            ),
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                available ? Icons.check_circle : Icons.info_outline,
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
