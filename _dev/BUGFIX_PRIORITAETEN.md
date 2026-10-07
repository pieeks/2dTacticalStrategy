# Bugfix / Tech Debt — Prioritätenliste

Abhak-Liste für bekannte Probleme. Reihenfolge: P0 zuerst, dann P1, dann P2.

## P0 — Kritisch (Gameplay / Multiplayer kaputt)

- [x] **NPC Sleep/Wake Off-by-One** — `scripts/characters/npc_character.gd`  
  `go_to_sleep()` nicht in `_ready()` mit Bubble-Decrement aufrufen; Zähler nur bei echten Enter/Exit ändern.

- [x] **Client „Level ready“ vor Level-Load** — `scripts/world/overworld.gd`  
  `notify_server_level_ready()` erst **nach** `_load_level()` (und ggf. Level-Init) auslösen.

- [x] **Charakter-IDs nicht eindeutig** — `scripts/ui/character_creation.gd`  
  Echte GUID/UUID statt `"player_guid_1234" + Name`; leere Namen und unsichere Pfadzeichen abfangen.

- [x] **Charakterliste kann crashen** — `autolaod/player_party_state.gd`  
  `members[0]` absichern; `update_unix` aus korrektem Meta-Feld lesen.

## P1 — Mittel (fragil / falsches Verhalten)

- [x] **`load_form_disk` umbenennen** → `load_from_disk` (Callers mitziehen) — `player_party_state.gd` + `world_selection.gd`

- [x] **`party_data`-Default korrigieren** — nicht `{"x","y"}`, sondern leere Party-Struktur / `{}`

- [x] **Join-IP in der UI** — nicht hart `127.0.0.1`; Eingabe/Dialog für Host-Adresse

- [x] **Network-Lifecycle Reset** — beim Verlassen der Session: Peer schließen, `_ready_peers` leeren, `is_host` zurücksetzen

- [x] **Authority-Check bei Position-RPC** — `character_sync.gd` `rpc_sync_position` nur von Authority akzeptieren

- [x] **Position-Typ in `CharacterSave` vereinheitlichen** — immer Dictionary `{x,y}` (oder immer `Vector2`)

- [x] **NPC-Spawn-Pfad klären** — `levelLoadManager`/`biom_1` vs. `npc_spawner.gd`: einen produktiven Weg behalten, Rest entfernen oder klar markieren

## P2 — Klein (Cleanups / Naming)

- [ ] Ordner `autolaod/` → `autoload/` (Referenzen in `project.godot` + Imports anpassen)

- [ ] Tippfehler `Specificatioins` → `Specifications` (Scene/Node/Dateien)

- [ ] Naming: `class_name NetworkManager` vs. Autoload `NetworkManagerTest` angleichen

- [ ] `match`-Duplikat `LOOP` in `npc_character.gd` `wake_up()` entfernen

- [x] `confirmation_join_dialog.gd` implementieren oder toten Code entfernen

- [ ] Unbenutzte `LEVEL_SCENE_PATH` / Testscene-Konstante in `main_menu.gd` aufräumen

- [ ] Steam-Dateien klar als WIP markieren oder aus dem aktiven Flow halten

## Empfohlene Reihenfolge

1. NPC Sleep/Wake
2. Overworld Ready-Handshake
3. Charakter-GUID + Listen-Crash
4. Network-Reset + Join-IP
5. RPC Authority + Save-Typen
6. Naming/Tippfehler-Cleanups
