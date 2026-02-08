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
