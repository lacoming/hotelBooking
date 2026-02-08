import { createContext, useContext, useState, type ReactNode } from "react";

// ── Dictionaries ──────────────────────────────────────────────

const translations: Record<string, Record<string, string>> = {
  // General
  hotels: { en: "Hotels", ru: "Отели" },
  room: { en: "Room", ru: "Комната" },
  rooms: { en: "Rooms", ru: "Комнаты" },
  bookings: { en: "Bookings", ru: "Бронирования" },
  open: { en: "Open", ru: "Открыть" },
  capacity: { en: "Capacity", ru: "Вместимость" },
  loading: { en: "Loading...", ru: "Загрузка..." },
  loading_hotels: { en: "Loading hotels...", ru: "Загрузка отелей..." },
  loading_bookings: { en: "Loading bookings...", ru: "Загрузка бронирований..." },
  error: { en: "Error", ru: "Ошибка" },
  no_bookings: { en: "No bookings", ru: "Нет бронирований" },

  // Room page
  back_to_hotels: { en: "Back to hotels", ru: "Назад к отелям" },
  date_range: { en: "Date range [startDate, endDate)", ru: "Диапазон дат [заезд, выезд)" },
  start: { en: "Start", ru: "Заезд" },
  end: { en: "End", ru: "Выезд" },
  select_both_dates: { en: "Please select both dates", ru: "Выберите обе даты" },
  check_availability: { en: "Check availability", ru: "Проверить доступность" },
  checking: { en: "Checking...", ru: "Проверка..." },
  book: { en: "Book", ru: "Забронировать" },
  booking_ellipsis: { en: "Booking...", ru: "Бронируем..." },
  cancel: { en: "Cancel", ru: "Отменить" },
  available: { en: "Available", ru: "Доступно" },
  not_available: { en: "Not available", ru: "Недоступно" },
  free: { en: "Free", ru: "Свободно" },
  busy: { en: "Busy", ru: "Занято" },

  // Messages
  booking_created: { en: "Booking created", ru: "Бронирование создано" },
  booking_canceled: { en: "Booking canceled", ru: "Бронирование отменено" },
  booking_overlap: {
    en: "Dates overlap with an existing booking!",
    ru: "Даты пересекаются с существующим бронированием!",
  },

  // Table headers
  id: { en: "ID", ru: "ID" },
  status: { en: "Status", ru: "Статус" },
  created: { en: "Created", ru: "Создано" },
};

// ── Context ───────────────────────────────────────────────────

interface I18nContextType {
  locale: string;
  toggleLocale: () => void;
  t: (key: string) => string;
}

const I18nContext = createContext<I18nContextType>({
  locale: "en",
  toggleLocale: () => {},
  t: (key) => key,
});

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState("en");

  const toggleLocale = () => setLocale((l) => (l === "en" ? "ru" : "en"));

  const t = (key: string) => translations[key]?.[locale] ?? key;

  return (
    <I18nContext.Provider value={{ locale, toggleLocale, t }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  return useContext(I18nContext);
}
