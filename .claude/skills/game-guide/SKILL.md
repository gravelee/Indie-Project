# Echoes of the Void — Design Guide

Master index. Console portability is a hard constraint — every mechanic must
map to both keyboard+mouse and a standard controller (Xbox/PS/Switch).

---

## File Tree

```
SKILL.md                   hub index
├── roadmap.md             file plan, phases, build order
│
├── Game Overview
│   └── game_overview.md       concept, pillars, loops, scope       ✓
│
├── Gameplay
│   ├── player_mechanic.md     all mechanics by category            ✓
│   └── player_input.md        input mapping, console layout        ✓
│
├── Narrative
│   ├── world_design.md        world lore, Resonance, races, arc    [P1]
│   ├── zone1_story.md         Zone 1 NPCs, quests, choices         [P1]
│   └── story_book.md          canonical prose narrative            [P1]
│
├── Characters
│   ├── character_sheet.md     Ares + future playable characters    [P1]
│   ├── npc_roster.md          all NPCs: schedules, tone, relations [P1]
│   └── enemy_roster.md        enemy types, AI states, variants     [P1]
│
├── Systems
│   └── systems_design.md      resources, class, combat, save       [P1]
│
├── UI/UX
│   └── ui_design.md           HUD, all screens, targeting          [P1]
│
├── Level Design
│   ├── dungeon_design.md      dungeon rules, AI, traps, puzzles    [P1]
│   └── levels/zone1/
│       ├── vinemore.md        village layout, NPCs, triggers       [P4]
│       ├── woods.md           farming + bridge road areas          [P4]
│       └── mine_cave.md       Old Mine + River Cave room layouts   [P4]
│
├── Data Specs
│   ├── dialogue_spec.md       dialogue tree, branch log format     [P2]
│   ├── quest_spec.md          quest data, triggers, save link      [P2]
│   ├── talent_spec.md         talent tree, scrolls, activation     [P2]
│   ├── map_spec.md            zone/room structure, spawn format    [P2]
│   └── save_spec.md           serialized state, autosave flow      [P2]
│
├── Technical
│   ├── architecture.md        scripts, signals, data pipeline      [P3]
│   └── asset_spec.md          sprite names, folders, import cfg    [P3]
│
└── reference/             old project files — mine for content
```

**Legend:** `✓` done | `[P1]` Phase 1 — Design | `[P2]` Phase 2 — Spec |
`[P3]` Phase 3 — Architecture | `[P4]` Phase 4 — Level Layouts

---

See **roadmap.md** for dependency graph, build order, and current position.
