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
| 1 | Quest-Scope v1 | Alle Quests **pro Spieler** in `PlayerPartyState`. Kategorien z. B. `side` / später `story` / `class` („globale“ = Story/Klassen-Fortschritt **des Spielers**, nicht Lobby-WorldState) |
| 2 | Autorität / Sync | Fortschritt v1 **lokal**. Gemeinsamer Progress **nur in einer Gruppe** — Gruppensystem fehlt → Sync in v1 nur **Stub/API vorbereitet**, nicht aktiv |
| 3 | Definition | **Daten-getrieben**: JSON unter `resources/quests/` (+ optionale Resource-Wrapper) |
| 4 | Laufzeit | Autoload **`QuestManager`** (laden, annehmen, Progress, complete, turn-in, Rewards; Group-Sync-Hook Stub) |
| 5 | Persistenz | Active/Completed-Liste in **`PlayerPartyState`** (Autosave übernimmt Schreiben) |
| 6 | Vergabe | Erster Anker: bestehender Overworld-NPC **`test_npc_basic`** (Biom1 `TestPath`); Spec trägt Demo-Quest |
| 7 | Ziele v1 | Mindestens **Talk-to-NPC**, **Kill-Count** (Encounter/Fight-Ende), **Reach-Marker** (Area2D); erweiterbar |
| 8 | UI | Interaction-Menü + **Quest**-Reiter/Button; Accept-Panel (Layout §3); Quest-Log |
| 9 | Debug | **F3-Quest-Cheats** (EN): Accept / Ready / Turn-in / Force Complete über QuestManager-API |

- [x] Entscheidungen §0 im Team kurz bestätigen (Tabelle oben)
- [x] Ordner anlegen: `resources/quests/`, `scripts/quest/`, `scenes/ui/quest/` (oder unter `scenes/ui/`)

---

## 1. Allgemeine Definition — Object / Scene / Backend

Ziel: Eine Quest ist **Content (JSON)** + **Runtime-State** + optional **World-Anker** (NPC/Objekt/Area).

### 1.1 Content-Schema (Object / JSON)

Beispiel `resources/quests/q_intro_slime.json`:

```json
{
  "id": "q_intro_slime",
  "category": "side",
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

`category`: v1 Demo = `side`. Später z. B. `story` / `class` für „globale“ Spieler-Story (Freischaltungen). **Nicht** mit geteiltem World-/Lobby-State verwechseln.

- [x] Schema dokumentieren (Pflichtfelder: `id`, `category`, `title_key`, `objectives[]`, `rewards`)
- [x] Mindestens **1 Demo-Quest**-JSON anlegen (`category: "side"`)
- [x] Query-Helfer vorbereiten: `has_completed(quest_id)`, `get_completed()` — Basis für spätere Biom-Gates
- [x] Alle sichtbaren Strings als Keys in `localization/translations.csv` (`quest.*`)

### 1.2 Backend (`QuestManager`)

- [x] Autoload `QuestManager` in `project.godot`
- [x] API (Skizze):
  - `load_definitions()` — alle `resources/quests/*.json`
  - `get_definition(quest_id) -> Dictionary`
  - `can_accept(quest_id) -> bool`
  - `accept(quest_id) -> bool`
  - `get_active() / get_completed() -> Array`
  - `report_progress(event: Dictionary)` — z. B. `{ "type": "kill", "target": "slime_basic", "amount": 1 }`
  - `is_ready_to_turn_in(quest_id) -> bool`
  - `turn_in(quest_id) -> bool` — Rewards + Status
- [x] Status-Enum: `inactive` | `active` | `ready` | `completed` (optional `failed` später)
- [x] Signal `quests_changed` für UI-Refresh
- [x] Group-Sync vorbereiten: `_peers_in_same_group(...)` Stub (v1 → immer `false`); `share_progress_with_group(event)` no-op — später Host-Relay nur an Gruppenmitglieder

### 1.3 Persistenz

- [x] `PlayerPartyState`: Feld z. B. `quest_data = { "active": {}, "completed": [] }`
- [x] In `save_to_disk` / `load_from_disk` aufnehmen
- [x] Nach Accept / Progress / Turn-in: State aktualisieren (Autosave-Intervall reicht; optional sofort `try_autosave("quest")`)

### 1.4 Scene / World-Anker (optional v1)

- [x] `QuestMarker` / `QuestObjectiveArea` (Area2D) für Reach-Ziele
- [x] Giver bleibt primär bestehender **NPC** (kein neuer Scene-Typ nötig)

---

## 2. Quest an NPC / Objekt zum Vergeben anhängen

**Ist-Zustand:** In der Overworld ist `test_npc_basic` ansprechbar. Das Interaction-Menü zeigt derzeit **Talk** (ohne Funktion) und **Leave**.

**Ziel v1:** Diesem NPC die Demo-Quest anhängen und einen **Quest**-Eintrag im Menü ergänzen.

- [x] NPC-Spec `resources/npcs/test_npc_basic.json` erweitern, z. B.  
  `"quests": { "offer": ["q_intro_slime"], "turn_in": ["q_intro_slime"] }`
- [x] Interaction-Menü (`PlayerUi`): Reihenfolge **Talk** | **Quest** | **Leave**
  - Talk bleibt vorerst Stub (oder später Dialog)
  - **Quest** nur sichtbar/aktiv, wenn Offer und/oder Turn-in für den lokalen Spieler möglich ist
  - Leave unverändert
- [x] Quest-Button öffnet Accept-Panel (§3) bzw. Turn-in-Panel (§7), je nach State
- [x] Kein Offer, wenn Quest schon `active` / `completed` (Repeat später)
- [ ] Später optional: weitere NPCs/Objekte gleichermaßen über Spec / Export

---

## 3. Quest annehmen — Accept-UI

Panel öffnet sich über Interaction → **Quest** am Giver-NPC.

### Layout (von oben nach unten)

1. **Quest-Titel** (`tr(title_key)`)
2. **Beschreibung** (`tr(description_key)`)
3. **Ziel** — Objective-Text(e) (`tr(text_key)`, inkl. Count wenn nötig)
4. **Belohnung** — z. B. Gold / Items-Preview (`tr` + Werte)
5. Unten zwei Buttons: **Annehmen** | **Ablehnen**

```
┌─────────────────────────────┐
│  Quest-Titel                │
│  Beschreibung …             │
│  Ziel: …                    │
│  Belohnung: …               │
│                             │
│  [ Annehmen ] [ Ablehnen ]  │
└─────────────────────────────┘
```

- [x] Scene/Control für Accept-Panel anlegen (unter `scenes/ui/` oder PlayerUi)
- [x] Layout exakt wie oben; alle sichtbaren Strings über CSV/`tr()`  
  (`quest.accept`, `quest.decline`, Demo-Quest-Keys, …)
- [x] **Annehmen** → `QuestManager.accept(id)` → Eintrag in `quest_data.active` (Objectives bei `current: 0`)
- [x] **Ablehnen** → Panel schließen, keine State-Änderung
- [x] Nach Accept: Interaction/Accept schließen, Quest-Log aktualisieren (wenn schon da)

---

## 4. Quest-Ziel definieren

Zieltypen v1 (erweiterbar über `type`-String):

| type | Bedeutung | Progress-Quelle |
|------|-----------|-----------------|
| `talk` | Mit NPC `target` sprechen | Interaction Talk |
| `kill` | `count` von `target` (npc_type / spec name) | Fight-Sieg / NPC remove |
| `reach` | Area / Marker `target` betreten | `QuestObjectiveArea` |

- [x] Objective-Runtime: `{ "id", "type", "target", "count", "current", "done" }`
- [x] `report_progress` matched active Quests und setzt `done` / Quest → `ready`
- [x] Hook Fight-Ende (Sieg): Kill-Event für Encounter-`npc_type`
- [x] Hook Interaction: Talk-Event
- [x] Hook Area: `body_entered` nur lokaler Player

---

## 5. UI erstellen

Vorhandene Anker: PlayerUi Interaction-Menü + HUD `Quests` ItemList.

- [x] Interaction: **Quest**-Reiter/Button an `test_npc_basic` (§2)
- [x] **Accept-Panel** mit Layout aus §3 (Titel → Beschreibung → Ziel → Belohnung → Annehmen/Ablehnen)
- [x] **Quest-Log**: Liste aktiver Quests + Kurzziele (erfüllt / offen)
- [x] **Detail** (einfach): ausgewählte Quest Beschreibung + Objectives
- [x] **Turn-in-Panel** (Abgabe + Rewards-Vorschau; Layout analog §3, Buttons Abgeben/Abbrechen)
- [x] Alle Labels/Buttons über `tr()` + CSV
- [x] Bei `quests_changed` / `LocaleManager.language_changed` Texte refreshen
- [x] **F3-Quest-Cheats** (Englisch, ohne CSV): Accept Demo-Quest, Objectives → Ready, Turn-in, Force Complete — alles über QuestManager

---

## 6. Ziel abschließbar machen

- [x] Progress nur zählen, wenn Quest `active` und Objective noch nicht `done`
- [x] Mehrere Objectives: Quest erst `ready`, wenn **alle** done (v1 AND-Logik)
- [x] Idempotent: doppelte Events nicht über `count` hinauszählen
- [x] Nach Ready: Giver/Turn-in-NPC zeigt Abgabe an (UI-Hinweis / Button aktiv)

---

## 7. Quest abgeben + Belohnung zuweisen

- [x] Turn-in nur am konfigurierten `turn_in_npc` / Objekt und nur wenn `ready`
- [x] `turn_in`: Status → `completed`, aus `active` entfernen, in `completed` listen
- [x] Rewards anwenden:
  - Gold → `PlayerPartyState.inventory_data` (Struktur anlegen falls leer: `{ "gold": 0, "items": [] }`)
  - Items → Placeholder-Array (echtes Item-System später)
- [x] UI: Belohnung anzeigen, Log aktualisieren
- [x] Persistenz: State gespeichert (Autosave / optional sofort)

---

## Empfohlene Reihenfolge (Sprint-Schnitt)

1. ~~§0 Entscheidungen~~ → bestätigen + Ordner
2. §1 Definition + `QuestManager` + Persistenz + 1 Demo-JSON + Progress-RPCs
3. §2 NPC-Spec Offer/Turn-in + Interaction-Hook
4. §3 Annehmen (Panel + State)
5. §4 Zieltypen + `report_progress` Hooks (Talk / Kill / Reach), lokal; Group-Sync-Stub
6. §5 Quest-Log UI + F3-Cheats
7. §6 Ready-Logik absichern
8. §7 Turn-in + Rewards
9. Kurztest-Checkliste (unten) manuell durchspielen
10. README / `project_current_state_v_2.md` aktualisieren

---

## „Globale Quests“ — gemeinte Semantik (Vorbereitung)

**Gemeint:** Story-/Klassenquests, die den **einzelnen Spieler** betreffen (eigener Fortschritt, eigener Save).  
**Nicht gemeint:** eine Quest-Instanz oder Freischaltung für die ganze Lobby/Welt.

Folgen fürs Design:

1. State bleibt in **`PlayerPartyState`** (auch für `category: "story"` / `"class"`).
2. **Gebiets-Gates** (neues Biom/Dungeon) prüfen **lokal** z. B. `QuestManager.has_completed("q_story_…")` / Progress-Flags — Peer A freigeschaltet, Peer B noch gesperrt → nur A darf rein.
3. **Gruppe:** Mitglieder können dem Quest-**Inhaber** beim Fortschritt helfen (`share_progress_with_group` später); Accept/Turn-in/Belohnung/Freischaltung bleiben beim Inhaber.
4. Kein Ablegen dieser Quests in `WorldState` als lobby-weite Wahrheit.

v1 legt nur `category` + Query-API + Group-Stub an; Story-Quests und Biom-Gates kommen später.

---

## Nicht in v1 (aber erweiterbar halten)

| Später | v1-Vorbereitung |
|--------|-----------------|
| Story/Klassen-Quests („global“ = spielerbezogen) | JSON-Feld `category` (`side` / später `story`/`class`); `has_completed(id)` / completed-Liste querybar für Gates |
| Biom-/Dungeon-Freischaltung pro Spieler | Gates lesen lokalen Quest-Fortschritt — **nicht** Lobby-WorldState |
| **Gruppen-Progress-Sync** | Nur wenn in derselben Gruppe; hilft dem Quest-Inhaber; Stub `_peers_in_same_group` / `share_progress_with_group` |
| Quest-Ketten / Dialoge | Optionale Felder `requires_completed[]`, `next_quest_id` |
| Volles Item-System | `rewards.items[]` + `_apply_rewards()` (v1: Gold) |
| Gilden-UI / Hub | Datengetriebene `offer`-IDs |
| Daily/Repeatable | Später Flag; v1 blockiert Re-Accept nach `completed` |

**In v1 enthalten:** F3-Quest-Cheats. Progress lokal.

- Story-/Klassen-Quest-Content und Biom-Gates (nur vorbereitet)
- Aktiver Gruppen-Progress-Sync (erst mit Gruppensystem)
- Quest-Ketten / Branching Dialoge
- Volles Item-/Equip-System
- Gilden-UI als Quest-Hub
- Daily/Repeatable Quests
- Lobby-weite/WorldState-„Global“-Quests (bewusst **nicht** das Ziel)

---

## Kurztest-Checkliste

- [ ] Overworld `test_npc_basic`: Menü zeigt Talk | Quest | Leave; Quest öffnet Accept-Panel (Layout §3)
- [ ] NPC mit Offer → Annehmen → Quest erscheint im Log; Ablehnen ändert nichts
- [ ] Ziel Talk / Kill / Reach jeweils einmal erfüllbar
- [ ] Nach allen Objectives: Status ready, Turn-in möglich
- [ ] Turn-in vergibt Gold (Inventory sichtbar/änderbar im Save)
- [ ] Nach Reload/Autosave: Active/Completed korrekt
- [ ] Sprache wechseln → Quest-UI-Texte folgen CSV
- [ ] Zweite Annahme derselben Quest blockiert
- [ ] Zwei Peers ohne Gruppe: Progress bleibt jeweils lokal (kein Sync)
- [ ] F3: Force Complete schließt Demo-Quest inkl. Rewards ab

---

## Definition of Done (erster spielbarer Quest-Loop)

- [x] Spieler kann bei einem NPC eine Demo-Quest annehmen
- [x] Mindestens ein Zieltyp ist im Spiel erfüllbar
- [x] Quest kann abgegeben werden und Rewards landen in `PlayerPartyState`
- [x] Fortschritt überlebt Autosave / Quit
- [x] Keine hardcodierten spieler-sichtbaren Quest-Strings (CSV/`tr()`) — Debug-Cheats ausgenommen (EN)
- [x] F3-Cheats funktionieren; Group-Sync-Stub vorhanden

---

## Verweise

- Design: [`rpg_multiplayer_design_v_2.md`](rpg_multiplayer_design_v_2.md)
- Kampfplan (Stil/Abhak-Muster): [`PLAN_KAMPFSYSTEM_GRID.md`](PLAN_KAMPFSYSTEM_GRID.md)
- Coding-Rules: [`.cursor/rules/godot-coding-standards.mdc`](../.cursor/rules/godot-coding-standards.mdc)
