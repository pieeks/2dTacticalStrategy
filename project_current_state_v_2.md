# Project Current State (v2)

## ✅ Bereits vorhanden
- **Ordnerstruktur** (assets, features, resources, scenes, etc.)
- **Multiplayer Core**:
  - ENet P2P Verbindung Host <-> Client
  - Multiplayer Spawner (Player-Spawn)
  - Lobby mit Buttons (Host, Join)
  - Debug Overlay (Peer-IDs, Spieleranzahl, IDs)
- **Player**:
  - Idle & Walk States (node_state.gd, node_state_machine.gd)
  - Bewegung sync funktioniert (x/y)
- **Testscenes** zum Ausprobieren

---

## 🔄 Neu hinzugekommen (Update)
- **Overworld-Planung**:
  - 1 Scene pro Biom (z. B. Steppe, Schnee)
  - Städte = Popup UI (Shop, Schmiede, Gilde)
  - Globaler Quest Manager geplant
- **Dungeon-Planung**:
  - 1 Scene pro Ebene
  - Erweiterbar (mehr Ebenen/Biome möglich)
  - Encounter-Symbole über Gegner (Kampf-Trigger)
- **Kampfsystem (Planung)**:
  - Grid-basiert (Tilemap)
  - Turn Order
  - Actions: Move, Attack, Wait
  - Verstärkungen (andere Spieler können Kämpfen beitreten)
- **Party-System**:
  - Jeder Spieler = eigene Gruppe (autark)
  - Option: Zusammenschluss zu Party (Koop)
  - Option: Rivalen (Gegeneinander, eigene Quests)
- **Technik**:
  - 2D-Only Fokus → Import Settings (Filter Off, Nearest, No Mipmaps)
  - Projekt läuft auf Linux (Manjaro), Vulkan-Renderer
- **Steamworks Ziel**:
  - Sobald Small Scope fertig → Umstieg auf Steam P2P
  - Vorteil: NAT Traversal, Friend Invites, Beta-Testing

---

## 🎯 Small Scope Ziel (Milestone)
- Overworld mit 1 Biom + 1 Stadt (Popup)
- 1 Dungeon mit 2–3 Ebenen
- 1 Battle Scene (Grid, Basic Actions)
- Party-System (Host/Client = autarke Gruppen)
- ENet Multiplayer stabil
- Danach Umstieg: Steamworks P2P

---

## 📌 Nächste Schritte
1. Overworld Scene + Stadt-Popup (UI)
2. Party-State ins Autoload packen
3. Dungeon Scene mit Ebenen bauen
4. Encounter-Symbole implementieren
5. Battle-Prototype starten (Grid, Turn-Order)
6. Small Scope fertigstellen → Steamworks Migration

