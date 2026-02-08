import 'package:graphql_flutter/graphql_flutter.dart';

// ─── Queries ────────────────────────────────────────────────

final hotelsQuery = gql(r'''
  query Hotels {
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
''');

final roomBookingsQuery = gql(r'''
  query RoomBookings($roomId: ID!) {
    roomBookings(roomId: $roomId) {
      id
      roomId
      startDate
      endDate
      status
      createdAt
      canceledAt
    }
  }
''');

final roomAvailabilityQuery = gql(r'''
  query RoomAvailability($roomId: ID!, $from: Date!, $to: Date!) {
    roomAvailability(roomId: $roomId, from: $from, to: $to) {
      available
      conflicts {
        id
        startDate
        endDate
        status
      }
    }
  }
''');

final hotelQuery = gql(r'''
  query Hotel($id: ID!) {
    hotel(id: $id) {
      id
      name
      rooms {
        id
        name
        capacity
      }
    }
  }
''');

// ─── Mutations ──────────────────────────────────────────────

final createBookingMutation = gql(r'''
  mutation CreateBooking($input: CreateBookingInput!) {
    createBooking(input: $input) {
      id
      roomId
      startDate
      endDate
      status
      createdAt
    }
  }
''');

final cancelBookingMutation = gql(r'''
  mutation CancelBooking($id: ID!) {
    cancelBooking(id: $id) {
      id
      status
      canceledAt
    }
  }
''');
