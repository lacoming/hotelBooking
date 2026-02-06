import { useState } from "react";
import { useLazyQuery, useMutation, useQuery } from "@apollo/client/react";
import {
  GET_ROOM_BOOKINGS,
  CHECK_AVAILABILITY,
  CREATE_BOOKING,
  CANCEL_BOOKING,
} from "./graphql";

interface Booking {
  id: string;
  roomId: string;
  startDate: string;
  endDate: string;
  status: "ACTIVE" | "CANCELED";
  createdAt: string;
  canceledAt: string | null;
}

interface AvailabilityResult {
  available: boolean;
  conflicts: { id: string; startDate: string; endDate: string; status: string }[];
}

interface Props {
  roomId: string;
  roomName: string;
  onBack: () => void;
}

export default function RoomPage({ roomId, roomName, onBack }: Props) {
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [availability, setAvailability] = useState<AvailabilityResult | null>(null);
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);

  const {
    data: bookingsData,
    loading: bookingsLoading,
    refetch: refetchBookings,
  } = useQuery<{ roomBookings: Booking[] }>(GET_ROOM_BOOKINGS, {
    variables: { roomId },
  });

  const [checkAvail, { loading: checkingAvail }] = useLazyQuery<{ roomAvailability: AvailabilityResult }>(CHECK_AVAILABILITY, { fetchPolicy: "network-only" });
  const [createBooking, { loading: creating }] = useMutation<{ createBooking: Booking }>(CREATE_BOOKING);
  const [cancelBooking] = useMutation(CANCEL_BOOKING);

  const handleCheckAvailability = async () => {
    setMessage(null);
    setAvailability(null);
    if (!startDate || !endDate) {
      setMessage({ text: "Please select both dates", error: true });
      return;
    }
    try {
      const result = await checkAvail({
        variables: { roomId, from: startDate, to: endDate },
      });
      if (result.data) {
        setAvailability(result.data.roomAvailability);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setMessage({ text: msg, error: true });
    }
  };

  const handleBook = async () => {
    setMessage(null);
    if (!startDate || !endDate) {
      setMessage({ text: "Please select both dates", error: true });
      return;
    }
    try {
      const { data } = await createBooking({
        variables: { input: { roomId, startDate, endDate } },
      });
      setMessage({
        text: `Booking created: ${data!.createBooking.id} (${data!.createBooking.startDate} - ${data!.createBooking.endDate})`,
        error: false,
      });
      setAvailability(null);
      refetchBookings();
    } catch (err: unknown) {
      const gqlErr = err as { graphQLErrors?: { extensions?: { code?: string }; message?: string }[] };
      const overlap = gqlErr.graphQLErrors?.find(
        (e) => e.extensions?.code === "BOOKING_OVERLAP"
      );
      if (overlap) {
        setMessage({ text: "Dates overlap with an existing booking!", error: true });
      } else {
        const msg = err instanceof Error ? err.message : String(err);
        setMessage({ text: msg, error: true });
      }
    }
  };

  const handleCancel = async (bookingId: string) => {
    setMessage(null);
    try {
      await cancelBooking({ variables: { id: bookingId } });
      setMessage({ text: `Booking ${bookingId} canceled`, error: false });
      refetchBookings();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setMessage({ text: msg, error: true });
    }
  };

  return (
    <div>
      <button onClick={onBack}>&larr; Back to hotels</button>
      <h1>Room: {roomName}</h1>
      <p style={{ color: "#888" }}>ID: {roomId}</p>

      {/* Date form */}
      <fieldset style={{ maxWidth: 400, marginBottom: "1rem" }}>
        <legend>Date range [startDate, endDate)</legend>
        <label>
          Start:{" "}
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
        </label>
        <br />
        <label>
          End:{" "}
          <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
        </label>
        <br />
        <br />
        <button onClick={handleCheckAvailability} disabled={checkingAvail}>
          {checkingAvail ? "Checking..." : "Check availability"}
        </button>{" "}
        <button onClick={handleBook} disabled={creating}>
          {creating ? "Booking..." : "Book"}
        </button>
      </fieldset>

      {/* Message */}
      {message && (
        <p style={{ color: message.error ? "red" : "green", fontWeight: "bold" }}>
          {message.text}
        </p>
      )}

      {/* Availability result */}
      {availability && (
        <div style={{ marginBottom: "1rem", padding: "0.5rem", background: availability.available ? "#e8f5e9" : "#ffebee" }}>
          <strong>{availability.available ? "Available" : "Not available"}</strong>
          {availability.conflicts.length > 0 && (
            <ul>
              {availability.conflicts.map((c) => (
                <li key={c.id}>
                  {c.id}: {c.startDate} - {c.endDate} ({c.status})
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* Bookings list */}
      <h2>Bookings</h2>
      {bookingsLoading ? (
        <p>Loading bookings...</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Start</th>
              <th>End</th>
              <th>Status</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {bookingsData?.roomBookings.map((b) => (
              <tr key={b.id} style={{ opacity: b.status === "CANCELED" ? 0.5 : 1 }}>
                <td>{b.id}</td>
                <td>{b.startDate}</td>
                <td>{b.endDate}</td>
                <td>{b.status}</td>
                <td>{new Date(b.createdAt).toLocaleString()}</td>
                <td>
                  {b.status === "ACTIVE" && (
                    <button onClick={() => handleCancel(b.id)}>Cancel</button>
                  )}
                </td>
              </tr>
            ))}
            {bookingsData?.roomBookings.length === 0 && (
              <tr>
                <td colSpan={6}>No bookings</td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
