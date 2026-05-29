---
name: World Design Reference
description: World lore, main quest arc, resonance framework, the consuming race, the dark figure, world zones, technology level, and narrative philosophy. Load this when working on story, lore, world building, or anything beyond Zone 1.
type: reference
---

# World Design Reference — Aethion and Beyond

**See also**: SKILL.md (technical), zone1_design.md (Zone 1 content), dungeon_design.md (dungeons), story_book.md (prose narrative)

## TL;DR [NEEDS REVIEW]
- 10 main quest beats locked. Do not change lightly.
- Consuming race: not evil by nature — were deceived into believing consumption is their only way to survive. Upper class exploits this lie.
- Dark figure: ancient Void Resonance being. Gave the ring = gave part of himself. Badly wounded in Zone 1. Returns once post-cave (ring path, graveyard).
- Ring/no-ring is a full-game narrative thread: no-ring = family discovery, no deaths from Ares's choices; ring = Ares eventually kills his father unknowingly, people die as collateral.
- Ares's father: left Vinemore, joined Royal Guard of Aethion. Ms. Kathy knows. Exact story TBD.
- 8-12 zones planned. Year 1: Zone 1 (Deep Forest) + Zone 2 (Meadow/Plains) only.
- Resonance: Verdant/Ember/Stone accessible at school Year 1. Void NOT school-accessible — ring is the only path, slow passive attunement.
- Technology: pre-industrial, magic fills gaps common people can't access. Mine powder exists as exception to no-explosives rule.
- Predefined named characters, not a character creator. Year 1: Ares only.
- Future playable characters must appear in Ares's story first before becoming selectable.
- Villain rule: every antagonist must have a worldview containing genuine truth.

## Table of Contents
1. [World Structure & Zone Overview](#world-structure)
2. [World Zones Table](#world-zones)
3. [Towns & Services](#towns)
4. [Village Shop (Zone 1)](#village-shop)
5. [Main Quest Arc (10 Beats)](#main-quest-arc)
6. [The Consuming Race — The True Threat](#consuming-race)
7. [The Dark Figure](#dark-figure)
8. [The Resonance Framework](#resonance-framework)
9. [Resonance Types](#resonance-types)
10. [Races & Resonance](#races)
11. [Planned Races](#planned-races)
12. [Villain & Story Depth](#villain-depth)
13. [World Technology Level](#technology)
14. [Narrative Design Philosophy](#narrative-philosophy)

---

### World Structure
- **Scale**: Medium world — 8–12 named zones. Dense and handcrafted, not open empty space.
- **Zone transitions**: Zone gates (visual threshold + loading trigger). Seamless transitions
  are a future upgrade — not year 1. Each zone is a complete 100×100 tile map.
- **Starting zone**: Mystic Forest Village — human village deep in a forest.
  Player has a home here. The player belongs to this place before the adventure begins.
- **Zone opening**: After Zone 1, MULTIPLE zones open simultaneously — not a linear chain.
  The world branches. Exploration is the player's choice. Biomes change sporadically across the
  world, but each zone entrance has a deliberate visual shift and introduces 1-2 new mechanics.
  Each zone has its own micro-world (story, NPCs, dungeon, creatures).
- **Zone progression**: No forced order — player can explore zones as they discover connections.
  Soft level gates (creature levels suggest readiness) but never hard locks.
- **Story structure per zone (One Piece formula)**:
  1. Tragic old story — something is wrong here, has been for a long time. Players learn WHY.
  2. The player engages — quests, dungeon, confrontation with what caused the imbalance.
  3. Restoration of order — not always clean. Some quests affect lives of specific people.
     How the player solved it (approach, choices) shapes what the restoration looks like.
  Each zone is a self-contained arc. The zone story and the main quest connect at key beats.

### World Zones (Target: 8–12, Year 1: 2 fully playable)
Planned biomes — names TBD, serve as design anchors:
| Zone | Biome | Water | Notes |
|---|---|---|---|
| 1 | Deep Forest | Rivers, small pools | Starting zone. Mystic Forest Village. |
| 2 | Meadow / Plains | Lakes, wide river | Opens after Zone 1. Other villages near water. |
| 3 | Mountain / Highland | Mountain streams | High altitude, vertical terrain feel. |
| 4 | Swamp / Marsh | Stagnant water, bogs | Dark, overgrown, visibility reduced. |
| 5 | Desert | Rare oasis | Harsh, exposed, heat mechanic potential. |
| 6 | Coastal / Shore | Sea, tidal zones | Near ocean. Sea Bottom dungeon entry point. |
| 7 | Tropical / Jungle | Dense rivers | Hot, lush, ruins buried in growth. |
| 8 | Ice / Snow | Frozen lakes | Cold mechanic potential. Frost Resonance. |
| 9 | Volcanic / Ember | Lava flows | Ember Resonance. Extreme hazard tiles. |
| 10 | Underground Network | Underground rivers | Cave system connecting zones. |
| 11 | Storm Peak / Sky | Clouds, wind | Tempest Resonance. Late game. |
| 12 | Void Sanctum | Absence | Final area. Void Resonance. |

Year 1 scope: Zone 1 (Deep Forest) + Zone 2 (Meadow/Plains). All others: design only.

### Towns & Services
- **Settlement types**: 2 mid-size villages + several smaller settlements/outposts.
  Not every zone has a town — wilderness zones may have only a single NPC camp or shrine.
  Every dungeon has a story but may or may not have a nearby settlement.
- **Standard village services** (what every mid-size village eventually offers):
  Blacksmith (gear repair), Vendor (consumables, basic gear), Inn (manual save, rest buff),
  Quest givers (named NPCs with story), Talent book shop or trainer (spend EXP).
- **Starting village exception**: Mystic Forest Village begins with LESS services.
  Some services unlock as the story progresses (e.g., the carpenter opens after a quest,
  the inn reopens when an NPC is rescued). Services growing with the story = investment in place.

### Village Shop (Zone 1)
Single shop in Mystic Forest Village. No gold at game start — player must barter creature parts
first. Once barter economy is established, gold flows from bounty quests and can be spent here.

**Stock:**
| Item | Type | Notes |
|---|---|---|
| Small Dagger | Weapon | Requires barter magical item to be traded with |
| Wooden Shield | Equipment | Active blocking item — reduces incoming damage |
| Rations | Consumable | Restores HP + Energy out of combat (see Ration Mechanics below) |
| Rope | Key Item | Used for the broken bridge puzzle in the woods |

**Ration Mechanics:**
- Player uses a ration → sits down animation plays, HP and Energy restore over a few seconds.
- Effect: out of combat only. Eating mid-combat is not possible.
- If combat begins while the player is sitting/eating: effect is immediately cut, player stands
  up and enters combat state. Partial restoration already gained is kept.

### Main Quest Arc (10 steps — do not change lightly)
The main quest is a guiding thread, not a forced path. These 10 beats are fixed; everything
between them is player-paced. Race-specific and playstyle-specific quests are additive.

1. **Local disruption**: The player wakes to a neighbor at their door — a fourth villager has
   just fallen ill. Four people sick, same symptoms. The player investigates: visits three houses,
   talks with patients.
   A guard blocks the eastern path — something feels wrong in the woods, no one passes without a
   weapon. The player returns to the couple (one of the patients), and a doctor arrives. Together
   they conclude the river water is contaminated. The source: the cave at the old abandoned mines
   to the east, where the river originates. Nobody understands the scope yet — it looks like a
   local problem with the water. A missing person adds a second thread. The player investigates.
2. **Into the cave**: Ares arms himself and travels to the mine complex. On the way: a detour
   to the Verdant Temple (lead from Kardino), then a creature encounter tied to the void ring.
   At the mine entrance: two entrances, two paths. Mike splits off if present. Ares enters the
   old mines. Light runs out. The cave holds evidence of a real fight — disrupted creatures,
   foreign markings from the consuming race, the aftermath of what happened the night before.
   Deep inside: one twin found alive but drained completely, unable to speak. The other twin
   is missing. The disruption well at the water source is confirmed as deliberate interference.
3. **The global picture**: TBD.
4. **Other peoples**: Player travels far, meets other races and cultures. Forms alliances.
   Some companions join. Each culture has its own relationship with the Resonance disruption.
5. **The consuming race**: Player discovers a race whose existence requires consuming others
   to survive. Not by choice — by nature. Like apex predators. Like humans to the earth.
   They are not evil. They simply ARE what they are.
6. **The antihero villain**: A powerful figure who opposes the player's approach. Not wrong —
   they have valid reasons and genuine truths behind their worldview. They function as a
   mirror: what the player might become if they chose a different path.
7. **The argument**: Player tries to convince the consuming race there is another way to survive.
   This is not a fight — it is a conversation, a philosophical confrontation.
8. **The revelation**: The consuming race did not choose this. They were TRICKED into believing
   this was the only way they could exist. A forbidden alternative lifestyle has been suppressed.
9. **Tracing the deception**: The manipulation traces back to the race's own powerful upper class.
   Those with power exploiting those without — using the powerless as a permanent justification
   for their own authority and survival method.
10. **The resolution**: Not a boss fight to save the day. A confrontation with power structures,
    with inequality, with the cost of choosing to see imbalance and act rather than just doing
    your job and looking away. No clean answers. Inspired by One Piece and Naruto in thematic depth.

**Core themes**: Inequality, power exploitation, the difficulty of seeing imbalance and choosing
to intervene, the cost of having a clear heart/mind/soul in a world that punishes it.

**Villain philosophy (standing rule)**: Any character functioning as antagonist must have a
backstory that explains their worldview, a perspective containing genuine truth, and a reason
they believe their path is better — not just power, not just evil.

### The Consuming Race — The True Threat

The main antagonist force of the game is not a single villain — it is a race that has been
deliberately creating Resonance disruption wells across the world for many years.

**What they do**: They identify an area and create a disruption well there — a forced destabilization
of the local Resonance. The well corrupts the land: water turns foul, wrong creatures manifest,
the elemental balance of the area shifts. Over time the zone becomes uninhabitable. This clears
the area of its current inhabitants, enabling the consuming race to move in and use whatever
they need.

**Why they do it**: Established in Main Quest Arc steps 5-9. They were not always like this.
They were deceived into believing consumption is their only means of survival. Their upper class
deliberately suppresses the alternative. Their society is built on this lie.

**The disruption wells are deliberate, not accidental.** Each well is placed. Each target area
is chosen. The storm at the Verdant Temple the night before Ares's story begins was not random —
it was triggered. The consuming race had already targeted Vinemore's area. The disruption in
the cave, the sickness in the river, the wrong creatures appearing — all of it is the opening
stage of a takeover that has succeeded in other parts of the world before this.

**Their presence in Zone 1**: A team from the consuming race is already in the cave at the Ancient
Mine complex when Ares arrives. They came to ensure the disruption well forms correctly and to
deal with any interference. The dark figure and the twins were that interference. The consuming
race team engaged them inside the cave, causing the separation.

### The Dark Figure

A being of Void Resonance. Old. Has been fighting the consuming race's expansion for a very long
time — long enough that he understands exactly what they are doing and has developed a method
to slow them: using his own life force alongside the life force of willing participants to build
**barriers** that trap the disruption wells from the outside, preventing them from expanding or
manifesting fully.

**His limitations**: The barriers are temporary and cost him life force to maintain. He is losing.
He can only slow the expansion — not stop it. He needs allies who understand the stakes.

**His state in Zone 1**: He found the twins — recognized them as powerful young Resonance users
and contacted them. He told them about the threat and what was coming to their area. Together
they went to the Verdant Temple to cast a protection barrier. The consuming race intervened
and the ritual failed. They retreated to the mines. Fighting in the cave left him badly wounded.
By the time he appears to Ares in the north woods (in the stolen-staff path), he is running on
almost nothing — which is why the ring he offers carries real cost. It is his remaining power,
shaped into a transferable object. He gave away part of himself.

**The ring**: Not a trick. A genuine gift of his power. The cost to Ares is real because the
power was never Ares's to carry — it belongs to a being of pure Void and exerts pressure on
someone who is not.

### The Resonance Framework
The world is sustained by ancient forces called **Resonances** — not gods, not conscious beings,
just the fundamental energies that everything is made of. Each Resonance sustains a part of the
world: one holds mountains together, another drives water to flow, another makes things grow.
They naturally balance each other like pressure in a closed system.

**When a Resonance is disrupted**, it doesn't die — it goes uncontrolled. The energy that once
held a mountain together now tears it apart. The forest Resonance no longer nurtures growth —
it grows wildly and consumes everything. These disrupted zones become **Resonance Wells** —
what people call dungeons.

Creatures inside Resonance Wells are not evil. They are animals and beings warped by uncontrolled
elemental energy. Their aggression is the Resonance expressing itself without moderation — the
same way electricity arcs when it has no ground. They are not malicious. They are suffering.

**Why dungeons respawn**: Defeating the boss re-anchors the Resonance temporarily, but the
disruption is not permanently healed. The force naturally becomes unstable again over time.
This is the lore justification for dungeon resets — not a game mechanic excuse, an honest
consequence of the world's nature.

### Resonance Types (evolving — add/rename over time)

**Player-accessible Resonances (Year 1 school path)**: Verdant, Ember, Stone.
Tide, Gale, Frost, Tempest unlock in later zones as the world expands.

**Void**: NOT accessible through the spellcaster school at any point in Year 1.
Accepting the dark figure's void ring begins a slow passive attunement to Void energy —
the player is not taught it, they absorb it through carrying the ring. Over time (future zones)
this attunement can be developed. Void is the most powerful and most dangerous Resonance.
The consuming race's power is rooted in Void. This path is intentionally difficult to reach
and has consequences the player does not fully understand until much later.

| Resonance | Sustains | When Disrupted |
|---|---|---|
| **Verdant** | Growth, forests, living things | Wild uncontrolled growth, creature mutation |
| **Ember** | Heat, light, transformation | Uncontrolled burning, volcanic activity |
| **Tide** | Water, cycles, flow | Floods, pressure, deep-sea emergence |
| **Gale** | Wind, sky, movement | Storms, disorienting currents, creatures of air |
| **Stone** | Earth, stability, mass | Collapses, earthquakes, creatures of living rock |
| **Frost** | Cold, stillness, preservation | Frozen spread, re-awakened preserved things |
| **Tempest** | Storm, electricity, violent change | Lightning arcs, electromagnetic distortion |
| **Void** | Silence, absence, space between | Things that shouldn't exist emerging |

### Races & Resonance
Every living thing is composed of Resonances. The number and combination shapes the being.

**Single-Resonance beings**: Driven by one pure force. Not evil — just undivided. No internal
conflict to moderate their nature. A pure Ember creature doesn't choose to burn — burning is
what Ember does. Their aggression (in disrupted zones) is Resonance without balance, not malice.
Single-Resonance beings experience the world with an absolute depth no multi-Resonance being
can match. They are not lesser — they are narrow and perfect within their nature.

**2-3 Resonance beings**: The most stable cultures. Enough internal dialogue to build real
philosophy, focused enough to have clear identity. These are the "wise elder race" archetypes —
not because they are inherently superior, but because balance within creates the capacity for
considered thought.

**All-Resonance beings (Humans)**: The most internally divided. Every force pulls in a different
direction simultaneously. This makes humans volatile, short-lived compared to single-Resonance
races, and prone to extremes — both the greatest acts of good and the worst things in the world's
history have been human. Not because humans are special or chosen — but because they are the only
race capable of going in *any* direction. Their all-Resonance nature is not a gift. It is a burden
that some carry toward wisdom and others toward destruction.

### Planned Races (evolving — expand over time)
- **Humans**: All Resonances in tension. Most adaptable, most volatile. No stat bonus, no
  penalty. The most unpredictable class of beings in the world.
- **Verak**: Stone + Frost. Dense, slow-aging, physically durable. High DEF/STA starting stats.
  Slate-like skin, amber-glow eyes. They don't mine stone — they grow with it over centuries.
- **Sylviri**: Verdant + Tide. Fast healers, poison-resistant. Bark patches, bioluminescent
  markings at night. High SPR/AGI starting stats. Curious and exploratory by nature.
- **Miren**: Tide-primary. Amphibious, iridescent skin, large dark eyes. Fast and agile,
  especially near water. High AGI starting stats. Fully land-capable.
- **Ashkari**: Ember + Gale. Wiry, fast, heat-resistant. Ember-glow veins under skin.
  High STR/AGI starting stats. Reckless and competitive by culture.

Each race has starting stat distributions that naturally nudge toward certain playstyles without
forcing them. Race-specific quests unlock during play based on race + emergent playstyle.

### Playable Character Roster (Predefined — Not Custom)

The game uses predefined named characters, not a character creator. Each playable character is
a person with a name, a starting life, and a specific situation. The player inherits an identity.

**Year 1: One character.**
- **Ares** — Human male. Vinemore. Full Zone 1 story designed and in progress.

**Ares's Background (known facts — expand as story develops):**
- His father left Vinemore and joined the **Royal Guard of Aethion** — the capital city's guard.
  This decision is spoken of in the village by people who knew him. Ares himself knows little
  about his father's current life or whereabouts. Ms. Kathy is one of the first people to bring
  it up — she knew Ares's father well and tells the story after Ares brings her mushrooms
  (no-ring path, Chapter 3). More details TBD as the story expands into Aethion's territory.

**The Ring / No-Ring Narrative Split (full-game thread — locked):**
This is the central consequence of accepting or refusing the void ring. It plays out across
the entire story, not just Zone 1.

- **No-ring path**: Ares learns about his family through NPCs over the course of the journey.
  People remember his father, share stories. No one dies because of his choices or his presence.
  His path is harder in some ways (less power) but cleaner in its human cost. The father story
  becomes a thread of discovery — who was this man, where did he go, what did he become?

- **Ring path**: Ares will eventually fight and kill his father without knowing it — somewhere
  in the main story, across a later zone. The father is serving Aethion (possibly in a role
  that puts him against Ares's mission). The ring's void influence and Ares's trajectory on
  this path lead directly to this moment. People die around Ares on this path — not from
  malice, but as collateral of what carrying the ring requires. The dark figure hinted at this
  in his final Zone 1 appearance: collateral losses are part of the method. Ms. Kathy was the
  first. The father will not be the last.
  **The reasons why this happens on the ring path specifically: TBD later.**

**Future additions (scope TBD — not Year 1):**
- A second human character (female, different name, different starting situation) is the most
  realistic next addition — same race means no new resonance/weapon framework, just a new story.
- Non-human characters require the race's resonance efficiency modifiers and weapon access rules
  to be fully designed first — do not add a non-human playable character until their race is
  well-defined mechanically.

**Future characters appear in Ares's story first (standing rule):**
Every future playable character must exist as a named NPC in Ares's journey before they become
selectable. They have a role, a personality, a moment that matters — a quest chain intersection,
a shared objective, a conflict, or a help that costs something. Players form a real relationship
with them through Ares's eyes before ever playing as them.
When the character is added to the roster, the payoff is: players already know her, already have
feelings about her, and now get to see the same events from the inside. Her starting situation
and opening area flows from what was already established in Ares's story — reducing the design
work and deepening the narrative connection simultaneously.
Design consequence: future character NPCs must be written with weight from the start. They cannot
be throwaway encounters. The moment Ares meets them should be one the player remembers.

**Race resonance efficiency (framework — TBD when races are defined):**
The design intent: non-human races are NOT locked out of resonances, they are more or less
efficient at them. A Verak can use Verdant Resonance with investment; they simply won't reach the
ceiling a Sylviri hits. Humans access everything at average efficiency — generalist, not specialist.
This applies to Resonance manipulation AND to weapon access. A Stone-resonance race might only be
able to wield large heavy weapons (which they swing faster and carry more easily than humans can),
but cannot use daggers or short blades at all. Their physical passive abilities compensate.
Do not design this in detail until the specific race's character is being built.

### Villain / Story Depth
No simple antagonist. Any character that functions as an antagonist must have:
- A backstory that explains how they arrived at their worldview
- A perspective that contains genuine truth or valid concern
- A reason they believe their path is better — not just power, not just evil

The most interesting antagonist direction: beings whose *existence* requires consuming others —
not out of malice, but because that is what they are. Like apex predators, like humans to the
earth. The question is not "how do we stop the evil being" — it is "what do we do about a being
that is simply being what it is?" There may be no clean answer. The story should not pretend
there is one. Inspired by Pain, Itachi, and Obito from Naruto Shippuden — characters whose
actions are monstrous and whose reasons are comprehensible.

The story's central mystery: why can't Resonance balance be permanently restored? What disrupted
it in the first place? Who or what keeps it unstable — and do they even know what they're doing?

---

## 10b. World Technology Level (Design Framework — Expand Per Zone)

This world is pre-industrial. Technology exists but it is NOT the driver of civilization —
**magic is**. Technological advancement stalled because magical solutions filled the gaps
that would otherwise have pushed engineering forward. The result is a world that looks and
feels roughly medieval in material terms but has magical infrastructure where another world
might have mechanical infrastructure.

### What Exists
- **Metalworking**: Iron and bronze in common use. Steel exists but rare and costly.
  No refined alloys, no blast furnaces — smithing is craft-scale.
- **Mining**: Hand tools (pickaxe, wedge, mallet). Wooden cart tracks for ore. Rope-and-pulley
  hoists for vertical shafts. Timber supports. Clay-lined drainage channels. No mechanized
  ventilation — ventilation shafts cut to surface, sometimes with magical airflow aid.
- **Lighting**: Oil lanterns (animal fat, rendered plant oil, whale-equivalent creature fat).
  Torches (pitch-soaked wood). Candles (beeswax or tallow). Magical light sources exist —
  Lesser Light spell, enchanted stones, luminous mushroom extracts in specific regions.
- **Medicine**: Herbal remedies, poultices, bone-setting, blood-letting (considered effective
  in this world — magical biology responds differently). No germ theory. Healing spells are
  real and fill the role of surgical medicine.
- **Writing and records**: Parchment, ink, quill. Books exist and are valuable. Libraries exist
  in cities. Rural villages may have only one or two literate residents.
- **Transportation**: Horses, carts, boats (river and coastal). No steam. Magical transportation
  exists in theory (portals, teleportation) but is rare, costly, and controlled.
- **Architecture**: Stone and timber. Mortared masonry. No concrete, no steel framing.
  Large structures (temples, city walls) built over generations. Magic assists in construction
  of impossible-looking structures (very tall towers, perfectly smooth stone).
- **Communication**: Messenger, written letter. Magical communication exists (crystal spheres,
  bound familiars) but only among the wealthy or the institutionally powerful.

### What Does NOT Exist
- No manufactured explosives or weapons-grade powder
  *(Exception: **mine blasting powder** — a rare craft-scale material found in old sealed mine
  sites, used historically for mining operations. Not produced commercially. Not a weapon by
  default. Limited quantities exist in specific locations — the Old Mine is one.)*
- No mechanical automation (gears, clockwork, steam)
- No electricity (except naturally occurring Tempest Resonance phenomena)
- No printing press — books are hand-copied
- No standardized currency at all regions (Vinemore's barter economy is normal for rural areas)
- No long-distance coordinated communication networks

### Magic as Infrastructure
Where another civilization would build a machine, this world casts a spell. Magical
solutions exist for: permanent light (rare, expensive), water purification (used in cities,
not villages), Resonance-based healing, travel (limited), communication (elite only).
The existence of magic did not make life easier for common people — magic is controlled
by those who can learn it (INT + SPR investment, scroll access, school attendance).
Common people live in the same material conditions as medieval equivalents.

### Cosmology — To Be Expanded
This is a placeholder. The world's cosmological framework (how Resonances relate to creation,
what lies beyond the world's edge, whether gods exist in any form, the true origin of the
consuming race) will be developed zone by zone as the narrative demands it.
Do not decide cosmology in advance of the story needing it. Let the story pull the answers out.

---

## 19. Narrative Design Philosophy — Real-Life Lessons Through Play

This game is built with a deliberate second layer: every quest chain is also a moral scenario.
Players don't receive lectures. They make choices, live with consequences, and the game reflects
the world back at them without judging. The lessons are embedded in outcomes, not dialogue.

**Core principles for writing quest branches:**
- No choice is labeled good/evil. The game never tells the player what is right.
- Consequences must be natural, not punitive. If you steal, NPCs trust you less — not because
  the game punishes theft, but because that is how trust works.
- Every path must be completable. No path dead-ends. Even the worst sequence of choices leads
  somewhere. The destination just looks different.
- Persistent ambition is always recognized eventually. A player who makes bad choices but
  genuinely pursues a goal will find someone who understands them.
- Good deeds without need for reward pay extra dividends later. This is embedded structurally.

**Moral threads established in Zone 1 (the bridge chain):**

| Choice | What the game teaches (without saying it) |
|---|---|
| Steal the staff | Easy gain, social cost. NPCs who don't know don't judge. Those who find out do. |
| Steal + tell truth | Admitting wrong restores trust. Better outcome than lying. |
| Steal + lie consistently | Doors close. You are left alone. But ambition still finds its own path. |
| Return the sword (didn't have to) | Voluntary good deed compounds. Affinity, clothes, help later. |
| Accept the cursed ring | Self-sacrifice for the people has a personal cost. Heroism isn't free. |
| Refuse ring + forced honesty | Losing something you took is the natural end of that road. |
| Sword person: love swords but return it | The path leads you to something different (axe) — not worse, just different. You trusted the process. |
| Persistent bad-path player | Eventually someone who shares your nature will understand your goal and help. |

**Intended player archetypes and what they experience:**
- *"Stealing is fine"*: Game never argues. But NPCs reflect it. Doors close quietly. The player
  sees the social cost without being told it's wrong. They decide what to do with that information.
- *"I'll do what it takes for the village"*: The ring. Effective. Personal cost. The game says:
  yes, and — here is what it cost you. Was it worth it? Player decides.
- *"I'll be honest even when it's hard"*: Best social outcomes. Not always the easiest road.
  But consistent: honesty and accountability are recognized and rewarded by people who value them.
- *"I'll do the right thing even if I'm poor"*: Returning the sword when you need a weapon,
  trusting you'll find another way. The game rewards this with extra. Always.

**Standing rule**: Never moralize in NPC dialogue. NPCs react as real people would — some judge,
some understand, some don't know. The player forms their own conclusions from outcomes.
