# Mini Booking

Hotel room booking system with GraphQL API, overlap protection, and PostgreSQL.

## Quick Start

```bash
docker compose up --build
```

Server: http://localhost:4000/graphql (Apollo Sandbox)

## Architecture

- **Backend**: Node.js + TypeScript + Apollo Server 4
- **DB**: PostgreSQL 16 with exclusion constraint (`daterange` + `btree_gist`)
- **ORM**: Prisma
- **Date model**: calendar dates `YYYY-MM-DD`, half-open intervals `[startDate, endDate)`
- **Anti-race**: Serializable transaction + DB exclusion constraint

## Seed Data

| Hotel        | Rooms               |
|-------------|---------------------|
| Grand Hotel | 101 (cap 2), 102 (cap 3), 103 (cap 1) |
| Beach Resort| A1 (cap 4), A2 (cap 2), A3 (cap 3)    |

Bookings:
- `bk-1`: Room 101, 2025-06-01 → 2025-06-05, ACTIVE
- `bk-2`: Room 101, 2025-06-10 → 2025-06-15, ACTIVE
- `bk-3`: Room 102, 2025-06-03 → 2025-06-07, ACTIVE
- `bk-4`: Room A1, 2025-06-01 → 2025-06-06, ACTIVE
- `bk-5`: Room A1, 2025-06-01 → 2025-06-04, CANCELED (overlap OK — canceled)

## GraphQL Examples

### 1. List Hotels with Rooms

```graphql
query {
  hotels {
    id
    name
    rooms {
      id
      name
      capacity
    }
  }
}
```

### 2. Check Availability (shows conflicts)

```graphql
query {
  roomAvailability(roomId: "room-101", from: "2025-06-03", to: "2025-06-07") {
    available
    conflicts {
      id
      startDate
      endDate
      status
    }
  }
}
```

Expected: `available: false`, one conflict (`bk-1`: 2025-06-01 → 2025-06-05).

### 3. Create Booking — OVERLAP error

```graphql
mutation {
  createBooking(input: {
    roomId: "room-101"
    startDate: "2025-06-03"
    endDate: "2025-06-07"
  }) {
    id
    startDate
    endDate
  }
}
```

Expected error: `extensions.code = "BOOKING_OVERLAP"`.

### 4. Create Booking — success (no conflict)

```graphql
mutation {
  createBooking(input: {
    roomId: "room-101"
    startDate: "2025-06-06"
    endDate: "2025-06-09"
  }) {
    id
    startDate
    endDate
    status
  }
}
```

Expected: new booking created, `status: ACTIVE`.

### 5. Cancel Booking

```graphql
mutation {
  cancelBooking(id: "bk-1") {
    id
    status
    canceledAt
  }
}
```

Expected: `status: CANCELED`, `canceledAt` set.

## Ports

| Service  | Port |
|----------|------|
| GraphQL  | 4000 |
| Postgres | 5433 (host) → 5432 (container) |

## Web Client (React)

**Requires Node.js >= 20** (Vite 7 + Apollo Client 4).

```bash
nvm use 20        # or any Node >= 20
cd web
npm install
npm run dev
```

Opens at http://localhost:5173. Requires backend running on port 4000.

Features:
- Hotels list with rooms
- Room detail: check availability, create/cancel bookings
- Overlap errors shown inline

## Cleanup

```bash
docker compose down -v
```
