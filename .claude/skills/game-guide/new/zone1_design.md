---
name: Zone 1 Design Reference
description: Zone 1 full story design — characters, opening sequence, weapon chain, quest log, spellcaster school, bridge puzzle, pre-cave journey, cave companion system. Load this when working on any Zone 1 story, quest, NPC, or content design.
type: reference
---

# Zone 1 Design Reference — Vinemore & The Old Mine

**See also**: SKILL.md (technical), world_design.md (lore/main quest), dungeon_design.md (cave rooms/bosses), story_book.md (prose narrative)

## TL;DR [NEEDS REVIEW]
- 5 weapon paths: sword (found in woods), staff (steal from Kardino), axe (Nathan fetch quest), rocks (terrain), dagger (magical trade at Lulu).
- Kardino's chest NEVER LOCKS under any circumstance. Absolute rule — do not add locking logic.
- Staff path commits at school entry. All other paths lock at east gate.
- Dark figure appears ONLY on staff path + did NOT tell Kardino the truth. Never on weaponmaster paths.
- Bridge: staff path needs 1 helper (Kardino counts as 2); all others need 2 helpers.
- Cave companion matrix: weaponmaster = Mike injured + Felan OK (can speak); spellcaster = Mike fine + Felan drained (cannot speak).
- Both twins in cave: Felan in SAFE ROOM, Vinie in Spider Queen's web.
- Spellcaster weight restriction: cannot carry Adventurer's Clothes or powder pouch. Caster's Robe only.
- Ring path: Ms. Kathy dies (water sickness + void ring proximity — both causes).
- Shadow figure returns once post-cave on ring path: at graveyard exit after funeral. Last Zone 1 appearance.
- Chapter 3 beats fully locked — see Section 13.
- Post-cave: Pontos/Nathan give weapon permanently. Lulu stocks powder pouch + shield after cave.

## Table of Contents
1. [NPCs — Brief Roster](#npcs)
2. [Zone 1 Named Characters (Full)](#zone-1-named-characters)
3. [World Names](#world-names)
4. [Village Context — State of the World at Game Start](#village-context)
5. [Opening Sequence (Main Quest Step 1)](#opening-sequence)
6. [Zone 1 Quest Log](#quest-log)
7. [The Woods & Road Areas](#the-woods)
8. [Bridge Puzzle — Full Design](#bridge-puzzle)
9. [Weapon Chain — Full Design](#weapon-chain)
10. [Spellcaster School](#spellcaster-school)
11. [Player Choice Log & Psychological Profile System](#player-choices)
12. [Cave — Companion System & What Ares Finds](#cave)

---

## 1. NPCs — Brief Roster {#npcs}

- **Named individuals** with personalities. Not generic types.
- **Schedules**: Key NPCs follow daily routines (Majora's Mask style). Reserve for significant characters only.
- **Reactive dialogue**: NPCs respond to story progression. How the player completed a quest changes what they say.
- **Exceptional hostility**: Rare. Always story-driven, never accidental.

---

## 2. Zone 1 Named Characters (Full) {#zone-1-named-characters}

**Naming convention**: Ancient Greek names are reserved for characters whose stories connect
to the main themes (heroism, grief, disruption, consequence). English names are used for the
everyday fabric of village life. The distinction is meaningful — a Greek name signals weight.

| Name | Role | Notes |
|---|---|---|
| **Ares** | Player character | Lives in the village. Slightly older than Mark. |
| **Mark** | Ares's friend / neighbor | Lives next door to Ares's family home. His father is a close friend of Leman. Knocks on Ares's door at game start. |
| **Miria** | Patient 3 — pregnant woman | Couple with Dario (husband). Fragility: pregnancy (not yet announced). |
| **Dario** | Miria's husband | Tries to turn Ares away at the door. Tells Ares about Ms. Kathy (patient 1). |
| **Ms. Kathy** | Patient 1 — old woman | Lives alone. Her name is never used in dialogue — everyone calls her "the old woman who lives alone." First to fall ill. She regularly goes to the river's edge to collect mushrooms and edible vegetables. **Ring path**: She dies. Cause is BOTH — water sickness progressing (oldest, weakest, most exposed) AND the void ring's proximity accelerating her decline. The ring drains from the vulnerable. The shadow figure hints at this after the funeral. |
| **Derol** | Patient 2 — river man | Was with his son Fredy at the eastern river. Second to fall ill. |
| **Mr. Gragi** | Derol's father | Answers the door at House 3. "Are you a doctor?" |
| **Fredy** | Derol's young son | Was with Derol at the river. Called for help when Derol collapsed. |
| **Vincent** | Witness / helper | Was passing by when Derol collapsed near the river. Helped carry him home. Confirms the spot to Ares in the village square. Only accessible after Ares attempts all 3 patient houses. |
| **Leman** | Patient 4 — chronic health | Has known, long-standing health problems. Mark's father is his close friend. Mentioned by Mark at game start: "Mr. Leman — with the known health issues." Doctor visits him first before coming to Miria. |
| **Peter** | Village doctor | Visits patients. Arrives at Miria's house after Ares. Connects all four cases. Leaves to prepare the public meeting. |
| **Daedalos** | East gate guard | Won't let anyone through without a weapon. Mentions weapon sources. Proud of his spear, Mariane. Introduces the concept of weapon range naturally. |
| **Pontos** | Sword owner | Lost his wooden sword in the north woods. Offers borrow deal in exchange for creature parts. Hints at other weapons if player seems hesitant. |
| **Mr. Kardino** | Old man / staff owner | Has a wooden staff in his chest at home. **Kardino's chest NEVER LOCKS — it is always accessible as optional theft. No game event locks it.** Kardino refuses to hand over the staff directly; the chest is always an option the player must discover themselves. |
| **Mr. Lulu** | General shop owner | Runs the village shop. Has: dagger, wooden shield, rations, rope. Economy starts barter-only. Dagger requires a magical item trade (not standard barter). |
| **Nathan** | Blacksmith | Will lend the hand axe, but requires a creature parts fetch quest first. Guard mentions the blacksmith. Legitimate early path but costs time. |
| **Kadmios** | Carpenter / bridge man | Standing at the broken bridge. His shop is closed — expecting a carriage from Roteltree. Close friend of the late Terin. Led the rescue team into the mines. Tells Ares about the missing twins. Before Ares leaves the village, Kadmios tells him he will send his son Mike along. Mike appears and joins Ares when Ares crosses the bridge heading east. |
| **Mike** | Ares's companion into the cave | Kadmios's son. Returned from a hunt in the south deep forest the evening before. Tired, but joins Ares when his father asks. **Always accompanies Ares into the dungeon — see Companion System for how they meet based on whether Ares carries the ring.** |
| **Lesen** | Lone mother of the twins | Husband Terin died in the mine accident. She went to Kadmios when Terin disappeared; she goes to him again when the twins go missing. |
| **Felan** | Twin — missing (BOY) | 15-17 years old. Gifted spellcaster, specific element TBD. Student of Kardino and the spellcaster school. Went missing during the thunderstorm. Found in the SAFE ROOM of the river cave. |
| **Vinie** | Twin — missing (GIRL) | 15-17 years old. Gifted spellcaster, different element from Felan. Student of Kardino and the spellcaster school. Went missing during the thunderstorm. Found in Spider Queen's web at the end of the river cave. |
| **Terin** | Lesen's deceased husband | Skilled miner. Continued secretly mining the closed eastern mines after the Aethion closure order. Fell into a deep gap in the tunnels and died. Only Lesen knew about his secret mining. |
| **Mitri** | Son of Asotos | Lives alone to the west. TBD — a separate character will take the notorious village role. Mitri's role is not yet defined. |
| **Asotos** | Village hero (deceased) | Defended the village from thieves. Poisoned by a knife, died the next morning. A statue in the village square bears his name and story. |
| **Dora** | Asotos's wife (deceased) | Died of grief after losing Asotos. |
| **Joel** | Asotos's child | Sibling of Mitri. Got over the grief, started a family in a nearby village. |
| **Shadow Figure** | Wanderer / spellcaster | Appears in the north farming woods to spellcaster-path players only. Offers the Void ring. No name ever given. |

---

## 3. World Names {#world-names}

- **Vinemore** — the starting village (canon name).
- **Roteltree** — neighboring village to the east, beyond the cave. Kadmios was expecting a carriage from Roteltree the morning the story begins.
- **Aethion** — the kingdom's capital city. The order to close the eastern mines came from Aethion years ago.

---

## 4. Village Context — State of the World at Game Start {#village-context}

Vinemore is a quiet, closed community deep in a forest. Most people have lived here their whole
lives. Few travel. Families know each other. There is a calm to the place — or there was.

**The night before the story begins**, a thunderstorm hit the village. One of the worst in
living memory — possibly the worst Ares has experienced in his lifetime. Lightning struck a
large tree on the east road. The tree fell across the bridge span and partially collapsed it.
By morning the storm had passed, but Vinemore is upside down: roofs damaged, fences down,
debris everywhere. People are already outside assessing what the night took from them.

Kadmios the carpenter learned early that the east road was blocked. He had been expecting a
carriage from Roteltree — supplies or trade, the road matters to his work. The blocked bridge
became his immediate problem.

**The same morning**, Lesen — a woman raising her twins alone since her husband Terin died
years ago — discovered that her children, Felan and Vinie, had not come home. They went out
during the storm and did not return. She went straight to Kadmios, the same way she had years
ago when Terin went missing in the mines. He did not need her to explain much. The whole
village knows the twins.

**Over recent days**, four villagers have also fallen ill: dizziness, fatigue, tachycardia.
Different underlying fragilities in each case. Nobody has yet connected the sickness to the
storm, the bridge, or the missing twins. Everything is happening at once.

**The mines**: The eastern mines were profitable for many years before an order from Aethion
closed them abruptly. The closure was fast. Terin — a skilled miner his whole life — could not
imagine another way to live. He continued secretly mining rare minerals from the closed tunnels.
Only Lesen knew. One day he did not come back. After a full day of waiting, Lesen told Kadmios
everything. Kadmios assembled a rescue team and went in. He found Terin dead — fallen into a
large gap deep in the tunnels. The mines were sealed more thoroughly after that.

**The twins — Felan and Vinie**: 15-17 years old. Gifted spellcasters, each able to manipulate
a different element. Considered the most talented young people in Vinemore. Both were taken under
the wing of Mr. Kardino, and both attended the spellcaster school.

**The statue in the village square**: Engraved name: Asotos. The inscription: a night long ago
when thieves attacked Vinemore. Asotos fought and won. Poisoned knife. Died the next morning.
The statue stands in his memory. His son Mitri lives alone to the west.

---

## 5. Opening Sequence (Main Quest Step 1 in Detail) {#opening-sequence}

Ares's day begins at home — making food or just waking up. A knock at the door.

**Mark** is there. Friend, neighbor, lives next door. He is urgent but not panicked:
*"Mr. Leman — you know, the one with the known health issues — he's the fourth now."*
A fast mention, no weight to it in this moment. Mark says he is going to find Peter the doctor.
He leaves quickly.

Ares decides to go see the other patients himself.

**Patient order:**
1. Ms. Kathy — old woman, lives alone (first to fall ill)
2. Derol — was at the eastern river with son Fredy (second)
3. Miria — Dario's wife, pregnant (third)

**Important**: Ares MUST attempt all three houses before Vincent becomes accessible in the
village square. The order is free, but all three must be tried. No skipping.

---

**House of Ms. Kathy** *(patient 1 — locked)*

Ares knocks. No answer. Again. Still nothing. The door is locked.
An old woman who lives alone. No way in. He moves on.

---

**House of Miria and Dario** *(patient 3)*

Dario is outside. "She's exhausted. She needs rest." Miria's voice from inside, thin but clear:
*"I'm awake. Let him in."* They go in together.

Miria talks — what she ate, where she went, what felt different. She doesn't know what caused
it. Dario, reaching for something solid: *"The old woman who lives alone — Ms. Kathy — she
was the first, you know. They found her so weak. Maybe it's something they ate. Something small."*

Neither mentions the pregnancy.

---

**House of Mr. Gragi and Derol** *(patient 2)*

Mr. Gragi opens the door. Looks Ares over: *"Are you a doctor?"*
- **Kind / honest reply** → access granted.
- **Dismissive reply** → door closed.

Inside, Derol is in bed. He was at the eastern river with his son Fredy — just standing near the
water. The fever came fast before they turned home. He almost fell. Fredy called for help.
Vincent was passing by, carried him home.

---

**Village Square**

Only accessible after Ares has attempted all three patient houses.

Vincent is not old — a regular villager who happened to be nearby when Derol collapsed.

- **If Ares entered Derol's house and spoke calmly**: Vincent confirms what Ares already mostly
  knows — Derol nearly fell by the river path, Vincent helped carry him home.
- **If Ares was turned away at Derol's house** (door closed): Vincent tells Ares what happened
  — saw a man collapse near the river, helped him home.

Either way, Vincent adds a specific detail: *"He went down right next to the river — exactly
the spot where the old woman goes to collect mushrooms and those edible greens of hers."*
Ares does not yet connect this. He files it away.

Main quest update: *Find the spot by the river where Derol fell ill.*
Secondary: *Return to Miria and Dario — they may know more.*

---

**Daedalos (east gate)**

Ares heads east. Daedalos is posted at the path.

*"Something's wrong out there. People falling ill, I don't know what's in those woods lately.
Nobody passes without a proper weapon."*

He gives Ares names — not descriptions, not what anyone has:
- Pontos — lives in the east part of the village.
- Old man Kardino — usually sits in the village square in the afternoons with his friends.
- The general shop (Mr. Lulu) might have something.
- The blacksmith (Nathan) might have something.
He does NOT say what kind of weapon any of these people have. He does NOT say where anything
is kept. He gives names and a general direction. What Ares finds is up to Ares.

He pats the shaft of his spear. *"Me — I like this. Close enough to reach, far enough to
breathe. I call her Mariane."* The player absorbs weapon range as an idea without being taught.

Main quest update: *Find a weapon. Return to Miria and Dario — they may know more.*

**WEAPON CHAIN UNLOCK**: All weapon NPCs (blacksmith, Pontos, Kardino, Mr. Lulu, spellcaster
school) become interactive only after this conversation. Before this, the village runs normally.

---

**Miria and Dario — Second Visit** *(with Peter)*

Miria speaks plainly this time. She is pregnant. Too early to announce — but four people ill
and a public meeting coming, she cannot hold it. The pregnancy is why she was fragile. She was
the third to fall ill and she does not think it is coincidence.

A knock. Peter enters. He came directly from visiting Leman — Mark's father's close friend,
the one with the long-standing health condition. The severity there worried him enough to stop
here before going home. When Miria tells him about the pregnancy, he exhales — slightly relieved.
But not for long.

Together in that room, all four cases laid out:
- Ms. Kathy: very old — her health is weakened simply by age. And Peter adds: she regularly
  goes to the river's edge to collect greens and mushrooms. Almost every other morning.
- Derol: was directly at the eastern river with Fredy.
- Miria: pregnant — her health is naturally suppressed during pregnancy.
- Leman: chronic long-standing health condition — always the first to fall when something spreads.

Dario says something about food. Peter pauses on that. He asks: what did Miria eat? Who else
might have eaten the same things? The answers don't line up for a shared food source. But then
he reconsiders: *what if it's not the food — what if it's the water used to prepare the food?
To drink? To wash with?*

Peter works it out: only Derol was directly at the river. But village water comes from the same
source. In a healthy person, trace contamination passes without effect. In someone with a
compromised system — elderly, pregnant, chronically ill — even trace amounts could cause this.
It would explain why only these four. The water.

Peter stands. Going to make this public tonight. He leaves with purpose.

Main quest update: *The river water may be the source — contaminated at its origin.
Find where the eastern river starts.*

---

**The Cave at the Old Mines**

The river flows east — out of the woods, from the cave near the old abandoned mines. Empty for
years. The entrance was blocked after the timbers started rotting — a barrier, not a seal, to
keep people from wandering in. The cave is accessible if you are determined. The river comes
out from inside it.

If the water is wrong, the source is in that cave. Between Ares and the cave: the woods, the
farming grounds, the broken bridge, and whatever made the water sick. None of it is reachable
without a weapon first.

---

## 6. Zone 1 Quest Log {#quest-log}

| Quest | Type | Trigger | Notes |
|---|---|---|---|
| Investigate the Sickness | Main Quest | Game start — knock at door | Full path: 3 houses (all attempted) → square (Vincent) → east instinct → guard blocks → weapon chain → east woods → bridge (Kadmios) → return to couple → doctor arrives → conclude water problem → buy rations → bridge puzzle → cave |
| Find the Missing Twins | Side Quest | Kardino mentions his missing students at the bridge; Kadmios tells the full story | Felan and Vinie — Lesen's twins — went missing during the thunderstorm. Ares adds this to his cave objective. |
| Return the Sword | Side Quest | Sword owner NPC (unlocks after finding sword) | Keep sword OR return for Adventurer's Clothes + borrow deal |
| Borrow the Sword | Repeatable | Sword owner, after return | Creature parts as payment |
| Fetch Parts for Nathan | Side Quest | Nathan (blacksmith) | Required to borrow the hand axe. Player brings creature parts → axe lent. |
| Creature Hides | Side Quest | Village NPC | Skins → money → rations |
| Resonance Manipulation | Side Quest (staff only) | Kardino interaction chain — see Spellcaster School | Optional quest for the spellcaster path |
| Creature Aura Investigation | Side Quest (staff only) | NPC in the woods | Reward: second lesser spell |
| Creature Bounties | Repeatable | Village shop NPC | Creature parts → barter → shop economy |
| Buy Rations | Quest-required step | Added to quest log after water conclusion with the doctor | Ares adds buying rations to his plan before heading into the cave. Must visit Mr. Lulu's shop. |

**Progression path**:
```
Home → 3 houses (all attempted, any order) → village square (Vincent)
→ east instinct → guard blocks → weapon chain (sword / staff / axe / dagger)
→ east woods first visit → bridge (Kadmios, learn about twins, Mike announced)
→ return to Miria's house (couple) → doctor arrives → water conclusion
→ quest update: buy rations + bridge puzzle needed
→ buy rations (Mr. Lulu) → bridge puzzle (weapon + rope + 2 helpers)
→ cross bridge → Mike joins Ares → road to mines
→ Verdant Temple detour (Kardino's tip) → [ring path: creature encounter]
→ mine complex entrance → player chooses which cave to enter first
```

**Shop / barter economy note**: Shop cannot accept gold at game start. Creature parts from
bounty hunting establish the barter economy. Ties into the bridge puzzle and ration loop.

---

## 7. The Woods & Road Areas {#the-woods}

Both forest areas are ~100×100 grid maps, same scale as the village. Creatures in the woods
must be avoided at game start — fists alone are not enough to fight safely.

**Area 1 — Farming Woods**
- Creatures: Rats (primary), occasional Snake
- Contains the hidden spot where the lost wooden sword can be found
- Primary creature farming zone — player returns here repeatedly for bounty quests and hides
- No combat shortcuts: the sword is a reward for exploring, not handed to the player

**Area 2 — Bridge Road (connects village to cave)**
- Creatures: Snakes (sparse — this is a path, not a farm zone)
- Contains the broken bridge over the poisoned river
- Bridge was destroyed by a storm-felled tree during the Resonance disruption
- The water is poisoned — the player cannot cross the river
- **The bridge puzzle must be solved to reach the cave** — see Bridge Puzzle below
- **East path is guarded**: Daedalos blocks the road. Will not let anyone through without a
  proper weapon. Rocks do not count — he says so directly.
  Effective gate: wooden sword, wooden staff, hand axe, dagger.

**Area 3 — Road to the Mines (after bridge)**
- Mike joins Ares here after crossing the bridge (Kadmios sent him)
- Creatures: Regional wildlife (mostly passive), with one scripted encounter (ring path only)
- Road is mostly clear. Dense vegetation on both sides.
- **Waypoint: Verdant Temple** — small shrine southeast of the woods, slightly off the main road.
  Kadmios directs Ares here before departing: a lead on the missing twins may be there.
  Built upon Verdant Resonance. Midday arrival if player goes directly.
  - Ares sits, eats the morning meal, makes a quiet wish for the children's safety.
  - **Void Ring Vision (ring required)**: If Ares carries the void ring, it resonates with the
    Verdant Resonance of the shrine. A vision strikes him — cold sweat, feeling of false memory.
    He sees: Felan and Vinie at this temple the night before, together with the shadowy figure
    from the north woods. A ritual of some kind. The thunderstorm erupts mid-ritual — something
    goes wrong. The dark figure shields the children from the storm. They flee toward the mines
    fast and direct. Then the vision ends and Ares is back at the shrine.
  - No ring: quiet rest. The shrine is peaceful. No vision.
- **Creature Encounter (ring path only)**: On the return path to the crossroads, a creature attacks.
  - Appearance: unlike anything from this region — darker, wrong somehow, dissonant with the forest.
  - Behavior: before attacking, it makes sounds as if trying to communicate. But its appearance is
    so ominous that Ares attacks first without waiting.
  - This creature ONLY appears if Ares carries the void ring.
  - **If player wins**: creature retreats. Mike meets Ares at the mine entrance — Kadmios sent him
    separately. They meet here for the first time and head in together.
  - **If player loses**: Mike arrives mid-fight and helps drive the creature off. They sit together
    to recover, Ares updates him on everything, then they travel to the mines together.

**Area 4 — The Mine Entrance**
- **Damage visible**: The wall built to seal the mine entrance (rotting timbers) has a clear breach.
  Someone or something got through.
- **Two cave systems discovered here**:
  - The old mine: sealed entrance (now breached). Dark. Connected to the river internally.
  - The river cave: a second opening nearby where the village river flows out from underground.
- **Mike and Ares arrive together** (always — see Companion System for how they met on the road).
  Mike recognizes the second entrance and tells Ares about it. They discuss the situation.
  **The player chooses which entrance to go into first** — no UI prompt, just the choice of
  which opening to approach. Mike takes the one Ares doesn't choose. They split to cover both
  routes and plan to reconnect inside. They enter as night falls.
- **Guard dialogue hub** (moved here for reference):
  - Mentions Pontos by name and where he lives — does NOT mention the sword or that it was lost
  - Mentions old man Kardino by name — says he's usually in the village square with friends.
    Does NOT mention any staff or any item Kardino has.
  - Points to general shop and blacksmith — does NOT specify what kind of weapon either carries.
  - Talks about his own spear with pride: introduces weapon range as a concept without lecturing.
- **Guard weapon-check mechanic** (when player arrives WITH a weapon):
  Guard acknowledges the weapon, asks if they've tried it. Mentions they can still swap before
  stepping east — once they go east, that's their weapon for the road.
  - Two different weapons (e.g. stolen staff + sword): guard says to pick one and come back.
  - Adventurer's Clothes: guard notices and gives brief positive acknowledgment.
  - **Weapon lock**: Once the player steps east past the gate, their weapon is locked for Zone 1.
    Exception: rocks are always collectible and never locked out.
    **Staff path exception**: The staff path locks earlier — when the player chooses to enter the
    spellcaster school. From that point, they are committed to the staff. Lended weapons are no
    longer available and cannot be picked up again.

---

## 8. Bridge Puzzle — Full Design {#bridge-puzzle}

The bridge collapsed when a storm-felled tree landed on it. The river is poisoned — player
cannot cross it. The fallen tree trunk remains at the scene.

The puzzle is a multi-step social chain. Choices made earlier in Zone 1 determine which helpers
are available.

**Step 1 — Assess**: Interact with Kadmios at the bridge. He examines the fallen trunk as a
carpenter and ex-miner — he knows heavy work. His read: they need rope to bind and control the
trunk, and at least 2 more people beyond just the two of them. He tells Ares to get rope from
the shop.

**Step 2 — Rope**: Lulu at the general shop. Pure transaction — he sells the rope, nothing more.
No puzzle information from him.

**Step 3 — Recruit helpers**: Player returns to the people they already have relationships with.
Available helpers depend on weapon path and choices made. See Bridge Helpers table in Section 9.
Once the player has the right number, they cannot recruit additional people — they know they have
enough and NPCs acknowledge this.

**Step 4 — Bridge solved**: Player + Kadmios + helpers move the trunk together. Kadmios provides
the leverage calculation; helpers provide the force; the trunk clears.

**Helper count by path**:
- **Staff path (any)**: +1 helper only. Kadmios looks at the group and says they may not be
  enough with only 3 people — he is proven wrong. Kardino's magic or the ring's power makes up
  the difference without Kadmios having accounted for it.
- **All other weapons (sword, axe, dagger)**: +2 helpers required.

---

## 9. Weapon Chain — Full Design {#weapon-chain}

### Pontos (Sword Owner)

**Quest trigger**: Ares must SPEAK WITH PONTOS before the sword quest exists. If Ares goes north
before talking to Pontos, nothing is in the woods — the sword is not there yet. The quest
activates when they talk. Pontos explains he lost his wooden sword somewhere in the north woods.

If Ares finds the sword and RETURNS it promptly:
- Pontos gives Adventurer's Clothes (+armor). Offers borrow deal (creature parts in exchange).
- Pontos stays in the village.

If Ares delays returning the sword (goes to guard with it, lingers):
- Pontos eventually goes looking for it himself. His own decision, based on time and worry.
- He meets the dark figure in the north woods. Background event — no consequence chain.

**Axe or dagger path — Pontos fetch quest**: A player already armed with the axe or dagger can
still speak with Pontos, learn about the lost sword, find it, and return it. Pontos sees Ares is
already armed and does not offer the sword. He gives Adventurer's Clothes as thanks and tells
Ares the sword is available to borrow only in a critical situation (left unarmed). This qualifies
Pontos as a bridge helper. **Adventurer's Clothes for the axe and dagger paths come from Pontos
— this is the only source.**

**Bridge helper**: Pontos helps move the bridge trunk if the sword was returned to him — on any
weapon path.

---

### Kardino (Old Man / Staff)

**Quest trigger**: Ares must SPEAK WITH KARDINO before the staff quest exists. Kardino is
usually in the village square in the afternoons with his friends. When Ares asks for a weapon,
Kardino refuses and becomes indignant — mentions his staff is safely locked at home. He is not
going to hand it to a young man he barely knows.

**Kardino's chest NEVER LOCKS.** This is the single authoritative rule. The chest at his home
is always accessible as optional theft. No game event, no timing, no story trigger ever locks it.
Do not add chest-locking logic anywhere in the codebase or design documents.

**Optional quest triggered**: "Resonance Manipulation"
- If Ares has NOT yet visited the spellcaster school → quest directs him to visit the school
  first to understand what disruption manipulation is and what tools are needed.
- If Ares HAS already visited the school → quest updates directly to finding the staff in Kardino's home.

**Kardino's questions** (inside school, if truth was told): Deferred — will be specified when
the spellcaster system is nearly ready.

**Bridge helper (staff path)**: Kardino helps move the bridge trunk if the player has the staff
and told him the truth. He uses the staff himself to help.

---

### Nathan (Blacksmith / Axe)

Nathan will lend the axe but requires a creature parts fetch quest first. Fair exchange — costs
time and combat. The guard's directions lead here.

**Dagger path — Nathan fetch quest**: A player on the dagger path can still do Nathan's fetch
quest (bring creature parts). Nathan sees Ares is already armed with the dagger. He thanks him,
says the hand axe is available to borrow only in a critical situation (left unarmed). This
qualifies Nathan as a bridge helper.

**Bridge helper**: Nathan helps move the bridge trunk if the fetch quest was completed — whether
the player is on the axe path or the dagger path.

---

### Dagger (Mr. Lulu's Shop)

The dagger requires a magical item trade — not standard barter, not creature parts.

- Lended weapons (sword, axe): Lulu recognizes them. Won't accept something that isn't the
  player's to give.
- Stolen staff: Lulu doesn't recognize it. Thinks it's unusual. Asks for confirmation — if yes,
  staff is gone permanently. Only way to get the dagger through trading.
- The dagger is a valid early path. Not economically blocked.

**Weapon lock (dagger)**: Once the player holds the dagger they cannot keep any other weapon,
even before passing the guard. The dagger commits the player from the moment of acquisition.

**Dagger path — building bridge helpers**: The player still needs +2 helpers. Since Kardino
cannot help (staff was traded away, no truth told), the player must invest in at least one
of the other NPC chains to reach the required count:
- Complete Pontos's fetch quest → Pontos helps (Adventurer's Clothes also received as thanks)
- Complete Nathan's fetch quest → Nathan helps
- Approach Mitri → Mitri helps with promise of future favour

Minimum: Mitri + one of (Pontos or Nathan). If both Pontos and Nathan quests are done, Mitri
is not needed.

**Adventurer's Clothes (axe and dagger paths)**: Received from Pontos as thanks for returning
his sword. The player keeps their own weapon — Pontos gives the clothes regardless. Requires
doing the Pontos fetch quest; not automatic for these paths.

**Escape route — give dagger to Kardino**: If the player tells Kardino the truth about the
stolen staff and gives him the dagger as an apology, Kardino accepts but is angry and will NOT
help at the bridge. The player is now unarmed and free to pursue the sword or axe path instead.
Kardino's anger is permanent for Zone 1 — his relationship with Ares does not recover here.

---

### Spellcaster School — Full Path Design {#spellcaster-school}

The school is in Vinemore. Ares can visit it at any time after the guard conversation unlocks
the weapon NPCs.

**If Ares visits school BEFORE speaking to Kardino**:
School tells him: to learn disruption manipulation, he needs a disruption tool — a staff, wand,
or crystal ball. He needs to find one first. He finds Kardino. Kardino refuses. Staff theft
becomes the obvious path.

**School entry requirements** (enforced at the door every time):
- Player must carry ONLY disruption tools (staff, wand, crystal ball, magical items).
- Any other weapon (sword, axe, dagger) → turned away at the door.
- Player must return any lended weapons before entering.
- Once committed to the school path, lended physical weapons are no longer available.
- **Commitment warning**: "Are you sure you want to begin Resonance Manipulation learning?
  This path is intense, and once committed you cannot return to the physical fighting way."
  Ares must confirm.

**Inside the school (entry sequence)**:

1. If the staff was stolen: someone at the entrance notices it and makes a comment —
   *"That staff looks familiar."* Nothing more. No confrontation. The comment is noted and the
   conversation moves on. Ares proceeds.

2. **Disruption Affinity Test**: Discovers the player's natural Resonance affinity. Result is
   partially random, partially player input. This is the player's assigned element. Can be
   changed later through an Attunement test.

3. **Manifestation Test**: A timed interactive test. Player gives inputs — button presses,
   combinations, frequency, rhythm. The game evaluates:
   - Total input frequency (how active was the player)
   - Pattern regularity (rhythmic vs. chaotic)
   - Sustained engagement (did they keep going or stop early)
   Visual feedback during the test shows elemental energy responding to the player's input.
   Failure: player not active enough → reduced result (lower tier starting spell, or retry).
   Success: player manifests their element → receives one **lesser offensive spell** of their
   affinity type.

4. **Spellcaster profiling (Kardino's questions — deferred)**: Will be specified when the
   spellcaster system is nearly ready. Shapes the character of the starting offensive spell.

**Guard check (staff path, school not yet visited)**:
Guard asks: "Do you have an affinity? Have you manifested at least one offensive spell?"
Ares doesn't understand. Guard explains: a Resonance Manipulation user who hasn't learned their
affinity is not useful out there. Visit the school first.

---

### Bridge Helpers — By Weapon

| Helper | Available when | Notes |
|---|---|---|
| **Kardino** | Staff path + truth told to Kardino | Counts as 2 people (magic). Staff path only needs +1 total. |
| **Pontos** | Sword returned to him | Available on sword path AND dagger path (if fetch quest done). |
| **Nathan** | Fetch quest completed for him | Available on axe path AND dagger path (if fetch quest done). |
| **Mitri** | All paths | Promises future favour (binding obligation). Needed most on ring path. |

**Staff path (truth told)**: Kadmios + Kardino = enough. Kadmios doubts 3 is enough — proven wrong.
**Staff path + ring (not truth told)**: Kadmios + Mitri (or any 1 helper) + ring = enough. Kadmios doubts 3 is enough — proven wrong.
**Sword / axe / dagger paths**: Need Kadmios + any 2 helpers from the table above.

Once the required number of helpers is assembled, no additional helpers can be recruited.

**Special case — over-recruited (staff + truth + Mitri)**: If the player recruited Mitri before
completing the Kardino chain, they arrive at the bridge with Kadmios + Mitri + Kardino (effective
power of 4). Kadmios makes no comment on manpower — the numbers are clearly fine. Kardino is the
one who remarks: something to the effect that with this many hands it will be straightforward.
A small moment that rewards players who explored more than they needed to.

---

### The Dark Figure

Appears ONLY to players on the staff path who did NOT tell Kardino the truth.
Does NOT appear to weaponmaster paths at all. Does NOT appear to staff path players who told
Kardino the truth (they are on the honest/Kardino path — the ring is irrelevant to them).

**Why**: He can sense Resonance affinity. He is drawn to disruption manipulation users who are
operating outside sanctioned channels — carrying the staff secretly. A player who told Kardino
the truth and has Kardino's blessing is on a different kind of path. The ring is Void energy —
only meaningful to someone already attuned to Resonance work and carrying that weight alone.

**When**: After the player is on the staff path (not-truth-told) and ventures into the north woods.

**The ring**: Power of two people, at personal cost. A genuine gift — not a manipulation. But
the Void energy exerts real pressure on a human body not built to carry it. The cost accumulates
as problems along the road. Not visible immediately.

**Identity**: A wanderer and spellcaster who has been fighting the consuming race's expansion
for years. He recognized the disruption forming near Vinemore before the village noticed. He
found the twins first because they are Resonance-sensitive. Now, badly wounded from the cave
fight, he gives what he has left. He returns ONE final time after the dungeon — after Ms. Kathy's
funeral (ring path only). Briefly. He sought Ares out specifically because of what the ring did
to her. He says what he needs to say and does not appear again in Zone 1 after that.

---

### Weapon State at Cave Entry

**Rule**: Player has exactly 1 weapon when entering the dungeon. Void ring is optional.
Player NEVER has both Adventurer's Clothes and Caster's Clothes simultaneously.

| Path | Weapon | Armor | Spells |
|---|---|---|---|
| Sword returned + borrow deal | Wooden Sword | Adventurer's Clothes | None |
| Sword returned + axe instead | Hand Axe | Adventurer's Clothes | None |
| Sword kept (not returned) | Wooden Sword | None | None |
| Axe path (Nathan) | Hand Axe | Adventurer's Clothes from Pontos (if sword quest done) | None |
| Dagger path | Small Dagger | Adventurer's Clothes from Pontos (if sword quest done) | None |
| Staff + school, truth told, ring refused | Wooden Staff | Caster's Clothes | 1+ lesser offensive spell |
| Staff + school, truth told, ring accepted | Wooden Staff + Void Ring | Caster's Clothes | 1+ lesser offensive spell |

**Notes**:
- Staff path player must have at least one lesser offensive spell before the guard lets them through.
- Additional spells possible if Creature Aura Investigation quest was completed.
- Adventurer's Clothes source for axe and dagger paths: TBD when those paths are built out.

**Spellcaster weight restriction** (applies throughout Zone 1 and forward):
- Spellcasters CANNOT carry: Adventurer's Clothes, blast powder pouches, or any heavy physical
  gear. These are too heavy and incompatible with caster discipline.
- Spellcasters MUST use: Caster's Robe + caster-specific items (TBD). These are their only
  armor/gear slots. They may not mix physical gear with caster gear.
- Enforced at the school door: carrying incompatible gear triggers a refusal/comment.

**Post-cave shop update (Mr. Lulu)**:
After Ares returns from the cave, Lulu's shop is restocked and expanded. New item available:
- **Powder Pouch** (Weapon Master only): allows collection and carrying of loose blasting powder.
  Not purchasable by spellcasters — Lulu reads who you are by what you're wearing/carrying.
  With the powder pouch, the weapon master can re-enter the Old Mine to collect powder and
  eventually return to use it on the sealed crack in Spider Queen's chamber (future content).

---

## 11. Player Choice Log & Psychological Profile System {#player-choices}

Every choice the player makes feeds into two tracking systems: a **Branch Log** (hard forks that
change what happens) and an **Affinity Profile** (soft accumulation that shapes how the world
reads the player over time).

Neither system is visible to the player. No morality bar. No alignment UI.
The world simply responds differently based on who the player has been.

---

### Branch Log — Hard Fork Choices (Zone 1)

| # | Choice Point | Options | Locked Consequence |
|---|---|---|---|
| B-01 | Weapon acquired | Sword / Staff / Axe / Rocks / Dagger | Weapon path shapes bridge puzzle options and available helpers; determines Weaponmaster vs. Spellcaster class |
| B-02 | Staff — taken or not | Steal / Leave alone | Stolen = staff in hand or traded for dagger |
| B-03 | Old man — truth or not | Tell truth / Say nothing | Truth = Caster's Clothes + full school path. Nothing = no Caster's Clothes, no school training. |
| B-04 | Sword — return or keep | Return promptly / Delay | Return = Adventurer's Clothes + borrow deal; delay = Pontos goes to woods on his own |
| B-05 | East gate — passed with sword before returning it? | Yes / No | Yes = Pontos eventually goes to woods on his own (time-based). No = Pontos stays. |
| B-06 | Dark figure encounter | Appears / Doesn't appear | Appears ONLY if player is on staff path AND did NOT tell Kardino the truth. Never appears on weaponmaster paths or honest staff path. |
| B-07 | Void ring — accept or refuse | Accept / Refuse | Accept = ring carried, creature encounter triggered on road to mines, affinity shifts toward Void |
| B-08 | Creature fight — win or lose | Win / Lose | Win = Mike meets Ares at mine entrance; Lose = Mike saves Ares mid-fight, then travels together |
| B-09 | Cave entrance chosen first | Old Mine / River cave | No locked consequence — both must be explored. Player choice reflects psychology only. |

---

### Affinity Profile — Soft Accumulation (Zone 1)

These values shift quietly based on behavior patterns. They do not gate content directly —
they weight future content, change NPC tone, and determine which optional scenes trigger.

**Void axis**: Separate from the trait profile below. A visual bar showing where the player
sits on a spectrum — no labels for the poles (not "light vs. dark," not good vs. evil).
Starts in the middle. Carrying the ring, accepting void offers, and attacking the temple creature
push toward one end. Refusing the ring and clean paths push toward the other. Perceptive NPCs
and void creatures react to this value. The player can see the bar but has no context for what
it means until later.

| Trait | Raised by | Lowered by | Future effect (examples) |
|---|---|---|---|
| **Honesty** | Telling truth to Kardino, returning sword voluntarily, refusing deceptive choices | Lying, keeping stolen property, misleading NPCs | High → NPCs in future zones trust Ares faster; certain quest branches open |
| **Boldness** | Attacking the temple creature first without waiting, rushing into combat, taking risks voluntarily | Cautious/patient combat approach, retreating without trying | High → certain villain dialogue changes; how the antihero mirror reads Ares |
| **Curiosity** | Talking to all villagers voluntarily, exploring off quest path, investigating objects with no prompt, reading signs | Strictly following markers only, skipping optional interactions | NOTE: required quest steps (patient houses, square, etc.) do NOT count — only unguided actions. High → more optional lore scenes, NPCs share extra info unprompted |
| **Empathy** | Letting NPC dialogue play at natural speed without skipping, engaging optional dialogue, making the wish at the temple | Rapidly skipping through dialogue, ignoring NPC attempts to speak | Tracked via dialogue skip rate. High → Lesen's reaction to Ares changes; twins respond differently during recovery |
| **Resilience** | Retrying after dying in the same area, returning to a failed puzzle, persisting through a hard fight | Giving up on an area and coming back much later, avoiding encounters | High → certain late-game NPCs recognize Ares's perseverance; affects antihero's assessment |

**Additional traits under consideration** (flag for discussion when psych profile is being built out):
- *Patience* — does the player wait for openings or rush everything? (Complements Boldness.)
- *Integrity* — does the player fulfill promises and return borrowed items without being reminded?
- *Trust* — does the player engage NPCs with good faith or default to suspicion in dialogue choices?
These draw from the Big Five psychological model (Conscientiousness, Agreeableness) and clinical
behavioral tracking. Worth adding when the affinity system is being implemented.

---

### Psychological Profile — Design Use

The accumulated values compose a silent profile the game uses to shape future experiences.
Not every player will see every scene. Two players with different profiles will have the same
main quest beats but different textures around them.

**Example**: A player with high Void + high Boldness + low Honesty who carries the ring will
have different dialogue with the consuming race in main quest beat 5 than a player with high
Empathy + high Honesty + no ring who helped everyone in Zone 1.

**Implementation note**: Float values (0.0-1.0 per trait), stored in player save. Void is a
separate float with its own bar. Thresholds trigger specific NPC lines, scene variants, optional
content. Never exposed in UI as labels. Design thresholds per-zone as content is built — do not
over-engineer upfront.

---

## 12. Cave — Companion System & What Ares Finds {#cave}

**Design principle**: The companion Ares has in the cave complements the player's playstyle.
A Weaponmaster player has a magical companion available (Felan, when in good condition).
A Spellcaster player has a physical companion (Mike) as their primary support.
Both paths show the player that the same problems can be solved through completely different means.

---

### Dungeon Companion — Mike's Arrival

Mike is ALWAYS present in the dungeon. How they meet depends on whether Ares carries the ring:

| Path | How Mike arrives | When they meet |
|---|---|---|
| No ring (no creature encounter) | Kadmios told Mike; Mike crosses the bridge with Ares after the puzzle | Together from bridge crossing through mine entrance |
| Ring, player wins fight | Kadmios sent Mike on a separate route; Mike arrives at mine entrance | They meet at the mine entrance |
| Ring, player loses fight | Mike arrives mid-fight on the road and helps drive the creature off | Together from fight scene through mine entrance |

---

### Class-Based Companion Dynamics (inside the cave)

Felan's condition and Mike's role inside the cave depend on the player's **class path** (weapon
at cave entry), not the ring:

| Player class | Mike's condition | Felan's condition (safe room) | Primary cave companion |
|---|---|---|---|
| Weaponmaster | Gets injured in the cave (fighting to protect Felan) | Okay — can speak, explains story | Felan (magical support) |
| Spellcaster | Fine — physical support role | Drained — hollow, cannot speak | Mike (physical support) |

**Mike (Kadmios's son)** — physical companion. Fights, lifts, moves obstacles. When they reach
the mine entrance, Mike and Ares discuss the two entrances. The player chooses which one to
enter first. Mike takes the other. They plan to reconnect inside.

**Felan (Twin — BOY)** — found in the SAFE ROOM of the river cave. When in good condition
(Weaponmaster path), he can cast and explains what happened: who the dark figure is, what
happened at the Verdant Temple, what the consuming race team did inside the cave, and where the
disruption well is. When drained (Spellcaster path), he cannot speak and cannot assist magically.

**Vinie (Twin — GIRL)** — found in the Spider Queen's web at the END of the river cave. Alive
but weakened. Ares cuts her free after the Spider Queen retreats. She is in worse condition than
Felan regardless of path.

---

### Cave Entrance — Player Choice

When Mike and Ares arrive at the mine entrance together, the player has full agency. They stand
at the breach in the sealed wall and see the river cave entrance nearby. Mike points out the
second entrance. The player decides which one Ares enters — no UI prompt, no marker. Mike takes
the other opening. They plan to reconnect at the junction inside.

The cave complex is designed so that both wings connect internally and each one's progression
assists the other. A gate on one side opens from the other. The player who explores both
naturally — or backtracks when they hit a blocked path — will make progress.

---

### What Ares Finds

**BOTH twins are found in the cave.** Confirmed design — do not change without asking.

---

## 13. Chapter 3 — Post-Cave Village Sequence {#chapter-3}

Ares wakes in his home. Mark sat beside him through the night. Chapter 3 begins here and
covers the full day of recovery visits — every patient, every reward, and one quiet new thread.

---

### Morning — Peter Knocks

Peter arrives at Ares's door early.

**Ring path**: Peter came directly from Ms. Kathy's funeral. The funeral was this morning —
early, small, quiet. He tells Ares she is gone. Then: *"You should visit her. Go to the
graveyard. Say goodbye if you want to."* He does not explain why she died faster than the
others. He may not fully understand it himself. He continues his rounds.

**No-ring path**: Peter updates Ares — Ms. Kathy is improving. She is weak but stable.
He says she has been asking about Ares and that Ares should visit her when he's ready.
He continues his rounds.

Both paths: Ares eats breakfast. The day is his.

---

### Ring Path — The Graveyard

The graveyard is **south of the village** — a quiet area, separate from the main cluster.
Light on creatures or none at all (TBD). A place people don't have much reason to come to.

Ares visits. A short moment. He does not need to do anything — just be there.

**Secret**: There is a cracked rock formation somewhere in the graveyard area that can be
blasted open. Accessible by both:
- Weapon master with the powder pouch
- Spellcaster who has learned the blast spell
What's behind it: TBD. A small reward for returning and exploring. Not essential content.

**The shadow figure — leaving the graveyard**:
As Ares exits the graveyard south gate, the shadow figure is there. He is in worse shape than
before — visibly. He does not waste time.

He does not say directly that the ring caused Ms. Kathy's death. But he admits it — in the
way someone admits something they knew was coming: *"The weak ones go first. That is the cost
of the method."* He tells Ares this is the only path he has found that can fight the void race
at all. He says Ares needs to prepare — that this is the beginning, not the end, of what that
will require. He says they will meet again when the time is right. But the situation will not be.
Then he is gone. He does not appear again in Zone 1.

---

### No-Ring Path — Ms. Kathy Fetch Quest

Ares visits Ms. Kathy at her home. She is in bed but awake — genuinely glad to see him.
She asks if he could bring her mushrooms from the east river path. The ones she usually
collects herself. She cannot go herself yet.

The player goes to the east river area and collects the mushrooms.

On return: Ms. Kathy receives them. She starts talking — not because she has to, but
because Ares reminds her of something. She says: *"You are as kind as your father."*
Then she tells him. His father left Vinemore years ago — decided to join the **Royal Guard
of Aethion**. She says it with a mix of pride and quiet sadness: a man like that, going to
a place like that. She knew him well. She does not know more than what she saw before he left.
The conversation ends gently. Ares leaves with something new to carry.

---

### Twins' House — Lesen

Lesen meets Ares at the door. She does not have the words at first. She finds them eventually —
something real, not a speech. Both her children are home.

**Spellcaster path**: The twins asked for Ares at the school. Lesen passes this along.
Felan or Vinie — or both — want him to come by when he can.

**Spellcaster school (spellcaster path)**:
The school receives Ares differently now. He is known here. As thanks for what happened in
the cave and what the twins said, the school gives him a **wand** — a reward, not a lesson.
His first non-staff tool for channeling Resonance.

---

### Gragi / Derol's House

Reaction is shaped by the earlier Gragi choice (B-01 in the choice log — whether Gragi let
Ares in or turned him away). If Ares was let in and spoke calmly: warm reception, Derol
thanks him directly. If Ares was turned away: Gragi is embarrassed, not hostile. Derol
handles it and thanks Ares himself.

---

### Miria and Dario

All well. Dario answers the door and lets Ares in without hesitation this time. Miria is
resting but good. Simple warm moment — they know what the cave cost and what it solved.

---

### Leman's House — Last Visit

Ares visits Leman last. Nothing dramatic here. Leman is resting — still weak but past the
worst. **Leman's wife answers the door.** She has been up all night and most of the day
caring for him. When she sees Ares, she goes inside for a moment and returns.
She gives him **rations** — if he has free inventory space. A quiet thank-you, no speech.
She goes back inside.

---

### Weapon Return and Permanent Gifts

After visiting patients, Ares returns any lent weapons (sword or axe).

- **Pontos (sword path)**: Returns the sword. Pontos tells Ares to keep it — permanently.
  Thanks for what he did.
- **Nathan (axe path)**: Same — Nathan tells Ares to keep the hand axe. His to keep now.
- **Staff path (truth told)**: Ares already has the staff with Kardino's blessing. No return needed.
- **Ring path**: Ares already has the ring. The ring is not returnable — the shadow figure is gone.
- **Dagger path**: Nothing to return.

---

### Shield — Now Available

After the cave, Mr. Lulu's shop restocks. The **wooden shield** is available for purchase
using creature parts from the east woods. This is the earliest the shield can be acquired.
Creature part economy is already established — the player knows how to farm.

**Felan** (BOY): Found in the SAFE ROOM of the river cave. His condition depends on player
class — see companion matrix above.

**Vinie** (GIRL): Found in the Spider Queen's lair at the END of the river cave — wrapped in
web, alive but weakened, ready to be eaten. The Spider Queen does not die here. She escapes
through a large hole in the ceiling after taking enough damage. Ares cuts Vinie free after she
flees. Both twins exit the cave with Ares.

**Evidence of the fight**: Throughout the cave — disrupted creatures killed by concentrated
Resonance blasts (the twins' spellwork), scorch and frost marks on walls. The consuming race
team's abandoned camp: foreign tools, markings carved in stone that belong to no culture Ares
knows. One of their dead — not a creature, not from this forest. No context. No explanation.
Ares cannot name what he is seeing.

**The disruption well**: At the water source in the deep mine. The room before the well is
where the fight with the consuming race member takes place. The well cannot be closed — Ares
and the companions leave it open. It will shrink slowly without its maintainer, but not fast
enough to solve Vinemore's water problem on its own. Ares can see the crack. Touch it if he
chooses. He understands nothing about how it was made. But he knows it was made deliberately.

**The global picture**: Delivered by Felan (if coherent, Weaponmaster path) or pieced together
from physical evidence (Spellcaster path — Felan cannot speak). What Ares carries out of the
cave: this targeted Vinemore, it is not the first time a place was targeted, and the situation
is larger than one village.
