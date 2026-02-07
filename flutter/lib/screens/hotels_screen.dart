import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_documents.dart';
import 'room_screen.dart';

class HotelsScreen extends StatelessWidget {
  const HotelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotels')),
      body: Query(
        options: QueryOptions(document: hotelsQuery),
        builder: (result, {refetch, fetchMore}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.hasException) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${result.exception.toString()}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: refetch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final hotels = result.data!['hotels'] as List;

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            child: ListView.builder(
              itemCount: hotels.length,
              itemBuilder: (context, i) {
                final hotel = hotels[i];
                final rooms = hotel['rooms'] as List;
                return _HotelCard(
                  hotelName: hotel['name'] as String,
                  rooms: rooms,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final String hotelName;
  final List rooms;

  const _HotelCard({required this.hotelName, required this.rooms});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotelName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...rooms.map((room) {
              final cap = room['capacity'];
              final subtitle = cap != null ? 'Capacity: $cap' : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(room['name'] as String),
                subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomScreen(
                          roomId: room['id'] as String,
                          roomName: room['name'] as String,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
