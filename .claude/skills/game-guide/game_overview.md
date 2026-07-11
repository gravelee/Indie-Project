---
name: Game Overview
description: >
  Core design identity: elevator pitch, pillars, target experience,
  core loops, scope, and hard constraints. Anchor for all GDD files.
type: project
---

# Echoes of the Void — Game Overview

**See also**: player_mechanic.md (mechanics), world_design.md (lore),
systems_design.md (progression + combat), doc_guide.md (build order)

## TL;DR

- Genre: 3D action RPG. Zelda dungeon feel + WoW world and quest depth.
- Engine: Godot 4.3. Platform: PC + console (hard constraint, day one).
- Year 1 scope: Zone 1 (Deep Forest) + Zone 2 (Meadow/Plains). No multiplayer.
- Predefined characters, not a character creator. Year 1: Ares only.
- No class selection. Class identity emerges through play.
- Difficulty is fixed — the world does not scale to the player.
- Every antagonist must have a worldview containing genuine truth.

---

## Table of Contents

1. [Elevator Pitch](#pitch)
2. [Design Pillars](#pillars)
3. [Target Experience](#experience)
4. [Core Loops](#loops)
5. [Scope and Year 1 Targets](#scope)
6. [Platform and Constraints](#platform)
7. [Genre and Inspirations](#genre)
8. [Unique Selling Points](#usp)
9. [Open Questions](#open)

---

## 1. Elevator Pitch {#pitch}

Echoes of the Void is a 3D action RPG for PC and console. The player
explores a handcrafted world of 8-12 zones — each a complete micro-world
with its own story, dungeon, and cast of characters. No class selection.
Identity emerges from choices and combat style. The world does not reset.
NPCs remember. Choices accumulate. The antagonists are not evil.

Inspired by Zelda's dungeon design, WoW's world depth and quest structure,
and the thematic honesty of One Piece and Naruto Shippuden.

---

## 2. Design Pillars {#pillars}

Five principles govern every design decision. When two options conflict,
the higher pillar wins.

**1. Skill over grind**
Player execution beats stat optimization. A skilled lower-level player can
clear higher-level content. Difficulty is set by the world — it does not
scale to the player. Stat investment deepens options; it does not replace
skill as the primary requirement.

**2. Emergent identity**
No class selection screen. Race selection at game start is the only
character creation choice. Everything else emerges through play: stat
investment, tools found, abilities discovered. The game reflects what you
became, not what you chose.

**3. Choices with weight**
A branch log tracks hard narrative forks. An affinity profile tracks soft
behavioral patterns. Neither is visible to the player. The world responds
differently based on who the player has been. Consequences are natural,
not punitive. No morality bar. No good/evil labels.

**4. A world that feels real**
Key NPCs have daily schedules and reactive dialogue. The starting village
was a real place before the player woke up. Services unlock through story.
Problems exist before Ares arrives. The tone: you stumbled into an ongoing
world — not into a game's start screen.

**5. Honest antagonists**
Every character that functions as an antagonist must have a backstory
explaining their worldview, a perspective containing genuine truth, and a
reason they believe their path is better. Not just power. Not just evil.
Inspired by Pain, Itachi, and Obito from Naruto Shippuden.

---

## 3. Target Experience {#experience}

**What the player should feel:**

- On arriving in the starting village: "something happened here last night,
  and I walked into the middle of it — nobody told me I'm the hero."
- On completing a zone: "this place is different because of how I handled
  it, not just because I cleared the dungeon."
- On encountering the consuming race: "I understand why they do this. I
  still have to stop them. I'm not entirely sure I'm right."

The game never tells the player what is right. Consequences reflect
choices. Players form their own conclusions.

---

## 4. Core Loops {#loops}

### Moment-to-Moment
Explore — interact with NPCs — fight creatures — solve puzzles.
Combat is skill-based: block timing, dodge, attack windows, resource
management (Energy / Flow / Focus). Exploration rewards curiosity:
hidden items, optional lore, NPC reactions to your behavior.

### Session
Arrive in zone — discover a problem — follow quest chain — enter dungeon
— confront what caused the Resonance disruption — leave something changed.
Each zone is a complete arc. The main quest and zone stories intersect at
defined beats.

### Long-Term
Emergent class identity solidifies through repeated combat style.
Branch log accumulates — later zones reflect earlier decisions.
Talent chains deepen skills. Gear degrades and must be maintained.
Main quest beats progress at the player's pace across zones.
Affinity profile shapes optional scenes and NPC dialogue across the game.

---

## 5. Scope and Year 1 Targets {#scope}

### In Scope — Year 1

- Zone 1 (Deep Forest): Vinemore village, woods, bridge, Old Mine +
  River Cave dungeon. Full story, all quest branches, both weapon paths.
- Zone 2 (Meadow/Plains): full design complete before coding begins.
- Ares as the only playable character.
- Emergent class system: Weaponmaster + Spellcaster archetypes.
- Branch log + affinity profile tracking.
- Gear + durability system (WoW-style, not BOTW-style — gear never
  disappears; it degrades and is repaired).
- Save system with faint mechanic (no permanent death for party members).
- PC build + console input mapping from day one.

### Out of Scope — Year 1

- Multiplayer of any kind. Do not build networking infrastructure.
- Zones 3-12: design only, no implementation.
- Non-Ares playable characters.
- Auction house or complex economy.
- Seamless zone transitions (zone gates in Year 1; seamless is future).

### Scale Reference

- Level cap: 30.
- Zone size: 100x100 tile maps.
- NPC daily schedules: key characters only.
- Quest count estimate: 14-21 quests per zone (main + side).
- Quest stat points: full game ~160; EXP buys the rest up to level 30.

---

## 6. Platform and Constraints {#platform}

### Hard Constraints — Non-Negotiable

- **Console portability**: every mechanic maps to a standard controller
  (Xbox/PS/Switch layout). No keyboard-only design decisions, ever.
- **Solo dev**: no feature requires another person to build or maintain.
  Every scope decision must account for one developer.
- **Engine**: Godot 4.3. No engine changes without full impact review.

### Technical Targets

- 3D environment. Camera mode TBD — see Open Questions.
- Each zone loads independently (zone streaming).
- Stable performance on mid-range hardware.

---

## 7. Genre and Inspirations {#genre}

**Genre**: 3D action RPG with dungeon exploration.

| Source              | What it contributes                                  |
|---------------------|------------------------------------------------------|
| The Legend of Zelda | Dungeon design, world interaction, key item puzzles  |
| World of Warcraft   | World depth, NPC life, quest structure, progression  |
| Majora's Mask       | NPC daily schedules; world-feels-alive quality       |
| One Piece           | Zone story formula: tragedy, engagement, restoration |
| Naruto Shippuden    | Antagonist design — Pain, Itachi, Obito as models    |
| Dark Souls          | World difficulty is set; skill is the answer         |

---

## 8. Unique Selling Points {#usp}

**No class screen**
Identity emerges, never declared. Two players finishing Zone 1 differently
have built different characters without choosing anything at a menu.

**Honest NPCs**
The world reflects behavior, not a morality bar. No good/evil labels.
Consequences are natural. Players see the social cost; they decide what
to do with that information.

**Antagonists worth understanding**
The consuming race is not evil. The antihero is not wrong. Players will
question their own mission before the game ends.

**Zone arcs**
Each zone is a complete story. The main quest is a thread connecting
micro-worlds — not a highway between boss rooms.

**Resonance framework**
Dungeons exist because the world's foundational energies were deliberately
disrupted. Not because a level designer placed a dungeon. The magic has
internal logic and consequences that extend into the main quest.

---

## 9. Open Questions {#open}

Unresolved design decisions. Do not close these until the file that owns
the topic is being written.

- **World name**: does the world at large have a canonical name? (The
  capital is Aethion; the world itself is unnamed in current documents.)
- **Zone 2 story**: protagonist situation, NPC cast, main quest beat 3,
  dungeon design. Design needed before Zone 1 coding is complete.
- **Ares's father**: his exact role in the Royal Guard of Aethion; what
  he becomes in later zones; why the ring path leads to their collision.
- **Cosmology**: what lies beyond the world's edge; whether gods exist;
  the true origin of the consuming race's nature. Let the story pull
  these answers out — do not decide cosmology ahead of narrative need.
- **Camera mode**: top-down fixed vs. 3/4 perspective vs. free follow.
  TBD after prototype testing. See player_mechanic.md for current state.
- **Spellcaster school profiling**: Kardino's questions during the
  Manifestation Test. Deferred until the spellcaster system is built.
- **Mitri**: currently a bridge helper with a placeholder character arc.
  His role in Zone 1 and beyond is not yet defined.
