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
  'capacity': {'en': 'Capacity', 'ru': 'Вместимость'},
  'free_today': {'en': 'Free', 'ru': 'Свободно'},
  'busy_today': {'en': 'Busy', 'ru': 'Занято'},

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
