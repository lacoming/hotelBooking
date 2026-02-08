import { describe, it, expect, vi, beforeEach } from "vitest";
import { ApolloServer } from "@apollo/server";

// ── Mock Prisma (hoisted so vi.mock factory can access them) ────
const { mockHotel, mockRoom, mockBooking, mockTransaction } = vi.hoisted(() => ({
  mockHotel: { findMany: vi.fn(), findUnique: vi.fn() },
  mockRoom: { findMany: vi.fn(), findUnique: vi.fn() },
  mockBooking: { findMany: vi.fn(), findUnique: vi.fn(), create: vi.fn(), update: vi.fn() },
  mockTransaction: vi.fn(),
}));

vi.mock("@prisma/client", () => {
  const BookingStatus = { ACTIVE: "ACTIVE", CANCELED: "CANCELED" };
  class PrismaClient {
    hotel = mockHotel;
    room = mockRoom;
    booking = mockBooking;
    $transaction = mockTransaction;
  }
  return { PrismaClient, BookingStatus };
});

// Import after mock
import { typeDefs } from "../schema.js";
import { resolvers } from "../resolvers.js";

// ── Server factory ───────────────────────────────────────────────
function createServer() {
  return new ApolloServer({ typeDefs, resolvers });
}

// ── Helpers ──────────────────────────────────────────────────────
function futureDate(offsetDays: number): string {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toISOString().split("T")[0];
}

// ═════════════════════════════════════════════════════════════════
//  Tests
// ═════════════════════════════════════════════════════════════════

describe("Query.hotels", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns list of hotels", async () => {
    const server = createServer();
    mockHotel.findMany.mockResolvedValue([
      { id: "h1", name: "Grand Hotel" },
      { id: "h2", name: "Beach Resort" },
    ]);

    const res = await server.executeOperation({
      query: `query { hotels { id name } }`,
    });

    expect(res.body.kind).toBe("single");
    const data = (res.body as { singleResult: { data: { hotels: unknown[] } } }).singleResult.data;
    expect(data.hotels).toHaveLength(2);
    expect(data.hotels[0]).toEqual({ id: "h1", name: "Grand Hotel" });
  });
});

describe("Query.roomAvailability", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns available=true when no conflicts", async () => {
    const server = createServer();
    mockBooking.findMany.mockResolvedValue([]);

    const from = futureDate(10);
    const to = futureDate(15);
    const res = await server.executeOperation({
      query: `query ($roomId: ID!, $from: Date!, $to: Date!) {
        roomAvailability(roomId: $roomId, from: $from, to: $to) { available conflicts { id } }
      }`,
      variables: { roomId: "room-101", from, to },
    });

    const data = (res.body as any).singleResult.data;
    expect(data.roomAvailability.available).toBe(true);
    expect(data.roomAvailability.conflicts).toEqual([]);
  });

  it("returns available=false when conflicts exist", async () => {
    const server = createServer();
    mockBooking.findMany.mockResolvedValue([
      {
        id: "bk-1",
        roomId: "room-101",
        startDate: new Date("2026-02-10"),
        endDate: new Date("2026-02-14"),
        status: "ACTIVE",
        createdAt: new Date(),
        canceledAt: null,
      },
    ]);

    const res = await server.executeOperation({
      query: `query ($roomId: ID!, $from: Date!, $to: Date!) {
        roomAvailability(roomId: $roomId, from: $from, to: $to) { available conflicts { id } }
      }`,
      variables: { roomId: "room-101", from: "2026-02-12", to: "2026-02-13" },
    });

    const data = (res.body as any).singleResult.data;
    expect(data.roomAvailability.available).toBe(false);
    expect(data.roomAvailability.conflicts).toHaveLength(1);
  });

  it("rejects from >= to with BAD_USER_INPUT", async () => {
    const server = createServer();

    const res = await server.executeOperation({
      query: `query ($roomId: ID!, $from: Date!, $to: Date!) {
        roomAvailability(roomId: $roomId, from: $from, to: $to) { available }
      }`,
      variables: { roomId: "room-101", from: "2026-02-15", to: "2026-02-10" },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors).toBeDefined();
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });
});

describe("Mutation.createBooking", () => {
  beforeEach(() => vi.clearAllMocks());

  it("creates booking successfully", async () => {
    const server = createServer();
    const start = futureDate(20);
    const end = futureDate(25);

    mockRoom.findUnique.mockResolvedValue({ id: "room-101", name: "101" });
    mockTransaction.mockImplementation(async (fn: Function) => {
      // The transaction callback receives a tx object with the same shape
      const tx = {
        booking: {
          findMany: vi.fn().mockResolvedValue([]),
          create: vi.fn().mockResolvedValue({
            id: "bk-new",
            roomId: "room-101",
            startDate: new Date(start),
            endDate: new Date(end),
            status: "ACTIVE",
            createdAt: new Date(),
            canceledAt: null,
          }),
        },
      };
      return fn(tx);
    });

    const res = await server.executeOperation({
      query: `mutation ($input: CreateBookingInput!) {
        createBooking(input: $input) { id roomId status }
      }`,
      variables: { input: { roomId: "room-101", startDate: start, endDate: end } },
    });

    const data = (res.body as any).singleResult.data;
    expect(data.createBooking.id).toBe("bk-new");
    expect(data.createBooking.status).toBe("ACTIVE");
  });

  it("rejects overlap with BOOKING_OVERLAP", async () => {
    const server = createServer();
    const start = futureDate(20);
    const end = futureDate(25);

    mockRoom.findUnique.mockResolvedValue({ id: "room-101", name: "101" });
    mockTransaction.mockImplementation(async (fn: Function) => {
      const tx = {
        booking: {
          findMany: vi.fn().mockResolvedValue([{ id: "bk-existing" }]),
          create: vi.fn(),
        },
      };
      return fn(tx);
    });

    const res = await server.executeOperation({
      query: `mutation ($input: CreateBookingInput!) {
        createBooking(input: $input) { id }
      }`,
      variables: { input: { roomId: "room-101", startDate: start, endDate: end } },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors).toBeDefined();
    expect(errors[0].extensions.code).toBe("BOOKING_OVERLAP");
  });

  it("rejects startDate >= endDate with BAD_USER_INPUT", async () => {
    const server = createServer();
    const date = futureDate(20);

    const res = await server.executeOperation({
      query: `mutation ($input: CreateBookingInput!) {
        createBooking(input: $input) { id }
      }`,
      variables: { input: { roomId: "room-101", startDate: date, endDate: date } },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });

  it("rejects non-existent room with BAD_USER_INPUT", async () => {
    const server = createServer();
    const start = futureDate(20);
    const end = futureDate(25);

    mockRoom.findUnique.mockResolvedValue(null);

    const res = await server.executeOperation({
      query: `mutation ($input: CreateBookingInput!) {
        createBooking(input: $input) { id }
      }`,
      variables: { input: { roomId: "no-room", startDate: start, endDate: end } },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });

  it("rejects past dates with BAD_USER_INPUT", async () => {
    const server = createServer();

    const res = await server.executeOperation({
      query: `mutation ($input: CreateBookingInput!) {
        createBooking(input: $input) { id }
      }`,
      variables: { input: { roomId: "room-101", startDate: "2020-01-01", endDate: "2020-01-05" } },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });
});

describe("Mutation.cancelBooking", () => {
  beforeEach(() => vi.clearAllMocks());

  it("cancels an active booking", async () => {
    const server = createServer();

    mockBooking.findUnique.mockResolvedValue({
      id: "bk-1",
      roomId: "room-101",
      startDate: new Date("2026-02-10"),
      endDate: new Date("2026-02-14"),
      status: "ACTIVE",
      createdAt: new Date(),
      canceledAt: null,
    });
    mockBooking.update.mockResolvedValue({
      id: "bk-1",
      roomId: "room-101",
      startDate: new Date("2026-02-10"),
      endDate: new Date("2026-02-14"),
      status: "CANCELED",
      createdAt: new Date(),
      canceledAt: new Date(),
    });

    const res = await server.executeOperation({
      query: `mutation ($id: ID!) { cancelBooking(id: $id) { id status } }`,
      variables: { id: "bk-1" },
    });

    const data = (res.body as any).singleResult.data;
    expect(data.cancelBooking.status).toBe("CANCELED");
  });

  it("rejects non-existent booking", async () => {
    const server = createServer();
    mockBooking.findUnique.mockResolvedValue(null);

    const res = await server.executeOperation({
      query: `mutation ($id: ID!) { cancelBooking(id: $id) { id } }`,
      variables: { id: "no-such" },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });

  it("rejects already canceled booking", async () => {
    const server = createServer();
    mockBooking.findUnique.mockResolvedValue({
      id: "bk-1",
      status: "CANCELED",
    });

    const res = await server.executeOperation({
      query: `mutation ($id: ID!) { cancelBooking(id: $id) { id } }`,
      variables: { id: "bk-1" },
    });

    const errors = (res.body as any).singleResult.errors;
    expect(errors[0].extensions.code).toBe("BAD_USER_INPUT");
  });
});
