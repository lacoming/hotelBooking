import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../api/graphql_documents.dart';
import '../app_settings.dart';
import '../l10n.dart';

// ── Colors ──────────────────────────────────────────────────────
const _blue = Color(0xFF3D7BF7);
const _red = Color(0xFFE53935);
const _lightGreen = Color(0xFF8BC34A);
const _deepGreen = Color(0xFF2E7D32);

// ── Availability state machine ──────────────────────────────────
enum AvailabilityState {
  idle, // no range chosen
  selected, // range picked, not yet checked
  checkedAvailable, // availability = true
  checkedConflict, // availability = false (has conflicts)
  bookedSuccess, // booking created
}

// ════════════════════════════════════════════════════════════════
//  RoomScreen
// ════════════════════════════════════════════════════════════════

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  // ── Calendar state ──
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // ── Availability state ──
  AvailabilityState _availState = AvailabilityState.idle;
  Set<DateTime> _busyDays = {};
  bool _isChecking = false;
  bool _isBooking = false;

  // ── Availability raw result (for banner) ──
  Map<String, dynamic>? _availabilityResult;
  String? _availabilityError;

  // ── Action feedback ──
  String? _actionMessage;
  bool _actionIsError = false;

  // ── Bookings list refresh key ──
  int _bookingsVersion = 0;

  // ── Helpers ──────────────────────────────────────────────────

  DateTime _norm(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _rangeValid =>
      _rangeStart != null &&
      _rangeEnd != null &&
      _rangeStart!.isBefore(_rangeEnd!);

  /// Expand a half-open interval [start, end) into a set of normalized days.
  Set<DateTime> _expandInterval(DateTime start, DateTime end) {
    final days = <DateTime>{};
    var d = _norm(start);
    final e = _norm(end);
    while (d.isBefore(e)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  /// Compute busy days = intersection of conflict intervals with selected range.
  Set<DateTime> _computeBusyDays(List conflicts) {
    if (_rangeStart == null || _rangeEnd == null) return {};
    final rangeDays = _expandInterval(_rangeStart!, _rangeEnd!);
    final busy = <DateTime>{};
    for (final c in conflicts) {
      final cs = DateTime.parse(c['startDate'] as String);
      final ce = DateTime.parse(c['endDate'] as String);
      final conflictDays = _expandInterval(cs, ce);
      busy.addAll(conflictDays.intersection(rangeDays));
    }
    return busy;
  }

  // ── Color logic ─────────────────────────────────────────────

  Color _dayCircleColor(DateTime day) {
    final nd = _norm(day);
    switch (_availState) {
      case AvailabilityState.idle:
      case AvailabilityState.selected:
        return _blue;
      case AvailabilityState.checkedAvailable:
        return _lightGreen;
      case AvailabilityState.checkedConflict:
        return _busyDays.contains(nd) ? _red : _blue;
      case AvailabilityState.bookedSuccess:
        return _deepGreen;
    }
  }

  Color _highlightBarColor() {
    switch (_availState) {
      case AvailabilityState.idle:
      case AvailabilityState.selected:
      case AvailabilityState.checkedConflict:
        return _blue.withAlpha(50);
      case AvailabilityState.checkedAvailable:
        return _lightGreen.withAlpha(50);
      case AvailabilityState.bookedSuccess:
        return _deepGreen.withAlpha(50);
    }
  }

  // ── Range selection callback ────────────────────────────────

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focused;
      _availState = (start != null && end != null)
          ? AvailabilityState.selected
          : AvailabilityState.idle;
      _busyDays = {};
      _availabilityResult = null;
      _availabilityError = null;
      _actionMessage = null;
    });
  }

  // ── Check availability ──────────────────────────────────────

  Future<void> _checkAvailability(GraphQLClient client) async {
    if (!_rangeValid) return;
    setState(() {
      _isChecking = true;
      _availabilityResult = null;
      _availabilityError = null;
      _actionMessage = null;
      _busyDays = {};
    });

    final result = await client.query(QueryOptions(
      document: roomAvailabilityQuery,
      variables: {
        'roomId': widget.roomId,
        'from': _fmtDate(_rangeStart!),
        'to': _fmtDate(_rangeEnd!),
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      if (result.hasException) {
        _availabilityError = result.exception.toString();
        _availState = AvailabilityState.selected;
      } else {
        final data = result.data!['roomAvailability'] as Map<String, dynamic>;
        _availabilityResult = data;
        final available = data['available'] as bool;
        if (available) {
          _availState = AvailabilityState.checkedAvailable;
        } else {
          final conflicts = data['conflicts'] as List;
          _busyDays = _computeBusyDays(conflicts);
          _availState = AvailabilityState.checkedConflict;
        }
      }
    });
  }

  // ── Create booking ──────────────────────────────────────────

  Future<void> _createBooking(GraphQLClient client) async {
    if (!_rangeValid) return;

    // Prevent booking in the past
    final today = _norm(DateTime.now());
    if (_rangeStart!.isBefore(today)) {
      setState(() {
        _actionIsError = true;
        _actionMessage = tr(context, 'past_dates');
      });
      return;
    }

    setState(() {
      _isBooking = true;
      _actionMessage = null;
    });

    final result = await client.mutate(MutationOptions(
      document: createBookingMutation,
      variables: {
        'input': {
          'roomId': widget.roomId,
          'startDate': _fmtDate(_rangeStart!),
          'endDate': _fmtDate(_rangeEnd!),
        },
      },
    ));

    if (!mounted) return;

    if (result.hasException) {
      final gqlErrors = result.exception?.graphqlErrors ?? [];
      final isOverlap =
          gqlErrors.any((e) => e.extensions?['code'] == 'BOOKING_OVERLAP');

      // On overlap, re-run availability to get fresh conflicts
      if (isOverlap) {
        setState(() {
          _isBooking = false;
          _actionIsError = true;
          _actionMessage = tr(context, 'booking_overlap');
        });
        // Fetch fresh conflicts
        await _checkAvailability(client);
      } else {
        setState(() {
          _isBooking = false;
          _actionIsError = true;
          _actionMessage =
              '${tr(context, 'error')}: ${result.exception}';
        });
      }
    } else {
      final booking = result.data!['createBooking'];
      setState(() {
        _isBooking = false;
        _actionIsError = false;
        _availState = AvailabilityState.bookedSuccess;
        final locale = AppSettings.of(context).locale;
        _actionMessage =
            '${tr(context, 'booking_created')}: ${booking['id']} (${formatDateRange(booking['startDate'], booking['endDate'], locale)})';
        _bookingsVersion++;
      });
    }
  }

  // ── Cancel booking ──────────────────────────────────────────

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
        _bookingsVersion++;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────

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
            const SizedBox(height: 12),

            // ── Calendar card ──
            _buildCalendarCard(isDark, settings.locale),

            const SizedBox(height: 16),

            // ── Action buttons ──
            _buildActionButtons(client),

            // ── Availability result banner ──
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
                      ? Colors.red.withAlpha(30)
                      : Colors.green.withAlpha(30),
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
              key: ValueKey('bookings_$_bookingsVersion'),
              roomId: widget.roomId,
              onCancel: (id) => _cancelBooking(client, id),
            ),
          ],
        ),
      ),
    );
  }

  // ── Calendar card widget ────────────────────────────────────

  Widget _buildCalendarCard(bool isDark, String locale) {
    final calBg = isDark ? const Color(0xFF1E2746) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      decoration: BoxDecoration(
        color: calBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 730)),
        focusedDay: _focusedDay,
        locale: locale == 'ru' ? 'ru_RU' : 'en_US',
        startingDayOfWeek: StartingDayOfWeek.monday,

        // ── Range selection ──
        rangeSelectionMode: RangeSelectionMode.toggledOn,
        rangeStartDay: _rangeStart,
        rangeEndDay: _rangeEnd,
        onRangeSelected: _onRangeSelected,
        onPageChanged: (focused) => _focusedDay = focused,

        // ── Header ──
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: mutedColor, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.chevron_left, color: mutedColor, size: 20),
          ),
          rightChevronIcon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: mutedColor, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.chevron_right, color: mutedColor, size: 20),
          ),
        ),

        // ── Day of week labels ──
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: mutedColor, fontSize: 13, fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(
              color: mutedColor, fontSize: 13, fontWeight: FontWeight.w600),
        ),

        // ── Default day styles ──
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          defaultTextStyle: TextStyle(color: textColor, fontSize: 15),
          weekendTextStyle: TextStyle(color: textColor, fontSize: 15),
          outsideTextStyle:
              TextStyle(color: mutedColor.withAlpha(80), fontSize: 15),
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _blue, width: 1.5),
          ),
          todayTextStyle: TextStyle(color: textColor, fontSize: 15),
          // Range highlight bar color (fallback; overridden by builder)
          rangeHighlightColor: _highlightBarColor(),
          // Disable default range decorations (we use builders)
          rangeStartDecoration: const BoxDecoration(shape: BoxShape.circle),
          rangeEndDecoration: const BoxDecoration(shape: BoxShape.circle),
          withinRangeDecoration: const BoxDecoration(shape: BoxShape.circle),
          rangeStartTextStyle:
              const TextStyle(color: Colors.white, fontSize: 15),
          rangeEndTextStyle:
              const TextStyle(color: Colors.white, fontSize: 15),
          withinRangeTextStyle:
              TextStyle(color: textColor, fontSize: 15),
        ),

        // ── Custom builders ──
        calendarBuilders: CalendarBuilders(
          rangeStartBuilder: (ctx, day, focused) =>
              _buildDayCell(day, isStart: true),
          rangeEndBuilder: (ctx, day, focused) =>
              _buildDayCell(day, isEnd: true),
          withinRangeBuilder: (ctx, day, focused) =>
              _buildDayCell(day),
          rangeHighlightBuilder: (ctx, day, isWithinRange) {
            if (!isWithinRange) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (ctx, constraints) => Container(
                height: constraints.maxHeight,
                color: _highlightBarColor(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build a custom day cell for days within the selected range.
  Widget _buildDayCell(DateTime day,
      {bool isStart = false, bool isEnd = false}) {
    final color = _dayCircleColor(day);
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Action buttons ──────────────────────────────────────────

  Widget _buildActionButtons(GraphQLClient client) {
    final bookEnabled =
        _availState == AvailabilityState.checkedAvailable && !_isBooking;
    final isBooked = _availState == AvailabilityState.bookedSuccess;

    // Book button color
    Color bookBg;
    Color bookFg = Colors.white;
    if (isBooked) {
      bookBg = _deepGreen;
    } else if (bookEnabled) {
      bookBg = _lightGreen;
    } else {
      bookBg = Colors.grey;
      bookFg = Colors.white70;
    }

    // Book button label
    String bookLabel;
    if (_isBooking) {
      bookLabel = tr(context, 'booking_ellipsis');
    } else if (isBooked) {
      bookLabel = tr(context, 'booked');
    } else {
      bookLabel = tr(context, 'book');
    }

    return Row(
      children: [
        // ── Check availability ──
        Expanded(
          child: ElevatedButton(
            onPressed: _rangeValid && !_isChecking
                ? () => _checkAvailability(client)
                : null,
            child: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(tr(context, 'check_availability')),
          ),
        ),
        const SizedBox(width: 8),

        // ── Book ──
        Expanded(
          child: ElevatedButton(
            onPressed: bookEnabled ? () => _createBooking(client) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bookBg,
              foregroundColor: bookFg,
              disabledBackgroundColor: bookBg,
              disabledForegroundColor: bookFg,
            ),
            child: _isBooking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(bookLabel),
          ),
        ),
      ],
    );
  }
}

// ─── Availability banner ────────────────────────────────────────

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
            ? Colors.green.withAlpha(30)
            : Colors.orange.withAlpha(30),
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
            ...conflicts.map((c) {
              final locale = AppSettings.of(context).locale;
              return Text(
                '  ${c['id']}: ${formatDateRange(c['startDate'], c['endDate'], locale)}',
                style: const TextStyle(fontSize: 13),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Bookings list (auto-refetching Query widget) ─────────────

class _BookingsList extends StatelessWidget {
  final String roomId;
  final void Function(String bookingId) onCancel;

  const _BookingsList({super.key, required this.roomId, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: roomBookingsQuery,
        variables: {'roomId': roomId},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
        pollInterval: const Duration(seconds: 30),
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
                  title: Text(formatDateRange(
                    b['startDate'] as String,
                    b['endDate'] as String,
                    AppSettings.of(context).locale,
                  )),
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
