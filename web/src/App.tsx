import { useState } from "react";
import HotelsPage from "./HotelsPage";
import RoomPage from "./RoomPage";
import "./App.css";

function App() {
  const [selectedRoom, setSelectedRoom] = useState<{
    id: string;
    name: string;
  } | null>(null);

  if (selectedRoom) {
    return (
      <RoomPage
        roomId={selectedRoom.id}
        roomName={selectedRoom.name}
        onBack={() => setSelectedRoom(null)}
      />
    );
  }

  return (
    <HotelsPage
      onSelectRoom={(id, name) => setSelectedRoom({ id, name })}
    />
  );
}

export default App;
