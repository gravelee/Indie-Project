# Echoes of the Void — Design Guide

Master index for all game design and implementation-spec files.
Console portability is a hard constraint — every mechanic must map to both
keyboard+mouse and a standard controller (Xbox/PS/Switch layout).

---

## Meta

**roadmap.md** — pre-production documentation roadmap: what files exist, what needs to be
created, phases and order, dependencies, parallelism notes. Read this to know where we are
and what to work on next.

---

## Player

**player_mechanic.md** — all mechanics: what Ares can do and how it works,
grouped by category (Presence, Resources, Movement, Camera, Combat, Abilities,
World Interaction, Equipment, Status Effects, Lifecycle, Expressive).

**player_input.md** — all input mapping: input modes, named button groups,
console mapping, context rules (key→behavior), and Mechanic Map
(every mechanic cross-referenced to its input action and trigger condition).

---

## World & Story

**world_design.md** — world lore, main quest arc, resonance framework, races, zones,
narrative philosophy, technology level.

**zone1_design.md** — Zone 1 full story: NPCs, weapon chain, spellcaster school,
bridge puzzle, companion system, player choice log, Chapter 3 post-cave beats.

**story_book.md** — canonical prose narrative (Chapters 1–3 complete).

---

## Systems

**systems_design.md** — resources (Energy/Flow/Focus), emergent class system,
EXP and talent system, combat system, save system, gear and durability, progression.

---

## Dungeons

**dungeon_design.md** — general dungeon rules, AI and trap systems, props standards,
puzzle design, creature roster, art TODO.

**dungeon_oldmine.md** — Old Mine + River Cave full design: rooms, progression,
bosses, blasting powder, post-cave road back.
