# Manny's PokeApp - ERD & Delivery Plan

## Architecture Notes
- Adopt a three-layer structure (`data` → `domain` → `presentation`) to keep networking, persistence, and UI concerns isolated. Repositories expose domain models, while view models remain test-friendly.
- Normalize authoritative PokeAPI data so forms, stats, and version group variants are reusable without duplication. User-authored records (teams, battle logs) reference canonical entities to stay DRY.
- Track PokeAPI CSV snapshots with checksums so the app can migrate between bundled versions without live network dependency.
- Bundle the official PokéAPI CSV hierarchy inside `assets/pokeapi/csv/` for deterministic web seeding; native/desktop builds keep the same dump in `data/pokeapi-master/data/v2/csv/` for local tooling.
- Avoid shipping large media blobs. Sprites and cries stay in the cloud, fetched on demand and tracked via `MEDIA_ASSET` so cache pruning remains centralized.
- Shared infrastructure services (cache manager, sync orchestrator, mock battle engine) live under a dedicated `infrastructure` module used by repositories and domain services.

## Entity Relationship Diagram

```mermaid
erDiagram
    USER_PROFILE ||--|| USER_PREFS : configures
    USER_PROFILE ||--o{ SYNC_SESSION : authorizes
    USER_PROFILE ||--o{ TEAM : owns
    USER_PROFILE ||--o{ CACHE_MANIFEST : caches
    USER_PROFILE ||--o{ BATTLE_RECORD : records

    DATA_SOURCE_SNAPSHOT ||--o{ SOURCE_IMPORT_RUN : records
    DATA_SOURCE_SNAPSHOT ||--o{ DATA_PACK : seeds
    CACHE_MANIFEST }o--|| DATA_SOURCE_SNAPSHOT : seeded_from

    CACHE_MANIFEST ||--o{ DATA_PACK : groups
    CACHE_MANIFEST ||--o{ ASSET_DOWNLOAD : contains
    DATA_PACK ||--o{ CACHE_ENTRY : indexes
    ASSET_DOWNLOAD }o--|| MEDIA_ASSET : materializes
    VERSION_GROUP ||--o{ DATA_PACK : scopes

    TEAM ||--o{ TEAM_SLOT : includes
    TEAM_SLOT ||--o{ TEAM_SLOT_MOVE : selects
    TEAM_SLOT }o--|| POKEMON_FORM : locks_in
    TEAM_SLOT }o--|| VERSION_GROUP : context
    POKEMON_MOVESET ||--o{ TEAM_SLOT_MOVE : selected_from

    BATTLE_RECORD ||--o{ BATTLE_PARTICIPANT : logs
    TEAM ||--o{ BATTLE_PARTICIPANT : fields

    POKEMON ||--o{ POKEMON_FORM : defines
    POKEMON_FORM ||--o{ POKEMON_FORM_STAT : stats
    POKEMON_FORM_STAT }o--|| STAT : measures
    POKEMON_FORM ||--o{ POKEMON_FORM_TYPE : typing
    POKEMON_FORM_TYPE }o--|| TYPE : typed_as
    TYPE ||--o{ TYPE_EFFECTIVENESS : attacker
    TYPE ||--o{ TYPE_EFFECTIVENESS : defender

    POKEMON }o--|| SPECIES : belongs_to
    SPECIES ||--o{ SPECIES_FLAVOR_TEXT : describes
    SPECIES ||--o{ EVOLUTION_LINK : as_source
    SPECIES ||--o{ EVOLUTION_LINK : as_target
    EVOLUTION_CHAIN ||--o{ EVOLUTION_LINK : orders

    VERSION_GROUP ||--o{ SPECIES_FLAVOR_TEXT : localizes
    VERSION_GROUP ||--o{ VERSION : enumerates

    MOVE }o--|| MOVE_DAMAGE_CLASS : classified_as
    MOVE ||--o{ POKEMON_MOVESET : learned_in
    MOVE_LEARN_METHOD ||--o{ POKEMON_MOVESET : via
    POKEMON_FORM ||--o{ POKEMON_MOVESET : learns
    VERSION_GROUP ||--o{ POKEMON_MOVESET : contextualizes

    MEDIA_ASSET ||--o{ POKEMON_FORM : renders
```

### Entity Highlights

**Reference Data (sourced from PokeAPI)**
- `POKEMON` / `POKEMON_FORM`: separates species-wide identity from form-specific stats, sprites, and typing. `MEDIA_ASSET` deduplicates sprite, icon, and audio blobs for offline storage.
- `POKEMON_FORM_STAT` + `STAT`: keeps stat definitions reusable across computed stat services.
- `POKEMON_FORM_TYPE`, `TYPE`, `TYPE_EFFECTIVENESS`: supports mock battle multipliers without hard-coding matchups.
- `SPECIES`, `EVOLUTION_CHAIN`, `EVOLUTION_LINK`, `SPECIES_FLAVOR_TEXT`: model evolution rules and flavor text per version group.
- `MOVE`, `MOVE_DAMAGE_CLASS`, `MOVE_LEARN_METHOD`, `POKEMON_MOVESET`: capture how moves become available across forms and version groups.
- `DATA_SOURCE_SNAPSHOT`: capture the bundled PokeAPI CSV metadata (version, checksum) so imports remain deterministic and auditable.
- `VERSION_GROUP`, `VERSION`: normalize generation-specific content; every cache entry references the applicable scope.

**User Authored Data**
- `USER_PROFILE`: single local profile (kept extensible for multi-user). `USER_PREFS` stores theme, accessibility, cache budget, and backup cadence.
- `TEAM`, `TEAM_SLOT`, `TEAM_SLOT_MOVE`: represent teams, individual Pokemon selections with context (form, level, version group), and move choices traced back to canonical learnset entries (`POKEMON_MOVESET`).
- `BATTLE_RECORD`, `BATTLE_PARTICIPANT`: persist mock battle outcomes with per-team scores and metadata for analytics and sync.

**Infrastructure & Support**
- `DATA_SOURCE_SNAPSHOT`, `SOURCE_IMPORT_RUN`: record which bundled PokeAPI CSV snapshots shipped with the app and whether imports succeeded, including checksums for rollback.
- `CACHE_MANIFEST`, `DATA_PACK`, `CACHE_ENTRY`: track cached datasets, region/version overlays, and individual entity freshness to coordinate offline availability and pruning.
- `ASSET_DOWNLOAD`, `MEDIA_ASSET`: separate canonical asset metadata from device-specific downloads so sprites/cries can be fetched on demand and pruned safely.
- `SYNC_SESSION`: Google Drive auth tokens & sync health. Linked to manifest so backups include cache metadata when requested.

## DRY & Segmentation Considerations
- Canonical learnsets (`POKEMON_MOVESET`) feed both the comparison view and team builder, ensuring stat calculators, legality checks, and move selections draw from one source of truth.
- Offline cache metadata is centralized in `CACHE_ENTRY`, enabling shared eviction, validation, and sync logic regardless of whether data was fetched on-demand or via packs.
- Versioned source snapshots ensure repositories read from a single consistent dataset, simplifying migrations and sync rollbacks.
- Shared domain services (stat calculator, type matchup resolver, battle scorer) consume normalized tables, so UI layers stay thin and testable.

## Phased Milestones & Test Strategy

| Phase | Focus & Deliverables | Key Unit Tests | Key Integration Tests |
| ----- | -------------------- | -------------- | --------------------- |
| **Phase 1 - Foundation & Data Layer (2-3 weeks)** | Flutter scaffold, dependency injection, bundled dataset ingestion (PokeAPI CSV), local database schema, repository skeleton, asset manifest service. | Repositories (Pokemon, Move, Version), CSV->entity mappers, cache manifest logic, asset hashing. | Sqflite import round-trips (native + web via sqflite_common_ffi_web), snapshot checksum validation, offline-first fetch with mocked PokéAPI, cache eviction workflow. |
| **Phase 2 - Browsing & Comparison (2 weeks)** | Pokemon browser, advanced search/filter, comparison view with base/computed stats, type matchup preview, selective caching triggers. | `StatCalculator`, `ComparisonViewModel`, filter combinators, type effectiveness resolver. | Widget tests for comparison screen, integration test ensuring cached stats served offline, golden tests for comparison cards (baseline accessibility). |
| **Phase 3 - Teams & Detail (2 weeks)** | Detail pages per version group, legal learnset display, team builder with open/closed mode rules, team persistence and validation. | `TeamValidator`, `LearnsetService`, `TeamRepository`, domain rules for open vs closed mode. | Integration test covering full team creation/edit flow, DB + UI sync for form/version switches, accessibility audit automation (semantics checks). |
| **Phase 4 - Mock Battles & Cloud Sync (2 weeks)** | Lightweight battle simulation, battle logs, Google Drive backup/restore, conflict resolution (last-write-wins) with manifest. | `BattleScoringService`, `SyncOrchestrator`, backup diff builder, serialization guards. | Full battle simulation against fixture teams, sync round-trip with mocked Drive API, offline-to-online reconciliation scenario. |
| **Phase 5 - Hardening & Release (1 week)** | Performance tuning, cache budgeting UX, comprehensive logging/telemetry, localization hooks, final accessibility pass. | Load-testing utilities, telemetry formatters, accessibility preference handlers. | End-to-end smoke on representative devices, upgrade/migration path test, failover/backoff scenarios for PokeAPI outages. |

**Ongoing Quality Gates**
- Enforce `flutter analyze`, `dart test`, and `integration_test` suites in CI; add golden tests for high-value screens and contract tests for domain services.
- Maintain deterministic test fixtures by snapshotting PokeAPI CSV imports; integration tests run against those fixtures to guarantee stability.
- Increment schema versions via migrations; include regression tests for data migrations to protect cached user teams and packs.

## Post-MVP (v1.1) Targets
Feedback from target users highlights a short list of features to queue immediately after the v1 release. They do not alter the current milestone plan but should influence backlog grooming:
- Allow duplicate Pokémon selections within a single team roster while keeping closed-mode restrictions configurable.
- Surface evolution chains, regional variants, and alternate forms directly on the detail page with deep links between related entries.
- Provide in-context access to the detail page during comparison or selection flows so users can inspect stats without leaving their current task.
