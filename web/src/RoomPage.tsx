import { useState } from "react";
import { useLazyQuery, useMutation, useQuery } from "@apollo/client/react";
import {
  GET_ROOM_BOOKINGS,
  CHECK_AVAILABILITY,
  CREATE_BOOKING,
  CANCEL_BOOKING,
} from "./graphql";
import { useI18n } from "./i18n";

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
  onBack: () => void;
}

export default function RoomPage({ roomId, onBack }: Props) {
  const { t } = useI18n();
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
    pollInterval: 30_000,
  });

  const [checkAvail, { loading: checkingAvail }] = useLazyQuery<{ roomAvailability: AvailabilityResult }>(CHECK_AVAILABILITY, { fetchPolicy: "network-only" });
  const [createBooking, { loading: creating }] = useMutation<{ createBooking: Booking }>(CREATE_BOOKING);
  const [cancelBooking] = useMutation(CANCEL_BOOKING);

  const handleCheckAvailability = async () => {
    setMessage(null);
    setAvailability(null);
    if (!startDate || !endDate) {
      setMessage({ text: t("select_both_dates"), error: true });
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
      setMessage({ text: t("select_both_dates"), error: true });
      return;
    }
    try {
      const { data } = await createBooking({
        variables: { input: { roomId, startDate, endDate } },
      });
      setMessage({
        text: `${t("booking_created")}: ${data!.createBooking.id} (${data!.createBooking.startDate} - ${data!.createBooking.endDate})`,
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
        setMessage({ text: t("booking_overlap"), error: true });
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
      setMessage({ text: `${t("booking_canceled")}: ${bookingId}`, error: false });
      refetchBookings();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setMessage({ text: msg, error: true });
    }
  };

  return (
    <div>
      <button onClick={onBack}>&larr; {t("back_to_hotels")}</button>
      <p style={{ color: "var(--text-secondary)", margin: "8px 0" }}>ID: {roomId}</p>

      {/* Date form */}
      <fieldset style={{ maxWidth: 420, marginBottom: "1rem" }}>
        <legend>{t("date_range")}</legend>
        <div style={{ display: "flex", gap: "12px", alignItems: "center", flexWrap: "wrap" }}>
          <label>
            {t("start")}:{" "}
            <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
          </label>
          <label>
            {t("end")}:{" "}
            <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
          </label>
        </div>
        <div style={{ marginTop: "12px", display: "flex", gap: "8px" }}>
          <button className="primary" onClick={handleCheckAvailability} disabled={checkingAvail}>
            {checkingAvail ? t("checking") : t("check_availability")}
          </button>
          <button className="primary" onClick={handleBook} disabled={creating}>
            {creating ? t("booking_ellipsis") : t("book")}
          </button>
        </div>
      </fieldset>

      {/* Message */}
      {message && (
        <div className={message.error ? "msg-error" : "msg-success"}>
          {message.text}
        </div>
      )}

      {/* Availability result */}
      {availability && (
        <div className={availability.available ? "msg-success" : "msg-warning"} style={{ marginBottom: "1rem" }}>
          <strong>{availability.available ? t("available") : t("not_available")}</strong>
          {availability.conflicts.length > 0 && (
            <ul style={{ margin: "4px 0 0", paddingLeft: "20px" }}>
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
      <h2>{t("bookings")}</h2>
      {bookingsLoading ? (
        <p>{t("loading_bookings")}</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>{t("id")}</th>
              <th>{t("start")}</th>
              <th>{t("end")}</th>
              <th>{t("status")}</th>
              <th>{t("created")}</th>
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
                    <button onClick={() => handleCancel(b.id)}>{t("cancel")}</button>
                  )}
                </td>
              </tr>
            ))}
            {bookingsData?.roomBookings.length === 0 && (
              <tr>
                <td colSpan={6}>{t("no_bookings")}</td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
