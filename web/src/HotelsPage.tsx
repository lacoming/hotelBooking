import { useQuery } from "@apollo/client/react";
import { GET_HOTELS } from "./graphql";

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

export default function HotelsPage({ onSelectRoom }: Props) {
  const { data, loading, error } = useQuery<{ hotels: Hotel[] }>(GET_HOTELS);

  if (loading) return <p>Loading hotels...</p>;
  if (error) return <p style={{ color: "red" }}>Error: {error.message}</p>;

  return (
    <div>
      <h1>Hotels</h1>
      {data!.hotels.map((hotel) => (
        <div key={hotel.id} style={{ marginBottom: "1.5rem" }}>
          <h2>{hotel.name}</h2>
          <table>
            <thead>
              <tr>
                <th>Room</th>
                <th>Capacity</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {hotel.rooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.name}</td>
                  <td>{room.capacity ?? "—"}</td>
                  <td>
                    <button onClick={() => onSelectRoom(room.id, room.name)}>
                      Open
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ))}
    </div>
  );
}
