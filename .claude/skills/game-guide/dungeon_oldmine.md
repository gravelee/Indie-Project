---
name: Old Mine Dungeon Design
description: >
  Full design for Zone 1's dungeon — Old Mine + River Cave. Rooms, progression
  sequence, boss design, companion dynamics, post-cave sequence.
  Load this when working on the Old Mine dungeon specifically.
type: reference
---

# Old Mine + River Cave — Full Design

**See also**: zone1_design.md (Zone 1 story/NPCs/companion system),
  dungeon_design.md (general dungeon rules, AI, props, puzzles),
  systems_design.md (talent drops, boss philosophy)

## TL;DR
- Two separate systems: Old Mine (human-cut) + River Cave (natural). Share one wall.
  Connected by a hidden crack.
- Player can enter either first. Mike takes whichever entrance Ares doesn't.
- Dungeon progression: Mine → blocker (cave-in) → River Cave → Spider Queen →
  blasting powder + Vinie freed → reunite → Mine together → consuming race member
  fight → well chamber.
- Blasting powder: permanent effect, lit with lantern directly. Weapon master
  needs pouch from Lulu (post-cave). Spellcaster gets magic blast alternative
  later. Spellcaster cannot carry pouch (weight restriction).
- Spider Queen encounter 1: retreats through ceiling crack. No kill. Vinie found
  in web, cut free. Powder found in chamber debris.
- Spider Queen encounter 2 (future): crack blown open, no escape route, full kill.
  This completes the river cave.
- Consuming race member: two-phase fight. Retreats through the well crack:
  "I will return. With help." Does NOT die in Zone 1.
- The well cannot be closed in Zone 1. It shrinks slowly without maintenance but not fast enough.
- Faint mechanic applies to all escort sequences.
- Graveyard (south of village): blast rock secret accessible by both weapon
  master (powder) and spellcaster (blast spell). What's behind it: TBD.

**Year 1 starter dungeon — tutorial mechanics. Build this first.**

Two separate cave systems that share one wall. They are NOT the same structure.
They are connected by a single small natural opening between them, discoverable by exploration.
If the player does not find the hidden passage, they can exit back to the surface and enter
the other cave through its main entrance. Both routes are valid and reachable.

---

## Mine Side (Old Mining Operation)

Sealed ~15 years ago by Aethion closure order. Realistic medieval mine layout: main shaft
descending at angle, horizontal galleries following ore veins, support timber frames, wooden
cart tracks, drainage channels, tool niches, rest chambers.

**Lore state**: The twin group (dark figure + Felan + Vinie) entered the mine first. They lit
lanterns as they went — those lanterns are still burning in the first sections they reached.
Beyond where they stopped: total darkness.

**Lantern mechanics**:
- Lantern for the player: random placement in one of the first several lit rooms (can be missed).
- The darkness is the soft blocker — without light the player cannot navigate deeper.
- Lesser Light spell substitutes for the lantern entirely.
- Neither is given. Neither is announced. Player notices, picks up, proceeds.
- Oil lanterns use animal fat or rendered plant oil (period-appropriate, no refined fuel).
- One night of oil — enough for full exploration of both systems if not wasted.

**Key facts**:
- The consuming race member has been here for many years, alone, maintaining the disruption well.
- The twin group encountered this creature deep in the mines. They could not defeat it. Instead
  they used their combined Resonance to seal it inside — NOT a magical barrier. A physical
  cave-in: they used their Resonance to crack the support timbers as they fled, bringing down a
  section to slow the creature behind them. The seal is the hard blocker stopping the player
  from reaching the well directly.
- To clear the blocker, Ares needs the item/ability gained from the first Spider Queen encounter.
  This is the cross-progression mechanic: mine blocker resolved by what you find in the river cave.
- Mine blasting powder EXISTS in the deep mine but is not accessible until after the Spider Queen.
- The fight with the consuming race member takes place in the room BEFORE the disruption well.

**Creatures (mine side)**:
- Rats (disturbed from nesting in old timbers)
- Bats (hanging in galleries)
- Disrupted creatures spawned by the well in deep sections (Stone-type, aggressive, wrong)

---

## River Cave (Natural Cave)

Natural cave structure: river channel, stalactite/stalagmite formations, cave pools, narrow
squeezes, moss-covered wet rock, upper dry sections with spider webs.

**NO intelligent creatures.** The consuming race has not entered this side. Only natural cave
life drawn here by Resonance bleeding.

**Key facts**:
- The river water source flows through here. Spider Queen has nested over the water channel.
  Her presence and her eggs are what is actively contaminating the village water.
  Killing the Spider Queen = fixes the village water. She is the symptom.
  The well (mine side) is the cause. Both must be addressed for full resolution.
- The hidden wall passage: a small natural crack in the shared rock wall, discoverable by
  exploring the river cave. Not marked. Not obvious. Found by looking at the walls carefully.

**Creatures (river side)**:
- Bats
- Cave Spiders (natural, not disrupted)
- River-adapted creatures TBD

---

## Full Dungeon Progression Sequence

```
1.  Mine entrance → lit rooms (twin group's lanterns still burning) → pick up lantern or miss it
2.  Mine — evidence of the fight: scorch marks, ice crystals, fallen disrupted creatures
3.  Mine — THE BLOCKER: a physical cave-in. Heavy rubble across the gallery.
    Cannot be moved alone — needs two people or specific tools.
    (NOT a magical seal. A real collapse caused by the twins deliberately cracking support
    timbers as they fled.)
    Note: mine blasting powder EXISTS in the deep mine but is not accessible yet.
4.  Player goes to river cave — through secret wall crack (R-03 ↔ M-03 area) OR
    back to surface and in through the river entrance. Both valid.
5.  River cave — companion situation resolved (Mike is always present — see zone1_design.md):
    → Weaponmaster path: Mike was injured in the cave before reaching the safe room.
      Felan (twin — boy) is found okay in the SAFE ROOM and can speak.
    → Spellcaster path: Mike arrives at the safe room in good shape.
      Felan (twin — boy) is found drained/hollow in the SAFE ROOM — cannot speak.
    All three meet in the SAFE ROOM. Felan gives updates if able. If drained: silence.
6.  Player leaves companion(s) in SAFE ROOM. Goes alone into deeper river cave.
7.  River cave puzzles → SPIDER QUEEN LAIR (first encounter) — END of river cave
    Spider Queen retreats when damaged — escapes through a LARGE HOLE in the ceiling.
    She leaves behind: Vinie (the girl twin) wrapped in web, ready to be eaten.
    The player cuts her free. She is alive but weakened.
    New item found in the chamber: mine blasting powder from the queen's collected debris
    OR a specific ability scroll she dropped — TBD. This is the tool for the mine blocker.
8.  Player carries/helps the girl back through river cave to SAFE ROOM.
    ESCORT SEQUENCE: Same rooms, but creature reinforcements spawn (small spiders, bats).
    Companion in safe room is vulnerable if player is slow. Tension: get back intact.
9.  SAFE ROOM — all reunited. Full update conversation. Two objectives established:
    - Find what the consuming race member is doing in the mine (the well)
    - Spider Queen is still alive — the river cave crack leads deeper but is sealed.
      The mine blasting powder (or equivalent item) can open that crack later.
    Decision: go into the mine together now. The well is the priority.
10. Mine — together now. New puzzles requiring BOTH characters:
    - Weight puzzles: one person holds a pressure gate, other passes through and operates mechanism
    - Reach puzzles: one person occupies a creature's attention while other activates something
    - These cannot be solved solo. No workaround. Companion is required.
11. THE BLOCKER — cleared with the item/ability from Spider Queen encounter or companion brute force.
12. Deep mine — room before the well — consuming race member fight. Tense. Two-phase:
    Phase 1: uses the well's energy — more powerful, disrupted creatures assist it.
    Phase 2: isolated from well — fighting on own reserves. Depleted. Retreating.
    It retreats through the well crack: "I will return. With help."
13. The well chamber — through the doorway from the fight room. The crack in the floor.
    Void energy rising. Water source visible. The well CANNOT be closed — Ares has no
    understanding of how it was made and no tools to close it.
    It will shrink slowly now unmaintained — not fast enough to solve Vinemore's water problem.
    They leave. Nothing more to do here without knowledge they don't yet have.
14. SAFE ROOM — last conversation. The full picture for Zone 1 is assembled here.
    The girl explains what she knows (if she can speak). Mike accounts for what he saw.
    The spider crack in R-07 can be opened now (with the blasting item) but they are
    exhausted and have two injured people. Decision: leave now. Come back for the spider.
    (Spider Queen = future dungeon re-entry, after rest, resupply, and recovery in village.)
15. EXIT THE CAVE — escort sequence through all rooms, surface entrance.
    Extra creature spawns on the way out. Player must protect injured companions.
    **Faint mechanic applies**: Any character at 0 HP falls unconscious and must be treated
    (carried/stabilized) before they can move again. No permanent party faint. If Ares himself
    reaches 0 HP in a situation where no conscious companion can help him, that is the only
    true game over. The tension is real: a fainted companion becomes a burden you carry.
```

---

## Post-Cave — Road Back to Vinemore

```
16. Outside the cave: if player has NO void ring → sword owner (Pontos) is waiting on the road.
    He had come to look for Ares — worried, heard nothing all night. He joins the group.
    If player has void ring: no Pontos. He is in the village.
17. Road back: wild animals on the road — disturbed by cave events, acting wrong.
    Not consuming race creatures — just normal animals panicked by Resonance disruption.
    Player must protect the group. Running/evading is valid. Fighting is also valid.
18. Village entrance: dark void-type creatures attack the group.
    Same type that attacked Ares on the road after the temple (ring path) — but this time
    they appear REGARDLESS of the ring. The disruption is bad enough now that they manifested.
    The village guard comes out and helps fight the creatures off. Between the guard and Ares,
    the creatures are driven back. The group enters the village.
19. Ares collapses at the village entrance. Exhaustion. Injuries. He goes down.
    He wakes in his own home. Mark is sitting beside him, watching over him.
    The cutscene covers: what happened to everyone, village reaction, who is recovering where,
    what the water situation looks like now (Spider Queen gone temporarily → slight clearing
    but not clean — she needs to be killed for full resolution), and what Ares now knows.
```

---

## Mine Blasting Powder — Full Design

### Core Rules
- **Permanent effect**: Walls or cracks blown open with powder stay open forever. No reset.
  This is a structural change to the dungeon, not a puzzle state.
- **Lighting mechanic**: The player lights the powder directly with the lantern. No separate
  fire source needed — the lantern is always the tool.
- **Expandable**: More blast-powder walls will exist in future dungeons and areas.
  The mechanic is the same everywhere — find the powder, find the marked wall, use the lantern.

### Class Split — Who Can Use Powder

**Weapon Master path**:
- Needs a **powder pouch** to collect and carry loose mine powder.
- Powder pouch is sold by Lulu in the village shop **after the dungeon** (post-cave return).
- On re-entry to the Old Mine, the weapon master can collect powder from the mine itself.
- Powder is a physical item. The weapon master carries it comfortably.

**Spellcaster path**:
- **Cannot carry the powder pouch** — too heavy, incompatible with caster weight restrictions.
- Spellcasters rely on Caster's Robe and caster-specific items only. No adventurer's
  gear (Adventurer's Clothes) and no physical tool bags like the powder pouch.
- **Future content**: The spellcaster will eventually learn a magic blast ability that works
  identically to blasting powder on crack walls — same interactions, different source.
  When that ability exists, caster players can open the same walls. TBD for later content.

### Zone 1 Powder Setup (the crack in R-07)
The crack in Spider Queen's fight room (ceiling crack she escaped through) can be blown open
to pursue her. This is NOT done in Zone 1 — the team is exhausted and must leave. The crack
and the powder are the setup for a dungeon re-entry (Zone 2 content or early Zone 2) to
complete the Spider Queen kill. Spider Queen is an open thread.
The powder may be left in the safe room or carried out — either works.

---

## Boss Design

- **Spider Queen (encounter 1)**: Teach the player her patterns. She retreats when sufficiently
  damaged — escapes through a LARGE HOLE in the ceiling. Vinie (the girl twin) is found in her
  web after she flees. No kill yet.
- **Consuming race member**: Intelligent, two-phase, fights in the room BEFORE the well.
  Uses well energy (phase 1), then own reserves (phase 2). Retreats — does not die in Zone 1.
  Sets up future return.
- **Spider Queen (encounter 2, future)**: Same room, crack blown open. No escape route now.
  She fights to the end. Full kill. River cave fully clears.

**Talent scroll drops**: TBD when Spider Queen is finally killed (future). None from consuming
race member retreat.

**Technology note**: Mine infrastructure is medieval — hand-carved stone, wooden support beams,
iron brackets, rope pulleys for ore carts, clay-sealed drainage channels. No mechanical
automation. Lighting is oil lanterns (animal fat). See world_design.md: Technology Level.
