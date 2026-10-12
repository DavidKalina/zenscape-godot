# Enemies and creatures: ideas (brainstorm, 2026-10-12)

> **Status: spitball, not decided.** Read concept.md and aqueduct-map.md first.
> Traps, the dragon and the shop are other docs. Nothing here is built; every
> number is a first guess to tune, using the pilot numbers in aqueduct-map.md
> section 5 (run 4.8 m/s, plain jump 0.8 m, pump 1.5 m, twirl, slide to 20 m/s,
> pocket sail 5.5 m/s).

## Rules every enemy follows

- **Physics, not damage.** Nothing has hit points. Enemies knock (`PilotMotor.knock`),
  seize (`seize`, then the enemy's own `knock` or `toss` lets go) or steal.
  "Dead" for the pilot means off an isle, plane lost, or a run item lost.
- **Dying for an enemy** means off the edge. So every enemy is a **mass, a reach and
  a footing**; a slide transfers speed, a downdraft slam is a ring shove, a
  twirl is the get-out.
- **Readable in 3D.** Each tell is a silhouette change plus a sound, held about
  0.6 to 1.0 s at tier 1, shorter at higher tiers (never under 0.35 s). The
  tell points at the target in world space, so it reads from behind the pilot.
- **Comedy from physics:** enemies fall off, collide with each other, bowl each
  other off edges, and get launched by the same wind the pilot uses.
- **Enemies are props.** Every entry lists what the pilot gets *from* it.
- **Melancholy:** these are the ruin's leftovers (watchers, mechanisms, scavengers),
  not an army. Few speak. Most are doing a job that no longer matters.

## Module model (what the generator spawns)

An enemy is a **module**: `{anchor, footprint, tier range, cost, group, tags}`.
The section generator picks modules that fit a section's anchors and budget.

| Field | Meaning |
|---|---|
| anchor | the surface it needs: `turf`, `deck` (narrow walkway), `water` (channel), `arch` (underside or crown), `stone` (standing stone / sarsen), `air`, `rope`, `edge` (rim of an isle) |
| footprint | clear plane area it needs, so a 2.4 m channel gets only channel-sized modules |
| cost 1-5 | counts against the section's danger budget (concept.md); a tier has a min and max total |
| group | solo / pair / pack (N); pack cost = cost x (1 + 0.5 x (N-1)) |
| tags | `knockable`, `pushes`, `steals`, `grabs`, `flies`, `loud`, `flammable`, `wakes` |
| pairs | modules that raise or lower its cost when placed together (listed per entry) |

Tier bands (a run climbs tiers): **T1** isles 1-2 (learn), **T2** 3-4, **T3** 5-6
(region one end), **T4+** is the next region. Cost 1-2 is a nuisance, 3 forces a
decision, 4-5 is a "do I stop for that?" hazard that can end a run alone.

**Cost modifiers (generator):** over open sky or a 10 m deck: +1. Narrow (<3 m)
footprint with no side room: +1. Pilot carrying the plane's parts or a rune
purse (see Thieves): +0. Clear escape (rope, ledge, glide height): -1.

---

## The creatures

Summary first, detail below.

| # | Name | Anchor | Tier | Cost | Kills you by |
|---|---|---|---|---|---|
| 1 | Cairnling | turf | 1-2 | 1 | shoving you over a rim |
| 2 | Millstone Beetle | deck, turf | 1-3 | 2 | rolling you off a deck |
| 3 | Sluice Eel | water | 1-3 | 2 | flicking you off the channel |
| 4 | Magpie Kite | air | 1-4 | 2 | stealing runes / a plane part |
| 5 | Gong Toad | turf, stone | 1-3 | 1 | (it is a trampoline; the bounce is the danger) |
| 6 | Weeper (sundial statue) | turf, deck | 2-4 | 3 | a shove when you look away |
| 7 | Plinth Ram | turf | 2-4 | 3 | charging you off an edge |
| 8 | Gnaw (rope rats) | rope, deck | 2-4 | 2 | cutting your rope mid-swing |
| 9 | Keystone Gargoyle | arch | 2-5 | 3 | stooping on you mid-jump |
| 10 | Spindle (weaver) | arch, stone | 3-5 | 4 | lassoing you and hauling you in |
| 11 | Draught Maw | air, stone | 3-5 | 3 | eating your updraft, dropping you |
| 12 | Reliquary Hand | turf | 3-5 | 4 | seizing and tossing you off the isle |
| 13 | Cinder Crows | air | 3-5 | 3 | wake of the dragon: flaming dive packs |
| 14 | Hook Skiff raiders | air | 2-5 | 3-5 | boarders: snatch the plane / you |
| 15 | Hush (the bell-eater) | any | 4-5 | 5 | silence and a bell that pulls you; run-ending |

---

### 1. Cairnling

- **Pitch:** a walking pile of the isle's own rubble; the tutorial.
- **Look:** knee-high stack of three stones with two eye-holes; a bobbing walk.
- **Behaviour:** ambles toward you, slow (1.5 m/s). **Tell:** the top stone
  tips and a grinding sound; it lunges 1.5 m. Falls apart into inert rubble
  (and a fallen-lintel step) when knocked off a rim or slammed.
- **Kills you by:** body-shoving you toward a rim while you are lining up a jump.
- **Beat it:** slide into it (a slide at 8 m/s throws it 6 m); or just jump; a
  downdraft slam scatters a whole cluster.
- **Pairs:** the rubble it leaves is a ledge (2 stones high = 1.2 m, a step you
  can build). Gong Toad bounce sends a Cairnling flying.
- **Spawn:** turf near rims; group of 1-4. Tier 1-2, cost 1 (pack of 3 = 2).
- **Aqueduct example:** 2-3 of them on the **Near meadow** between the spawn and
  the **Grand stair**; one stands on the stair's balustrade and slides
  down itself, scattering the others.

### 2. Millstone Beetle

- **Pitch:** a beetle pushing a stone wheel along the deck, the way it always
  did, because it has no other job.
- **Look:** a low shell, a wheel taller than the pilot (1.4 m), legs like oars.
- **Behaviour:** patrols a deck back and forth at 3 m/s, never turns early.
  **Tell:** it plants its legs and the wheel *clicks*, then it sprints (7 m/s)
  for 8 m when you are within 10 m on its line. Knock it off the end (it
  falls with the wheel, which becomes a rolling hazard below).
- **Kills you by:** the wheel clears a 2.4 m channel wall to wall; you cannot
  step past.
- **Beat it:** wall-run the **blind wall's** face over it; twirl the wheel; or a
  slide *under* its raised wheel on a slope; at a gap it is a **bridge**: lure
  it so the wheel jams in the 3 m fallen-span gap (it plugs the gap; walk over
  the wheel).
- **Pairs:** two beetles on one deck facing each other bowl each other off (cost
  of a pair is 2, not 4, because they hurt each other). Sluice Eel flicks it.
- **Spawn:** `deck` or `turf` strip >= 8 m. Tier 1-3, cost 2 (+1 on a 10 m deck).
- **Aqueduct example:** the **channel**, z -2 to -22 (the blind wall): the
  beetle patrols the 20 m run so you must use the **kick slot** or the
  **buttress** route instead of the straight walk; the wheel jams in **the
  gap** for a loyal "I made a bridge" moment.

### 3. Sluice Eel

- **Pitch:** the water in the channel is not empty.
- **Look:** a pale, long eel with a lamp-like tail; only the ripple and the
  lamp show until it jumps.
- **Behaviour:** moves under the surface following you (your wade speed is 0.67),
  **tell:** a V-wake that speeds up and the lamp winking toward you; then a
  leap, 1.5 m up, arcing over you and shoving sideways as it lands. 3 s
  cooldown. It only lives where there is water (the **channel**, cisterns,
  tarns).
- **Kills you by:** flicks you off the parapet or into the sky; slows you in the
  water first.
- **Beat it:** leave the water (hop onto the parapet, 0.42 m high); bait the
  leap so it lands out of water and flaps helplessly (a free **platform** for 4
  s: stand on it and it carries you a short way down the channel); a
  downdraft slam stuns it.
- **Pairs:** water + Beetle: the eel flicks the beetle's wheel. Fire (dragon)
  boils the channel: eels flee, 20 s safe. A cracked slab dams the channel
  and strands them.
- **Spawn:** anchor `water`. Tier 1-3, cost 2.
- **Aqueduct example:** **channel**, z -2.6 to -54.4 (the wading section); an
  eel haunts the long stretch before **the gap**, so you hurry to the
  dry fallen-span edge.

### 4. Magpie Kite

- **Pitch:** a thief bird that wants your shiny things, and your plane's.
- **Look:** a long-tailed sky bird, a little larger than a goose, carrying
  tin trinkets that jingle (the tell is the jingle).
- **Behaviour:** circles at 12 m; **tell:** it tilts and the jingling stops;
  then it stoops, snatches a *rune purse* (or one of the plane's loose parts if
  parked) and flees at 9 m/s toward a nest on a higher isle. Knock it
  (twirl into it, a sail bump) and it drops the item.
- **Kills you by:** does not push; it steals. You lose runes or a part and
  must chase it across an isle (a mini-quest: nest = ledger slot).
- **Beat it:** bait with a decoy rune (leave 1 rune on a ledge, it stoops,
  you pocket-sail into it); catch with a downdraft; the nest holds all it ever stole,
  with other runs' leftovers. Nest is a rewarding side route.
- **Pairs / grudge:** a **thief grudge** persists in the run: a Kite you wronged
  (knocked off an edge, nest raided) returns with friends and goes straight
  for the plane. The shop's grudge: the trader hates Kite-stolen goods.
- **Spawn:** `air` over open isles. Tier 1-4, cost 2 (steals, doesn't kill).
- **Aqueduct example:** circling the **Henge terrace**; its nest sits on the
  **Heel stone** top (grab, 2.3 m), a 1-rune reward that pays to look.

### 5. Gong Toad

- **Pitch:** a bell-throated toad that makes a trampoline of itself. An
  enemy that is a traversal prop.
- **Look:** a squat bronze-green toad with a bell for a belly; sits on a
  stone; it rings when disturbed.
- **Behaviour:** inflates when the pilot is near ( **tell:** the belly swells
  and hums, 0.8 s ) then releases: a shockwave **bounces** you 4 m up (and
  away). Harmless on its own, but the bounce is tuned to throw you off a rim.
- **Beat it:** land on it from above on purpose for a free 4 m; use a
  chain of them as a staircase; at a gap it launches you across (long
  jump). Slide into one and it ricochets.
- **Pairs:** a Cairnling pack near a toad launches itself; a toad next to a
  Millstone Beetle sends the wheel flying. Hearing it ring wakes sleepers
  (`wakes`).
- **Spawn:** `turf` or `stone` top. Tier 1-3, cost 1; the bounce angle
  (generator) decides whether it is a gift or a trap: toward the rim -> 2.
- **Aqueduct example:** on the **Kick slot** block: the toad is a free way
  up to the channel *or* a shove into the **Forecourt** gap depending on
  your approach angle.

### 6. Weeper (sundial statue)

- **Pitch:** a statue that only moves when you are not looking at it (the camera
  or a flick of the sun's shadow).
- **Look:** a robed stone figure with a sundial for a face; stands still in
  a doorway or on a deck; its shadow points where it is going.
- **Behaviour:** when it is **on screen** it freezes, with a held creak;
  when off-screen it glides 5 m/s toward you. **Tell:** each time it moves
  it leaves a scrape and a chime; its sundial face sweeps. In the plane's
  view it is slow.
- **Kills you by:** shoves you from behind (a long push, 6 m) - a rim death
  for a nervous player.
- **Beat it:** keep it on camera and back away (the camera is the weapon);
  slide into it while it is frozen (it is heavy, 2x a Cairnling; it topples
  *back*, and on a deck it **falls and becomes a bridge piece** (lying
  lintel)); use the binoculars to freeze one from afar.
- **Pairs:** two Weepers in one room: you cannot watch both: cost 5; one Weeper
  plus a Gargoyle: look up or look back.
- **Spawn:** `turf` or `deck` near doorways. Tier 2-4, cost 3 (pair 5).
- **Aqueduct example:** **Arcade (under the arches)**, z -22 to -40: a Weeper
  at each arch; you walk the 18 m arcade, glancing back at each.

### 7. Plinth Ram

- **Pitch:** a ram carved on a plinth that charges the pilot, and is
  proud.
- **Look:** a stone ram with a block of pedestal dragging behind it; horns
  shaped as lintel corners.
- **Behaviour:** paws the ground ( **tell:** three scrapes and a dust puff,
  1.0 s ), then charges in a straight line at 10 m/s for up to 15 m, cannot
  turn. Smashes through Cairnlings.
- **Kills you by:** hits for a 9 m knock along its charge.
- **Beat it:** sidestep so it overshoots the rim (it falls; the plinth
  stays a stone you can use); stand *on* a stone it cannot reach and let it
  hit the wall (stuns it 3 s: ride it, it is a moving platform); wall-kick
  off its charge.
- **Pairs:** Weeper (the ram fears none); Gong Toad launches a ram, glorious;
  a ram charging at the pilot standing next to a Beetle bowls the beetle.
- **Spawn:** open `turf` >= 20 m long, near a rim. Tier 2-4, cost 3.
- **Aqueduct example:** **Near meadow** east of the spawn; you are lured to
  stand on the **Heel stone** (118, 0) while it hits the rise.

### 8. Gnaw (rope rats)

- **Pitch:** the rats that chew the ruin's ropes; systemic with every rope.
- **Look:** blind grey rats the size of a cat, too many teeth, clustered at
  rope anchors with a clicking.
- **Behaviour:** climb to rope anchors / rope bridges and **chew**. **Tell:**
  a thread falls off and the rope jiggles; it parts in 4 s once they start.
- **Kills you by:** the rope snaps mid-swing, dropping you where you stood.
- **Beat it:** shake them off (a downdraft slam clears all rats on a beam);
  swing with speed (a snapped rope still carries you the same arc if released
  *before* the snap); eat bait; slide along the beam into them.
- **Pairs:** cuts every rope-using module (bridges, ferries, swing sets); fire
  ends them; Magpie Kites steal their cheese for a trade.
- **Spawn:** `rope` or `beam`. Tier 2-4, cost 2 (+2 if it is the only crossing).
- **Aqueduct example:** the **Rope line** (x 106.3): rats on rope 2's
  beam (z -47); you must swing early, or take the **ferry** or the **stumps**.

### 9. Keystone Gargoyle

- **Pitch:** a grey gargoyle on an arch's keystone; the arch watches you.
- **Look:** a crouched winged shape that looks like part of the arch,
  until its eyes light.
- **Behaviour:** waits until you stand in its cone (about 8 m), **tell:** eyes
  glow, wings spread, a grinding of stone ( 0.7 s ), then dives to hit you
  mid-jump (it prefers airborne targets). One dive then it returns to its
  perch (4 s).
- **Kills you by:** a mid-air hit with a 7 m knock; over a gap, fatal.
- **Beat it:** stay on the ground under its cone (it will not dive at a
  grounded pilot); bait the dive then twirl over it; a downdraft hits it
  and it crashes into the deck (a lump you can stand on).
- **Pairs:** arches over **sky** (cost +1) vs arches over turf; fire wakes
  them all; Weeper nearby doubles the dread.
- **Spawn:** `arch`. Tier 2-5, cost 3.
- **Aqueduct example:** arches 4 and 6 (z -46, -66) over the sky; the rope
  swing from rope 3 passes right under the keystone.

### 10. Spindle (the weaver)

- **Pitch:** a stone spider that spins a thread to *lasso* you, an actual
  `seize`.
- **Look:** a thin-legged arch-spider with a bobbin in its belly, silver thread
  catching the light (glints are the tell).
- **Behaviour:** hangs under an arch or stone; **tell:** a glint line draws
  toward you over 1.0 s, thick as a rope (readable from far; the line is
  *visible* before it fires). On hit, it reels you in 5 m/s, holds you, and
  `toss`es you away when it's done or knocked.
- **Kills you by:** reels you to its web (hold), then `toss`es you off the
  isle; or suspends you while Gargoyles dive.
- **Beat it:** cut the line with a slide or the pilot's body turn (a wall
  run across the line snaps it); the thread is a **slackline**: after
  cutting, a used thread is a rail you can slide on. Kill it by luring its
  thread across a rim.
- **Pairs:** with Gargoyle: held, then hit (cost 5, avoid); with water it rusts.
- **Spawn:** `arch`, `stone`. Tier 3-5, cost 4.
- **Aqueduct example:** **Henge terrace**: a Spindle on the **great trilithon**
  top covers the lintel run; its thread is a rail to the **ring sarsen**.

### 11. Draught Maw

- **Pitch:** a floating mouth that eats wind.
- **Look:** a ragged sheet-like kite fish with a round mouth, pulsing as it
  swallows; wind streaks visibly spiral into it.
- **Behaviour:** drifts near updrafts and thermals; **tell:** nearby grass
  and flags lean toward it, a rushing inhale. Cancels updrafts and
  **pulls the pilot** gently (sail glide goes off course). Exhales after
  15 s in a blast that knocks everything outward.
- **Kills you by:** drains the thermal you needed; the exhale throws you.
- **Beat it:** fly *into* the exhale for a launch (a free 12 m height);
  knock it into an edge and its updraft returns; downdraft slam pops it.
- **Pairs:** the dragon's wake: it eats the draught and the dragon's slipstream
  with it. Cinder Crows ride its exhale.
- **Spawn:** `air` at a thermal. Tier 3-5, cost 3.
- **Aqueduct example:** the **Sky gap** (25.6-30.2 m): it drifts over the
  gap, eating the thermal you hoped to glide with.

### 12. Reliquary Hand

- **Pitch:** a stone hand that rises out of a tomb floor to take the pilot.
- **Look:** an enormous 3 m carved hand, fingers like columns, half-buried
  in a tiled floor; offerings in the palm (bait: a rune pile).
- **Behaviour:** dormant until you pick up the offering; **tell:** the floor
  trembles and cracks in a hand shape (1.2 s). Grabs (`seize`), lifts, and
  `toss`es off the isle.
- **Kills you by:** the toss: 14 m, usually off the rim.
- **Beat it:** grab the offering and dive off before it closes (twirl); lure
  it to fist on a Cairnling pack; its **fingers are a staircase** when it
  holds still; a slam on the palm stuns it.
- **Pairs:** wakes (`wakes`) with every rune stolen from the isle: the
  grudge. Shopkeeper-style: the more you take, the more hands.
- **Spawn:** `turf` in a tomb or crypt module. Tier 3-5, cost 4.
- **Aqueduct example:** a tomb under the **Castellum** crown: runes in the
  palm.

### 13. Cinder Crows

- **Pitch:** the dragon's scavengers; they follow its wake and light up.
- **Look:** thin black crows with an ember in the chest, trailing sparks.
- **Behaviour:** appear after the dragon passes; fly in a pack of 3-6, **tell:**
  ember glow brightening, the pack tightens, then they dive in a line.
- **Kills you by:** the hit is a knock (4 m each) and **sets grass on fire**
  (a hazard); a pack chain-knocks you.
- **Beat it:** run on wet ground (the channel); knock one into the others;
  their embers light **braziers** for the other puzzles.
- **Pairs:** needs the dragon (dragon doc); with Draught Maw they ride thermals.
- **Spawn:** `air`, after a dragon pass. Tier 3-5, cost 3.
- **Aqueduct example:** **Near meadow** after a dragon pass: the fire
  spreads along the turf.

### 14. Hook Skiff raiders (sky folk, bad ones)

- **Pitch:** an existing airship with sky folk, but some are raiders now.
- **Look:** a patched airship with a crane arm and a hook.
- **Behaviour:** lowers on a rope near a parked plane or a lone pilot,
  **tell:** a flare and a bell; then boards.
- **Kills you by:** hooks the plane and hauls it off; or a boarder
  knocks you from the deck.
- **Beat it:** cut the line; ride the line up as a rail; knock the boarder
  into the sky and **keep the crate**.
- **Pairs:** with a trader's grudge: friendly skiffs are peaceful.
- **Spawn:** `air`. Tier 2-5, cost 3-5.

### 15. Hush (the bell-eater)

- **Pitch:** the late-run enemy that a region of weird comic stuff makes
  you fear: silence made solid.
- **Look:** a tall dark shape with no face; sound dies near it.
- **Behaviour:** audio mutes around it (the player's own sound cue is lost),
  **tell:** all the ruin's sounds drain to nothing, the sky dims; it
  pulls the pilot toward a bell that tolls when it arrives.
- **Kills you by:** drags you to its bell (seize) and tosses you.
- **Beat it:** ring a bell (a Gong Toad, a hanging bell) to push it back;
  stay moving.
- **Spawn:** any, tier 4-5, cost 5; at most one per isle.

---

## Interactions grid (the systemic web)

| | wind / downdraft | fire | water | rope | dragon | trader |
|---|---|---|---|---|---|---|
| Cairnling | scatters | none | none | none | flees | none |
| Beetle | none | none | wheel floats | none | none | none |
| Eel | stuns | boils away | home | none | flees | none |
| Kite | carried | burns | none | steals rope? | prey | grudge |
| Toad | none | none | none | none | none | buys |
| Weeper | none | none | none | none | none | none |
| Ram | none | none | none | none | none | none |
| Gnaw | clears | burns | none | cuts | none | none |
| Gargoyle | crashes | wakes | none | none | none | none |
| Spindle | cuts thread | burns thread | rusts | thread = rope | none | none |
| Maw | eats it | blown | none | none | follows | none |
| Hand | none | none | none | none | none | grudge |
| Crows | none | start fire | stops | none | follow | none |

Combos that make the comedy: Ram + Toad (launched ram), Beetle + Beetle
(bowling), Cairnling pack + Maw exhale (a snowstorm of stones), Eel +
Beetle wheel, Kite + Gnaw (cheese).

---

## Bosses (region one, ruins)

One boss per region, guarding the way to the next region (concept.md). Fixed
arenas, **composed from authored pieces with the isle's tier layout**, so a
run's boss differs only by arena dressing and which minions spawn (the
generator rolls a *tier of minions* from this doc).

### Boss A: The Henge Guardian (on the summit)

- **Arena:** fixed, the **Henge terrace** (summit crag r ~11-14 m, ring of
  7 sarsens, gap to the missing 8th). A generated layer: the sarsens'
  count and the fallen trilithon vary.
- **Look:** a stone colossus built of sarsens, lintels for shoulders; moves in
  slow, huge steps; ground shakes.
- **Phases:**
  1. **Stride:** it walks the ring and *sweeps* an arm (tell: it raises a
     lintel for 1.2 s). Dodge by jumping the arm (low), sliding under.
     You knock it by sliding it into a sarsen (the sarsens crack).
  2. **Slam:** it slams the floor in a ring; the pilot twirls over it, or the
     **downdraft slam** counters. Floor tiles fall away: the arena shrinks
     toward the **bite**.
  3. **Hurl:** it picks up a sarsen and throws it (1.5 s tell); the sarsen
     becomes a floating platform; use it to reach its **crown**.
- **Physics:** the guardian is a mass. Beaten when its crown stone is
  knocked off by a downdraft slam at its head: it falls through the bite.
- **Opens:** the henge's 8th stone: the gap becomes a **gate**; the way up
  through the cloud deck, plus the region branch.
- **Reward:** the lodestone chain; a pocket-sail upgrade (tool).

### Boss B: The Sluice Warden (aqueduct channel)

- **Arena:** a **channel-run** of generated deck: 3-5 spans (each 18-22 m)
  with 3 m gaps, a wide *cistern* at the end. Generated: span count and
  where the gaps fall.
- **Look:** a giant eel-and-heron: a long neck rising from the water, a
  lamp in the beak.
- **Phases:**
  1. **Flood:** water rises along the channel: you run ahead, the Warden
     surfaces behind you (a chase, 3 m gaps = twirls).
  2. **Strike:** the neck lunges (tell: the lamp points down for 1 s). Dodge so
     it hits a pier and the pier cracks; the stone pier becomes a bridge.
  3. **Drain:** break the sluice (a cracked slab) so the water drops and it
     lies helpless; slide into its head.
- **Physics:** water level is the lever; the Warden is slowed on dry.
- **Opens:** the aqueduct's far gate; every channel in the world runs with
  clean water (eels fewer); a tender mercy.

### Boss C: The Great Toll (belfry crown)

- **Arena:** a **vertical** belfry (crown of the isle), generated as a stack
  of 3 floors with bell-ropes and hanging bells.
- **Look:** an enormous bell with arms, ringing as it steps.
- **Phases:**
  1. **Toll:** each ring sends a shockwave outward (jump at the right beat).
  2. **Fall:** it hits a floor and the floor collapses; you drop into the next
     floor, the bell gets angrier.
  3. **Silence:** it goes quiet; the Hush approaches (tie to enemy 15).
- **Physics:** shockwaves launch the pilot, ropes swing you into the bell
  mouth to silence it.
- **Opens:** the cloud deck gap: the climb to the next region.

---

## Top-5 shortlist

1. **Millstone Beetle:** the aqueduct's signature; teaches the deck, the
   gap and the bowling comedy in one module. Cheap, readable, systemic.
2. **Weeper:** a camera-based tell is purely a 3D idea, and that is the
   dread; cost 3 for almost no code (a visibility check).
3. **Plinth Ram:** the cleanest "physics, not damage" duel; bait it off the
   edge, ride it when it is stunned.
4. **Magpie Kite:** a thief with a persistent grudge hits the run's
   emotional core (runes, the plane), and the nest is a free side quest.
5. **Spindle:** the first real `seize`; its thread is a slackline you can
   slide on after cutting: enemy as prop.

Honourable: Gong Toad (cheap, funny, a prop), Sluice Eel (tied to the aqueduct).

## Wildcards

- **Mimic Lintel:** a fallen lintel that is a creature; it lets you walk
  onto it as a platform, then stands up. Pure comedy, and a gap-bridge that
  lies: cost 3, tier 3+.
- **The Last Sky Folk:** a single sad sky-folk figure who follows you holding
  a lantern and never attacks; every enemy attacks it; protect it for the
  run (an escort that is also a shield, a tender mercy that costs you).

## Open questions

- Is the camera-freeze Weeper fair when the plane's camera is wide? Needs a
  test.
- How many modules per section? Start at one (T1), two (T2), up to three (T3).
- Do enemies respawn on a return to an isle? Spelunky says no; the dragon
  covers the need to hurry.
