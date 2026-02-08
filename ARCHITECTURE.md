# Architecture — Mini Booking System

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            CLIENTS                                      │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │   React Web      │  │  Flutter Mobile   │  │  Flutter Desktop     │  │
│  │   Vite 7 + TS    │  │  iOS / Android    │  │  Windows / macOS     │  │
│  │   :5173          │  │                   │  │                      │  │
│  │                  │  │                   │  │                      │  │
│  │  Apollo Client 4 │  │  graphql_flutter  │  │  graphql_flutter     │  │
│  │  i18n (EN/RU)    │  │  i18n (EN/RU)     │  │  i18n (EN/RU)        │  │
│  │  Dark/Light      │  │  Dark/Light       │  │  Dark/Light          │  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘  │
│           │                     │                        │              │
└───────────┼─────────────────────┼────────────────────────┼──────────────┘
            │ HTTP POST           │ HTTP POST              │ HTTP POST
            │                     │                        │
            │  localhost:4000     │  10.0.2.2:4000         │  localhost:4000
            │                     │  (Android emu)         │
            │                     │  localhost:4000        │
            │                     │  (iOS sim)             │
            ▼                     ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        BACKEND (Docker)                                 │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                 Apollo Server v4  :4000/graphql                   │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                    GraphQL API Layer                        │  │  │
│  │  │                                                             │  │  │
│  │  │  Queries:                    Mutations:                     │  │  │
│  │  │  ├─ hotels                   ├─ createBooking(input)       │  │  │
│  │  │  ├─ hotel(id)                └─ cancelBooking(id)          │  │  │
│  │  │  ├─ room(id)                                               │  │  │
│  │  │  ├─ roomBookings(roomId, from?, to?)                       │  │  │
│  │  │  └─ roomAvailability(roomId, from, to)                     │  │  │
│  │  │                                                             │  │  │
│  │  │  Custom Scalars:             Enums:                        │  │  │
│  │  │  └─ Date (YYYY-MM-DD)       └─ BookingStatus {ACTIVE,     │  │  │
│  │  │                                   CANCELED}                │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                              │                                    │  │
│  │                              ▼                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                      Resolvers                              │  │  │
│  │  │                                                             │  │  │
│  │  │  createBooking:                                             │  │  │
│  │  │    1. Validate startDate < endDate                          │  │  │
│  │  │    2. Check room exists                                     │  │  │
│  │  │    3. Serializable TX:                                      │  │  │
│  │  │       ├─ find overlaps [ns,ne) ∩ [es,ee)                   │  │  │
│  │  │       │  where es < ne AND ns < ee                          │  │  │
│  │  │       ├─ conflicts? → throw BOOKING_OVERLAP                │  │  │
│  │  │       └─ insert Booking                                     │  │  │
│  │  │    4. Log JSON event                                        │  │  │
│  │  │                                                             │  │  │
│  │  │  cancelBooking:                                             │  │  │
│  │  │    1. Verify exists & not already canceled                  │  │  │
│  │  │    2. Set status=CANCELED, canceledAt=now()                 │  │  │
│  │  │    3. Log JSON event                                        │  │  │
│  │  │                                                             │  │  │
│  │  │  roomAvailability:                                          │  │  │
│  │  │    1. Validate from < to                                    │  │  │
│  │  │    2. Find ACTIVE overlapping bookings                      │  │  │
│  │  │    3. Return {available, conflicts}                         │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                              │                                    │  │
│  │                              ▼                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Prisma ORM 5.22                          │  │  │
│  │  │                                                             │  │  │
│  │  │  Models:                                                    │  │  │
│  │  │  ├─ Hotel  (id, name)                                      │  │  │
│  │  │  ├─ Room   (id, hotelId, name, capacity?)                  │  │  │
│  │  │  └─ Booking(id, roomId, startDate, endDate,                │  │  │
│  │  │             status, createdAt, canceledAt?)                 │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                              │ TCP :5432                                │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                PostgreSQL 16  (Alpine)                            │  │
│  │                                                                   │  │
│  │  Database: minibooking                                            │  │
│  │                                                                   │  │
│  │  Tables:                                                          │  │
│  │  ┌──────────┐    ┌──────────┐    ┌─────────────────────────────┐  │  │
│  │  │  Hotel    │◄───│   Room   │◄───│         Booking             │  │  │
│  │  │          │ 1:N│          │ 1:N│                             │  │  │
│  │  │ id (PK)  │    │ id (PK)  │    │ id (PK, uuid)              │  │  │
│  │  │ name     │    │ hotelId  │    │ roomId (FK → Room)          │  │  │
│  │  │          │    │ name     │    │ startDate (DATE)            │  │  │
│  │  │          │    │ capacity │    │ endDate   (DATE)            │  │  │
│  │  │          │    │          │    │ status    (ACTIVE|CANCELED) │  │  │
│  │  │          │    │          │    │ createdAt (TIMESTAMP)       │  │  │
│  │  │          │    │          │    │ canceledAt (TIMESTAMP?)     │  │  │
│  │  └──────────┘    └──────────┘    └─────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  Constraints:                                                     │  │
│  │  ├─ btree_gist extension                                         │  │
│  │  └─ EXCLUDE USING gist (roomId =, daterange(start,end) &&)      │  │
│  │     WHERE status = 'ACTIVE'                                       │  │
│  │                                                                   │  │
│  │  Indexes:                                                         │  │
│  │  └─ Booking(roomId, status)                                      │  │
│  │                                                                   │  │
│  │  Port: 5432 (internal) / 5433 (host)                             │  │
│  │  Volume: pgdata (persistent)                                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Model — Relationships

```
Hotel 1 ──── N Room 1 ──── N Booking
  │               │              │
  │               │              ├─ status: ACTIVE | CANCELED
  │               │              ├─ dates: [startDate, endDate)  ← half-open
  │               │              │          startDate included
  │               │              │          endDate excluded
  │               │              │
  │               │              └─ Overlap rule:
  │               │                 new [ns,ne) conflicts with existing [es,ee)
  │               │                 if es < ne AND ns < ee
  │               │
  │               └─ idx: (roomId, status) for fast booking lookups
  │
  └─ 2 hotels in seed data
```

## Seed Data (relative to today)

Seed использует **относительные даты** (`today ± offset`), поэтому конфликтные сценарии воспроизводимы при любом запуске.

```
Grand Hotel (hotel-1)                Beach Resort (hotel-2)
├── Room 101 (room-101, cap 2)       ├── Room A1 (room-a1, cap 4)
│   ├── bk-1: [today-2, today+3)    │   ├── bk-4: [today, today+5)
│   │         ACTIVE, covers today   │   │         ACTIVE, covers today
│   └── bk-2: [today+5, today+10)   │   └── bk-5: [today-3, today+1)
│             ACTIVE, future         │             CANCELED (no conflict effect)
├── Room 102 (room-102, cap 3)       ├── Room A2 (room-a2, cap 2) — Free today
│   └── bk-3: [today-1, today+2)    └── Room A3 (room-a3, cap 3) — Free today
│             ACTIVE, covers today
└── Room 103 (room-103, cap 1) — Free today

Busy today:  room-101 (bk-1), room-102 (bk-3), room-a1 (bk-4)
Free today:  room-103, room-a2, room-a3

Overlap test: book room-101 [today, today+4) → BOOKING_OVERLAP (conflicts with bk-1)
Adjacent ok: book room-101 [today+3, today+5) → success (half-open: bk-1 ends at today+3)
```

## Request Flows

### Create Booking

```
Client                    Apollo Server              Prisma                PostgreSQL
  │                            │                       │                      │
  │  createBooking(input)      │                       │                      │
  │ ──────────────────────────►│                       │                      │
  │                            │  validate dates       │                      │
  │                            │  check room exists    │                      │
  │                            │                       │                      │
  │                            │  BEGIN SERIALIZABLE   │                      │
  │                            │ ─────────────────────►│  BEGIN               │
  │                            │                       │ ────────────────────►│
  │                            │  find overlaps        │                      │
  │                            │ ─────────────────────►│  SELECT ... WHERE    │
  │                            │                       │  startDate < to AND  │
  │                            │                       │  endDate > from AND  │
  │                            │                       │  status = ACTIVE     │
  │                            │                       │ ────────────────────►│
  │                            │                       │◄────────────────────│
  │                            │◄─────────────────────│                      │
  │                            │                       │                      │
  │                            │  conflicts? → error   │                      │
  │                            │                       │                      │
  │                            │  INSERT booking       │                      │
  │                            │ ─────────────────────►│  INSERT + exclusion  │
  │                            │                       │  constraint check    │
  │                            │                       │ ────────────────────►│
  │                            │                       │◄────────────────────│
  │                            │  COMMIT               │                      │
  │                            │ ─────────────────────►│  COMMIT              │
  │                            │                       │ ────────────────────►│
  │                            │                       │                      │
  │                            │  log JSON event       │                      │
  │  Booking result            │                       │                      │
  │◄──────────────────────────│                       │                      │
```

### Cancel Booking

```
Client                    Apollo Server              Prisma                PostgreSQL
  │                            │                       │                      │
  │  cancelBooking(id)         │                       │                      │
  │ ──────────────────────────►│                       │                      │
  │                            │  find booking         │                      │
  │                            │ ─────────────────────►│  SELECT              │
  │                            │◄─────────────────────│◄────────────────────│
  │                            │                       │                      │
  │                            │  verify ACTIVE        │                      │
  │                            │                       │                      │
  │                            │  update status        │                      │
  │                            │ ─────────────────────►│  UPDATE SET          │
  │                            │                       │  status=CANCELED     │
  │                            │                       │  canceledAt=now()    │
  │                            │                       │ ────────────────────►│
  │                            │◄─────────────────────│◄────────────────────│
  │                            │                       │                      │
  │                            │  log JSON event       │                      │
  │  Booking result            │                       │                      │
  │◄──────────────────────────│                       │                      │
```

## Client Architecture

### Web (React)

```
App.tsx ── route ──┬── HotelsPage.tsx ── hotels list + rooms + Free/Busy badges
                   └── RoomPage.tsx   ── date inputs, availability, bookings, cancel

Shared:
├─ apolloClient.ts ── ApolloClient(HttpLink → localhost:4000/graphql, InMemoryCache)
├─ graphql.ts      ── GQL query/mutation documents (gql`...`)
├─ i18n.tsx        ── TranslationProvider context (EN/RU), useT() hook
├─ theme.tsx       ── ThemeProvider context (dark/light), CSS data-theme attribute
├─ index.css       ── CSS variables for light/dark, component styles
└─ App.css         ── layout, header bar styles
```

**Screens:**
- **HotelsPage** — запрашивает `hotels` query, для каждого номера проверяет `roomAvailability(today, tomorrow)`, отображает бейдж Free/Busy
- **RoomPage** — два `<input type="date">`, кнопки Check / Book, таблица броней с Cancel, обработка BOOKING_OVERLAP

### Flutter

```
main.dart ── GraphQLProvider + AppSettings(locale, theme) + MaterialApp
│
├── screens/
│   ├── hotels_screen.dart ── Hotels list, room tiles + Free/Busy badges,
│   │                         pull-to-refresh, locale/theme toggles
│   └── room_screen.dart   ── TableCalendar (range selection), availability
│                              state machine, create/cancel booking,
│                              conflict highlighting on calendar
├── api/
│   ├── client.dart            ── GraphQLClient with platform-aware URL:
│   │                             Android emu → 10.0.2.2:4000
│   │                             iOS/Desktop/Web → localhost:4000
│   │                             Override: --dart-define=API_URL=...
│   └── graphql_documents.dart ── GQL documents (hotelsQuery, roomBookingsQuery,
│                                  roomAvailabilityQuery, createBookingMutation,
│                                  cancelBookingMutation)
├── app_settings.dart ── InheritedWidget: locale (en/ru), themeMode (dark/light)
├── l10n.dart         ── Translation dictionary (25+ keys, EN/RU)
└── theme.dart        ── Material 3 themes (lightTheme, darkTheme)
```

**Room screen state machine:**
```
idle → selected → checkedAvailable → bookedSuccess
                → checkedConflict  → (re-select dates)
```

**Availability visualization on calendar:**
- `idle/selected` — синий выделение дат
- `checkedAvailable` — зелёный (свободно)
- `checkedConflict` — красный для конфликтных дней, синий для свободных
- `bookedSuccess` — тёмно-зелёный (забронировано)

**Platforms:** iOS, Android, Windows, macOS, Linux, Web — единая кодовая база.

## File Map

```
hotelBooking/
├── docker-compose.yml          # Orchestration: db + backend
├── README.md                   # Quick start, ports, sample queries
├── CLAUDE.md                   # Project spec & constraints
├── ARCHITECTURE.md             # This file
│
├── backend/
│   ├── Dockerfile              # node:20-alpine + openssl + prisma
│   ├── entrypoint.sh           # prisma db push → seed → start server
│   ├── package.json            # @apollo/server 4.11, @prisma/client 5.22,
│   │                           # graphql 16.9, tsx 4.19, typescript 5.7
│   ├── tsconfig.json
│   ├── prisma/
│   │   └── schema.prisma       # Hotel, Room, Booking models + indexes
│   └── src/
│       ├── index.ts            # Apollo standalone server startup (:4000)
│       ├── schema.ts           # GraphQL type definitions (SDL)
│       ├── resolvers.ts        # Query/Mutation logic + Date scalar
│       └── seed.ts             # 2 hotels, 6 rooms, 5 bookings + exclusion constraint
│
├── web/
│   ├── package.json            # react 19.2, @apollo/client 4.1, vite 7.2,
│   │                           # graphql 16.12, typescript 5.9
│   ├── .nvmrc                  # Node >= 20 (required by Vite 7)
│   ├── vite.config.ts
│   ├── index.html
│   └── src/
│       ├── main.tsx            # React root + ApolloProvider + ThemeProvider + i18n
│       ├── App.tsx             # Router: HotelsPage ↔ RoomPage, header bar
│       ├── apolloClient.ts     # HttpLink → localhost:4000/graphql + InMemoryCache
│       ├── graphql.ts          # GQL query/mutation documents
│       ├── HotelsPage.tsx      # Hotels list with rooms + Free/Busy badges
│       ├── RoomPage.tsx        # Room detail: dates, availability, bookings, cancel
│       ├── i18n.tsx            # TranslationProvider (EN/RU), useT() hook
│       ├── theme.tsx           # ThemeProvider (dark/light), CSS data-theme
│       ├── index.css           # Global styles, CSS variables, component styles
│       └── App.css             # Layout, header styles
│
└── flutter/
    ├── pubspec.yaml            # graphql_flutter 5.2.1, table_calendar 3.1.2,
    │                           # intl 0.20.2, Dart SDK ^3.10.8
    ├── lib/
    │   ├── main.dart           # GraphQLProvider + AppSettings + MaterialApp
    │   ├── app_settings.dart   # InheritedWidget: locale, themeMode
    │   ├── l10n.dart           # Translation dictionary (EN/RU)
    │   ├── theme.dart          # Material 3 light/dark themes
    │   ├── api/
    │   │   ├── client.dart     # Platform-aware GraphQL URL routing
    │   │   └── graphql_documents.dart  # GQL documents
    │   └── screens/
    │       ├── hotels_screen.dart  # Hotels grid + rooms + Free/Busy + refresh
    │       └── room_screen.dart    # Calendar, state machine, book/cancel
    ├── android/                # Android build config (Gradle)
    ├── ios/                    # iOS build config (Xcode)
    ├── windows/                # Windows desktop target (CMake)
    ├── macos/                  # macOS desktop target
    ├── linux/                  # Linux desktop target
    └── web/                    # Flutter web target
```

## Ports & Endpoints

| Service         | Internal Port | External Port | URL                                |
|-----------------|---------------|---------------|------------------------------------|
| PostgreSQL      | 5432          | 5433          | `postgresql://postgres:postgres@localhost:5433/minibooking` |
| Apollo Server   | 4000          | 4000          | `http://localhost:4000/graphql`    |
| React Web (dev) | 5173          | 5173          | `http://localhost:5173`            |

## Double Protection Against Overlaps

```
                    Application Layer              Database Layer
                    ─────────────────              ──────────────
createBooking() →  Serializable TX:              Exclusion Constraint:
                    SELECT conflicts              EXCLUDE USING gist
                    WHERE es < ne                  (roomId =,
                      AND ns < ee                   daterange(start,end) &&)
                      AND status=ACTIVE            WHERE status = 'ACTIVE'
                    if any → throw
                    BOOKING_OVERLAP               → 23P01 exclusion violation

                    Both layers must pass for INSERT to succeed
```

**Зачем два уровня?**
- Application layer — для user-friendly ошибки `BOOKING_OVERLAP` с деталями конфликтов
- DB constraint — safety net при race condition (два параллельных запроса)

## Error Handling

| Ситуация | Код | Описание |
|---|---|---|
| Некорректный диапазон дат (start >= end) | `BAD_USER_INPUT` | Валидация в resolvers |
| Невалидный формат даты | `BAD_USER_INPUT` | Date scalar parseValue/parseLiteral |
| Комната не найдена | `BAD_USER_INPUT` | Check в createBooking |
| Бронь не найдена | `BAD_USER_INPUT` | Check в cancelBooking |
| Бронь уже отменена | `BAD_USER_INPUT` | Check в cancelBooking |
| Пересечение дат | `BOOKING_OVERLAP` | Serializable TX check или DB constraint |

Все клиенты (Web, Flutter) парсят `extensions.code` из GraphQL ошибки и отображают user-friendly сообщение.

## Logging

Операции create/cancel логируются в stdout как JSON:

```json
{"event":"booking_created","bookingId":"...","roomId":"...","startDate":"YYYY-MM-DD","endDate":"YYYY-MM-DD","ts":"ISO"}
{"event":"booking_canceled","bookingId":"...","ts":"ISO"}
```

## Architectural Decisions & Trade-offs

| Решение | Альтернатива | Причина выбора |
|---|---|---|
| PostgreSQL + exclusion constraint | SQLite + BEGIN IMMEDIATE | Гарантия целостности на уровне БД, невозможность race condition |
| Relative seed dates (today ± N) | Hardcoded dates | Seed всегда актуален при демо, Free/Busy корректно при любом запуске |
| Half-open intervals [start, end) | Closed intervals [start, end] | Смежные брони не конфликтуют, стандартная модель для бронирований |
| Единая Flutter кодовая база | Отдельный Windows app | Меньше кода, одинаковый UX, Windows = тот же app через flutter run -d windows |
| Apollo Client 4 + HttpLink | REST / fetch | Типизированные запросы, кэш, единый контракт |
| Prisma ORM | Raw SQL | Быстрая разработка, типобезопасность, миграции |
| InheritedWidget (Flutter) | Provider / Riverpod | Минимум зависимостей, достаточно для locale/theme |
| CSS variables (Web) | CSS-in-JS / Tailwind | Простота, нативная поддержка тем без доп. библиотек |
| setState + Query widgets | BLoC / Redux | Минимальная сложность для MVP, достаточно для 2 экранов |
