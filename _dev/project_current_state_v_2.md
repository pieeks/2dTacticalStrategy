# Project Current State (v2)

Stand: Hex-Kampf-Prototyp spielbar (Host + Client), Stand nach PLAN §1–§8.

## Bereits vorhanden

- **Ordnerstruktur** (assets, features, resources, scenes, scripts, `_dev`)
- **Multiplayer Core**
  - ENet P2P Host/Client, MultiplayerSpawner, Lobby
  - Debug Overlay F3 (Peer-Info, In Fight, aktive Fight-Owners, Start/Join/Leave)
- **Overworld**
  - Player-Bewegung + Appearance-Sync
  - NPCs mit Specs unter `resources/npcs/` (z. B. Slime)
  - Force-Fight → Host startet Kampf; NPC bleibt sichtbar und gelockt
- **Kampf (Hex, turn-basiert)**
  - Fight-Instanzen unter `Overworld/FightLayer` (kein Scene-Wechsel)
  - Zwei Nodes: World-Player gated + `BattleCharacter` im Fight
  - Host-autoritativ: Start / Join / Leave / Destroy + Late-Join-Sync
  - `GridManager` (Hex + AStar2D), Move / Attack / Wait, Enemy-AI
  - Join: E auf kämpfenden Peer **oder** fight-locked NPC → Join-Menü (Ally queued)
  - Stats aus NPC-JSON + Party-Placeholder; `group_size` aus Spec
  - Free-Cam im Fight (Zoom 0.8); Overworld-Kamera unverändert
  - Absicherung: Request-RPCs Server-only; Broadcasts Host-Sender-Guard; Disconnect-Cleanup
- **UI**: Charaktererstellung, World Selection, Settings, ESC (Quit + Autosave), PlayerUi
- **Persistenz**: `PlayerPartyState` Autosave (45 s Intervall + Quit / WM_CLOSE / Session-Ende)

## Bewusst später / offen

- Encounter-Symbol über Gegner; Loot-UI
- Party-Multi-Unit (v1 = 1 Avatar pro Peer)
- Koop-Start / PvP-Join-Seiten
- Dungeons mit mehreren Ebenen
- Steam P2P produktiv

## Nächste sinnvolle Schritte

1. Kurztest-Checkliste in `PLAN_KAMPFSYSTEM_GRID.md` §8 manuell durchspielen
2. Polish: Encounter-Symbole, Loot-Placeholder
3. Small Scope Overworld/Dungeon erweitern
4. Steamworks-Migration wenn Scope stabil

## Verweise

- Kampfsystem-Plan: [`PLAN_KAMPFSYSTEM_GRID.md`](PLAN_KAMPFSYSTEM_GRID.md)
- README (aktueller Feature-Überblick)
