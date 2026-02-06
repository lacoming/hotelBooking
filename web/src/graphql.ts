import { gql } from "@apollo/client";

export const GET_HOTELS = gql`
  query GetHotels {
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
`;

export const GET_ROOM_BOOKINGS = gql`
  query GetRoomBookings($roomId: ID!) {
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
`;

export const CHECK_AVAILABILITY = gql`
  query CheckAvailability($roomId: ID!, $from: Date!, $to: Date!) {
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
`;

export const CREATE_BOOKING = gql`
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
`;

export const CANCEL_BOOKING = gql`
  mutation CancelBooking($id: ID!) {
    cancelBooking(id: $id) {
      id
      status
      canceledAt
    }
  }
`;
