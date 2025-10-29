# Manny’s PokéApp — Product Requirements Document (PRD)

## 1. Overview

Manny’s PokéApp is a web and mobile app that interfaces with the PokéAPI to let users view, compare, and manage Pokémon data, design and save teams, and simulate mock battles. It should function fully offline once data is cached, and optionally sync user data via Google Drive.

---

## 2. Goals

- Compare up to 6 Pokémon at a time by base or computed stats.
- Build and manage multiple teams.
- Mock battles between teams (lightweight simulation for v1).
- View detailed per-version Pokémon data including stats, moves, and evolutions.
- Offline-first with selective caching and optional cloud backup.

---

## 3. Platform and Stack

**Framework:** Flutter 3.x
**Language:** Dart
**API:** PokéAPI ([https://pokeapi.co/](https://pokeapi.co/))
**Storage:** Local SQLite (via `drift` or `isar`)
**Offline Caching:** On-demand + version/region packs
**Cloud Sync:** Google Drive (OAuth via `googleapis` + `flutter_secure_storage`)
**Testing:** Flutter test + integration tests + mock PokéAPI
**AI Agentic Coding Compatibility:** Flutter + Dart are well-structured for LLM-based coding; type safety and unified UI make refactoring agent-friendly.

### Why Flutter

- Single codebase across web, Android, and desktop.
- Responsive and performant for tablets and phones.
- Clean dev experience (hot reload, simple build pipeline).
- Excellent offline support via native storage.

---

## 4. Core Features

### 4.1 Pokémon Comparison View

- View up to **6 Pokémon** side by side.
- Show: HP, Attack, Defense, Sp. Atk, Sp. Def, Speed.
- Compare **Base Stats** or **Computed Stats** at user-selected level.
- Switch between different **movesets** dynamically.
- Sort Pokémon by any stat (asc/desc).

### 4.2 Team Management

- Create and save multiple teams.
- Add Pokémon with:

  - Selected **version group**.
  - Selected **level**.
  - Automatically limited movesets (level-up to level N + TM/TR/HM for version).

- Teams can include Pokémon from **different version groups** in Open Mode.
- **Closed Mode** enforces tournament-style restrictions (same version group, species clause, etc.).

### 4.3 Detailed Pokémon Page

- Tabs for: **Stats**, **Types**, **Movesets**, **Evolutions**.
- Movesets include **Level-up**, **TM/TR/HM**, and filter by level.
- Evolutions link to relevant version-group variants.
- **Add to Team** button respecting version and level context.

### 4.4 Mock Battles (v1 — Lightweight Simulation)

- Compare team scores using simplified formulas:

  - Aggregate offensive/defensive stats.
  - Type advantage multipliers.
  - Speed tiebreakers.

- Display summary outcome and highlight key matchups.
- Log match results locally.

### 4.5 Offline & Cloud Sync

- **Offline-first architecture**: all cached data available offline.
- **Caching strategy:**

  - On-demand (when visited).
  - Region/version pack downloads (gradual respect for API rate limits).
  - Cache budget setting in preferences (soft limit; user can override).

- **Cloud backup:**

  - Manual or scheduled backup to Google Drive.
  - Auth only required for cloud sync.
  - Conflict handling: last-write-wins.

---

## 5. Non-Functional Requirements

| Category           | Requirement                                                           |
| ------------------ | --------------------------------------------------------------------- |
| **Performance**    | Load time < 2s for cached pages; target 60fps on mid-tier Android.    |
| **Storage**        | Estimate cache size before downloads; enforce user-set cache cap.     |
| **Offline Mode**   | Full offline operation once data cached.                              |
| **Accessibility**  | Colorblind-safe palettes, scalable fonts, high contrast themes.       |
| **Localization**   | English only for now; rely on PokéAPI if localized text available.    |
| **Data Integrity** | Use PokéAPI directly; fallback policies TBD.                          |
| **Licensing**      | Start with PokéAPI official sprites; user opt-in for community packs. |

---

## 6. Stat Calculation Policy

To compute “average” Pokémon stats at a chosen level:

```
Stat = (((2 × BaseStat + IV + (EV/4)) × Level) / 100) + 5
HP = (((2 × BaseHP + IV + (EV/4)) × Level) / 100) + Level + 10
```

Assume: IV = 15, EV = 0, Neutral Nature (×1.0 multiplier).

---

## 7. Data Model

### Pokémon

- id, name, base_stats {hp, atk, def, spa, spd, spe}
- types[]
- forms[]
- sprites
- species_id

### Species

- id, evo_chain_id, flavor_text[], growth_rate, egg_groups

### VersionGroup

- id, name, versions[], generation_id

### Move

- id, name, type, power, accuracy, pp, priority, damage_class, effect_entries

### Learnset

- pokemon_id, move_id, version_group_id, learn_method, level, machine_id?

### Team

- id, name, open_mode(bool), created_at, updated_at

### TeamMember

- id, team_id, pokemon_id, version_group_id, level, moves[4]

### UserPrefs

- cache_budget_mb
- theme, accessibility_options
- last_backup_timestamp

---

## 8. UX Outline

**Primary Screens:**

1. **Pokémon Browser** – search, filter, and sort.
2. **Compare View** – up to 6 Pokémon, radar and tabular stats.
3. **Detail Page** – version tabs, movesets, evolutions, add to team.
4. **Team Builder** – add/edit Pokémon, open/closed mode toggle.
5. **Mock Battle** – select two teams, simulate, show summary.
6. **Settings** – cache management, cloud sync, accessibility, about.

---

## 9. MVP Milestones

| Phase       | Duration  | Key Deliverables                                                     |
| ----------- | --------- | -------------------------------------------------------------------- |
| **Phase 1** | 2–3 weeks | Flutter setup, PokéAPI client, local DB, cache infra, browsing list. |
| **Phase 2** | 2 weeks   | Compare view + stat computation + sorting.                           |
| **Phase 3** | 2 weeks   | Team builder (save/load) + detailed Pokémon pages.                   |
| **Phase 4** | 2 weeks   | Mock battle lite + Google Drive backup integration.                  |
| **Phase 5** | 1 week    | QA, polish, accessibility pass.                                      |

---

## 10. Future Versions (v2+)

- Add abilities, items, held items, natures.
- Full battle simulation (damage formula, turn engine).
- Tournament rulesets and team validation.
- Expanded cloud sync (Dropbox, iCloud).
- Localization and advanced analytics.
- Team sharing via links or QR codes.

---

## 11. Risks & Mitigations

| Risk                | Mitigation                                                          |
| ------------------- | ------------------------------------------------------------------- |
| PokéAPI rate limits | Implement gradual fetch with backoff; allow partial pack downloads. |
| Incomplete data     | Cache schema versioning for future enrichment.                      |
| App size growth     | Allow cache budget setting; prune least-used data.                  |
| Sync conflicts      | Simple last-write-wins; option to view change logs.                 |

---

## 12. Next Steps

1. Create Flutter repo with skeleton architecture (data → domain → UI layers).
2. Implement PokéAPI client with caching and version group mapping.
3. Build core Compare View and Team Builder screens.
4. Draft UI mockups and theming guidelines.
5. Begin incremental data pack preloading pipeline.

---

**End of PRD**
