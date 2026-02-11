import { PrismaClient, BookingStatus } from "@prisma/client";

const prisma = new PrismaClient();

/** Create a UTC midnight Date offset by `days` from today */
function dayOffset(days: number): Date {
  const now = new Date();
  const d = new Date(
    Date.UTC(now.getFullYear(), now.getMonth(), now.getDate() + days)
  );
  return d;
}

async function main() {
  // --- exclusion constraint for race-condition safety ---
  await prisma.$executeRawUnsafe(`CREATE EXTENSION IF NOT EXISTS btree_gist`);
  await prisma.$executeRawUnsafe(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'booking_no_overlap'
      ) THEN
        ALTER TABLE "Booking"
          ADD CONSTRAINT booking_no_overlap
          EXCLUDE USING gist (
            "roomId" WITH =,
            daterange("startDate", "endDate") WITH &&
          ) WHERE (status = 'ACTIVE'::"BookingStatus");
      END IF;
    END $$;
  `);

  // --- hotels ---
  await prisma.hotel.upsert({
    where: { id: "hotel-1" },
    update: { timezone: "Europe/Moscow" },
    create: { id: "hotel-1", name: "Grand Hotel", timezone: "Europe/Moscow" },
  });
  await prisma.hotel.upsert({
    where: { id: "hotel-2" },
    update: { timezone: "Asia/Dubai" },
    create: { id: "hotel-2", name: "Beach Resort", timezone: "Asia/Dubai" },
  });

  // --- rooms ---
  const rooms = [
    { id: "room-101", hotelId: "hotel-1", name: "101", capacity: 2 },
    { id: "room-102", hotelId: "hotel-1", name: "102", capacity: 3 },
    { id: "room-103", hotelId: "hotel-1", name: "103", capacity: 1 },
    { id: "room-a1", hotelId: "hotel-2", name: "A1", capacity: 4 },
    { id: "room-a2", hotelId: "hotel-2", name: "A2", capacity: 2 },
    { id: "room-a3", hotelId: "hotel-2", name: "A3", capacity: 3 },
  ];
  for (const r of rooms) {
    await prisma.room.upsert({ where: { id: r.id }, update: {}, create: r });
  }

  // --- bookings (relative to today) ---
  // bk-1: room-101, today-2 → today+3  — ACTIVE, covers today ⇒ Busy
  // bk-2: room-101, today+5 → today+10 — ACTIVE, future (no overlap with bk-1)
  //   Overlap scenario: trying to book today → today+4 on room-101 will conflict with bk-1
  // bk-3: room-102, today-1 → today+2  — ACTIVE, covers today ⇒ Busy
  // bk-4: room-a1,  today   → today+5  — ACTIVE, covers today ⇒ Busy
  // bk-5: room-a1,  today-3 → today+1  — CANCELED (no Busy effect)
  //
  // Rooms with NO active bookings covering today: room-103, room-a2, room-a3 ⇒ Free

  const bookings = [
    {
      id: "bk-1",
      roomId: "room-101",
      startDate: dayOffset(-2),
      endDate: dayOffset(3),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-2",
      roomId: "room-101",
      startDate: dayOffset(5),
      endDate: dayOffset(10),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-3",
      roomId: "room-102",
      startDate: dayOffset(-1),
      endDate: dayOffset(2),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-4",
      roomId: "room-a1",
      startDate: dayOffset(0),
      endDate: dayOffset(5),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-5",
      roomId: "room-a1",
      startDate: dayOffset(-3),
      endDate: dayOffset(1),
      status: BookingStatus.CANCELED,
    },
  ];

  // Wipe ALL bookings for seeded rooms to avoid exclusion constraint conflicts
  // (covers both previous seed bookings and manually-created test bookings)
  const seedRoomIds = rooms.map((r) => r.id);
  await prisma.booking.deleteMany({
    where: { roomId: { in: seedRoomIds } },
  });

  for (const b of bookings) {
    await prisma.booking.create({ data: b });
  }

  const fmt = (d: Date) => d.toISOString().slice(0, 10);
  console.log("Seed complete: 2 hotels, 6 rooms, 5 bookings");
  console.log("  Today:", fmt(dayOffset(0)));
  console.log(
    "  Busy today: room-101 (bk-1), room-102 (bk-3), room-a1 (bk-4)"
  );
  console.log("  Free today: room-103, room-a2, room-a3");
  console.log(
    `  Overlap test: book room-101 from ${fmt(dayOffset(0))} to ${fmt(dayOffset(4))} → should fail`
  );
}

main()
  .catch((e) => {
    console.error("Seed failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
