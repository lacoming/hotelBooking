import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_documents.dart';
import '../app_settings.dart';
import '../l10n.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _checkingAvailability = false;
  Map<String, dynamic>? _availabilityResult;
  String? _availabilityError;

  String? _actionMessage;
  bool _actionIsError = false;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _availabilityResult = null;
        _availabilityError = null;
        _actionMessage = null;
      });
    }
  }

  bool get _datesValid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isBefore(_endDate!);

  Future<void> _checkAvailability(GraphQLClient client) async {
    if (!_datesValid) return;
    setState(() {
      _checkingAvailability = true;
      _availabilityResult = null;
      _availabilityError = null;
      _actionMessage = null;
    });

    final result = await client.query(QueryOptions(
      document: roomAvailabilityQuery,
      variables: {
        'roomId': widget.roomId,
        'from': _formatDate(_startDate!),
        'to': _formatDate(_endDate!),
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;
    setState(() {
      _checkingAvailability = false;
      if (result.hasException) {
        _availabilityError = result.exception.toString();
      } else {
        _availabilityResult = result.data!['roomAvailability'];
      }
    });
  }

  Future<void> _createBooking(GraphQLClient client) async {
    if (!_datesValid) return;
    setState(() {
      _actionMessage = null;
    });

    final result = await client.mutate(MutationOptions(
      document: createBookingMutation,
      variables: {
        'input': {
          'roomId': widget.roomId,
          'startDate': _formatDate(_startDate!),
          'endDate': _formatDate(_endDate!),
        },
      },
    ));

    if (!mounted) return;

    if (result.hasException) {
      final gqlErrors = result.exception?.graphqlErrors ?? [];
      final isOverlap = gqlErrors.any(
        (e) => e.extensions?['code'] == 'BOOKING_OVERLAP',
      );
      setState(() {
        _actionIsError = true;
        _actionMessage = isOverlap
            ? tr(context, 'booking_overlap')
            : '${tr(context, 'error')}: ${result.exception}';
      });
    } else {
      final booking = result.data!['createBooking'];
      setState(() {
        _actionIsError = false;
        _actionMessage =
            '${tr(context, 'booking_created')}: ${booking['id']} (${booking['startDate']} → ${booking['endDate']})';
        _availabilityResult = null;
      });
    }
  }

  Future<void> _cancelBooking(GraphQLClient client, String bookingId) async {
    final result = await client.mutate(MutationOptions(
      document: cancelBookingMutation,
      variables: {'id': bookingId},
    ));

    if (!mounted) return;

    if (result.hasException) {
      setState(() {
        _actionIsError = true;
        _actionMessage =
            '${tr(context, 'cancel_error')}: ${result.exception}';
      });
    } else {
      setState(() {
        _actionIsError = false;
        _actionMessage = '${tr(context, 'booking_canceled')}: $bookingId';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);
    final isDark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          TextButton(
            onPressed: settings.toggleLocale,
            child: Text(
              settings.locale == 'en' ? 'RU' : 'EN',
              style: TextStyle(
                color: theme.appBarTheme.foregroundColor,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr(context, 'room_id')}: ${widget.roomId}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),

            // ── Date pickers ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(context, isStart: true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_startDate != null
                        ? _formatDate(_startDate!)
                        : tr(context, 'start_date')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(context, isStart: false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_endDate != null
                        ? _formatDate(_endDate!)
                        : tr(context, 'end_date')),
                  ),
                ),
              ],
            ),
            if (_startDate != null &&
                _endDate != null &&
                !_startDate!.isBefore(_endDate!))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr(context, 'start_before_end'),
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            const SizedBox(height: 16),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _datesValid && !_checkingAvailability
                        ? () => _checkAvailability(client)
                        : null,
                    child: _checkingAvailability
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(tr(context, 'check_availability')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _datesValid ? () => _createBooking(client) : null,
                    child: Text(tr(context, 'book')),
                  ),
                ),
              ],
            ),

            // ── Availability result ──
            if (_availabilityError != null) ...[
              const SizedBox(height: 12),
              Text(_availabilityError!,
                  style: const TextStyle(color: Colors.red)),
            ],
            if (_availabilityResult != null) ...[
              const SizedBox(height: 12),
              _AvailabilityBanner(data: _availabilityResult!),
            ],

            // ── Action message ──
            if (_actionMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _actionIsError
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _actionMessage!,
                  style: TextStyle(
                    color: _actionIsError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),

            // ── Bookings list ──
            Text(tr(context, 'bookings'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _BookingsList(
              roomId: widget.roomId,
              onCancel: (id) => _cancelBooking(client, id),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Availability banner ────────────────────────────────────

class _AvailabilityBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AvailabilityBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final available = data['available'] as bool;
    final conflicts = data['conflicts'] as List;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: available
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: available ? Colors.green : Colors.orange,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, available ? 'available' : 'not_available'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: available ? Colors.green : Colors.orange,
            ),
          ),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${tr(context, 'conflicts')}:',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ...conflicts.map((c) => Text(
                  '  ${c['id']}: ${c['startDate']} → ${c['endDate']}',
                  style: const TextStyle(fontSize: 13),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Bookings list (auto-refetching Query widget) ───────────

class _BookingsList extends StatelessWidget {
  final String roomId;
  final void Function(String bookingId) onCancel;

  const _BookingsList({required this.roomId, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: roomBookingsQuery,
        variables: {'roomId': roomId},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading && result.data == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException) {
          return Text(
              '${tr(context, 'error_loading')}: ${result.exception}');
        }

        final bookings = result.data!['roomBookings'] as List;
        if (bookings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr(context, 'no_bookings')),
          );
        }

        return Column(
          children: [
            ...bookings.map((b) {
              final isActive = b['status'] == 'ACTIVE';
              return Card(
                child: ListTile(
                  title: Text('${b['startDate']} → ${b['endDate']}'),
                  subtitle: Text(
                    '${b['status']}  •  ${b['id']}',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isActive
                      ? TextButton(
                          onPressed: () async {
                            onCancel(b['id'] as String);
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            refetch?.call();
                          },
                          child: Text(tr(context, 'cancel'),
                              style: const TextStyle(color: Colors.red)),
                        )
                      : null,
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => refetch?.call(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(tr(context, 'refresh')),
            ),
          ],
        );
      },
    );
  }
}
