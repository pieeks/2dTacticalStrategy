# 2DStrategyTacticalGame

2D-Multiplayer-RPG mit eigenständigen Partys und Hex-Grid-Kampf-Prototyp. Entwickelt mit **Godot 4.7** und **GDScript** (Viewport 640×360, Stretch `canvas_items`).

Jeder Spieler steuert eine eigene Gruppe (Quests, Inventar, Fortschritt). Geplante Modi: autark, Koop und Rivalen. Design und Kampfsystem-Plan: [`_dev/`](_dev/).

## Features

### Vorhanden

**Multiplayer**

- ENet-Lobby: Host erstellen und Client joinen (Port `4242`, max. 6 Spieler)
- Peer-Signale: Connect/Disconnect, Ready-Handshake, Late-Join-Erkennung
- `MultiplayerSpawner` für Spieler-Spawn nach Ready
- Positions-Sync für Spieler und NPCs
- Host-Quit-/Disconnect-Teardown und Late-Join Appearance/Pose-Sync

**Charakter & Party**

- Idle-/Walk-State-Machine für Spieler
- Charaktererstellung: Rasse, Haare, Körper, Beine (modulares Appearance)
- Charakterliste: gespeicherte Charaktere auswählen
- Party-State-Autoload mit Speichern/Laden (`user://saveGames/`)
- Appearance wird aus Save-Daten auf den Character angewendet

**Welt & NPCs**

- Overworld lädt Level (Standard: Biom 1)
- NPC-Spawning über Path2D oder Spawn-Areas
- Patrol-Verhalten (Pfad folgen / Ping-Pong)
- Aggro- und Force-Fight-Areas an hostile NPCs
- Activation-Areas am Spieler für NPC-Nähe/Interaktion
- World-State-Autoload für Welt-Saves (Städte/Dungeons/Events vorbereitet)

**Kampf (Hex-Grid-Prototyp)**

- Fight-Instanzen unter Overworld-`FightLayer` (kein Scene-Wechsel)
- Zwei Nodes: World-Player (während Fight gated) + `BattleCharacter` im Fight
- Host-autoritativer Lifecycle: Start / Join / Leave / Destroy + Late-Join-Sync
- Hex-`GridManager` (`AStar2D`), Reachable-Highlights, WASD-Kamera-Pan
- Turn-basiert: Initiative-Order, Move / Attack / Wait (Host validiert, Clients requesten)
- Simple Enemy-AI auf dem Host; minimales Fight-HUD (aktives Unit, Attack/Wait)
- Force-Fight: Encounter startet Kampf; Overworld-NPC bleibt sichtbar und gelockt
- Sieg entfernt den Overworld-NPC; Niederlage/Leave unlockt ihn wieder
- Parallele Fights räumlich isoliert (nur Teilnehmer sehen ihren Kampf)
- Placeholder-Gegner im Fight aus NPC-Spec-Daten

**UI**

- Hauptmenü → Charakter → World Selection → Host/Join → Overworld
- Settings: Audio (Lautstärke), Video (Auflösung, Vollbild), Controls (Rebinding)
- ESC-Menü: Fortsetzen, Optionen, Speichern & Beenden
- Interaktionsmenü bei NPCs (`PlayerUi`)
- UI-Skalierung für unterschiedliche Fenstergrößen

**Debug**

- Debug-Overlay (F3): Netzwerkinfo + Start / Join / Leave Fight
- Dev-Testscenes unter `_dev/tests/`
- Kampfsystem-Plan: [`_dev/PLAN_KAMPFSYSTEM_GRID.md`](_dev/PLAN_KAMPFSYSTEM_GRID.md)

### Geplant / in Arbeit

- Encounter-Symbol über Gegner; Loot-UI
- Verstärkung / Party-Multi-Unit im Fight
- Dungeons mit mehreren Ebenen
- Steam P2P (Addons vorbereitet, noch nicht produktiv)

## CI

GitHub Actions auf `main`: GDScript-Lint (`gdtoolkit`) und Headless-Projektcheck mit Godot 4.7.

## Voraussetzungen

- [Godot 4.7](https://godotengine.org/) (Projekt-Feature-String: `4.7`)

## Starten

1. Godot 4.7 öffnen und den Projektordner importieren bzw. öffnen.
2. Mit **F5** / Play starten. Main Scene: `scenes/ui/main_menu.tscn`.
3. Ablauf: Hauptmenü → Charakter erstellen/wählen → World Selection → Host oder Join → Overworld.

Lokal joinen: `127.0.0.1:4242`.

Kampf testen: Hostile NPC (z. B. Slime) berühren (Force-Fight) oder F3 → Start/Join/Leave Fight.

## Steuerung

| Aktion              | Standard     |
|---------------------|--------------|
| Bewegung (Overworld)| WASD         |
| Interaktion         | E            |
| Debug-Overlay       | F3           |
| Kampf: Move/Ziel    | Linksklick (nur im eigenen Zug) |
| Kampf: Attack/Wait  | HUD-Buttons                     |
| Kampf: Kamera-Pan   | WASD                            |

Tasten können in den Control-Settings neu belegt werden (`left_click` für Grid-Aktionen).

## Projektstruktur

```
├── scenes/       # UI, Charaktere, Welt / Level, battle/
├── scripts/      # GDScript (battle, characters, ui, world)
├── autoload/     # Autoloads (Globals, Party/World State, Network)
├── features/     # Spawner, Debug, Character-Parts
├── resources/    # Themes, Tilesets, NPC-Daten, Input-Helper
├── assets/       # Art, Fonts, UI
├── addons/       # GodotSteam, steam-multiplayer-peer
└── _dev/         # Design-Docs, Kampfplan, Status, Testscenes
```

## Multiplayer & Addons

- **Aktiv:** ENet über Autoload `NetworkManagerTest` (`autoload/network_manager_test.gd`)
- **Vorbereitet:** GodotSteam und [steam-multiplayer-peer](addons/steam-multiplayer-peer/) (noch nicht angebunden)
- **Steam-WIP-Skripte:** [`_dev/steam_wip/`](_dev/steam_wip/) (nicht als Autoload aktiv)

Status und Roadmap: [`_dev/project_current_state_v_2.md`](_dev/project_current_state_v_2.md), Design: [`_dev/rpg_multiplayer_design_v_2.md`](_dev/rpg_multiplayer_design_v_2.md), Kampf-Abhakliste: [`_dev/PLAN_KAMPFSYSTEM_GRID.md`](_dev/PLAN_KAMPFSYSTEM_GRID.md).

## Lizenz

Die Projektlizenz ist noch offen. Enthaltene Third-Party-Komponenten haben eigene Lizenzen (z. B. steam-multiplayer-peer: MIT, Playfair-Font: SIL OFL).
