export const typeDefs = `#graphql
  scalar Date

  enum BookingStatus {
    ACTIVE
    CANCELED
  }

  type Hotel {
    id: ID!
    name: String!
    rooms: [Room!]!
  }

  type Room {
    id: ID!
    hotelId: ID!
    name: String!
    capacity: Int
    hotel: Hotel!
    bookings(from: Date, to: Date): [Booking!]!
  }

  type Booking {
    id: ID!
    roomId: ID!
    startDate: Date!
    endDate: Date!
    status: BookingStatus!
    createdAt: String!
    canceledAt: String
  }

  type AvailabilityResult {
    available: Boolean!
    conflicts: [Booking!]!
  }

  input CreateBookingInput {
    roomId: ID!
    startDate: Date!
    endDate: Date!
  }

  type Query {
    hotels: [Hotel!]!
    hotel(id: ID!): Hotel
    room(id: ID!): Room
    roomBookings(roomId: ID!, from: Date, to: Date): [Booking!]!
    roomAvailability(roomId: ID!, from: Date!, to: Date!): AvailabilityResult!
  }

  type Mutation {
    createBooking(input: CreateBookingInput!): Booking!
    cancelBooking(id: ID!): Booking!
  }
`;
