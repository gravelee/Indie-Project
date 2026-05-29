# Review Sheet — All Key Decisions

> **How to use**: Read or listen to this file. Flag anything wrong, unclear, or that needs more thought.
> Say "mark [file] as reviewed" to clear its TL;DR status. Say "change: [what]" to queue an update.
> macOS TTS: `sed 's/#//g; s/\*//g; s/`//g; s/|/ /g' _review_sheet.md | say`

---

## SKILL.md — Technical Standards
- Tile 32×32. Entity sprites 96×96. Maps 100×100 tiles.
- GL Compatibility renderer. 1920×1080 fullscreen.
- Camera: 360° RMB rotation. WASD always camera-relative.
- Z-sort formula: z = pos.x × sin + pos.y × cos. Do not change without proof.
- Programmatic scene building — no TSCN files. Everything built in code.
- All stat math lives in stats.gd only. No hardcoded values elsewhere.
- Resource renames (code): rage → focus, mp/mana → flow.
- Blocking costs NO energy while held. Active shield abilities DO cost energy.
- Year 1: Zone 1 + Zone 2 fully playable only. Everything else design-only.

---

## zone1_design.md — Zone 1 Story & Quests
- 5 weapon paths: sword (found in woods), staff (steal from Kardino), axe (Nathan fetch), rocks (terrain), dagger (magical trade at Lulu).
- Kardino's chest NEVER LOCKS. Absolute. No game event locks it.
- Staff path locks at school entry. All others lock at east gate after the guard pass.
- Dark figure appears ONLY on staff path AND truth NOT told to Kardino. Never on weaponmaster paths.
- Bridge: staff path needs 2 helper (Kardino or void ring counts as 2). All others need 2 helpers.
- Cave companions: weaponmaster = Mike injured + Felan OK and speaking. Spellcaster = Mike fine + Felan drained and silent.
- Both twins in cave: Felan in SAFE ROOM. Vinie in Spider Queen's web.
- Spellcaster weight restriction: no Adventurer's Clothes, no powder pouch. Caster's Robe only.
- Ring path: Ms. Kathy dies from water sickness AND void ring proximity — both causes.
- Shadow figure returns once after cave on ring path — at graveyard exit after the funeral.
- Chapter 3 post-cave beats locked: Peter morning visit, Ms. Kathy mushrooms + father story, Lesen/twins, Gragi/Derol, Miria/Dario, Nathan gives axe permanently, Leman's wife gives rations.
- Post-cave shop: Lulu stocks powder pouch (weapon master only) and shield (creature parts).

---

## world_design.md — World Lore & Main Quest
- 10 main quest beats locked. Beats 1-2 fully designed. Beats 3-10 are concepts only.
- Consuming race: not evil — deceived into believing consumption is the only way to survive. Upper class suppresses the alternative.
- Dark figure: ancient Void Resonance being. Gave the ring = gave part of himself. Badly wounded. Returns once post-cave on ring path (graveyard), then gone from Zone 1.
- Ring/no-ring is a full-game narrative split: no-ring = learn about family from NPCs, no deaths from Ares's choices. Ring = eventually kills his father unknowingly, collateral deaths throughout.
- Ares's father: left Vinemore, joined Royal Guard of Aethion. Ms. Kathy knows. Exact future role TBD.
- 8-12 zones planned. Year 1: Zone 1 + Zone 2 only.
- Resonance: Verdant, Ember, Stone accessible at school Year 1. Void NOT school-accessible ever. Ring = slow passive attunement only.
- Technology: pre-industrial. Magic fills gaps. Mine blasting powder exists as exception to no-manufactured-explosives rule.
- Predefined named characters, not character creator. Year 1: Ares only.
- Future playable characters must appear in Ares's story first before selectable.
- All antagonists must have a worldview containing genuine truth.

---

## systems_design.md — Game Systems
- Energy: depletes from running, rolling, jumping, swimming, pushing, throwing, attacking, casting spells, active shield abilities. FREE while passively holding shield. Regens out of combat only.
- Flow (was mana): magic abilities. Regens out of combat only.
- Focus (was rage): builds IN combat from landing hits AND taking hits. Decays out of combat.
- Hybrid leveling: every completed quest = 1 guaranteed stat point (free). EXP from kills/exploration = additional stat OR talent points, player's choice.
- No class selection. Emergent from stats invested and tools acquired.
- Faint mechanic: party members faint at 0 HP — no permanent party death. Game over only if Ares is down with NO conscious companion available.
- EXP since last autosave lost on Ares death. Gear durability -10% on death.
- Autosave triggers: puzzle cleared, room cleared, boss defeated, quest step done, new zone/dungeon entered.
- Gear slots: weapon, shield, helmet, chest, legs, boots, ring x2, necklace. WoW-style durability — degrades, repaired at blacksmith, never disappears.
- Talent scrolls: boss drops, class-influenced. Must spend EXP talent points to activate in talent book.

---

## dungeon_design.md — General Dungeon Rules
- 15-25 rooms per dungeon. Entrance + mid-boss + final boss rooms.
- Dungeons fully reset on re-entry (creatures, boss, doors, puzzles). Story events do NOT repeat. Farm mode.
- Creature levels scale per repeat run, capped at player level +5.
- Dungeon map: paper and pencil style. Hand-sketched CanvasLayer fills in explored rooms. Player can annotate with icons.
- Patrol AI and Trap entities are NEW scripts — separate from creature.gd (overworld AI).
- Patrol types: LINE_PATROL, WALL_FOLLOW, AREA_WANDER, ROOM_CHASE.
- Trap types: spike trap, falling object, cracked tile, dart shooter, hazard tiles via tilemap metadata.
- Old Mine traps: spike LINE_PATROL movers + falling stalactites.
- Puzzle types: pressure plates, block push with Z-undo required, switches, sequence, ice slide, enemy-required, environmental trigger, light/mirror (late game only).
- Zone 1 creatures: rat (hostile), snake (hostile), bat (hostile, cave), cave spider (dungeon only), wolf (neutral), bear (neutral), deer (passive).
- Bosses are Resonance disturbance made manifest — NOT large versions of common enemies.
- ⚠ UNCONFIRMED: Old Mine mid-boss identity. "Stone Golem" mentioned for final boss only — mid-boss needs a decision.
- Year 1: Old Mine + Verdant Temple themes only.

---

## dungeon_oldmine.md — Old Mine + River Cave
- Two separate systems sharing one wall: Old Mine (human-cut medieval mine) + River Cave (natural cave). Not the same structure.
- Connected by a hidden natural crack in the shared wall — discoverable by exploring the river cave.
- Player chooses which entrance first. Mike takes the other. Plan to reconnect inside.
- Sequence: mine lit rooms → blocker cave-in → through wall crack to river cave → Spider Queen chamber → powder found + Vinie freed → all reunite in safe room → mine together → cave-in broken → consuming race member fight → well chamber.
- Blasting powder: permanent effect, lit directly with lantern. Weapon master needs pouch from Lulu post-cave. Spellcaster gets magic blast alternative (future content). Spellcaster cannot carry pouch.
- Spider Queen encounter 1: retreats through ceiling crack. Not killed. Vinie found in web, cut free. Blasting powder found in her debris pile.
- Spider Queen encounter 2 (future, Zone 2 timeline): crack blown open with powder. No escape. Full kill.
- Consuming race member fight: two-phase (uses well energy then own reserves). Retreats through the well crack. Does not die in Zone 1. Threat: "I will return. With help."
- The well cannot be closed. Ares lacks the knowledge. It shrinks slowly without maintenance.
- Faint mechanic applies: companions can faint in escort sequences. No permanent death.
- Graveyard south of village: blast rock secret, accessible by weapon master (powder) or spellcaster (blast spell). Contents TBD.

---

## story_book.md — Canonical Prose Narrative
- Canonical path: no ring, weaponmaster, hand axe, Adventurer's Clothes. No dark figure. No void vision.
- Chapters 1, 2, and 3 complete.
- Chapter 1: investigation → 4 patients → water source identified → weapon chain (sword found, axe chosen) → bridge with 4 helpers.
- Chapter 2: Verdant Temple quiet rest → mine entrance → split with Mike → mine (cave-in blocker) → wall crack into river cave → Spider Queen retreats + Vinie freed + powder found → all reunite → cave-in blown → consuming race member retreats → well cannot be closed → road back (animals wrong) → void creatures at gate → Daedalos helps → Ares collapses → wakes home, Mark beside him.
- Chapter 3: Mike's note in the dark → Peter morning visit (Ms. Kathy improving) → mushroom fetch → Ms. Kathy tells father story (Aethion Royal Guard) → twins Lesen visit → Gragi/Derol → Miria/Dario → Nathan gives axe permanently → Leman's wife gives rations → "tomorrow, east."

---

## architecture_reference.md — Old Project Snapshot
- Old project ~6k lines, 14 scripts, one flat level. Preserved for reference only. Never modify.
- Keep: z-sort formula, prop hierarchy, 3-layer pathfinding, static asset loader cache, stats formula pattern, ability resolution order.
- Rewrite: game.gd (split into camera/z-sort/builder), creature wander (simplify), map spawning (data-driven), effect management (separate from stats.gd), UI (signals not polling).
- Rewrite order: game.gd → stats.gd with renames → player.gd → creature.gd → props → pathfinder → UI → room system → NPC/dialogue/quest/inventory.

---

## Open Questions (not yet decided)
- Old Mine mid-boss: who/what is it? (final boss candidate mentioned was Stone Golem — but mid-boss unconfirmed)
- What is behind the blast rock in the graveyard?
- Gragi choice flag: which branch log entry is this? (door opened vs. turned away)
- Spellcaster blast spell: what is it called and when is it acquired?
- Verdant Temple dungeon: is this Year 1 or post-Year 1? (listed as Year 1 theme 2, but full design not started)
- Zone 2 story: not yet designed.
