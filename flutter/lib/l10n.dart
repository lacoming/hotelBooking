import 'package:flutter/widgets.dart';
import 'app_settings.dart';

const _translations = <String, Map<String, String>>{
  // ── General ──
  'hotels': {'en': 'Hotels', 'ru': 'Отели'},
  'room': {'en': 'Room', 'ru': 'Комната'},
  'rooms': {'en': 'Rooms', 'ru': 'Комнаты'},
  'bookings': {'en': 'Bookings', 'ru': 'Бронирования'},
  'open': {'en': 'Open', 'ru': 'Открыть'},
  'retry': {'en': 'Retry', 'ru': 'Повторить'},
  'refresh': {'en': 'Refresh', 'ru': 'Обновить'},
  'cancel': {'en': 'Cancel', 'ru': 'Отменить'},
  'book': {'en': 'Book', 'ru': 'Забронировать'},
  'loading': {'en': 'Loading...', 'ru': 'Загрузка...'},

  // ── Hotels screen ──
  'capacity': {'en': 'Max guests', 'ru': 'Макс. кол-во человек'},
  'free_today': {'en': 'Free', 'ru': 'Свободно'},
  'busy_today': {'en': 'Has free dates', 'ru': 'Есть свободные даты'},
  'overview': {'en': 'Overview', 'ru': 'Обзор'},

  // ── Room screen ──
  'room_id': {'en': 'Room ID', 'ru': 'ID комнаты'},
  'start_date': {'en': 'Start date', 'ru': 'Дата заезда'},
  'end_date': {'en': 'End date', 'ru': 'Дата выезда'},
  'start_before_end': {
    'en': 'Start must be before end',
    'ru': 'Дата заезда должна быть раньше выезда',
  },
  'check_availability': {
    'en': 'Check availability',
    'ru': 'Проверить доступность',
  },
  'checking': {'en': 'Checking...', 'ru': 'Проверка...'},
  'booking_ellipsis': {'en': 'Booking...', 'ru': 'Бронируем...'},
  'available': {'en': 'Available', 'ru': 'Доступно'},
  'not_available': {'en': 'Not available', 'ru': 'Недоступно'},
  'conflicts': {'en': 'Conflicts', 'ru': 'Конфликты'},
  'no_bookings': {'en': 'No bookings yet.', 'ru': 'Бронирований пока нет.'},

  'select_date_range': {
    'en': 'Select date range',
    'ru': 'Выберите диапазон дат',
  },
  'booked': {'en': 'Booked', 'ru': 'Забронировано'},
  'dates_busy': {
    'en': 'Dates are busy',
    'ru': 'Даты заняты',
  },
  'dates_free': {'en': 'Available', 'ru': 'Свободно'},

  // ── Check-in/out ──
  'check_in': {'en': 'Check-in', 'ru': 'Заезд'},
  'check_out': {'en': 'Check-out', 'ru': 'Выезд'},
  'hotel_time': {'en': 'Hotel time', 'ru': 'Время отеля'},
  'your_time': {'en': 'Your time', 'ru': 'Ваше время'},
  'check_in_out_info': {
    'en': 'Check-in from 16:00, check-out until 12:00',
    'ru': 'Заезд с 16:00, выезд до 12:00',
  },

  // ── Messages ──
  'booking_created': {
    'en': 'Booking created',
    'ru': 'Бронирование создано',
  },
  'booking_canceled': {
    'en': 'Booking canceled',
    'ru': 'Бронирование отменено',
  },
  'booking_overlap': {
    'en': 'Dates overlap with an existing booking.',
    'ru': 'Даты пересекаются с существующим бронированием.',
  },
  'cancel_error': {
    'en': 'Cancel error',
    'ru': 'Ошибка отмены',
  },
  'past_dates': {
    'en': 'Cannot book dates in the past',
    'ru': 'Нельзя бронировать прошедшие даты',
  },
  'error': {'en': 'Error', 'ru': 'Ошибка'},
  'error_loading': {
    'en': 'Error loading data',
    'ru': 'Ошибка загрузки данных',
  },
};

/// Translate a key using the current locale from AppSettings.
String tr(BuildContext context, String key) {
  final locale = AppSettings.of(context).locale;
  return _translations[key]?[locale] ?? key;
}

// ── Month names (genitive for Russian) ──────────────────────────
const _monthsRu = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ── Timezone utilities ───────────────────────────────────────

/// Map of common IANA timezone names → UTC offset in hours.
const _tzOffsets = <String, int>{
  'Europe/Moscow': 3,
  'Asia/Dubai': 4,
  'Europe/London': 0,
  'Europe/Berlin': 1,
  'Europe/Paris': 1,
  'Europe/Istanbul': 3,
  'Asia/Tokyo': 9,
  'America/New_York': -5,
  'America/Los_Angeles': -8,
  'UTC': 0,
};

/// Short display name for timezone.
const _tzShortNames = <String, String>{
  'Europe/Moscow': 'MSK',
  'Asia/Dubai': 'GST',
  'Europe/London': 'GMT',
  'Europe/Berlin': 'CET',
  'Europe/Paris': 'CET',
  'Europe/Istanbul': 'TRT',
  'Asia/Tokyo': 'JST',
  'America/New_York': 'EST',
  'America/Los_Angeles': 'PST',
  'UTC': 'UTC',
};

/// Get UTC offset hours for a timezone. Returns 0 if unknown.
int getUtcOffset(String ianaTz) => _tzOffsets[ianaTz] ?? 0;

/// Get short name for a timezone.
String getTzShortName(String ianaTz) => _tzShortNames[ianaTz] ?? ianaTz;

/// Get the device's local UTC offset in hours.
int getLocalUtcOffset() => DateTime.now().timeZoneOffset.inHours;

/// Get the device's timezone short name (e.g. "UTC+3").
String getLocalTzShortName() {
  final offset = getLocalUtcOffset();
  if (offset == 0) return 'UTC';
  final sign = offset > 0 ? '+' : '';
  return 'UTC$sign$offset';
}

/// Convert a time (hour:minute) from one UTC offset to another.
/// Returns (hour, minute, dayDelta) where dayDelta is -1, 0, or +1.
({int hour, int minute, int dayDelta}) convertTime(
    int hour, int minute, int fromOffset, int toOffset) {
  final diff = toOffset - fromOffset;
  var newHour = hour + diff;
  var dayDelta = 0;
  if (newHour >= 24) {
    newHour -= 24;
    dayDelta = 1;
  } else if (newHour < 0) {
    newHour += 24;
    dayDelta = -1;
  }
  return (hour: newHour, minute: minute, dayDelta: dayDelta);
}

/// Format check-in or check-out time with optional local conversion.
/// Returns e.g. "16:00 (MSK)" or "16:00 (MSK) / 14:00 (your time)" if different.
String formatCheckTime(int hour, int minute, String hotelTz) {
  final hotelOffset = getUtcOffset(hotelTz);
  final localOffset = getLocalUtcOffset();
  final hotelShort = getTzShortName(hotelTz);
  final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  if (hotelOffset == localOffset) {
    return '$timeStr ($hotelShort)';
  }

  final local = convertTime(hour, minute, hotelOffset, localOffset);
  final localStr =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final localTzName = getLocalTzShortName();
  final dayNote = local.dayDelta != 0
      ? (local.dayDelta > 0 ? ' +1d' : ' -1d')
      : '';
  return '$timeStr ($hotelShort) / $localStr$dayNote ($localTzName)';
}

/// Smart date range formatting:
///   Same month+year:  "06 - 11 февраля 2026"
///   Same year:        "06 февраля - 13 марта 2026"
///   Different years:  "12 декабря 2025 - 08 января 2026"
String formatDateRange(String startDate, String endDate, String locale) {
  final s = DateTime.parse(startDate);
  final e = DateTime.parse(endDate);
  final months = locale == 'ru' ? _monthsRu : _monthsEn;

  final sd = s.day.toString().padLeft(2, '0');
  final ed = e.day.toString().padLeft(2, '0');
  final sMonth = months[s.month - 1];
  final eMonth = months[e.month - 1];

  if (s.year == e.year && s.month == e.month) {
    // 06 - 11 февраля 2026
    return '$sd - $ed $eMonth ${e.year}';
  } else if (s.year == e.year) {
    // 06 февраля - 13 марта 2026
    return '$sd $sMonth - $ed $eMonth ${e.year}';
  } else {
    // 12 декабря 2025 - 08 января 2026
    return '$sd $sMonth ${s.year} - $ed $eMonth ${e.year}';
  }
}
