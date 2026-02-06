import { PrismaClient, BookingStatus } from "@prisma/client";

const prisma = new PrismaClient();

function d(s: string) {
  return new Date(s + "T00:00:00Z");
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
    update: {},
    create: { id: "hotel-1", name: "Grand Hotel" },
  });
  await prisma.hotel.upsert({
    where: { id: "hotel-2" },
    update: {},
    create: { id: "hotel-2", name: "Beach Resort" },
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

  // --- bookings ---
  const bookings = [
    {
      id: "bk-1",
      roomId: "room-101",
      startDate: d("2025-06-01"),
      endDate: d("2025-06-05"),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-2",
      roomId: "room-101",
      startDate: d("2025-06-10"),
      endDate: d("2025-06-15"),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-3",
      roomId: "room-102",
      startDate: d("2025-06-03"),
      endDate: d("2025-06-07"),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-4",
      roomId: "room-a1",
      startDate: d("2025-06-01"),
      endDate: d("2025-06-06"),
      status: BookingStatus.ACTIVE,
    },
    {
      id: "bk-5",
      roomId: "room-a1",
      startDate: d("2025-06-01"),
      endDate: d("2025-06-04"),
      status: BookingStatus.CANCELED,
    },
  ];

  for (const b of bookings) {
    await prisma.booking.upsert({ where: { id: b.id }, update: {}, create: b });
  }

  console.log("Seed complete: 2 hotels, 6 rooms, 5 bookings");
}

main()
  .catch((e) => {
    console.error("Seed failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
