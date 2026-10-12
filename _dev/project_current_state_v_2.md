# Project Current State (v2)

Stand: Hex-Kampf-Prototyp spielbar; Quest-System v1 (Demo-Quest, Accept/Turn-in, F3-Cheats).

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
  - Stats aus NPC-JSON + Party-Placeholder; Host-`enemy_roster` (`units[]` / `encounter_id` / `group_size`-Fallback)
  - Free-Cam im Fight (Zoom 0.8); Overworld-Kamera unverändert
  - Absicherung: Request-RPCs Server-only; Broadcasts Host-Sender-Guard; Disconnect-Cleanup
- **UI**: Charaktererstellung, World Selection, Settings, ESC (Quit + Autosave), PlayerUi
- **Persistenz**: `PlayerPartyState` Autosave (45 s Intervall + Quit / WM_CLOSE / Session-Ende); inkl. `quest_data`
- **Quests (v1)**: `QuestManager`, Demo `q_intro_slime` an `test_npc_basic`, Accept/Turn-in-UI, Quest-Log, kill/talk/reach, F3-Cheats; Group-Sync Stub

## Begriffe (Party / Group / Encounter)

- **Party** — ein Spieler: Main + Gefährten (`PlayerPartyState.party_data`)
- **Group** — mehrere Spieler-Partys in einer Session (Koop; geplant: `GroupManager`)
- **Encounter** — Map-Anker → Kampf-Roster (`units[]`; Ordner `resources/encounters/`)

## Bewusst später / offen

- Encounter-Symbol über Gegner; Loot-UI
- Party-Multi-Unit (v1 = 1 Avatar pro Peer)
- Story-/Klassen-Quests + Biom-Gates; Gruppen-Progress-Sync
- Koop-Start / PvP-Join-Seiten
- Dungeons mit mehreren Ebenen
- Steam P2P produktiv

## Nächste sinnvolle Schritte

1. Party / Group / Encounter nach [`PLAN_PARTY_GROUP_ENCOUNTER.md`](PLAN_PARTY_GROUP_ENCOUNTER.md)
2. Kurztest-Checkliste in `PLAN_QUESTSYSTEM.md` manuell durchspielen
3. Polish: Encounter-Symbole, Loot-Placeholder
4. Steamworks-Migration wenn Scope stabil

## Verweise

- Kampfsystem-Plan: [`PLAN_KAMPFSYSTEM_GRID.md`](PLAN_KAMPFSYSTEM_GRID.md)
- Quest-Plan: [`PLAN_QUESTSYSTEM.md`](PLAN_QUESTSYSTEM.md)
- Party/Group/Encounter: [`PLAN_PARTY_GROUP_ENCOUNTER.md`](PLAN_PARTY_GROUP_ENCOUNTER.md)
- README (aktueller Feature-Überblick)
