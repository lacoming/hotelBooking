import { useQuery } from "@apollo/client/react";
import { GET_HOTELS, CHECK_AVAILABILITY } from "./graphql";
import { useI18n } from "./i18n";
import { useApolloClient } from "@apollo/client/react";
import { useState, useEffect, useCallback } from "react";

interface Room {
  id: string;
  name: string;
  capacity: number | null;
}

interface Hotel {
  id: string;
  name: string;
  rooms: Room[];
}

interface Props {
  onSelectRoom: (roomId: string, roomName: string) => void;
}

function todayStr(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function tomorrowStr(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export default function HotelsPage({ onSelectRoom }: Props) {
  const { t } = useI18n();
  const { data, loading, error } = useQuery<{ hotels: Hotel[] }>(GET_HOTELS, {
    pollInterval: 60_000,
  });
  const client = useApolloClient();
  const [availability, setAvailability] = useState<Record<string, boolean>>({});

  const fetchAvailability = useCallback(async (rooms: Room[]) => {
    const today = todayStr();
    const tomorrow = tomorrowStr();
    const results: Record<string, boolean> = {};
    await Promise.all(
      rooms.map(async (room) => {
        try {
          const { data } = await client.query({
            query: CHECK_AVAILABILITY,
            variables: { roomId: room.id, from: today, to: tomorrow },
            fetchPolicy: "network-only",
          });
          results[room.id] = (data as { roomAvailability: { available: boolean } }).roomAvailability.available;
        } catch {
          // ignore errors for badge
        }
      })
    );
    setAvailability((prev) => ({ ...prev, ...results }));
  }, [client]);

  useEffect(() => {
    if (data?.hotels) {
      const allRooms = data.hotels.flatMap((h) => h.rooms);
      // eslint-disable-next-line react-hooks/set-state-in-effect -- async fetch, not synchronous setState
      fetchAvailability(allRooms);
    }
  }, [data, fetchAvailability]);

  if (loading) return <p>{t("loading_hotels")}</p>;
  if (error) return <p className="msg-error">{t("error")}: {error.message}</p>;

  return (
    <div>
      {data!.hotels.map((hotel) => (
        <div key={hotel.id} className="card" style={{ marginBottom: "16px" }}>
          <h2 style={{ margin: "0 0 4px" }}>{hotel.name}</h2>
          <p style={{ margin: "0 0 12px", color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            {hotel.rooms.length} {t("rooms").toLowerCase()}
          </p>
          {hotel.rooms.map((room) => (
            <div key={room.id} className="room-row">
              <div className="room-info">
                <span className="room-name">{room.name}</span>
                {room.capacity != null && (
                  <span className="room-capacity">
                    {t("capacity")}: {room.capacity}
                  </span>
                )}
              </div>
              <div className="room-actions">
                {room.id in availability ? (
                  <span className={`badge ${availability[room.id] ? "badge-free" : "badge-busy"}`}>
                    {availability[room.id] ? t("free") : t("busy")}
                  </span>
                ) : (
                  <span style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>...</span>
                )}
                <button onClick={() => onSelectRoom(room.id, room.name)}>
                  {t("open")}
                </button>
              </div>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
