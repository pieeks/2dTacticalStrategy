# Plan — Quest-System

Abhak-Liste für das nächste große Feature nach dem Hex-Kampf-Prototyp: **Quest-Lifecycle** in **2dTaticalStrategy**.

Bezug:
- Design: [`rpg_multiplayer_design_v_2.md`](rpg_multiplayer_design_v_2.md) (Party-Quests, Gilde später; Global vs. Party)
- Persistenz: `PlayerPartyState` (`user://saveGames/…/save.json`, Autosave)
- Interaktion: `PlayerUi` (Talk / **Quest**-Button vorhanden), NPC-Specs unter `resources/npcs/`
- i18n: spieler-sichtbare Texte → `localization/translations.csv` + `tr()` (Debug ausgenommen)

Reihenfolge: Definition → Vergabe an NPC/Objekt → Annehmen → Ziele → UI → Abschluss → Abgabe + Belohnung.

---

## 0. Architektur-Entscheidungen (vor Code)

### Vorschlag (v1 — festzuhalten beim Start)

| # | Thema | Entscheidung |
|---|--------|--------------|
| 1 | Quest-Scope v1 | **Party-spezifisch** (pro lokalem Spieler / `PlayerPartyState`); globale/World-Quests später |
| 2 | Autorität | **Lokal authoritative** für eigenen Quest-Fortschritt (wie Inventar/Save); Host muss fremde Rewards nicht syncen in v1 |
| 3 | Definition | **Daten-getrieben**: JSON unter `resources/quests/` (+ optionale Resource-Wrapper) |
| 4 | Laufzeit | Autoload **`QuestManager`** (laden, annehmen, Progress, complete, turn-in, Rewards) |
| 5 | Persistenz | Active/Completed-Liste in **`PlayerPartyState`** (Autosave übernimmt Schreiben) |
| 6 | Vergabe | NPC/Objekt trägt `quest_id`(s) in Spec / Export; Interaktion → Accept-UI |
| 7 | Ziele v1 | Mindestens **Talk-to-NPC**, **Kill-Count** (Encounter/Fight-Ende), **Reach-Marker** (Area2D); erweiterbar |
| 8 | UI | Quest-Log (PlayerUi HUD-Liste), Accept/Turn-in Dialog, kurze Tracker-Zeile optional |

- [ ] Entscheidungen §0 im Team kurz bestätigen (Tabelle oben)
- [ ] Ordner anlegen: `resources/quests/`, `scripts/quest/`, `scenes/ui/quest/` (oder unter `scenes/ui/`)

---

## 1. Allgemeine Definition — Object / Scene / Backend

Ziel: Eine Quest ist **Content (JSON)** + **Runtime-State** + optional **World-Anker** (NPC/Objekt/Area).

### 1.1 Content-Schema (Object / JSON)

Beispiel `resources/quests/q_intro_slime.json`:

```json
{
  "id": "q_intro_slime",
  "title_key": "quest.q_intro_slime.title",
  "description_key": "quest.q_intro_slime.desc",
  "giver_npc": "test_npc_basic",
  "turn_in_npc": "test_npc_basic",
  "objectives": [
    { "id": "kill_1", "type": "kill", "target": "slime_basic", "count": 1, "text_key": "quest.q_intro_slime.obj.kill" }
  ],
  "rewards": {
    "gold": 10,
    "items": []
  }
}
```

- [ ] Schema dokumentieren (Pflichtfelder: `id`, `title_key`, `objectives[]`, `rewards`)
- [ ] Mindestens **1 Demo-Quest**-JSON anlegen
- [ ] Alle sichtbaren Strings als Keys in `localization/translations.csv` (`quest.*`)

### 1.2 Backend (`QuestManager`)

- [ ] Autoload `QuestManager` in `project.godot`
- [ ] API (Skizze):
  - `load_definitions()` — alle `resources/quests/*.json`
  - `get_definition(quest_id) -> Dictionary`
  - `can_accept(quest_id) -> bool`
  - `accept(quest_id) -> bool`
  - `get_active() / get_completed() -> Array`
  - `report_progress(event: Dictionary)` — z. B. `{ "type": "kill", "target": "slime_basic", "amount": 1 }`
  - `is_ready_to_turn_in(quest_id) -> bool`
  - `turn_in(quest_id) -> bool` — Rewards + Status
- [ ] Status-Enum: `inactive` | `active` | `ready` | `completed` (optional `failed` später)
- [ ] Signal `quests_changed` für UI-Refresh

### 1.3 Persistenz

- [ ] `PlayerPartyState`: Feld z. B. `quest_data = { "active": {}, "completed": [] }`
- [ ] In `save_to_disk` / `load_from_disk` aufnehmen
- [ ] Nach Accept / Progress / Turn-in: State aktualisieren (Autosave-Intervall reicht; optional sofort `try_autosave("quest")`)

### 1.4 Scene / World-Anker (optional v1)

- [ ] `QuestMarker` / `QuestObjectiveArea` (Area2D) für Reach-Ziele
- [ ] Giver bleibt primär bestehender **NPC** (kein neuer Scene-Typ nötig)

---

## 2. Quest an NPC / Objekt zum Vergeben anhängen

- [ ] NPC-Spec erweitern, z. B. `"quests": { "offer": ["q_intro_slime"], "turn_in": ["q_intro_slime"] }`
- [ ] Alternativ/zusätzlich: Interactable-Objekt mit Export `quest_ids: PackedStringArray`
- [ ] Interaction-Flow: bei E / Talk-Menü prüfen, ob Offer oder Turn-in verfügbar
- [ ] `PlayerUi`-Button **Quest** verdrahten (nicht nur Stub): öffnet Offer-/Turn-in-Panel wenn möglich
- [ ] Kein Offer, wenn Quest schon active/completed (außer Repeat später)

---

## 3. Quest annehmen

- [ ] Accept-Dialog / Panel: Titel, Beschreibung (`tr(title_key)` / `tr(desc_key)`), Accept / Decline
- [ ] `QuestManager.accept(id)` → Eintrag in `quest_data.active` mit Objective-Progress `0`
- [ ] UI aktualisieren (Log + optional Tracker)
- [ ] Feedback kurz (Statuszeile / Dialog schließen) — Toast optional später

---

## 4. Quest-Ziel definieren

Zieltypen v1 (erweiterbar über `type`-String):

| type | Bedeutung | Progress-Quelle |
|------|-----------|-----------------|
| `talk` | Mit NPC `target` sprechen | Interaction Talk |
| `kill` | `count` von `target` (npc_type / spec name) | Fight-Sieg / NPC remove |
| `reach` | Area / Marker `target` betreten | `QuestObjectiveArea` |

- [ ] Objective-Runtime: `{ "id", "type", "target", "count", "current", "done" }`
- [ ] `report_progress` matched active Quests und setzt `done` / Quest → `ready`
- [ ] Hook Fight-Ende (Sieg): Kill-Event für Encounter-`npc_type`
- [ ] Hook Interaction: Talk-Event
- [ ] Hook Area: `body_entered` nur lokaler Player

---

## 5. UI erstellen

Vorhandene Anker nutzen: PlayerUi HUD `Quests` ItemList, Interaction `Quest`-Button.

- [ ] **Quest-Log**: Liste aktiver Quests + Kurzziele (erfüllt / offen)
- [ ] **Detail** (einfach): ausgewählte Quest Beschreibung + Objectives
- [ ] **Accept-Panel** (Vergabe)
- [ ] **Turn-in-Panel** (Abgabe + Rewards-Vorschau)
- [ ] Alle Labels/Buttons über `tr()` + CSV
- [ ] Bei `quests_changed` / `LocaleManager.language_changed` Texte refreshen
- [ ] Debug (F3): optional Quest accept/complete cheat — **Englisch, ohne CSV**

---

## 6. Ziel abschließbar machen

- [ ] Progress nur zählen, wenn Quest `active` und Objective noch nicht `done`
- [ ] Mehrere Objectives: Quest erst `ready`, wenn **alle** done (v1 AND-Logik)
- [ ] Idempotent: doppelte Events nicht über `count` hinauszählen
- [ ] Nach Ready: Giver/Turn-in-NPC zeigt Abgabe an (UI-Hinweis / Button aktiv)

---

## 7. Quest abgeben + Belohnung zuweisen

- [ ] Turn-in nur am konfigurierten `turn_in_npc` / Objekt und nur wenn `ready`
- [ ] `turn_in`: Status → `completed`, aus `active` entfernen, in `completed` listen
- [ ] Rewards anwenden:
  - Gold → `PlayerPartyState.inventory_data` (Struktur anlegen falls leer: `{ "gold": 0, "items": [] }`)
  - Items → Placeholder-Array (echtes Item-System später)
- [ ] UI: Belohnung anzeigen, Log aktualisieren
- [ ] Persistenz: State gespeichert (Autosave / optional sofort)

---

## Empfohlene Reihenfolge (Sprint-Schnitt)

1. ~~§0 Entscheidungen~~ → bestätigen + Ordner
2. §1 Definition + `QuestManager` + Persistenz + 1 Demo-JSON
3. §2 NPC-Spec Offer/Turn-in + Interaction-Hook
4. §3 Annehmen (Panel + State)
5. §4 Zieltypen + `report_progress` Hooks (Talk / Kill / Reach)
6. §5 Quest-Log UI
7. §6 Ready-Logik absichern
8. §7 Turn-in + Rewards
9. Kurztest-Checkliste (unten) manuell durchspielen
10. README / `project_current_state_v_2.md` aktualisieren

---

## Nicht in v1

- Globale / Server-weite Quests (WorldState)
- Koop-geteilte Quest-Progress-Sync zwischen Peers
- Quest-Ketten / Branching Dialoge
- Volles Item-/Equip-System
- Gilden-UI als Quest-Hub (Design: später Stadt-Popup)
- Daily/Repeatable Quests

---

## Kurztest-Checkliste

- [ ] NPC mit Offer → Accept → Quest erscheint im Log
- [ ] Ziel Talk / Kill / Reach jeweils einmal erfüllbar
- [ ] Nach allen Objectives: Status ready, Turn-in möglich
- [ ] Turn-in vergibt Gold (Inventory sichtbar/änderbar im Save)
- [ ] Nach Reload/Autosave: Active/Completed korrekt
- [ ] Sprache wechseln → Quest-UI-Texte folgen CSV
- [ ] Zweite Annahme derselben Quest blockiert
- [ ] (Optional) Zwei Peers: jeder hat eigene Quest-Liste (kein Sync nötig)

---

## Definition of Done (erster spielbarer Quest-Loop)

- [ ] Spieler kann bei einem NPC eine Demo-Quest annehmen
- [ ] Mindestens ein Zieltyp ist im Spiel erfüllbar
- [ ] Quest kann abgegeben werden und Rewards landen in `PlayerPartyState`
- [ ] Fortschritt überlebt Autosave / Quit
- [ ] Keine hardcodierten spieler-sichtbaren Quest-Strings (CSV/`tr()`)

---

## Verweise

- Design: [`rpg_multiplayer_design_v_2.md`](rpg_multiplayer_design_v_2.md)
- Kampfplan (Stil/Abhak-Muster): [`PLAN_KAMPFSYSTEM_GRID.md`](PLAN_KAMPFSYSTEM_GRID.md)
- Coding-Rules: [`.cursor/rules/godot-coding-standards.mdc`](../.cursor/rules/godot-coding-standards.mdc)
