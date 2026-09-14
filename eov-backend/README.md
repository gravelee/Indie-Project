# eov-backend

REST API backend for **Echoes of the Void** — a 3D action RPG built in Godot 4.3.

Handles all persistent game state: character progression, equipment, quest tracking,
and narrative branch logging. The Godot client calls this API at save points;
all real-time gameplay runs locally in the engine.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Java 21 |
| Framework | Spring Boot 4.1 |
| Persistence | Spring Data JPA / Hibernate |
| Database | H2 (in-memory) |
| Build | Maven |
| Utilities | Lombok |
| Testing | JUnit 5, Mockito, MockMvc |

---

## Architecture

```
controller/   HTTP layer — request/response only, no business logic
service/      Business logic, validation, transactional boundaries
repository/   Spring Data JPA interfaces
model/        JPA entities
dto/          API-facing data objects, decoupled from persistence layer
enums/        ItemSlot, ItemRarity, ItemType, QuestStatus
exception/    Global exception handler (404, 409, 400)
```

---

## Domain Model

```
PlayerSave (root)
  ├── CharacterStats      (OneToOne) — level, STR/AGI/STA/INT/SPR/RES/DEF, EXP, gold
  ├── CharacterResources  (OneToOne) — current HP, Energy, Flow, Focus
  ├── AffinityProfile     (OneToOne) — 6 behavioral axes 0-100, invisible to player
  ├── Equipment           (OneToOne) — 9 slots: weapons, armor, accessory
  ├── List<QuestState>    (OneToMany) — per-quest status: NOT_STARTED/IN_PROGRESS/COMPLETED
  ├── List<BranchEntry>   (OneToMany) — narrative forks B-01 to B-09, write-once
  └── List<InventoryItem> (OneToMany) — item stacks across ammo/food/misc pouches
```

Every entity maps directly to a decision in the game design documents.
The `AffinityProfile` tracks soft behavioral patterns (honesty, boldness, curiosity, etc.)
that influence NPC dialogue without ever being shown to the player.
`BranchEntry` records are permanently locked once written — the service layer
rejects duplicate branch IDs with a 409 Conflict, reflecting the design rule
that narrative forks are irreversible.

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/saves` | Create new save (initialises all child records) |
| GET | `/api/saves/{id}` | Load save metadata |
| PUT | `/api/saves/{id}` | Update zone and checkpoint |
| DELETE | `/api/saves/{id}` | Delete save and all related data |
| GET | `/api/saves/{id}/stats` | Get character stats |
| PUT | `/api/saves/{id}/stats` | Update stats |
| GET | `/api/saves/{id}/resources` | Get current HP/Energy/Flow/Focus |
| PUT | `/api/saves/{id}/resources` | Update resources |
| GET | `/api/saves/{id}/equipment` | Get equipped items |
| PUT | `/api/saves/{id}/equipment/slot` | Equip or unequip an item slot |
| GET | `/api/saves/{id}/quests` | Get quest log (optional `?status=` filter) |
| PUT | `/api/saves/{id}/quests/{questId}` | Update quest status (upsert) |
| GET | `/api/saves/{id}/branches` | Get all recorded narrative forks |
| POST | `/api/saves/{id}/branches` | Record a branch decision (write-once) |
| GET | `/api/saves/{id}/affinity` | Get affinity profile |
| PATCH | `/api/saves/{id}/affinity` | Update affinity axes |

---

## Running Locally

**Requirements:** Java 21, Maven (or use the included `mvnw` wrapper).

```bash
./mvnw spring-boot:run
```

The server starts on `http://localhost:8080`.

H2 console (browse the live database schema):
```
http://localhost:8080/h2-console
JDBC URL: jdbc:h2:mem:eovdb
Username: sa
Password: (leave blank)
```

---

## Running Tests

```bash
./mvnw test
```

14 tests across 5 test classes:

- **Unit tests** (Mockito) — `PlayerSaveServiceTest`, `BranchEntryServiceTest`,
  `QuestStateServiceTest`: isolate service logic with mocked repositories
- **Integration test** (MockMvc) — `PlayerSaveControllerIntegrationTest`:
  full stack against H2, tests POST/GET flow and validation rejection
- **Context test** — `EovBackendApplicationTests`: verifies the application context loads

---

## Design Notes

The data model is grounded in the game design documents (`game_overview.md`,
`player_mechanic.md`). Nothing was speculated beyond what is decided in those files.
Files not yet written in the design phase (`systems_design.md`, `npc_roster.md`, etc.)
will drive future backend extensions — talent trees, NPC state, dialogue history.

H2 is used for local development. Switching to PostgreSQL requires only changing
the datasource config in `application.properties` — the JPA layer is database-agnostic.
