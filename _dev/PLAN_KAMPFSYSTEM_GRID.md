# Plan — Taktisches Grid-Kampfsystem

Abhak-Liste für den nächsten großen Schritt: Grid-Kampf in **2dTaticalStrategy**, basierend auf dem Prototyp in **NewGameRepo** (`/home/raidho103/Projects/NewGameRepo`).

Bezug:
- Design: `_dev/rpg_multiplayer_design_v_2.md` (Turn-Order, Move/Attack/Wait, Verstärkung; Grid-Typ hier: **Hex**, abweichend vom alten „Tilemap“-Hinweis)
- Prototyp: NewGameRepo (`FightManager`, `FightTemplate`, `GridManager`, Grid-Movement)
- Trigger hier bereits vorhanden: Aggro- / Force-Fight-Areas

Reihenfolge: Voraussetzungen → Architektur-Entscheidung → Port Kampf-Rahmen → Grid → Trigger → Turn-Gameplay → Multiplayer-Features → Polish.

---

## 0. Voraussetzungen (Multiplayer-Stabilität)

Vor dem Kampf-Port die fragilen Stellen absichern — sonst bricht Late-Join/Fight-Sync leichter.

- [x] **Late-Join Appearance** — Host forderte `rpc_notify_peer_connected`; Client-Authorities senden Appearance per `rpc_id` an Joiner
- [x] **Ready/Spawn idempotent** — `_mark_ready` Early-Return; Spawner skip bei `players.has(peer_id)`
- [x] **Disconnect-Cleanup** — `server_disconnected` → `reset_session` + deferred Main Menu
- [x] **Signal-Connects** — disconnectbare Handler; `reset_session` trennt Signale vor Rejoin
- [x] **Host-Quit-Teardown** — Peer vor Scene-Wechsel schließen; RPC-Guards wenn kein Peer (`character_sync` / Position-Broadcast)
- [ ] **(Optional)** RPC-Sender-Checks für Appearance/Animation nachziehen

---

## 1. Architektur-Entscheidungen (vor Code)

### Festgehalten (2026-10-07)

| # | Thema | Entscheidung |
|---|--------|--------------|
| 1 | Grid-Typ | **Hex** (NewGameRepo-`GridManager` / `AStar2D` als Basis) |
| 2 | Kampf-Raum | **Eigene Fight-Instanz** unter Overworld-`FightLayer` (kein Scene-Wechsel) |
| 3 | Charaktere | **Zwei Nodes**: World-Char pausieren/verstecken + Battle-Char im Fight spawnen |
| 4 | Autorität | **Host-only** für Start/Ende/Join-Resolve; Clients nur Request-RPCs |
| 5 | Erste Trigger | **1) Debug-UI Start/Leave → 2) Force-Fight-Area → 3) später Encounter-Symbol** |

Hinweis: Design-Docs erwähnen noch „Tilemap“; für den Kampf-Prototype gilt bewusst **Hex**. Docs später angleichen.

- [x] **Grid-Typ festlegen** → Hex
- [x] **Kampf-Raum** → Fight-Instanz unter `FightLayer`
- [x] **Charaktere** → Zwei Nodes (World + Battle)
- [x] **Host-Autorität** → Host-only
- [x] **Quelle der Begegnung** → Debug-UI, dann Force-Fight, dann Encounter-Symbol
- [x] **Referenz-Pfade** aus NewGameRepo (nicht blind kopieren):
  - `scripts/fight_manager.gd`
  - `scripts/fights/fight_template.gd`
  - `scripts/fights/grid_manager.gd`
  - `scripts/movement/grid_movement.gd`
  - `scripts/movement/movement_controller.gd`

---

## 2. Kampf-Rahmen portieren (Lifecycle)

Ziel: Start / Join / Leave / Destroy + Late-Join-Sync, **ohne** Turn-Gameplay.

- [x] Ordner/Struktur anlegen z. B. `scripts/battle/`, `scenes/battle/`
- [x] **`FightManager`** (Host-Autorität) anlegen und unter Overworld einbinden
- [x] **`FightLayer`** in `overworld.tscn` (Container für Kampfinstanzen)
- [x] **`FightTemplate`**-Szene: Grid-Root, Participant-Liste, Character-Container, eigener `MultiplayerSpawner` falls nötig
- [x] RPCs: Start / Join / Leave / Destroy / Sync-für-Late-Joiner
- [x] Sichtbarkeit: Kampf nur für Teilnehmer sichtbar
- [x] World-Movement pausieren/blockieren solange Peer im Fight (`is_peer_in_fight`)
- [x] Nach Leave/End: World-Kamera / Steuerung wiederherstellen
- [x] Manuelles Test-UI (Debug: Start/Leave Fight) zum Validieren — später durch echte Trigger ersetzen

---

## 3. Grid & Bewegung

- [x] **`GridManager`** aus NewGameRepo portieren (**Hex** + `AStar2D`, Entscheidung §1)
- [x] Pfadfindung (`AStar2D` / TileMap-Nachbarschaft)
- [x] Grid-Visualisierung (Debug-Zeichnung oder Tile-Highlight)
- [x] **Grid-Movement**: Klick → Pfad → Bewegung (Authority-lokal, Sync wie im Prototyp)
- [x] Battle-Char an Grid koppeln (`grid_manager`-Referenz setzen beim Spawn)
- [x] Kamera-Verhalten im Kampf (Pan / Follow) definieren und umsetzen
- [x] Movement-Modus umschaltbar (Overworld vs. Grid) — Pattern aus `MovementController` oder Integration in bestehende States
  → erledigt durch Zwei-Node-Architektur (World-Player vs. BattleCharacter + GridMovement)

---

## 4. Overworld-Trigger anbinden

Vorhandene Hooks nutzen statt F-Menü allein.

- [x] **Force-Fight-Area** → Host startet Fight für betroffene Peers (`force_fight_area_2d.gd` / `aggro_controller.gd`)
- [x] Aggro-Controller: klar trennen „verfolgen“ vs. „Kampf starten“
- [x] Encounter-Daten mitgeben (NPC-Typ, Party, Position) an `FightManager.start_fight…`
- [x] Gegner im Fight aus NPC-/Spec-Daten spawnen (auch wenn Stats noch Placeholder)
- [x] Overworld-NPC während Fight: despawnen / locken / unsichtbar — Regel festlegen und umsetzen
  → **Locken, sichtbar lassen** (andere Peers sehen den Gegner in der Overworld)
- [ ] (Später) Encounter-Symbol über Gegner (Design-Doc Schritt 4)

---

## 5. Turn-basiertes Gameplay (Kern)

Erst wenn Rahmen + Grid stabil laufen.

- [x] **BattleInstance-Datenmodell**: ID, Participants, TurnOrder, State (`_dev/rpg_multiplayer_design_v_2.md`)
  → `BattleUnit` + `BattleTurnController` im FightTemplate
- [x] Initiative / Turn-Order berechnen (Host-autoritativ)
- [x] Turn-State-Machine: Waiting → ActiveUnit → Resolve → Next
- [x] Aktion **Move**: Reichweite, begehbare Kacheln, Pfad, Commit
- [x] Aktion **Attack**: Reichweite, Zielwahl, Schaden (erst simpel)
- [x] Aktion **Wait** / Ende Zug
- [x] UI: aktives Unit, erlaubte Aktionen, Tile-Highlights
- [x] Sync: Clients sehen nur Host-bestätigte Zustände (keine lokalen „Cheat“-Züge)
- [x] Kampfende: Sieg/Niederlage/Flucht → Rewards-Placeholder → zurück Overworld
  → Sieg entfernt Overworld-NPC; Niederlage/Leave unlockt; Loot = Print/TODO

---

## 6. Multiplayer-Kampf-Features

- [ ] **Join / Verstärkung**: Peer tritt laufendem Fight bei (nächste Runde / Queue laut Design)
- [ ] Mehrere parallele Fights (nicht nur „erstes Kind im Layer“)
- [ ] Late-Joiner der Session: aktive Fights korrekt nachziehen (`sync_active_fights_to_peer`)
- [ ] Koop-Start: Parteien im selben Bereich gemeinsam starten (nach Party-Regeln)
- [ ] (Später) Rivalen / PvP-Variante

---

## 7. Daten & Content (minimal lebensfähig)

- [ ] Battle-Stats am Charakter/NPC (HP, ATK, MOVE, Initiative) — auch wenn Placeholder
- [ ] Encounter-Definition (welche Gegner, wie viele) — Prefab oder Dictionary
- [ ] Ordner `data/` oder bestehende Specs erweitern (nicht leere `.gitkeep` wie in NewGameRepo)
- [ ] Party-Mitglieder im Kampf (nicht nur 1 Avatar) — Scope für v1 festlegen

---

## 8. Polish & Absicherung

- [ ] Disconnect eines Fight-Teilnehmers: sauber aus Participant-Liste / Fight beenden wenn Owner weg
- [ ] RPC: Start/Join/End nur Host-seitig ausführen; Requests von Clients validieren
- [ ] Keine doppelten Fight-Starts für denselben Peer
- [ ] Debug-Overlay: Peer im Fight? aktive Fight-IDs?
- [ ] Kurztest-Checkliste (2 Instanzen): Start → Move → Leave → Late-Join während Fight
- [ ] README / `_dev/project_current_state_v_2.md` aktualisieren wenn Prototype spielbar

---

## Empfohlene Reihenfolge (Sprint-Schnitt)

1. §0 kritische Multiplayer-Fixes (mindestens Appearance + idempotenter Spawn)
2. ~~§1 Entscheidungen~~ → erledigt (Hex, FightLayer, Zwei Nodes, Host-only, Debug→Force-Fight)
3. §2 Kampf-Rahmen + manuelles Debug-Start
4. §3 Hex-Grid-Bewegung im Fight
5. §4 Force-Fight-Trigger
6. ~~§5 Turn-Order + Move/Attack/Wait~~ → erledigt (Host-AI, HUD, Sieg/Niederlage)
7. §6 Join/Verstärkung
8. §7–§8 Daten + Absicherung

---

## Nicht aus NewGameRepo übernehmen

- Kompletter `NetworkManager` / Lobby (hier schon weiter)
- Roher Steam-P2P-Pfad
- Leerer Content-Layer als „fertig“
- Annahme „Kampf = nur gleichzeitige Grid-Bewegung“ — hier Ziel ist **turn-basiert**

---

## Definition of Done (erster spielbarer Kampf)

- [ ] Host und Client können über Force-Fight (oder Debug) in denselben Fight
- [ ] Beide sehen dasselbe Grid und können im eigenen Zug bewegen (oder v1: nur bewegen ohne Turns, klar als Zwischenziel markiert)
- [ ] Leave/End bringt beide zurück in die Overworld ohne kaputte Peer-State
- [ ] Late-Joiner der Session crasht nicht und sieht laufende Fights korrekt (oder bewusst: Fights erst nach Ready)
