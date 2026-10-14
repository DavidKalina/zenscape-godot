# The Tithe Wheel — "Twelve months, and the thirteenth is the one that collects."
Lenses: verb = time a crossing; purpose = calendar (a henge that is a mechanism); mood = wrong; twist = the ruin still doing its old job. Scale: human, with a colossal hub. Decay: intact and still working. Shape: a ring, spoked.

Pitch: A round island ringed by twelve month-posts with a standing circle of stone at the hub, and the floor between rim and hub is counting. You arrive on the rim and the slabs between you and the centre are already turning over, one after another, on a beat that is almost, but not quite, regular.

Top (1 char ~ 4 m; N up)
```
                 rim N
          o  o   ^   o  o          o = month-post (aqueduct_stump)
        o    ##  :  ##    o        ## = flip slab, ':' = spoke row
      o      ##  :  ##      o      @ = hub, stone_circle
     o  ## ##   (@@@)   ## ##  o   A = arena (hub floor)
 rim W<.. ## ## (@ A @) ## ## ..>rim E   C = cover behind hall_column pair
     o  ## ##   (@@@)   ## ##  o   P = perch (S rim, hub chest)
      o      ##  :  ##      o      ~ = gulf ring between rim and hub
        o    ##  :  ##    o
          o  o   :   o  o
                 :
                rim S (entry)  ~ ~ ~ gulf
```
Side
```
              hub circle  .-@-.   (hub top)
  rim turf ====.          |   |          .==== rim turf
  month-posts  |   ## ## ##|   |## ## ##   |   (slab rows span the gulf)
  ~~~~~~~~~~~~~~ void under the slab rows ~~~~~~~~~~~~~~
```
A ring road of rim turf with the twelve posts on it, a gulf ring inside it, and the hub an island inside that. Up to four spokes (rows of flip slabs) are the only way to the hub.

Play:
1. Land on the S rim (entry). The posts read as a clock face and the spokes as four ways in, each a row of flat slabs.
2. Watch one spoke: a slab shudders and warms orange (the tell), turns over, then the next, a wave down the row. Each spoke keeps its own beat: South quick, East slow, West quick on a long stagger, North with a hole under it.
3. Cross: hop onto a slab the moment it has turned flat, run-hop to the next that has just turned. A twirl or pump-jump bridges a missed beat; a slab caught turning carries you round and throws you back along the row or off it. The fall is the gulf, then the layer below.
4. The wrong part: the spokes disagree. Their beats are out of step, and on one the wave runs toward you, so the flat slab is the one behind, not the one ahead. The calendar counts a year that does not have these months. Walking the ring road between the posts is safe but long (each post is an aqueduct_stump, a short hop apart) and loses the beat.
5. The hub: a flat floor inside the stone_circle with the prize (tomb_chest). Every few cycles (the tithe) the spokes flip together, throwing anyone on them. From the hub you can choose that toss as a launch out across the gulf to the rim you want.

Threat: the flip slabs (scripts/traps/trap_flip.gd; knobs count, period, tell, flip, stagger, underside, speedup) are the whole wheel. Also a tool: a slab's toss is a launch (knock, knock_angle), a "slick" underside is a conveyor toward hub or rim, and "gone" is a hole you read before you step. Optional second layer: a wind_horn (ruin_kit_horn.gd, rig in scripts/wind_horn.gd: aim_at, tell, fired, disabled) on a pedestal at the hub blows "noon" at whoever is on a spoke; knocking it out (the existing disabled path) buys a quiet cycle.

Combos (every hand-off is between different sources, so restun_gap does not bite; each spoke is its own trap instance and names itself as source; stun-round1.md says flip tosses and carries a downed body):
1. By accident, "the wheel plays you": a late hop on the East spoke, the slab turns under you and its knock throws you back along the row, stunned (flip) -> you drop tumbling onto the neighbouring South spoke's slab just as it has turned flat (grounded check: it carries a downed body) -> that slab's flip tosses you, still stunned, inward -> you land sprawled on the hub floor by the chest. The wheel has delivered you, wrongly timed, to the middle; the cost is time and the beat.
2. On purpose, "ride the tithe": stand on the outermost slab of the spoke that faces the exit rim; on the tithe beat every spoke flips and the toss (knock, knock_angle, the slab's own pace) throws you outward and a little up -> pocket sail across the gulf (twirl out of the stun at once if free) -> land on that rim, run-up already pointed at the exit. A skilled player times the hub-side slab to get a longer toss.
3. With the horn (knob): at the hub you stand in the noon horn's blast, which knocks like the wind blaster (names itself) -> thrown across a spoke, tumbling -> the flat slab under you carries you to the spoke's end -> the rim.
Ports:
- Catches from outside: a body thrown in from a neighbouring isle (an Olmec head's blast from a nearby isle, a cannon shot, the dragon's swipe) lands in the gulf ring's wide target, falls onto a slab (a grounded slab carries a stunned body) or the rim turf, so anything flung at the wheel is sorted by its beat. Wind or an updraft that lifts a body over the posts lands it on the hub.
- Throws out: each spoke's outer end throws, on the tithe or a late hop, along the spoke out toward its rim socket (up a little, 5-8 m, still stunned if it came stunned); the hub toss picks a spoke by where you stand. An arena on a rim with an inhaler head aimed across the gulf spits you at the hub: head -> hub -> tithe -> next rim.

Mystery: A henge of the ruin-builders. Each of the twelve posts carries a rune on its hubward face, and each slab's underside carries the same rune, so a month's rune shows only while its slab is upside down. You learn the order of the runes by crossing, and with it what the wheel counts toward. The thirteenth beat is on no post. Something is owed (the tithe), and the dragon's roost, a stone-circle ward seen from afar, is the same kind of stone. Ties into ideas-runes-ledger.md rune sets.

Kit used (all verified in scripts/ruin_kit.gd FAMILIES or the sibling files): stone_circle (hub), aqueduct_stump (twelve posts), tomb_chest (prize), floor (ring road), wall (parapet, cover), buttress (cover), hall_column (two colossal posts as landmark and cover), wind_horn (optional noon horn). Trap: trap_flip. Foot pieces: floating stones for one off-spoke link, optional.

Kit asks:
- A flip row laid on a curve or an annular sector (trap_flip lays a straight row; four spokes work, a curved row would read as a true wheel).
- A shared clock for traps within one motif (one phase source, plus an all-at-once tithe beat); today each trap keeps its own clock and offsets are by start phase.
- A calendar post: a short column with a rune band readable from one side only (aqueduct_stump plus carving stands in).

Family knobs:
- spokes: 3 / 4 / 5.
- beat: ratio of the spokes' periods, 1:1:1:1 (tier 1), 1:2:3:2, or all different (tier 3).
- underside: safe / slick / gone, per spoke (a hole on one at tier 3).
- tithe: none / every 4th cycle (all flip) / with the horn.

Sockets:
- rim: up to 4, one at each spoke's outer end, facing out over the drop, run-up the ring road behind; entry faces the layer's lowest isle.
- arena: the hub floor (room = the circle's inner radius); a rim stretch between two posts.
- cover: behind the hall_column pair and the buttresses; the hub circle is open to the sky.
- perch: the rim opposite entry; the hub chest.

Generator fit: role hero (a landmark); footprint about 40 x 40 m, height_span about 10 m; suits a ring or a spread-wide layer, a puzzle isle between two bridge hops.

Distinct from: broken_ring (a stone circle round a broken turret, a spiral of 8 islets climbing 21 m: hop and climb). This is flat, the circle is the mechanism, and the verb is waiting for a beat. Colonnade_spine is a ridge to walk; nothing in the pool is a flat timed crossing.

## Greybox (Opus pass)
First build (round 1, Sonnet): four straight spokes of 6 slabs at the pilot's gaps, West built hub-out; chain 1 delivered only from West's two hub-side slabs, ride-the-tithe needed `knock` 12, the head reached the hub only at `blast_out` 20 or 23-25.

Run: `godot --path . res://studies/greybox/tithe_wheel.tscn -- --no-title [--knob=k=v] [--no-horn] [--no-head] [--no-tithe] [--tithe=<s>]` (`--knob=` sets a flip knob on every spoke, including the carrier rows' gap). Files: `studies/greybox/tithe_wheel.gd` / `.tscn`; the whole layout is the tables at the top of the script (ISLES, SPOKES, POSTS, STONES, WALLS, COLUMNS, CHEST, HORN, HEAD, TITHE, STOPS). New isle kind "spit" (a tongue of turf on a bearing) and WALLS (arcs) for the turf pass.

**What the physics is.** A flip's toss is a lever, not a fixed 1.4 m. The slab turns about its middle, so where you stand sets the throw: on the half that rises (the end the row walks toward) you are flung back along the row, about 1 m from the middle and 7-9 m from the lip; on the half that drops, the slab turns out from under you and you fall. The toss is always along the row's own line, never sideways. So two radial spokes can never hand a body to each other; a hand-off between spokes has to be a row laid on another row's line. That is what this pass builds.

Stations: 1 start (S rim) - 2 South (the thrower) - 3 East (slow) - 4 West (the carrier) - 5 North (holes) - 6 hub and chest - 7 chain 1 - 8 chain 2 - 9 chain 3 - 0 chain 4 - minus the layer below (12 m down). F1 shows each row's slabs and the tithe count.

What I rearranged and why:
- **Hub r 5** (was 4), rim r 17.2-22.2, gulf still 12.2.
- **West is the carrier: two rows on one line**, W in (4 slabs, period 1.7) and W out (5 slabs, period 2.4), both built hub-out, so each throws you hubward: W out's toss lands on W in, W in's on the hub. Different beats, different trap instances, so they are different sources. Slabs 1.3 m with 0.05 m gaps (9 fill the gulf) so a throw along the line lands on stone, not in a gap; stagger 0.15 so the slabs ahead have just turned and are flat when you come down. It is a one-way spoke in: going out, it throws you back to the hub.
- **South is the thrower**: walks in from the rim, same tight 9-slab row, so every toss throws you out. Crossable inward by walking just behind its wave (5/5 at 0.6-0.7 stick, 0/5 slower). A **S avenue** (6 x 10 m pad past the rim, the entry socket) catches its 7-9 m lip throws.
- **East (slow) carries the tithe ride**: its origin sits 0.66 m into the rim so the first slab is flush with the rim (no gap to fall into), and the row sits 0.35 m proud of the rim so a low throw off the rim end clears the edge. The hub end is now a 1.4 m hop down. An **E apron** (8 x 6 m) catches the long throws. North is unchanged (pilot gaps, holes).
- **The head sits on a dais**, a 7 m-wide spit of rim turf on the NE bearing reaching in to r 11, facing the hub (head at r 15, its ring 1 m). Its default blast (15) carries you about 8.9 m in the air and 6 m in a tumbling skid: launched from r ~12.5, you land on the hub at r ~2.6 and skid across it. The **backstop** (a lintel wall on the circle's far side, bearings 195-255, 1.6 m tall, between the S and W mouths) stops the skid. The two stones on the head's bearing are gone: the circle's gate faces the dais. Columns moved off that line (SE and NW).
- **Tithe knock 4** (was 12: with the lever, 12 threw you past the rim), and it leaves the carrier rows' toss alone (`tithe_throw` false).
- **Horn** (stand-in) plate moved onto the S axis, `blast_out` 19 (its own 14.4 dropped you mid-spoke, where a body that got up was flipped off the row's side).

Chains, headless, each through the real play loop (scripted stick input into `tick`), jittered start ±0.5 m and timing ±0.2 s (chain 1 also tried at any point in the beat):
- **Chain 1, the wheel plays you** (step onto W out and stand): **35/40**, hub. W out hands you to W in in most runs, or its lip throw reaches the hub directly. Misses: 2 fell when they landed as a slab began to turn, 3 caught a slab's lip mid-row (a player would climb on).
- **Chain 2, ride the tithe** (step onto E's first slab a second before the tithe and wait): **23/24**, onto the E rim or apron, every one thrown by the tithe. The miss was the bot stopping short of the slab.
- **Chain 3, the noon horn** (stand-in; step on the plate): **35/36** onto the S rim or avenue, the body landing on the S row and being skidded or thrown off its end. The miss fell between rows as a slab turned.
- **Chain 4, head to hub, default blast**: **19/20** on the hub, stopped at the backstop (r 3.7-4.0). The miss was the head's aim 10 degrees off (its lock angle) plus an off-axis start: the skid ran past the backstop's end onto the S row (which then throws you out to the rim).
- Smoke: the scene loaded headless for 400 frames, no script or parse errors. Every station stands grounded.

STAND-INs: the noon horn is a wind blaster on the hub (blast_out 19); the tithe is a script timer (every 9.6 s every flat slab goes to its tell together, knock 4 for 1.6 s); straight rows stand in for curved ones; posts are plain stumps.

Still needs an engine change:
- **A sideways hand-off between radial spokes** (the card's East -> South): trap_flip throws only along its row (`_ride`: `out = basis*(0, up, k) + tangent`, all in the row's local y z). Needs a knob such as `throw_yaw` (turn the throw about up by that angle) or slabs that turn about a skewed axis. Until then, spoke-to-spoke is row-to-row on one line.
- **The flip doesn't stun**: `_ride` calls `motor.toss(out)`. For the card's "thrown, stunned, sprawled by the chest" it needs `motor.knock(out, self)` (or a `stuns` knob). Only the horn and the head stun here.
- **The lever is a cliff, not a slope**: standing on the dropping half drops you (no toss). A knob for a minimum toss, or tossing whoever is on the slab at the tell's end, would make the rear half throw too.
- A shared clock for the tithe (kit ask, unchanged).

Not made: catches from outside (cannon, dragon), wind over the posts. Noticed: the head on its dais can see and pull a player crossing the inner North spoke (within ~11 m); a body that lands on the horn plate at the hub centre trips the horn (hub -> horn -> S -> rim). Both are chains, not checked for reliability. A player could try sailing the 6 m from the dais tip to the hub.
