# Architecture — Mini Booking System

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            CLIENTS                                      │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │   React Web      │  │  Flutter Mobile   │  │  Flutter Desktop     │  │
│  │   (Vite + TS)    │  │  (iOS / Android)  │  │  (Windows)           │  │
│  │   :5173          │  │                   │  │                      │  │
│  │                  │  │                   │  │                      │  │
│  │  Apollo Client 4 │  │  graphql_flutter  │  │  graphql_flutter     │  │
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

## Seed Data

```
Grand Hotel (hotel-1)                Beach Resort (hotel-2)
├── Room 101 (room-101)              ├── Room A1 (room-a1)
│   ├── bk-1: Jun 1–5   ACTIVE      │   ├── bk-4: Jun 1–6   ACTIVE
│   └── bk-2: Jun 10–15 ACTIVE      │   └── bk-5: Jun 1–4   CANCELED
├── Room 102 (room-102)              ├── Room A2 (room-a2)
│   └── bk-3: Jun 3–7   ACTIVE      └── Room A3 (room-a3)
└── Room 103 (room-103)

Overlap demo: try booking room-101 for Jun 12–13 → BOOKING_OVERLAP
Adjacent ok:  booking room-101 for Jun 5–7 → success (half-open [5,7) after [1,5))
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

## File Map

```
hotelBooking/
├── docker-compose.yml          # Orchestration: db + backend services
├── README.md                   # Quick start, ports, sample queries
├── CLAUDE.md                   # Project spec & constraints
│
├── backend/
│   ├── Dockerfile              # node:20-alpine + openssl + prisma
│   ├── entrypoint.sh           # prisma db push → seed → start server
│   ├── package.json            # apollo-server, prisma, graphql, tsx
│   ├── tsconfig.json
│   ├── prisma/
│   │   └── schema.prisma       # Hotel, Room, Booking models
│   └── src/
│       ├── index.ts            # Apollo standalone server startup (:4000)
│       ├── schema.ts           # GraphQL type definitions (SDL)
│       ├── resolvers.ts        # Query/Mutation logic + Date scalar
│       └── seed.ts             # 2 hotels, 6 rooms, 5 bookings + exclusion constraint
│
├── web/
│   ├── package.json            # react 19, apollo-client 4, vite 7
│   ├── vite.config.ts
│   ├── index.html
│   └── src/
│       ├── main.tsx            # React root + ApolloProvider
│       ├── App.tsx             # Router: HotelsPage ↔ RoomPage
│       ├── apolloClient.ts     # HttpLink → localhost:4000/graphql
│       ├── graphql.ts          # GQL query/mutation documents
│       ├── HotelsPage.tsx      # Hotels list with rooms
│       └── RoomPage.tsx        # Room detail: dates, availability, bookings
│
└── flutter/
    ├── pubspec.yaml            # graphql_flutter 5.2.1
    └── lib/
        ├── main.dart           # GraphQLProvider + MaterialApp
        ├── api/
        │   ├── client.dart     # URL resolution (Android emu / iOS / desktop)
        │   └── graphql_documents.dart  # GQL documents
        └── screens/
            ├── hotels_screen.dart  # Hotels grid + pull-to-refresh
            └── room_screen.dart    # Date pickers, availability, bookings
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
