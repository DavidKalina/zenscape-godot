# The Washing Rite — "Pilgrims were not asked to jump. They were sent."
Lenses: verb = defend / hold ground; purpose = shrine; mood = playful; decay = drowned; twist = the threat is the only way across. Scale: human. Shape in a layer: a line.

Pitch: You wade ashore into a flooded forecourt and hear the gate at the far head of a long stone channel groan. The shrine across the gulf is a jump and a half too far, and the only thing that reaches it is the flood the rite was built to send: you brace in a pier's lee, let the wave break past, then next time ride it, leap from its back and surf out over the drop.

Top (1 char ~ 4 m; `w` wading water, `=` wave channel, `~` gulf, `C` refuge pier, `o` trap):
```
 ^^^^^^^^                                          ^^^^^
 ^ 1 A  ^   wwwwwwwww  ###########@               ^ 2 ^
 ^   .  ^   wwCwwwCwww  # gate    |=C==C==C=>~~~~~~^ P ^
 ^ ...  ^...wwwwwwwwww  # (plate) |=C==C==C=>~~~~~~^ @ ^
 ^^^.^^^^   w"wwwwwCwww ###########@          ~~~~ ^ # ^
    .       wwwwwwwwwww                       ~~~~ ^^^^^
```
Side (wave runs left to right, then spills over the gulf):
```
 gate  ___                                      shrine terrace
 head |   |_____ channel floor _______           ____P____
 ~~~~~|___|   C     C     C    [wave ->]  ~~~~~|  altar  |
 wading basin   (refuge top above the wave)  void (gulf)
```

Play:
1. Arrive on the south-west rim (`1`), a drowned forecourt: a still basin, wadeable stone floor, a swimmable moat (as in drowned_nave). Floating stones bob; splashing about costs nothing. Playful, low stakes.
2. Wade to the channel's mouth: a long walled aqueduct-style channel, floor dry, with the sluice gate at its far head and rune-cut refuge piers standing in the floor, each tall enough to jump up on (the sluice's `refuge_top`). A frieze at the mouth shows figures running one way.
3. The shrine (`2`) is on its own terrace beyond a gulf wider than a chained long jump. Walk up the channel (the parapet wall-walks are a slower flank), step on the plate near the gate (or wait out the `timer`). The gate rattles, spray bursts, the channel drains: the tell, with the pilot mid-channel and a wave coming.
4. Hold ground: jump onto a pier and stand while the wave passes under. A first cycle spent this way is safe and teaches the timing; the plate re-arms. The wave carries anything not on a pier, so the pier is the ground you hold.
5. Ride: stay in the wave (carried at its pace, your wade only a fraction of it), run with it, and jump near the open end: a jump taken while carried keeps the wave's pace (`rides`), so one arc clears the gulf. Twirl or pocket sail to stretch it; grab the terrace lip if short. A miss drops a layer, a soft fail onto the isle below.
6. The shrine terrace: tomb chest altar, rose gable, the exit rim behind. Coming back, the far end is the `pool` variant of the sluice (a wall and a pool at the end), so the way home can be a swim rather than another flood.

Threat: the Sluice Flush (scripts/traps/trap_sluice.gd; sluice_aqueduct.gd is the in-context template), the rite's own machinery. It is the tool: its carried jump is the only reach to the shrine, the piers are the refuge, and it can also carry loose stones along the channel for fun.

Combos (the wave is a conveyor and a thrower; stun-round1: the sluice washes a grounded stunned body, pushes it in the air, and its spill is a `toss` that keeps the stun):
1. By accident: a Plinth Ram charges you in the forecourt, you are knocked (stunned) into the channel mouth just as the timer fires -> the wave carries the downed body down the channel (washed while grounded) -> the spill tosses you, still stunned, out over the gulf -> poise returns mid-arc (stun works in the air) -> twirl/pocket sail to catch the terrace lip, or you drop a layer. Three different sources (Ram, sluice, your own sail), so no restun gap bites.
2. On purpose, the speed route: plate -> ride the wave with a carried jump (keeps its pace) -> pocket sail across the gulf -> land on the terrace in front of the wind horn on the shrine's back wall (flow charge: updraft up) -> glide off the top to the east rim. The shrine is a launch pad if you carry the wave's speed into it.
3. Enemy chain: the headless body shoves you onto the plate from the forecourt (it homes on a head; it ignores you but shoves anything in its way) -> the wave fires with you in it and takes the body too if it follows (carrying enemies is a to-verify, see asks) -> the body is spilled over the gulf and falls; the pilot who held a pier watches it go.
Ports: catches (west): a body thrown in from the isle before it, a head blast or a cannon shot or a dragon swipe, lands in the forecourt basin or the channel: the basin is shallow, a soft landing that is still in the machine's reach (a swim to the plate). Throws (east): toward the terrace's east rim at the carried jump's reach, 1.5 to 2.5 x the chained long jump, and a sailed pilot a good deal farther; the spill's toss is along the channel axis (east), so the next isle is aimed straight down the line.

Mystery: wave-and-figure friezes show pilgrims swept to the shrine every year, a washing and an arrival: the gulf was cut wide on purpose so nobody came dry. The carved figures are not drowned; they ride, arms spread. By the altar a tomb chest holds the last pilgrim's pair of carved oars.

Kit used (all verified in ruin_kit.gd FAMILIES / ruin_kit_cloister.gd): gothic `pier`, `arch`, `fallen_pier`, `wall`, `floor`, `stairs`, `grand_stair`, `tomb_chest`, `rose_gable`, `buttress`; aqueduct `aqueduct_span`, `aqueduct_end` (the gate head), `aqueduct_stump`, `aqueduct_broken`; ruin_kit_cloister `range_run` (parapet wall-walks), `slab_bridge`, `heap`; foot pieces: floating/bob stones, scripts/footbridge.gd (plank causeway over the moat); water: the shared KitWater pond (drowned_nave, cloister_tarn). Trap: trap_sluice.gd (plate or timer, `refuges`, `rides`, `end`).
Kit asks:
- Check or add: whether the sluice wave carries enemies (the Ram, the headless body) as it carries the pilot; combo 3 assumes it does.
- Rune frieze strips (a wall panel with wave-and-figure relief); gothic `wall` has none.
- A gate head piece with a visible portcullis leaf for the sluice (sluice_aqueduct.gd builds its own greybox).
- An Olmec-style half-sunk head as dressing (no such mesh exists outside the enemy models).

Family knobs: `channel_len` (3 / 4 / 6 pier-lengths); `gulf` (1.5 / 2.0 / 2.5 x the chained long jump, as WorldScale.opening, never under what the wave's carried jump reaches); `trigger` (plate / timer); `flood` (basin depth: wade / wade+swim moat / swim only).

Sockets: rim: the south-west forecourt (facing west, run-up across the wading floor) and the terrace's far rim (facing east, run-up on the terrace). arena: the forecourt (room ~12 m radius), the terrace. cover: under the parapets and channel walls. perch: the terrace beside the altar, the forecourt's ledge.

Generator fit: role hero (the shrine is a landmark with a lock), footprint about 110 x 44 m, height_span ~12 m (the rose gable), a line. Suits a bridging position between two clusters; the generator never turns isles, so the channel axis is fixed east-west and the rims sit on it.

Distinct from: drowned_nave (same drowned gothic, but the nave is a wading causeway you hop; this is a timed machine and a lock-and-key crossing). Not the aqueduct isle's sluice either: the trap there is a hazard on a channel, here it is the route.

## Greybox (Opus pass)
Run: `godot --path . res://studies/greybox/washing_rite.tscn -- --no-title` (`--no-ram`, `--no-body`, `--no-head` leave an enemy out). Code: `studies/greybox/washing_rite.gd`. The whole layout is one `LAYOUT` table for a later KitLand pass: isles with tiers, walls as segments, the channel, horns, enemies with their casts, stations and labels. World frame: the channel runs +x from the gate at x = 0.

First build (round 1, Sonnet): a plate 4.3 m in, a level 7.5 m gulf, enemies loose in the forecourt. Chain 2 worked. Chain 1 was untested (the ram's 9 m shove overshot the plate). Chain 3 could not happen (a 4.4 m body, a 1.5 m channel).

Stations (each brings its own cast):

- 1 start, the forecourt rim (everyone)
- 2 refuge pier 1
- 3 the channel mouth (step in, the gate opens)
- 4 the channel, 12 m down
- 5 the terrace
- 6 chain 1 (the ram, in the lane facing it)
- 7 chain 2 (the speed route)
- 8 chain 3 (the body, in the lane facing it)
- 9 the horn
- 0 the exit rim

All ten stand (checked headless).

What moved, and why:
- **The plate is the channel floor.** The sluice's `trigger` is "timer" with `period` 0.5 s. Half a second of a pilgrim's weight on the channel floor opens the gate, then the 2 s tell, then the wave. A knock only has to end in the channel; there is no 0.7 m plate to hit or overshoot. Walking in does the same, so the speed route is "walk in, wait".
- **The pilgrims' lane** is a dry 6 x 14 m lane on the channel's axis, with wading floor on either side. The ram lives in it and charges along the axis. A funnel of two 2.4 m walls (6 m long, 14 deg) narrows the lane into the gate. The first 8 m of the channel are walled over their parapets (the throat). A shove up to about 30 deg off the axis slides along the funnel into the throat. Without the throat, 2 ram runs in 10 came to rest on a parapet's top, where the timer doesn't count: it reads only the 1.5 m floor.
- **The gate's lintel** is solid, 2.5 to 4.5 m up over the gate. A pilgrim and the ram pass under it. The body's chest ray meets it, so the body stops at the gate. Without the lintel, the body followed into the channel and shoved the pilot again from behind. It shoves from its centre, so those shoves went up to 35 deg sideways. They stacked him onto the throat walls' tops and into the void in 7 runs of 10.
- **The gulf is 9.5 m and the terrace is 1.5 m down.** It was 7.5 m and level. Reaches measured from the channel's end, at the terrace's height:

  | Move | Reach |
  |---|---|
  | Spill, no input | 3.5 m |
  | Plain carried jump | about 7 m |
  | Chained long jump | 9.1 m at best |
  | Carried jump + twirl, takeoff 0 to 3 m before the end | 9.5 to 11 m |
  | Spill + twirl (a late Space still works) | about 9.8 m |
  | Chained long jump + a perfectly placed twirl | about 10.5 m |

  A level terrace could not take ±0.2 s of timing (±1.9 m of takeoff at the wave's 9.6 m/s) and still keep the long jump out. The card's lock ("only the wave reaches") is now mostly true. A long jump plus a perfect twirl is a skilled second way across.
- **The head** sits at the exit rim's far corner. At its old spot it caught gliders. The body's `hear` is raised to 130 head heights (a spawn knob, x1.6), so the body hears the head from the forecourt. At 93 m away it had been out of hearing and wandered west. In the full run from station 1, the body wades in, reaches the gate at about 30 s and paces the lane mouth.
- **Labels:** "JUMP HERE" sits 1.5 m before the end. The lintel, funnel, throat and timer are named.

Chains: checked by `C:/Users/Tenut/AppData/Local/Temp/claude/greybox-checks/washing_rite-opus/chains.gd` (uncommitted). Each run goes through the real motor, the study's tick, the sluice and the enemy AI, with jitter:

- The pilot's start: ±0.5 m along the lane, ±0.3 to 0.4 m across.
- The enemy's spawn: ±0.5 m.
- The rider does nothing until carried, then holds forward. He presses Space at the mark ±0.2 s, and the twirl 0.3 ±0.15 s after it.

- **Chain 1, the ram: 10/10 (20/20).**
  - The ram notices, tells and charges down the lane. Its knock (11.7 m/s, resting 9.1 m on) lands the pilot in the throat, 4.7 to 5.8 m in. The timer fires about 0.5 s after he lands.
  - He is up about 2 s before the wave reaches him, so he is not downed when it takes him.
  - The wave carries him 10/10. The rider's jump and twirl reach the terrace 10/10. With no input, the spill drops him to the layer below 5/5: the card's soft fail.
  - As the wave goes, the ram re-tells and charges after him. It chases the wave's back down the channel and comes to rest about 15 m in. It is never inside the wave, so the stand-in carry never takes it.
- **Chain 2, the speed route: 10/10 (19/20).**
  - The miss: Space 0.15 s early, with a twirl 0.16 s after it.
  - Landings come 0 to 4 m past the lip; 3 in 20 end in a lip catch.
  - Without the twirl the jump lands 0/10. With no input, 0/5.
  - The tail: he lands on the terrace with the Q charge at 0.57 to 0.66, all from the ride. Q with the stick still lifts him 4.5 to 5.2 m. Space opens the sail over the 3.5 m gable. He drops onto the exit rim 10/10. The rider lets go over the rim; holding on, the glide overshoots the rim's 10 m.
- **Chain 3, the body: 10/10 (20/20).**
  - The body walks the lane toward its head and into the pilot. Its shove (5.6 m) lands him in the throat 1.4 to 3.6 m in, and the timer fires.
  - The wave carries him 10/10. The rider then reaches the terrace 10/10, or could hold pier 1 instead.
  - The body stops at the lintel. The card's ending, with the body following and being spilled over the gulf, does not happen: it needs the engine changes below.

Real: the sluice (timer, tell, wave, carry, spill, three refuge piers at 9, 18 and 27 m), the Plinth Ram, the Headless Body, the Inhaler Head (the body's bait), and the pilot's own Q updraft and sail.

STAND-IN:
- The wave carrying enemies (`carry_enemies`, which moves any enemy standing in a wave and tosses it off the end). Nothing reached it in these runs.
- The horn: a wind vent. The real lift is your Q.
- The gable: a 3.5 m wall.
- The altar.
- The layer below: a soft-fail slab.
- The funnel, throat and lintel: plain greybox walls. The turf pass would use the kit's `aqueduct_end` gate head and the gothic `wall`.
- The frieze, floating stones and half-sunk head: labels only.

Engine changes still needed for the card's full chain 3 and chain 1:
- **The sluice carries only the pilot.** `_sweep` and `_fling` in scripts/traps/trap_sluice.gd move `motor` alone. They should also take every grounded enemy standing in a wave: step it to the front, and fling it off an open end, as the stand-in `carry_enemies` does. That is the card's "the body is spilled over the gulf".
- **The body walks through walls narrower than itself and shoves from its centre.** In scripts/enemies/headless_body.gd, `_wall_along` casts only along the body's centre line, so a 4.4 m body walks through a 1.5 m throat's walls. `touch()` shoves along the line from the body's centre to his feet, so a pilot a metre off its line goes 30 to 35 deg sideways. Two changes would let the body follow a pilgrim down the channel and herd him safely: rays across its width, and a shove along its walk for a pilot in front of it. Until then, the lintel holds it at the gate.
- Optional: plates that count any body's weight (the round README's blocker 5) would let the plate come back alongside the timer.
- Not an engine change: the card has the wave carry him while he is still down from the stun. For that, the knock would have to land within about 0.5 s of the wave arriving. With the 2 s tell he is always up first. A shorter `tell_time` would trade away the hold-ground beat, so it is left at 2 s.

Unverified:
- Everything by eye (these were headless checks only).
- Whether the funnel, throat and lintel read as one gate.
- How the ram chasing the wave down the channel looks.
- The body pacing the lane mouth for a long time.
- The round README's Washing Rite row still describes round 1.
