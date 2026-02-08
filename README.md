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

## Clients

| Client           | URL / Port                | Run command                          |
|-----------------|---------------------------|--------------------------------------|
| Backend GraphQL  | http://localhost:4000/graphql | `docker compose up --build`        |
| Web (React)      | http://localhost:5173      | `cd web && npm install && npm run dev` |
| Flutter (Chrome) | http://localhost:8080      | `cd flutter && flutter run -d chrome --web-port=8080` |
| Flutter (Windows)| native window             | `cd flutter && flutter run -d windows` |
| PostgreSQL       | localhost:5433 (host)      | via docker-compose                   |

## Seed Data

Seed uses **relative dates** (today ± offset), so data is always relevant regardless of when you start the server.

| ID   | Room | Start    | End      | Status   | Note                      |
|------|------|----------|----------|----------|---------------------------|
| bk-1 | 101  | today−2  | today+3  | ACTIVE   | Covers today → room Busy  |
| bk-2 | 101  | today+5  | today+10 | ACTIVE   | Future booking            |
| bk-3 | 102  | today−1  | today+2  | ACTIVE   | Covers today → room Busy  |
| bk-4 | A1   | today    | today+5  | ACTIVE   | Covers today → room Busy  |
| bk-5 | A1   | today−3  | today+1  | CANCELED | No conflict (canceled)    |

**Busy today**: room-101 (bk-1), room-102 (bk-3), room-a1 (bk-4)
**Free today**: room-103, room-a2, room-a3

> **Tip:** The server prints actual dates on startup. Look for the `Seed complete` log line.

## GraphQL Examples

> **Note:** Replace dates below with actual values based on today's date.
> For example, if today is `2026-02-08`:
> - `TODAY` = `2026-02-08`
> - `TODAY+1` = `2026-02-09`
> - `TODAY+4` = `2026-02-12`

### 1. List Hotels with Rooms

```graphql
query {
  hotels {
    id
    name
    rooms { id name capacity }
  }
}
```

### 2. Check Availability (expect conflict — room-101 is busy today)

```graphql
# Use TODAY and TODAY+1 (room-101 has bk-1 covering today)
query {
  roomAvailability(roomId: "room-101", from: "TODAY", to: "TODAY+1") {
    available
    conflicts { id startDate endDate status }
  }
}
```

Expected: `available: false`, conflict `bk-1`.

### 3. Create Booking — OVERLAP error

```graphql
# Room-101 is busy from today-2 to today+3
mutation {
  createBooking(input: {
    roomId: "room-101"
    startDate: "TODAY"
    endDate: "TODAY+4"
  }) { id startDate endDate }
}
```

Expected error: `extensions.code = "BOOKING_OVERLAP"`.

### 4. Create Booking — success (free room)

```graphql
# Room-103 has no bookings
mutation {
  createBooking(input: {
    roomId: "room-103"
    startDate: "TODAY"
    endDate: "TODAY+3"
  }) { id startDate endDate status }
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
- Light/Dark theme toggle, EN/RU language switch

## Flutter Mobile (iOS/Android)

**Requires Flutter SDK >= 3.38** (Dart 3.10).

```bash
cd flutter
flutter pub get
flutter run
```

### Navigation Flow

**Mobile/Web**: Hotels → Rooms → Room (3-step navigation)
**Desktop (Windows/macOS/Linux)**: Overview (all hotels + rooms status) → Room

### API URL Configuration

The app auto-detects the platform and uses the appropriate URL:

| Platform         | URL                                      | Command                                                              |
|-----------------|------------------------------------------|----------------------------------------------------------------------|
| Android emulator | `http://10.0.2.2:4000/graphql`          | `flutter run` (default)                                              |
| iOS simulator    | `http://localhost:4000/graphql`          | `flutter run` (auto-detected)                                        |
| Chrome (web)     | `http://localhost:4000/graphql`          | `flutter run -d chrome --web-port=8080`                              |
| Windows/macOS    | `http://localhost:4000/graphql`          | `flutter run -d windows` / `flutter run -d macos`                    |
| Real device      | `http://<LAN_IP>:4000/graphql`          | `flutter run --dart-define=API_URL=http://192.168.x.x:4000/graphql`  |

### Features
- **Mobile**: Hotels → Rooms → Room detail (calendar, check availability, book, cancel)
- **Desktop**: Overview screen with all hotels, rooms with Free/Busy status, Refresh button, tap to Room detail
- Bookings list with Cancel for ACTIVE bookings
- Overlap errors shown as friendly message
- Pull-to-refresh, manual Refresh button
- Light/Dark theme, EN/RU language switch

### Testing Overlap in UI
1. Open Room 101 (Busy today)
2. Pick dates covering today (e.g., today → today+2)
3. Tap "Check availability" → shows "Not available" with conflict
4. Pick dates in a free range (e.g., today+3 → today+5 — between bk-1 and bk-2)
5. "Check availability" → "Available" → "Book" succeeds
6. Cancel the new booking from the list

## Cleanup

```bash
docker compose down -v
```
