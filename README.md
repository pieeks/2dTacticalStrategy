# 2DStrategyTaticGame

2D-Multiplayer-RPG mit eigenständigen Partys und geplantem taktischem Grid-Kampf. Entwickelt mit **Godot 4.5** und **GDScript** (Viewport 640×360, Stretch `canvas_items`).

Jeder Spieler steuert eine eigene Gruppe (Quests, Inventar, Fortschritt). Geplante Modi: autark, Koop und Rivalen. Details zum Design stehen unter [`_dev/`](_dev/).

## Features

### Vorhanden

**Multiplayer**

- ENet-Lobby: Host erstellen und Client joinen (Port `4242`, max. 6 Spieler)
- Peer-Signale: Connect/Disconnect, Ready-Handshake, Late-Join-Erkennung
- `MultiplayerSpawner` für Spieler-Spawn nach Ready
- Positions-Sync für Spieler und NPCs

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
- Aggro-, Action- und Force-Fight-Areas
- Activation-Areas am Spieler für NPC-Nähe/Interaktion
- World-State-Autoload für Welt-Saves (Städte/Dungeons/Events vorbereitet)

**UI**

- Hauptmenü → Charakter → World Selection → Host/Join → Overworld
- Settings: Audio (Lautstärke), Video (Auflösung, Vollbild), Controls (Rebinding)
- ESC-Menü: Fortsetzen, Optionen, Speichern & Beenden
- Interaktionsmenü bei NPCs (`PlayerUi`)
- UI-Skalierung für unterschiedliche Fenstergrößen

**Debug**

- Debug-Overlay (F3): Peer-ID, Host/Client, verbundene und ready Peers
- Dev-Testscenes unter `_dev/tests/`

### Geplant / in Arbeit

- Taktisches Grid-Kampfsystem (Tilemap, Turn Order, Move/Attack/Wait)
- Dungeons mit mehreren Ebenen
- Steam P2P (Addons vorbereitet, noch nicht produktiv)

## Voraussetzungen

- [Godot 4.5](https://godotengine.org/) (Projekt-Feature-String: `4.5`)

## Starten

1. Godot 4.5 öffnen und den Projektordner importieren bzw. öffnen.
2. Mit **F5** / Play starten. Main Scene: `scenes/ui/main_menu.tscn`.
3. Ablauf: Hauptmenü → Charakter erstellen/wählen → World Selection → Host oder Join → Overworld.

Lokal joinen: `127.0.0.1:4242`.

## Steuerung

| Aktion        | Standard |
|---------------|----------|
| Bewegung      | WASD     |
| Interaktion   | E        |
| Debug-Overlay | F3       |

Tasten können in den Control-Settings neu belegt werden.

## Projektstruktur

```
├── scenes/       # UI, Charaktere, Welt / Level
├── scripts/      # GDScript (characters, ui, world)
├── autolaod/     # Autoloads (Globals, Party/World State, Network)
├── features/     # Spawner, Debug, Character-Parts
├── resources/    # Themes, Tilesets, NPC-Daten, Input-Helper
├── assets/       # Art, Fonts, UI
├── addons/       # GodotSteam, steam-multiplayer-peer
└── _dev/         # Design-Docs, Status, Testscenes
```

## Multiplayer & Addons

- **Aktiv:** ENet über Autoload `NetworkManagerTest` (`autolaod/network_manager_test.gd`)
- **Vorbereitet:** GodotSteam und [steam-multiplayer-peer](addons/steam-multiplayer-peer/) (noch nicht angebunden)

Status und Roadmap: [`_dev/project_current_state_v_2.md`](_dev/project_current_state_v_2.md), Design: [`_dev/rpg_multiplayer_design_v_2.md`](_dev/rpg_multiplayer_design_v_2.md).

## Lizenz

Die Projektlizenz ist noch offen. Enthaltene Third-Party-Komponenten haben eigene Lizenzen (z. B. steam-multiplayer-peer: MIT, Playfair-Font: SIL OFL).
