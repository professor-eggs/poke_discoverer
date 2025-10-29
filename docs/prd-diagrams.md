# Manny’s PokéApp — Key Diagrams

## 1. High-Level UI Flow Diagram

```mermaid
graph TD
    A[Home / Browse Pokémon] -->|Select Pokémon| B[Pokémon Detail Page]
    A -->|Compare Mode| C[Comparison View]
    B -->|Add to Team| D[Team Builder]
    D -->|View Team| E[Team List]
    E -->|Select 2 Teams| F[Mock Battle]
    F -->|View Results| G[Battle Summary]
    D -->|Backup Teams| H[Cloud Sync]
    H -->|Manage Cache & Prefs| I[Settings]
    I -->|Return| A
```

**Flow Notes:**

- The app starts on **Home/Browse Pokémon** with search/sort filters.
- Users move freely between **Detail**, **Compare**, and **Team** pages.
- **Cloud Sync** and **Settings** are accessible globally.
- **Offline** operation means all arrows remain valid even without internet (as long as cached).

---

## 2. Data Schema Diagram

```mermaid
erDiagram
    USERPREFS ||--o{ TEAM : has
    TEAM ||--o{ TEAMMEMBER : includes
    TEAMMEMBER ||--|| POKEMON : references
    POKEMON ||--|| SPECIES : belongs_to
    POKEMON ||--o{ LEARNSET : has
    LEARNSET ||--|| MOVE : maps_to
    POKEMON ||--o{ FORM : has
    POKEMON }o--|| VERSIONGROUP : valid_in

    USERPREFS {
        string theme
        int cache_budget_mb
        bool accessibility_high_contrast
        datetime last_backup_timestamp
    }

    TEAM {
        int id
        string name
        bool open_mode
        datetime created_at
        datetime updated_at
    }

    TEAMMEMBER {
        int id
        int team_id
        int pokemon_id
        int version_group_id
        int level
        json moves[4]
    }

    POKEMON {
        int id
        string name
        json base_stats
        json types
        string sprite_url
        int species_id
    }

    SPECIES {
        int id
        int evo_chain_id
        json flavor_text
        string growth_rate
    }

    VERSIONGROUP {
        int id
        string name
        json versions
        int generation_id
    }

    MOVE {
        int id
        string name
        string type
        int power
        int accuracy
        string damage_class
    }

    LEARNSET {
        int pokemon_id
        int move_id
        int version_group_id
        string learn_method
        int level
    }
```

**Schema Notes:**

- Separation between `Pokémon` and `Species` ensures version/form flexibility.
- `VersionGroup` normalizes generation/version-specific data.
- `Learnset` bridges Pokémon ↔ Move ↔ Version relationships.
- `Team` and `TeamMember` form the core of user data synced to the cloud.

---

## 3. Offline Caching Flow

```mermaid
graph LR
    A[PokéAPI Endpoint] -->|Fetch & Normalize| B[Data Normalizer]
    B -->|Store JSON Objects| C[Local DB (SQLite/Isar)]
    C -->|Serve Cached Data| D[UI Components]
    D -->|Trigger Prefetch| E[Cache Manager]
    E -->|Download Region/Version Packs| A
```

**Flow Notes:**

- The cache manager handles both on-demand and pack downloads.
- Respect PokéAPI rate limits by throttling requests.
- Indexed/normalized data enables efficient offline queries.

---

## 4. Mock Battle Logic (Lite)

```mermaid
flowchart TD
    A[Select Team 1 & 2] --> B[Calculate Team Score]
    B --> C[Apply Type Matchups]
    C --> D[Adjust for Speed Tie Breakers]
    D --> E[Determine Winner]
    E --> F[Display Battle Summary]
    F --> G[Save Log Locally]
```

**Computation Notes:**

- Team score = Σ(weighted offensive + defensive stats)
- Type matchup = multiplier based on type chart (1x, 2x, 0.5x, 0x)
- Output includes match summary and MVP Pokémon suggestion

---

**End of Diagrams**
