# RPG Multiplayer Design (v2)

## 🎮 Core Konzepte
- **Spieler = Gruppe** (Party mit mehreren Charakteren)
- **Autarkes Spielen**:
  - Spieler können unabhängig durch die Welt laufen
  - Jeder hat eigene Quests, Inventar, Fortschritt
- **Koop-Modus**:
  - Parteien können sich zusammenschließen
  - Innerhalb eines Bereichs: Kämpfe & Quests gemeinsam starten
- **Rivalen-Modus**:
  - Parteien bleiben getrennt
  - Eigene Quests, eigener Fortschritt
  - Optional: PvP oder indirekter Wettbewerb

---

## 🌍 Overworld
- 1 Scene pro Biom (z. B. Steppe, Schnee, Wald)
- Städte = Popup UI (Bild + Buttons → Shop, Gilde, Schmiede)
- Gilde = Quest-Hub
- Quests können **global** oder **party-spezifisch** sein

---

## 🏰 Dungeon Design
- Dungeon = mehrere Szenen (1 Scene = 1 Ebene)
- Erweiterbar → neue Ebenen oder Biome jederzeit möglich
- Encounter-Symbole über Gegner → Kampf kann gestartet werden
- Multiplayer: Spieler sehen, wer im Dungeon kämpft

---

## ⚔️ Kampfsystem
- **Grid-basiert (Tilemap)**
- **Turn-Order** basierend auf Initiative
- **Aktionen**: Move, Attack, Wait (Basis)
- **Verstärkungen**:
  - Spieler können Kämpfen beitreten (z. B. nächste Runde)
  - Wahl: Verstärkung einer Seite oder neutrales Eingreifen
- **Koop-Kampf**: Gemeinsamer Start, wenn Parteien im selben Bereich
- **Rivalen-Kampf**: Direkter PvP oder konkurrierende Kämpfe

---

## 🔗 Networking
- **Aktuell**: ENet P2P (funktionierend, Lobby + Spawner)
- **Debug-Tools**: Debug Overlay (Peer-IDs, Spieleranzahl)
- **Später**: Steamworks API
  - P2P Verbindungen über Steam Friends
  - Lobby & Invites integriert
  - Vorteil: NAT Traversal, vereinfachtes Testing

---

## 📦 Datenmodell (erweitert)
- **PlayerParty**
  - ID (peer_id)
  - Characters (Array)
  - Inventory
  - ActiveQuests
  - Position (Overworld/Dungeon)
- **Quest**
  - ID
  - Type: Global / Party
  - Status: NotStarted / Active / Completed / Failed
- **BattleInstance**
  - ID
  - Participants (Players + Enemies)
  - TurnOrder
  - Reinforcements (Queue)

---

## 🛠️ Ablaufplan
1. Multiplayer Core stabilisieren (Lobby, Spawner, Movement Sync)
2. Overworld implementieren (Biom Scene, Stadt Popup, Party-State)
3. Dungeon-System mit Ebenen bauen
4. Encounter-Symbole für Kämpfe einführen
5. Battle-Prototype (Grid + Turn-Order + Basic Actions)
6. Verstärkungsmechanik für Multiplayer-Kämpfe
7. Questsystem (global + party-spezifisch)
8. Steamworks Integration → P2P über Steam

