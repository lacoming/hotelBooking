# Architecture Rationale — Mini Booking System

## Резюме (10 строк)

Проект Mini Booking — трёхуровневый вертикальный срез: Backend (Node.js + Apollo Server 4 + Prisma 5 + PostgreSQL 16), Web (React 19 + Apollo Client 4 + Vite 7), Flutter (mobile iOS/Android + desktop Windows/macOS/Linux). GraphQL контракт заморожен и един для всех клиентов. Основная бизнес-задача — предотвращение пересечения бронирований — решена двойной защитой: Serializable-транзакция в приложении + exclusion constraint (btree_gist) в Postgres. Все даты — календарные (YYYY-MM-DD), интервалы полуоткрытые [start, end). Каждый слой минимален: бэкенд — 4 файла, веб — 6 файлов, Flutter — 5 файлов. Docker Compose поднимает Postgres + бэкенд одной командой. Seed-данные идемпотентны (upsert + фиксированные ID). Основной долг: отсутствует Windows Light Widget (overview «Free/Busy today»), нет промежуточного экрана RoomsScreen во Flutter, seed-даты в 2025 вместо 2026.

---

## 1. Технологический стек по слоям

### 1.1 Backend

| Технология | Версия | Файлы |
|---|---|---|
| Node.js | 20 (Alpine) | `backend/Dockerfile` |
| TypeScript | 5.7 | `backend/tsconfig.json` |
| Apollo Server | 4.11 (standalone) | `backend/src/index.ts` |
| Prisma ORM | 5.22 | `backend/prisma/schema.prisma` |
| PostgreSQL | 16 (Alpine) | `docker-compose.yml` |
| tsx | 4.19 | `backend/package.json` (dev runner) |

**Почему именно этот набор:**

**Apollo Server 4 (standalone mode):**
1. Единый GraphQL-эндпоинт без Express/Fastify — меньше кода и зависимостей для прототипа.
2. Встроенный Apollo Sandbox (playground) — мгновенная проверка API без внешних инструментов.
3. `startStandaloneServer` — 5 строк для запуска сервера (`backend/src/index.ts:7-11`).
4. Экосистема Apollo хорошо документирована и совместима с Apollo Client на вебе.

*Отклонённые альтернативы:*
- **Express + apollo-server-express**: лишний слой middleware; не нужен, т.к. нет REST-эндпоинтов, auth, CORS-хаков.
- **Fastify + mercurius**: быстрее по throughput, но меньше tooling из коробки; overhead не критичен при 2 мутациях.
- **Yoga (GraphQL Yoga)**: легче Apollo, но Apollo Client 4 на вебе лучше интегрирован с Apollo Server.

*Цена/выгода:* минимальный boilerplate (1 файл index.ts), мгновенный playground. Цена — связка с экосистемой Apollo; при масштабировании потребуется Express для middleware.

---

**Prisma 5:**
1. Type-safe клиент генерируется из schema.prisma — ошибки ловятся на этапе компиляции.
2. `$transaction` с настраиваемым isolation level — ключевая фича для Serializable TX (`backend/src/resolvers.ts:108`).
3. `prisma db push` — быстрая синхронизация схемы без файлов миграций (удобно для прототипа).
4. `$executeRawUnsafe` — позволяет создавать exclusion constraint, который Prisma не поддерживает декларативно.

*Отклонённые альтернативы:*
- **Drizzle ORM**: более лёгкий, ближе к SQL, но нет `$transaction` с isolation levels из коробки.
- **Knex.js**: голый query builder — больше ручного кода, нет type-safety из схемы.
- **TypeORM**: тяжелее, decorator-based, менее предсказуемое поведение миграций.
- **Raw pg (node-postgres)**: максимальный контроль, но вся type-safety вручную.

*Цена/выгода:* быстрая разработка + type-safety + transaction isolation. Цена — Prisma не поддерживает exclusion constraints нативно (обходим через raw SQL в seed), и Alpine требует ручной установки openssl.

---

**PostgreSQL 16 (vs SQLite):**
1. Exclusion constraint (`EXCLUDE USING gist`) — *единственная* СУБД с нативной поддержкой проверки пересечения интервалов на уровне БД.
2. Настоящий Serializable isolation level (SSI), а не только `BEGIN IMMEDIATE` как в SQLite.
3. Тип `DATE` без time-зоны — идеально для календарных дат.
4. Docker-friendly: postgres:16-alpine с healthcheck работает предсказуемо.

*Отклонённые альтернативы:*
- **SQLite**: проще (один файл), но нет exclusion constraints → вся защита от overlap только в приложении; `BEGIN IMMEDIATE` — грубая блокировка, не SSI.
- **MySQL/MariaDB**: нет exclusion constraints, GiST индексов; daterange type отсутствует.

*Цена/выгода:* максимальная корректность overlap-проверки на уровне БД. Цена — нужен Docker для PostgreSQL; порт 5432 часто занят (поэтому маппим на 5433 снаружи).

---

**tsx 4.19 (вместо ts-node / tsc+node):**
1. Нулевая конфигурация: запускает .ts файлы напрямую через esbuild.
2. Режим `watch` для dev-разработки (`"dev": "tsx watch src/index.ts"`).
3. Поддержка ESM (`"module": "ESNext"` в tsconfig) без лишних флагов.

*Цена/выгода:* мгновенный запуск без шага сборки. Цена — runtime overhead esbuild (пренебрежимо для сервера с 2 мутациями).

---

### 1.2 Web (React)

| Технология | Версия | Файлы |
|---|---|---|
| React | 19.2 | `web/src/main.tsx` |
| TypeScript | 5.9 | `web/tsconfig.app.json` |
| Vite | 7.2 | `web/vite.config.ts` |
| Apollo Client | 4.1 | `web/src/apolloClient.ts` |

**Почему именно этот набор:**

**React 19:**
1. ТЗ явно требует React + TypeScript.
2. React 19 стабилен, совместим с Apollo Client 4.
3. Минимальная структура: 2 страницы, без router (навигация через useState).

*Отклонённые альтернативы:*
- **Next.js / Remix**: SSR/SSG не нужен для SPA-прототипа; добавляет сложность маршрутизации.
- **Svelte / Vue**: отклонено по ТЗ (явно React).

---

**Apollo Client 4:**
1. Нативная интеграция с Apollo Server (единый GraphQL ecosystem).
2. `useQuery` / `useMutation` / `useLazyQuery` — декларативное управление данными.
3. `InMemoryCache` — автоматическое кэширование по `__typename:id`.
4. `fetchPolicy: "network-only"` для availability-запросов — гарантирует свежие данные.

*Важный нюанс Apollo Client 4:*
- React-хуки перенесены в `@apollo/client/react` (не `@apollo/client`).
- Конструктор требует `link: new HttpLink({uri})` вместо прямого `uri`.

*Отклонённые альтернативы:*
- **urql**: легче, но менее документирован для error handling с extensions.code.
- **graphql-request**: нет кэширования и React-хуков из коробки.
- **TanStack Query + graphql-request**: мощнее, но overengineering для 5 операций.

---

**Vite 7:**
1. Мгновенный HMR (< 100ms на изменение файла).
2. Нулевая конфигурация для React + TS (`@vitejs/plugin-react` + 1 строка).
3. Стандарт де-факто для React SPA в 2025–2026.

*Требование:* Node >= 20.19 (`.nvmrc` установлен).

*Отклонённые альтернативы:*
- **Create React App**: deprecated, медленный webpack.
- **Webpack manual config**: тяжёлый, не оправдан для прототипа.

---

### 1.3 Flutter

| Технология | Версия | Файлы |
|---|---|---|
| Flutter SDK | >= 3.38 | `flutter/pubspec.yaml` |
| Dart | >= 3.10.8 | `flutter/pubspec.yaml` |
| graphql_flutter | 5.2.1 | `flutter/lib/api/client.dart` |

**Почему именно этот набор:**

**graphql_flutter 5.2.1:**
1. ТЗ рекомендует `graphql_flutter` как «fastest» вариант.
2. Декларативные виджеты `Query` и `Mutation` — минимум boilerplate.
3. Встроенный `GraphQLProvider` + `ValueNotifier<GraphQLClient>` — аналог ApolloProvider.
4. Также поддерживает императивный вызов через `GraphQLProvider.of(context).value.query(...)`.

*Отклонённые альтернативы:*
- **ferry**: code generation, type-safe — мощнее, но дольше настраивать.
- **graphql (без flutter)**: только низкоуровневый клиент, нужны свои виджеты.
- **artemis**: code-gen подход, overkill для прототипа с 5 операциями.
- **dio + REST**: нарушает ТЗ (GraphQL required).

---

**setState (без state management):**
1. ТЗ явно допускает: «Keep state simple: setState + Query widgets is acceptable».
2. Только 2 экрана, только локальный UI-стейт (выбранные даты, сообщения, результат availability).
3. Серверный стейт управляется `Query` виджетами (refetch после мутаций).

*Отклонённые альтернативы:*
- **Provider / Riverpod**: добавляют слой абстракции без выгоды при 2 экранах.
- **Bloc / Cubit**: event-driven — overengineering для формы с 2 datepickers.
- **GetX**: контроверсиальная архитектура, не подходит для портфолио.

---

**API_URL конфигурация (`flutter/lib/api/client.dart`):**

Трёхуровневый fallback:
1. `--dart-define=API_URL=http://192.168.x.x:4000/graphql` — compile-time override для реальных устройств.
2. Платформенная детекция: Android emulator → `10.0.2.2:4000`, всё остальное → `localhost:4000`.
3. `kIsWeb` проверяется первым (Web Flutter → localhost).

*Почему не env vars / .env файл:*
- Dart/Flutter не читает process.env. `--dart-define` — стандартный механизм конфигурации при компиляции.
- Альтернатива `flutter_dotenv` добавляет runtime-чтение файла, но для одного URL это overengineering.

---

### 1.4 Инфраструктура

| Технология | Файлы |
|---|---|
| Docker Compose | `docker-compose.yml` |
| PostgreSQL 16 Alpine | `docker-compose.yml` service `db` |
| Node 20 Alpine | `backend/Dockerfile` |

**Архитектура Docker:**
- 2 сервиса: `db` (Postgres) + `backend` (Apollo Server).
- Healthcheck на `db` (`pg_isready`) → `backend` стартует только когда БД готова.
- `entrypoint.sh`: `prisma db push` → `seed.ts` → `index.ts` (последовательно).
- Named volume `pgdata` — данные переживают `docker compose down` (но не `down -v`).
- Порт 5433 снаружи (5432 часто занят на dev-машине).

*Что НЕ в Docker:*
- Web (React) — запускается локально через `npm run dev` на :5173.
- Flutter — компилируется нативно, не имеет смысла в Docker.

---

## 2. Архитектура кода

### 2.1 Backend: бизнес-логика overlap

**Где хранится:** `backend/src/resolvers.ts`, функция `overlapWhere()` (строка ~30) и мутация `createBooking` (строка ~80).

**Алгоритм проверки пересечения:**

```
Новый интервал [ns, ne) пересекается с существующим [es, ee) если:
  es < ne AND ns < ee

В Prisma WHERE:
  startDate: { lt: toDate(endDate) }    ← es < ne
  endDate:   { gt: toDate(startDate) }  ← ns < ee (т.е. ee > ns)
  status:    BookingStatus.ACTIVE
```

**Двойная защита от race conditions:**

| Уровень | Механизм | Файл:строка | Что делает |
|---|---|---|---|
| Приложение | Serializable TX | `resolvers.ts:108-130` | `prisma.$transaction(fn, { isolationLevel: "Serializable" })` — SELECT + INSERT в одной транзакции; PostgreSQL SSI детектирует read-write конфликты |
| БД | Exclusion constraint | `seed.ts:11-26` | `EXCLUDE USING gist (roomId =, daterange(startDate, endDate) &&) WHERE (status = 'ACTIVE')` — Postgres отклоняет INSERT даже если приложение пропустило overlap |

**Почему именно Serializable (а не Read Committed + row lock):**
- Read Committed + `SELECT ... FOR UPDATE` не спасает от phantom reads (новые строки, вставленные параллельной TX между SELECT и INSERT).
- Serializable (SSI) в PostgreSQL гарантирует, что результат эквивалентен последовательному выполнению. Если две TX одновременно проверяют overlap и обе видят «пусто», одна из них получит serialization failure при COMMIT.
- Exclusion constraint — дополнительная страховка: даже при баге в приложении, Postgres не пропустит пересечение.

**Обработка ошибок constraint:**
```
resolvers.ts:144-154:
  catch (err) →
    if GraphQLError → re-throw
    if Prisma P2010 (exclusion violation) → throw BOOKING_OVERLAP
    else → throw err
```

**Логирование:**
```
resolvers.ts:132-140 (create):  { event: "booking_created", bookingId, roomId, startDate, endDate, ts }
resolvers.ts:170-175 (cancel):  { event: "booking_canceled", bookingId, ts }
```

---

### 2.2 Web: структура компонентов и Apollo Client

**Навигация** (`web/src/App.tsx`):
- Без react-router. Один `useState<{id, name} | null>` переключает между `HotelsPage` и `RoomPage`.
- Обоснование: всего 2 экрана, URL-навигация не требуется, экономия на зависимости.

**Apollo Client** (`web/src/apolloClient.ts`):
- Singleton `ApolloClient` с `HttpLink` → `http://localhost:4000/graphql`.
- `InMemoryCache` без custom type policies (хватает дефолтного `__typename:id`).
- Нет Error Link, Retry Link, Auth headers — не нужны для прототипа без авторизации.

**Обработка ошибок** (`web/src/RoomPage.tsx:62-75`):
```
Создание бронирования → catch →
  graphQLErrors.find(e.extensions.code === "BOOKING_OVERLAP")
    → "Dates overlap with an existing booking!"
  else
    → err.message (generic)
```

Этот паттерн — явная проверка `extensions.code` — соответствует GraphQL контракту из CLAUDE.md.

**Паттерн данных:**
- `useQuery(GET_ROOM_BOOKINGS)` — eagerly fetch при монтировании, `refetch` после мутаций.
- `useLazyQuery(CHECK_AVAILABILITY, { fetchPolicy: "network-only" })` — по кнопке, всегда с сервера.
- `useMutation(CREATE_BOOKING / CANCEL_BOOKING)` — fire-and-forget с catch.

---

### 2.3 Flutter: конфигурация и state management

**API URL** (`flutter/lib/api/client.dart:13-26`):
```dart
String get apiUrl {
  if (_override.isNotEmpty) return _override;     // --dart-define
  if (kIsWeb) return 'http://localhost:4000/...';  // Web Flutter
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:4000/...';            // Android emu
  }
  return 'http://localhost:4000/...';              // iOS/desktop
}
```

Это compile-time решение. `String.fromEnvironment('API_URL')` — const-выражение, вычисляется при AOT-компиляции.

**Почему setState, а не Provider/Bloc:**
1. `HotelsScreen` — Stateless, данные из `Query` виджета.
2. `RoomScreen` — StatefulWidget, но весь стейт локальный:
   - `_startDate`, `_endDate` — выбранные даты
   - `_availabilityResult` — результат проверки
   - `_actionMessage` — feedback пользователю
3. Нет shared state между экранами. При возврате с RoomScreen на HotelsScreen данные refetch-ятся.
4. `mounted` проверяется перед каждым `setState` после async-операций — корректная обработка lifecycle.

**BOOKING_OVERLAP в Flutter** (`flutter/lib/screens/room_screen.dart`):
```dart
for (final e in result.exception!.graphqlErrors) {
  if (e.extensions?['code'] == 'BOOKING_OVERLAP') {
    // показать "Dates overlap with an existing booking."
  }
}
```

---

## 3. Соответствие ТЗ (CLAUDE.md)

### 3.1 Backend

| # | Требование | Статус | Где реализовано |
|---|---|---|---|
| B1 | Node.js + Apollo GraphQL (TypeScript) | Done | `backend/src/index.ts`, `backend/package.json` |
| B2 | Storage: PostgreSQL | Done | `docker-compose.yml`, `backend/prisma/schema.prisma` |
| B3 | Query: list hotels + rooms | Done | `backend/src/resolvers.ts` → `Query.hotels` |
| B4 | Query: room availability for date range | Done | `backend/src/resolvers.ts` → `Query.roomAvailability` |
| B5 | Mutation: create booking | Done | `backend/src/resolvers.ts` → `Mutation.createBooking` |
| B6 | Mutation: cancel booking | Done | `backend/src/resolvers.ts` → `Mutation.cancelBooking` |
| B7 | Query: list bookings (optionally filter by range) | Done | `backend/src/resolvers.ts` → `Query.roomBookings` (from/to optional) |
| B8 | Query: hotel(id) | Done | `backend/src/resolvers.ts` → `Query.hotel` |
| B9 | Query: room(id) | Done | `backend/src/resolvers.ts` → `Query.room` |
| B10 | Seed: 2 hotels | Done | `backend/src/seed.ts` → hotel-1, hotel-2 |
| B11 | Seed: several rooms per hotel | Done | `backend/src/seed.ts` → 3 rooms each (6 total) |
| B12 | Seed: several bookings + conflict scenario | Done | `backend/src/seed.ts` → 5 bookings, bk-1 overlaps demo range |
| B13 | Validation: startDate < endDate | Done | `backend/src/resolvers.ts` → createBooking + roomAvailability |
| B14 | Validation: max range 365 days (optional) | **Not done** | Не реализовано (ТЗ говорит «optional») |
| B15 | Error: BAD_USER_INPUT | Done | `backend/src/resolvers.ts` → Date scalar, createBooking, cancelBooking |
| B16 | Error: BOOKING_OVERLAP | Done | `backend/src/resolvers.ts` → createBooking (app + constraint catch) |
| B17 | Logging: JSON on create/cancel | Done | `backend/src/resolvers.ts` → console.log JSON |
| B18 | Atomicity: exclusion constraint / serializable TX | Done | `backend/src/seed.ts` (constraint) + `resolvers.ts` (Serializable TX) |
| B19 | GraphQL contract matches spec exactly | Done | `backend/src/schema.ts` — все типы/запросы/мутации совпадают |

### 3.2 Web (React)

| # | Требование | Статус | Где реализовано |
|---|---|---|---|
| W1 | List hotels/rooms | Done | `web/src/HotelsPage.tsx` |
| W2 | Room detail: bookings list | Done | `web/src/RoomPage.tsx` → таблица bookings |
| W3 | Room detail: create booking | Done | `web/src/RoomPage.tsx` → handleBook |
| W4 | Room detail: cancel booking | Done | `web/src/RoomPage.tsx` → handleCancel |
| W5 | Show overlap errors clearly | Done | `web/src/RoomPage.tsx:62-75` → red message "Dates overlap..." |

### 3.3 Flutter Mobile

| # | Требование | Статус | Где реализовано |
|---|---|---|---|
| F1 | Navigation: Hotels -> Rooms -> Room | **Partial** | `hotels_screen.dart` → `room_screen.dart` (нет промежуточного RoomsScreen; комнаты встроены в карточки отелей) |
| F2 | Room screen: choose date range | Done | `room_screen.dart` → `showDatePicker` x2 |
| F3 | Room screen: check availability | Done | `room_screen.dart` → `_checkAvailability()` |
| F4 | Room screen: create booking | Done | `room_screen.dart` → `_createBooking()` |
| F5 | Room screen: cancel booking from list | Done | `room_screen.dart` → `_cancelBooking()` + `_BookingsList` |
| F6 | GraphQL integration (graphql_flutter) | Done | `api/client.dart`, `api/graphql_documents.dart` |
| F7 | Show overlap errors | Done | `room_screen.dart` → проверка `extensions['code'] == 'BOOKING_OVERLAP'` |

### 3.4 Flutter Windows Light

| # | Требование | Статус | Где реализовано |
|---|---|---|---|
| FW1 | Overview: hotels + rooms status «Free/Busy today» | **Not done** | Нет виджета, определяющего «сегодня в рамках бронирования» |
| FW2 | Refresh button | Done | `hotels_screen.dart` → `RefreshIndicator` (pull-to-refresh) |
| FW3 | At least one detail view | Done | `room_screen.dart` работает на десктопе |
| FW4 | Windows build scaffold | Done | `flutter/windows/` — CMakeLists.txt, runner, 1280x720 |

### 3.5 Docker / Reproducibility

| # | Требование | Статус | Где реализовано |
|---|---|---|---|
| D1 | docker-compose.yml starts backend + DB | Done | `docker-compose.yml` |
| D2 | README: docker compose up --build | Done | `README.md` |
| D3 | README: ports + URLs | Done | `README.md` → таблица портов |
| D4 | README: GraphQL endpoint + playground | Done | `README.md` → Apollo Sandbox |
| D5 | README: quick test queries/mutations | Done | `README.md` → 5 примеров |

### 3.6 Quality Gates

| # | Гейт | Статус | Примечание |
|---|---|---|---|
| QG1 | create booking works | Done | Серверная + UI проверка |
| QG2 | overlap fails with BOOKING_OVERLAP | Done | App + constraint двойная защита |
| QG3 | cancel sets CANCELED | Done | `resolvers.ts` → update status |
| QG4 | after cancel, same range works | Done | Constraint WHERE status='ACTIVE' |
| QG5 | Web UI create/cancel + overlap errors | Done | `RoomPage.tsx` |
| QG6 | Flutter mobile create/cancel + overlap | Done | `room_screen.dart` |
| QG7 | Windows overview + refresh + detail | **Partial** | Нет «Free/Busy today» в overview |
| QG8 | Fresh clone + compose run = README | Done | backend в Docker, web/flutter локально |

### 3.7 Demo Video Checklist

| # | Сценарий | Готов к демо? |
|---|---|---|
| DV1 | docker compose up --build | Yes |
| DV2 | GraphQL playground: list, availability, create, overlap, cancel | Yes |
| DV3 | Mobile: Hotels → Room → book → overlap → cancel | Yes |
| DV4 | Web: list → room → create/cancel | Yes |
| DV5 | Windows: overview → refresh → detail | **Partial** (нет Free/Busy статуса) |

---

## 4. TODO на сегодня (приоритеты)

### P0 — Блокеры для демо-видео

| # | Задача | Описание | Оценка |
|---|---|---|---|
| P0-1 | **Windows Light Widget: Free/Busy today** | Добавить на `HotelsScreen` (или новый `OverviewScreen`) колонку/badge для каждой комнаты: определить, попадает ли `today` в `[startDate, endDate)` любого ACTIVE booking. Нужен новый GQL-запрос или использовать `roomAvailability(from: today, to: tomorrow)`. | ~30 мин |
| P0-2 | **Обновить seed-даты на 2026** | Текущие даты в seed (2025-06-xx) в прошлом → «Free/Busy today» всегда будет «Free». Нужно перенести минимум 1-2 бронирования на текущий диапазон (февраль 2026), чтобы демо показало «Busy today». | ~10 мин |

### P1 — Важно, но не блокирует демо

| # | Задача | Описание |
|---|---|---|
| P1-1 | **Промежуточный RoomsScreen (Flutter)** | ТЗ явно упоминает 3 экрана: Hotels → Rooms → Room. Сейчас комнаты встроены в HotelsScreen. Можно добавить отдельный экран списка комнат при нажатии на отель. |
| P1-2 | **Валидация max range 365 дней (backend)** | ТЗ говорит «optional», но если останется время — добавить `if (daysDiff > 365) throw BAD_USER_INPUT`. |
| P1-3 | **Кнопка Refresh на Windows** | `RefreshIndicator` (pull-to-refresh) неудобен на десктопе. Добавить `IconButton(onPressed: refetch)` в AppBar для десктопа. |
| P1-4 | **Client-side валидация startDate < endDate (Web)** | Сейчас проверяется только на бэкенде. Добавить клиентскую проверку перед отправкой запроса для лучшего UX. |

---

## 5. Предложения по улучшению архитектуры

| # | Улучшение | Выгода | Делать сейчас? |
|---|---|---|---|
| 1 | **GraphQL codegen (graphql-codegen для web, ferry для Flutter)** | Type-safe хуки, автогенерация типов из schema — ловить ошибки при компиляции, а не в runtime. | **Нет** — protype с 5 операциями не оправдывает overhead настройки codegen. Делать при росте API. |
| 2 | **Apollo Error Link + Retry Link (web)** | Автоматический retry при network errors, централизованная обработка ошибок вместо try/catch в каждом handler. | **Нет** — для 2 мутаций текущий подход достаточен. Делать при добавлении auth/retry логики. |
| 3 | **DataLoader для N+1 (backend)** | `Hotel.rooms` и `Room.bookings` делают отдельный SQL-запрос на каждый элемент списка. DataLoader batch-ит запросы. | **Нет** — при 2 отелях и 6 комнатах N+1 не ощущается. Делать при > 50 записях. |
| 4 | **Pagination (cursor-based) для bookings** | При большом количестве бронирований `roomBookings` вернёт слишком много данных. | **Нет** — seed содержит 5 записей. Делать при > 100 бронирований на комнату. |
| 5 | **React Router + URL state** | Позволит deep-linking (открыть конкретную комнату по URL), кнопка Back в браузере. | **Можно** — низкий effort (~20 мин), улучшает UX. Но не блокирует демо, поэтому только если останется время. |

---

## Приложение: Порты и URL

| Сервис | Внутренний | Внешний | URL |
|---|---|---|---|
| PostgreSQL | 5432 | 5433 | `postgresql://postgres:postgres@localhost:5433/minibooking` |
| Apollo Server | 4000 | 4000 | `http://localhost:4000/graphql` |
| React Web (dev) | 5173 | 5173 | `http://localhost:5173` |
| Flutter Android emu | — | — | API: `http://10.0.2.2:4000/graphql` |
| Flutter iOS sim / desktop | — | — | API: `http://localhost:4000/graphql` |
