import { GraphQLScalarType, Kind, GraphQLError } from "graphql";
import { PrismaClient, BookingStatus } from "@prisma/client";

const prisma = new PrismaClient();

// ---------- Date scalar (YYYY-MM-DD) ----------

const DateScalar = new GraphQLScalarType({
  name: "Date",
  description: "Calendar date in YYYY-MM-DD format",
  serialize(value: unknown): string {
    if (value instanceof Date) return value.toISOString().split("T")[0];
    if (typeof value === "string") return value.split("T")[0];
    throw new GraphQLError("Date serialize: unexpected type");
  },
  parseValue(value: unknown): string {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new GraphQLError("Date must be a string in YYYY-MM-DD format", {
        extensions: { code: "BAD_USER_INPUT" },
      });
    }
    return value;
  },
  parseLiteral(ast): string {
    if (ast.kind !== Kind.STRING || !/^\d{4}-\d{2}-\d{2}$/.test(ast.value)) {
      throw new GraphQLError("Date must be a string in YYYY-MM-DD format", {
        extensions: { code: "BAD_USER_INPUT" },
      });
    }
    return ast.value;
  },
});

// ---------- helpers ----------

function toDate(s: string) {
  return new Date(s + "T00:00:00Z");
}

/** Build overlap WHERE for [from, to) half-open interval */
function overlapWhere(roomId: string, from: string, to: string, statusFilter?: BookingStatus) {
  const where: Record<string, unknown> = {
    roomId,
    startDate: { lt: toDate(to) },
    endDate: { gt: toDate(from) },
  };
  if (statusFilter) where.status = statusFilter;
  return where;
}

function bookingsDateFilter(roomId: string, from?: string | null, to?: string | null) {
  const where: Record<string, unknown> = { roomId };
  const and: Record<string, unknown>[] = [];
  if (from) and.push({ endDate: { gt: toDate(from) } });
  if (to) and.push({ startDate: { lt: toDate(to) } });
  if (and.length) where.AND = and;
  return where;
}

// ---------- resolvers ----------

export const resolvers = {
  Date: DateScalar,

  Query: {
    hotels: () => prisma.hotel.findMany(),

    hotel: (_: unknown, { id }: { id: string }) =>
      prisma.hotel.findUnique({ where: { id } }),

    room: (_: unknown, { id }: { id: string }) =>
      prisma.room.findUnique({ where: { id } }),

    roomBookings: (_: unknown, args: { roomId: string; from?: string; to?: string }) =>
      prisma.booking.findMany({ where: bookingsDateFilter(args.roomId, args.from, args.to) }),

    roomAvailability: async (_: unknown, args: { roomId: string; from: string; to: string }) => {
      if (args.from >= args.to) {
        throw new GraphQLError("from must be before to", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }
      const conflicts = await prisma.booking.findMany({
        where: overlapWhere(args.roomId, args.from, args.to, BookingStatus.ACTIVE),
      });
      return { available: conflicts.length === 0, conflicts };
    },
  },

  Mutation: {
    createBooking: async (_: unknown, { input }: { input: { roomId: string; startDate: string; endDate: string } }) => {
      const { roomId, startDate, endDate } = input;

      if (startDate >= endDate) {
        throw new GraphQLError("startDate must be before endDate", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }

      const today = new Date().toISOString().split("T")[0];
      if (startDate < today) {
        throw new GraphQLError("Cannot book dates in the past", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }

      const room = await prisma.room.findUnique({ where: { id: roomId } });
      if (!room) {
        throw new GraphQLError("Room not found", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }

      try {
        const booking = await prisma.$transaction(
          async (tx) => {
            const conflicts = await tx.booking.findMany({
              where: overlapWhere(roomId, startDate, endDate, BookingStatus.ACTIVE),
            });

            if (conflicts.length > 0) {
              throw new GraphQLError("Booking overlaps with existing reservation", {
                extensions: { code: "BOOKING_OVERLAP" },
              });
            }

            return tx.booking.create({
              data: {
                roomId,
                startDate: toDate(startDate),
                endDate: toDate(endDate),
                status: BookingStatus.ACTIVE,
              },
            });
          },
          { isolationLevel: "Serializable" },
        );

        console.log(
          JSON.stringify({
            event: "booking_created",
            bookingId: booking.id,
            roomId,
            startDate,
            endDate,
            ts: new Date().toISOString(),
          }),
        );

        return booking;
      } catch (err: unknown) {
        // Re-throw GraphQL errors as-is
        if (err instanceof GraphQLError) throw err;
        // Postgres exclusion constraint violation → friendly error
        if (typeof err === "object" && err !== null && "code" in err && (err as { code: string }).code === "P2010") {
          throw new GraphQLError("Booking overlaps with existing reservation (constraint)", {
            extensions: { code: "BOOKING_OVERLAP" },
          });
        }
        throw err;
      }
    },

    cancelBooking: async (_: unknown, { id }: { id: string }) => {
      const booking = await prisma.booking.findUnique({ where: { id } });
      if (!booking) {
        throw new GraphQLError("Booking not found", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }
      if (booking.status === BookingStatus.CANCELED) {
        throw new GraphQLError("Booking is already canceled", {
          extensions: { code: "BAD_USER_INPUT" },
        });
      }

      const updated = await prisma.booking.update({
        where: { id },
        data: { status: BookingStatus.CANCELED, canceledAt: new Date() },
      });

      console.log(
        JSON.stringify({
          event: "booking_canceled",
          bookingId: id,
          roomId: booking.roomId,
          startDate: booking.startDate.toISOString().split("T")[0],
          endDate: booking.endDate.toISOString().split("T")[0],
          ts: new Date().toISOString(),
        }),
      );

      return updated;
    },
  },

  Hotel: {
    rooms: (hotel: { id: string }) =>
      prisma.room.findMany({ where: { hotelId: hotel.id } }),
  },

  Room: {
    hotel: (room: { hotelId: string }) =>
      prisma.hotel.findUnique({ where: { id: room.hotelId } }),
    bookings: (room: { id: string }, args: { from?: string; to?: string }) =>
      prisma.booking.findMany({ where: bookingsDateFilter(room.id, args.from, args.to) }),
  },

  Booking: {
    createdAt: (b: { createdAt: Date }) => b.createdAt.toISOString(),
    canceledAt: (b: { canceledAt: Date | null }) =>
      b.canceledAt ? b.canceledAt.toISOString() : null,
  },
};
