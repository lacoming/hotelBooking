import { useState } from "react";
import { useI18n } from "./i18n";
import { useTheme } from "./theme";
import HotelsPage from "./HotelsPage";
import RoomPage from "./RoomPage";
import "./App.css";

function App() {
  const [selectedRoom, setSelectedRoom] = useState<{
    id: string;
    name: string;
  } | null>(null);
  const { locale, toggleLocale, t } = useI18n();
  const { theme, toggleTheme } = useTheme();

  const header = (
    <div className="app-header">
      <h1>{selectedRoom ? `${t("room")}: ${selectedRoom.name}` : t("hotels")}</h1>
      <div className="header-actions">
        <button className="lang-btn" onClick={toggleLocale}>
          {locale === "en" ? "RU" : "EN"}
        </button>
        <button className="icon-btn" onClick={toggleTheme} title="Toggle theme">
          {theme === "dark" ? "\u2600\uFE0F" : "\uD83C\uDF19"}
        </button>
      </div>
    </div>
  );

  if (selectedRoom) {
    return (
      <>
        {header}
        <RoomPage
          roomId={selectedRoom.id}
          roomName={selectedRoom.name}
          onBack={() => setSelectedRoom(null)}
        />
      </>
    );
  }

  return (
    <>
      {header}
      <HotelsPage
        onSelectRoom={(id, name) => setSelectedRoom({ id, name })}
      />
    </>
  );
}

export default App;
