# Traps and environmental hazards (ideas, 2026-10-12)

> **Status: brainstorm, not decided.** Ideas only; no code. Companion to
> concept.md and aqueduct-map.md (all numbers below come from its section 5:
> walk 2.4 / run 4.8 m/s, plain jump 0.8 m high / ~2.2 m long, pump 1.5 m,
> long jump 4.2 m (6.7 chained), twirled jump ~3 m, grab 1.875 / chain 2.575,
> wall kick 1.4 m, slide up to 20 m/s, glide 3.7 m across per m down, plane
> span 2.8 m). Enemies and the dragon are other agents' work; here they are
> only combo partners.

## Principles

- **Physics, not damage.** Almost every trap moves the pilot (shove, fling,
  tip, drop, wash) and the real injury is where he ends up. Hit points never
  appear in this doc.
- **Fail ladder.** Void = death-ish. One layer down = a softer fail: you land
  on a lower isle or ruin, lose time, items stay, and the climb back is a
  fresh route. Tag each trap with what is under it. A generator rule: a trap
  at a fall-is-void spot costs +1 and needs a bigger tell.
- **The tell is the contract.** Every trap has (a) a sight tell visible from
  the section's entry, (b) a sound tell, (c) a first-hit that is a shove and
  not a kill when it is a tier 1-2 placement. Tells are authored in the module
  (cracks, scrape marks, dripping, a dust line), never random.
- **Modules are sized in pilot units, not metres:** `reach` (4.2 m long jump),
  `step` (1.6 SET_OFF), `twirl gap` (3.0), `channel` (2.4 wide, 1.5 clear). A
  module reads those from WorldScale/PilotMotor so it follows resizing.
- **Sections stay chainable:** each module declares an entry/exit like the
  concept's sections, plus the verbs it asks for.

Danger cost: 1 = a nuisance, 3 = a real decision, 5 = hellish, only late
tiers or with a pressure on (storm, dragon).

## Index

| # | Module | Cost | Home |
|---|---|---|---|
| 1 | Loose Voussoirs | 2 | span deck over sky |
| 2 | Seesaw Slab | 3 | gap between two ledges |
| 3 | Censer Pendulum | 3 | channel, arcade |
| 4 | Drum Run | 3 | slope, ramp, channel |
| 5 | Sluice Flush | 3 | any channel with water |
| 6 | Draft Vents | 2 | ledge, rim, crown |
| 7 | Bell Toll | 3 | belfry, crown, tower |
| 8 | Gargoyle Spitter | 2 | any wall facing a route |
| 9 | Jaw Slot | 4 | wall-kick slot, corridor |
| 10 | Windmill Beam | 4 | pier head, henge top |
| 11 | Mossy Slope | 2 | any slope 15-30 deg |
| 12 | Ivy Fuse | 4 | overgrown wall, bridge, hall |
| 13 | Keystone Collapse | 5 | arch run, colonnade |
| 14 | Catapult Flag | 2 | any flat tile with room |
| 15 | Orbit Stones | 3 | open sky between isles |
| 16 | Rotten Bridge | 3 | rope or plank span |
| 17 | Tripwire Pennants | 2 | any approach to a prize |
| 18 | Lintel Drop | 4 | doorway, arch, alcove |
| 19 | Mist Shelf | 3 | low deck, rim |
| 20 | Hangar Tilt | 2 | any plane parking patch |
| 21 | Plughole | 3 | cistern, flooded floor |
| 22 | Cracked Cistern Floor | 3 | tarn, nave, courtyard |

## Modules

### 1. Loose Voussoirs
Pitch: a stretch of deck slabs that were never mortared; each drops a beat after you stand on it.
- **Where:** any span over open sky or a layer-down drop, 6-20 m run.
- **Tell:** slabs are visibly offset by a few cm, grass-free, with a hairline dark gap; one dust puff and a grinding chirp when anything lands on a slab (the first slab always "tests" harmlessly).
- **Does:** each slab (1.2 x 2.4 m, one channel width) drops 0.5 s after the first foot lands, then falls away. At run speed 4.8 m/s you cross a 1.2 m slab in 0.25 s: running is safe, walking (2.4 m/s, 0.5 s) is not. Dropped slabs fall onto whatever is below.
- **Counter:** just run. Speedrun: long jump chains skip every other slab. A slab can be wall-kicked or ledge-grabbed in its last half second.
- **Combos:** under a Sluice Flush, a washed pilot crosses the whole run for free (or gets swept off). Dragon swipe takes the whole row. Slabs that fall onto a lower trap (Jaw Slot, Seesaw) arm it.
- **Knobs:** timer 0.8 s to 0.3 s; slab length 1.2 to 2.4; every third slab already missing (a jump gap of 2.4 to 3.0); neighbours drop in chain (a wave behind you, forcing speed).
- **Cost:** 2 (3 over void).
- **Worked example:** the **channel** between the castellum and the gap (z -30 to -50), over the arcade arches: 8 slabs, fail = the arcade turf below (a layer down, a softer fail), but the **north deck / far run** past the gap over sky is the 3-cost version.

### 2. Seesaw Slab
Pitch: a long slab balanced on a pier head; weight shoves the far end up, and anything on it slides.
- **Where:** a gap of 4-7 m between two ledges at similar height, or as a ramp up a 2-3 m rise.
- **Tell:** the slab rests slightly tilted with its low end touching the near ledge; a rock rests on the high end that rolls when tilt changes. Pivot is a visible stump with a worn groove.
- **Does:** a 6 m slab tips under weight like the bob slabs but 10x as hard: stepping on it at the near end tips it down (slides you toward the pivot), the far end rises 1.5 m. Reaches level when you reach the pivot, then tips the other way. A heavy item or a placed stone on the far end keeps it balanced.
- **Counter:** run across (momentum carries you over before the tilt completes), or pre-load the far end with a rubble stone or the plane's loose gear. Speedrun: jump the rising end for a free 1.5 m boost (the slab as a launcher).
- **Combos:** a Catapult Flag or rolling Drum onto the far end flings the slab's occupant. The plane parked on it rolls off (comedy). Wind pushes the tilt.
- **Knobs:** length 4 to 9 m; pivot offset (uneven, then it tips early); two seesaws in a row (a rhythm); stones on it that roll off and become the next trap.
- **Cost:** 3.
- **Worked example:** the **stump line** (x 92): replace the 2.11 m slot stump with a seesaw bridging the 3.4 and 3.0 m gaps.

### 3. Censer Pendulum
Pitch: a huge stone urn on a chain swings across a corridor like a church censer.
- **Where:** under arches (8 m clear), covered channels, halls with a beam 4-8 m up.
- **Tell:** the chain's upper mount (iron ring, rust trail), the urn's long scrape mark on the floor, a low creak that rises in pitch at the top of each swing; smoke or ash drips from the urn.
- **Does:** period ~2.5 s, arc covers 3-6 m of the route. The urn is a shove (not a hit): it carries the pilot along its swing for a body-length and drops him. At the channel (1.5 m clear) it blocks everything.
- **Counter:** time the pass in the 1 s the urn is at the far end of its swing (it shows a flat-bottom shadow); or slide under at the bottom (a 0.5 m crouch). Speedrun: ride the urn itself (hop onto its top at the apex) to cross a gap 10 m wide.
- **Combos:** knocks a fire brazier into Ivy Fuse; flings the pilot into a Jaw Slot; pushes enemies off. In the dragon's wake it swings wildly and unpredictably.
- **Knobs:** period 4 s down to 1.6 s; two out of phase; chain shortened for faster swing; urn spills oil (slick) at the bottom.
- **Cost:** 3.
- **Worked example:** the **arcade** (z -22 to -40) under arch 2: urn hung from the arch crown (crown 8.0 m, chain ~6 m), swinging along z, forcing a timed run past a pier.

### 4. Drum Run
Pitch: a fallen column drum rolls downhill whenever a pressure tile near its cradle is stepped on.
- **Where:** slopes (rubble slope, ramps, stairs), long channels with a gentle fall (>5 deg), halls.
- **Tell:** a drum cradled by wedges at the top, drag tracks in the dust down the slope, a clear tile with a stone-cut ring.
- **Does:** a 2 m diameter drum (taller than the pilot) accelerates down at 3-6 m/s and runs the full slope. It knocks the pilot sideways rather than over him: contact = a shove of ~6 m/s along its tangent. It breaks at the bottom into rubble (a new scramble heap) or rolls off the edge into the layer below.
- **Counter:** hop on top of the drum (stands on it and rides it down, balance-walking), or jump the 2 m body with a pump + twirl, or sidestep into a wall alcove. Speedrun: trigger it early from a distance with a thrown stone, then walk behind it.
- **Combos:** a drum crashing into a Loose Voussoir run drops the lot; into a Seesaw's high end launches it; onto the parked plane it rolls the plane off. A dragon's wing sweep triggers every drum on an isle at once.
- **Knobs:** drum size 1.2 to 2.6 m; two drums staggered; slope angle; the tile hidden under moss (a bush marks it); bounces off walls, so it zigzags.
- **Cost:** 3.
- **Worked example:** the **rubble slope** (spawn to head, 30 deg, 2.4 m wide) is too narrow and too early for tier 1, but at tier 3 a drum waits at the **head**; the **grand stair** with the balustrade slides is the safe lane (slide down a cheek while the drum rolls past).

### 5. Sluice Flush
Pitch: the channel's water is held back by a gate; a pressure plate or timer opens it and the flood sweeps the walkway.
- **Where:** any channel with water (aqueduct deck, nave floor, cistern).
- **Tell:** a rusted gate stone with a damp ring a few metres upstream; the water level drops to a trickle just before; a low gurgle and a rising pitch for 2 s; foam lines down the channel.
- **Does:** a wave 0.6 m deep moving at 6 m/s along the channel, carrying the pilot (at wade speed 0.67 of 4.8) with it, over the end if the channel is open. The channel is 1.5 m clear with 0.42 m parapets: standing on a parapet (0.42 m) is not enough; get up to 1 m.
- **Counter:** hop onto the parapet and a pump to the arch above, ledge-grab a side lip, or jump into the flow and ride it (a chain of slide speed). Speedrun: the flood is a free 6 m/s conveyor for the whole channel; dive off the end into a glide.
- **Combos:** sweeps Loose Voussoirs, Rotten Bridge planks, and enemies; floats drums and crates along (moving platforms); a Plughole at its end drains it. Fire on the water (oil) burns down the channel.
- **Knobs:** wave height 0.4 to 1.2 m; period 20 s to 8 s; second wave 3 s later; open end vs. a dead end with a pool (soft fail).
- **Cost:** 3.
- **Worked example:** the **channel**, between the head and the **gap**, with the gate hidden in the **castellum** (it IS a water tower): the flood ends at the gap and water cascades over it (existing "water spills over the south end"), so a washed pilot is flung over the 3 m gap or into it.

### 6. Draft Vents
Pitch: old chimneys and flues breathe sideways wind in bursts, shoving the pilot (and the plane) off ledges.
- **Where:** a ledge 2-6 m wide, rims, crowns, stair landings.
- **Tell:** a round stone mouth in a wall, leaves and ash whirling out of it, a hoot like blowing into a bottle that rises before the burst; grass lies flat in a line.
- **Does:** a burst, 1 s on, ~4 s off, pushes at 7 m/s (more than run speed) across a 3 m wide lane. On the ground it pushes you toward the edge; in air it carries you (a long jump gets 3 m more).
- **Counter:** crouch and hold (a wall-hug stops you), time the gap, or use it: jump into the burst for an extra 3-4 m of range. Speedrun: vents arranged along a route are a free glide boost; glide in the burst to cross isles.
- **Combos:** with the dragon wake, wild gusts. Blows out torches/Ivy Fuse flames (or fans them). Stacks with a Bell Toll's shockwave.
- **Knobs:** period 6 s to 2 s; force 5 to 10 m/s; two vents opposed (a washing machine); vent on a 1.5 m wide ledge over void.
- **Cost:** 2.
- **Worked example:** the **summit** of the hill, **henge terrace**: vents in the sarsens' bases blow along the ring, making the lintel run (3 m break) a gamble.

### 7. Bell Toll
Pitch: a big cracked bell rings on a timer; the ring is a shockwave that bucks everything within 12 m.
- **Where:** belfry, crown, tower tops, near any big hanging stone.
- **Tell:** the bell visibly swings and the clapper starts 1 s before the toll; the ground shows ring-shaped dust.
- **Does:** each toll sends a ring wave out at 12 m/s: anything it passes is lifted 0.6 m and nudged 2 m outward. Over a Loose Voussoir slab it triggers it. Standing on a floating stone it bobs it.
- **Counter:** be airborne when it passes (jump with it: no effect and a free 0.6 m boost), or stand behind a wall.
- **Combos:** triggers every other trap in range (a master switch); wakes things.
- **Knobs:** radius 8 to 20 m; period 6 s to 3 s; strikes irregularly (a long-short cadence); ring pushes harder.
- **Cost:** 3.
- **Worked example:** the **castellum** crown (the water tower has a broken bell frame on it): the toll rattles the **drift** stones, whose 1.6 m gaps become much harder.

### 8. Gargoyle Spitter
Pitch: a carved face in a wall spits rubble stones when you cross its line (Spelunky's arrow trap, but the arrow is a shove).
- **Where:** any wall facing a route, 1-3 m up.
- **Tell:** a mouth with a dark tongue, a stone lid on the lip, a trail of pebbles in front, a faint glow-less hiss. Spits a harmless pebble first at 2 s warning.
- **Does:** fires a 0.4 m stone at 12 m/s along a line, knocking 3 m/s of push. It's a shove: harmless on a wide path, deadly at a ledge. The stones bounce and roll after the shot, becoming a hazard.
- **Counter:** a hop or a duck; the lid can be blocked by standing close to the wall. Speedrun: bait the shot, then the stone is a free platform (it rolls and stops).
- **Combos:** shot stones knock out Seesaws, trigger Tripwire Pennants, hit enemies (friendly fire), go through Ivy Fuse. In the channel (1.5 m wide) the line is unavoidable except by jumping.
- **Knobs:** rate 1/3 s to 1/0.8 s; double mouths; tracking (aims at you, delayed); size.
- **Cost:** 2.
- **Worked example:** the **buttress** (x 103.8, z -12 to -6) climb: a spitter on the blind wall's east face fires across the wall-kick route.

### 9. Jaw Slot
Pitch: two wall faces of a kick slot close and open like a jaw.
- **Where:** a wall-kick slot (2.8 m between walls) or corridor.
- **Tell:** the walls have tooth-grooves with pale scrape marks on the top; moss-free strips; a low grind a full second before moving; the slot floor is stained.
- **Does:** walls move 0.6 m each way, period ~4 s; at the close the slot is 1.6 m (pilot can't stand), open 2.8 m (kick works). Caught in the close = pushed along the groove and thrown out the top or bottom (no instakill; a shove up or out).
- **Counter:** enter on open and kick up as it closes (the closing wall is a free kick); the squeeze pushes you up 1.4 m, like a kick. Speedrun: abuse the squeeze as an elevator.
- **Combos:** drums or stones dropped into the slot jam it; the plane's wingtips (2.8 m) are exactly the slot's size, so the slot is a plane trap too.
- **Knobs:** speed; walls rough (slows kick); two slots stacked out of phase.
- **Cost:** 4.
- **Worked example:** the **kick slot** (1.8 m gap between the castellum steps and the blind wall) at tier 3: the castellum side is a sliding wall.

### 10. Windmill Beam
Pitch: a stone beam spins on a pier head like a windmill sail; jump the sweep.
- **Where:** pier heads, henge top, wide ledges (>= 6 m across).
- **Tell:** a central pin with a lighter wear circle; scored arcs in the floor; the beam creaks, and its shadow sweeps the floor.
- **Does:** a 5 m beam 0.6 m above the floor turning at 1 rev per 4 s; the tip moves at 7.8 m/s (faster than the pilot). Contact = flung outward tangentially, 8 m/s. Beam height 0.6 m: a plain jump (0.8 m) clears it, with a window.
- **Counter:** jump-rope it: plain jump on the beam's passing. Or stand at the pin (dead centre is safe). Speedrun: ride it, grab the beam in air and get flung across a gap (the beam as a launcher).
- **Combos:** knocks Spitter stones, flings enemies, with wind it speeds up.
- **Knobs:** speed; two beams crossed (cross-jump); beam height 1.2 m (needs a pump); beam extends past the edge.
- **Cost:** 4.
- **Worked example:** the **summit**, the **henge** circle centre: a beam on the hill's crag top, the ring's 8 sarsens as the edge.

### 11. Mossy Slope
Pitch: a damp slope is slick; footing is a gamble, but the slide is fast.
- **Where:** any slope 15-30 deg, stairs, ramps.
- **Tell:** bright green and a wet sheen, a runnel of water, snail trails, footprints that smear.
- **Does:** treats the slope as a slide (>22 deg now slides anyway; mossy makes it slide at 15 deg), no steering except lean. Speed up to 20 m/s.
- **Counter:** stay on the dry stripe; a twirl re-grips; run-jump off it. Speedrun: use it as a conveyor, slide off the lip into a glide for a free 20 m/s launch.
- **Combos:** drums and Sluice Flush on a mossy slope; the plane parked on it rolls; in a Draft Vent it drifts.
- **Knobs:** angle; length; edge guard (none, a low kerb, a drop-off); dry patches fewer.
- **Cost:** 2.
- **Worked example:** the **ramp** (T1 to T2, 60 deg arc) of the hill: a mossy section, with the retaining wall inside and the kerb outside, so a slip spills you to the T1 below (soft fail).

### 12. Ivy Fuse
Pitch: dry ivy and old cloth ignite from a spark and the flame runs along the growth, burning the route.
- **Where:** overgrown walls, rope bridges, wooden planks, halls with tapestry.
- **Tell:** brown, dry ivy (distinct from green), a smouldering brazier or dragon-breath scorch nearby, a smell/smoke wisp, a clay oil pot.
- **Does:** fire spreads at ~3 m/s, burning a rope bridge in seconds; the player burns? No: fire pushes and the burned footing fails (planks, ropes) rather than damaging; touching flame makes you hop/scramble (stunned for 0.4 s).
- **Counter:** cross before it, cut the ivy first (a slide through it), or wait it out. Speedrun: ignite deliberately from a distance and use the burnt gap's rising smoke thermals as updraft.
- **Combos:** brazier knocked by a Pendulum, Spitter stones, dragon breath; Draft Vents fan it; Sluice Flush puts it out; thermals from the fire lift the glide.
- **Knobs:** spread speed; fuel density; oil trails (faster); two lines converging.
- **Cost:** 4.
- **Worked example:** the **rope line** (x 106.3), the three swing ropes: a pot above rope 2 can ignite and burn it at the swing, so rope 3 is the safer choice (soft decision).

### 13. Keystone Collapse
Pitch: take the keystone prize or step on the wrong stone and the whole arch run unzips behind you.
- **Where:** arch runs, colonnades, any 3+ pier line (deck over hanging piers).
- **Tell:** a keystone with a bright, clean face; scatter of fine dust each time anything shakes; a ring of cracks climbing the pier; the piers lean a few degrees.
- **Does:** on trigger, the deck falls span by span at 8 m/s, chasing from the trigger forward or back. You must outrun it (run 4.8 m/s: it overtakes! so a ramp at the start gives a lead). Falling pieces drop onto the layer below as new hazards.
- **Counter:** long jump chain (6.7 m/s); slide the broken deck; pump up onto a pier; swing off a rope. Speedrun: trigger it on purpose from a distance by throwing a stone, skipping the chase.
- **Combos:** drops a Seesaw's counterweight; the falling pieces trigger Drum Runs below; the dragon sets it off with one swipe; a Sluice Flush adds speed.
- **Knobs:** speed 5 to 10 m/s; the number of spans; a branch point (two exits, one a dead end); a side route (a ledge-grab) from the start.
- **Cost:** 5.
- **Worked example:** the **channel** from the **gap** north to the **north deck / far run**: the keystone at the far end of pier 71. The collapse runs south toward the **gap** with only the far end safe.

### 14. Catapult Flag
Pitch: a flagstone on a spring-lever launches whoever steps on it, usually somewhere regrettable.
- **Where:** any flat tile with 5 m of free air in the launch direction.
- **Tell:** a tile with a seam round it and a paler carved arrow/groove; a stone counterweight in a pit beside it.
- **Does:** launches at 14 m/s along the arrow at ~55 deg, a 12 m lob that lands where the generator set it (usually one layer down or on a prize). A launch is a ballistic arc, glide-able.
- **Counter:** step around; glide out of the arc to reach somewhere else (it launches you into the pocket sail window); the generator guarantees a landing. Speedrun: launches over whole routes.
- **Combos:** loaded with the plane's gear. Draft Vents change the arc; a Bell Toll triggers all of them; launch into a Mist Shelf.
- **Knobs:** arrow hidden or not; the landing (soft pad, hard stone, void); two in series.
- **Cost:** 2.
- **Worked example:** the **forecourt** east of the grand stair: a flag throws the pilot at the **drift** stones' start (a shortcut) but a misstep sends him into the castellum steps.

### 15. Orbit Stones
Pitch: a ring of floating stones circles a point in the sky, a rotating bridge you board mid-flight.
- **Where:** open sky between isles (a gap of 15-30 m), a hub pillar.
- **Tell:** the hub pillar with an orbit ring of dust on it; the stones' clear path; the stones' creaks and their hum with differing pitch.
- **Does:** 4-6 stones (2 x 1.8 m, like the drift stones) orbit a hub at r 9 m, period 18 s (edge speed 3 m/s). Stones tilt slightly when stepped on.
- **Counter:** step on at the closest approach; stones aligned in a line at one moment (a 1.6 m jump gap) form a bridge.
- **Combos:** Draft Vents shift their orbit; dragon's wake scatters them; Bell Toll bobs them.
- **Knobs:** radius; speed; number of stones (gaps up to a twirl); inner and outer rings counter-rotating.
- **Cost:** 3.
- **Worked example:** the **sky gap**, beside the **ferry lane**: an orbit ring at the middle, alternate to the ferry.

### 16. Rotten Bridge
Pitch: a rope-and-plank bridge where each plank has its own opinion.
- **Where:** a span of 8-20 m, between ledges.
- **Tell:** planks of differing colour; the sound under a prod (the first plank is always strong); frayed rope.
- **Does:** weak planks snap after 0.3 s of weight; the bridge sways with steps; one bad plank = a 1.4 m hole (a plain jump gap).
- **Counter:** spot the dark planks, run (fast crossing skips the timer), or glide.
- **Combos:** Ivy Fuse burns it; Sluice Flush; wind sway; pendulum swings through.
- **Knobs:** weak share 15% to 50%; length; sway.
- **Cost:** 3.
- **Worked example:** the **bobs** to **east islet** at the **east rim**: a bridge connects the islands.

### 17. Tripwire Pennants
Pitch: a line of tattered pennants hides a thin cord that releases something nasty elsewhere.
- **Where:** any approach to a prize or in front of a doorway.
- **Tell:** the cord glints in low light and is visible against sky; the pennants flutter in line.
- **Does:** on break, drops a net/stone/starts a Drum Run or triggers a Spitter further on.
- **Counter:** jump or slide under; cut it (a thrown stone) to disarm; or use it to trigger traps early.
- **Combos:** the wire for every other module; enemies trip them.
- **Knobs:** height; tension; hidden second wire.
- **Cost:** 2.
- **Worked example:** the **heel stone** at the **east meadow** and the buried token (slam spot): a wire sets off a drum.

### 18. Lintel Drop
Pitch: you walk through a doorway and the lintel above drops (Indiana Jones).
- **Where:** doorways, arches, alcoves with a prize.
- **Tell:** the lintel is a block set loosely; dust trickles; the sill has a notch.
- **Does:** falls 0.6 s after the pressure plate; blocks the exit and leaves you trapped (soft: a wall-kick or the plane to leave).
- **Counter:** slide through; throw a stone first to trigger it; jump over.
- **Combos:** locks enemies in; seals a prize chamber.
- **Knobs:** speed; plate hidden.
- **Cost:** 4.
- **Worked example:** the **gate arch** on the **far island**, a closing portcullis to the final area.

### 19. Mist Shelf
Pitch: a low cloud drifts across a deck, hiding the edge.
- **Where:** low decks, rims, the lower layers.
- **Tell:** the cloud arrives with wisps; the rim has lantern posts that show through the fog; the player sees the edge line by the shining wet.
- **Does:** reduces visibility to 4 m; the footing is unaffected; the edge is marked by tall markers.
- **Counter:** follow the markers; stay in the middle; the plane's compass.
- **Combos:** hides other hazards (but their sounds warn), Draft Vents clear it.
- **Knobs:** density; duration; markers fewer.
- **Cost:** 3.
- **Worked example:** the **north path** along the near island's north rim.

### 20. Hangar Tilt
Pitch: the parking patch isn't level; the plane creeps downhill.
- **Where:** any plane parking patch.
- **Tell:** a slight slope with a chock stone; scraped wheel tracks.
- **Does:** the parked plane rolls toward the edge slowly (0.3 m/s^2) unless chocked (a stone placed under the wheel). Run to catch it.
- **Counter:** place the chock; park at the uphill end.
- **Combos:** any shove (Bell Toll, Draft Vent) sets it rolling; the dragon.
- **Knobs:** slope; distance to the edge.
- **Cost:** 2.
- **Worked example:** the **near meadow**, off the **spawn** (the plane's home).

### 21. Plughole
Pitch: a flooded floor drains into a hole with a whirlpool that pulls the pilot and floating debris.
- **Where:** cisterns, a sunken nave, the end of channel.
- **Tell:** the whirl, a gurgle rising; a floating debris orbit.
- **Does:** pulls at 3 m/s toward the hole; falls = a layer down.
- **Counter:** swim across the edge; jump the hole; ride a floating drum.
- **Combos:** Sluice Flush feeds it; debris crosses the hole.
- **Knobs:** pull; hole size.
- **Cost:** 3.
- **Worked example:** the **castellum** foot (water tower) pool.

### 22. Cracked Cistern Floor
Pitch: a glass-thin stone floor over a deeper room; weight breaks sections open in a pattern.
- **Where:** tarn, nave, courtyard.
- **Tell:** a web of cracks and a hollow echo; dark patches.
- **Does:** sections 2 x 2 m crack when stepped, fall after 1 s.
- **Counter:** run; follow the crack lines; jump-slam (the slam token).
- **Combos:** slam-token interplay (the buried item); drums.
- **Knobs:** section size; delay; path length.
- **Cost:** 3.
- **Worked example:** the **near meadow**'s buried token spot.

## Combo cheat sheet (chains the generator should be allowed to make)

| Chain | Result |
|---|---|
| Bell Toll -> Loose Voussoirs + Orbit Stones bob | whole section shakes at once |
| Pendulum -> brazier -> Ivy Fuse -> Rotten Bridge | a bridge burns in the middle of a swing |
| Drum Run -> Seesaw high end | the pilot is flung (or the drum flies off) |
| Sluice Flush -> Plughole | a washed pilot circles the drain |
| Dragon swipe -> Keystone Collapse | the arch run unzips on its own |
| Draft Vent + glide | a free long boost; or the gust off the ledge |
| Spitter stone -> Tripwire | triggers a trap early for a speedrunner |
| Catapult Flag + Mist Shelf | launched blind into a layer below |

## Top 5 shortlist

1. **Keystone Collapse** (5): the set-piece. A chase against a falling world, the Spelunky "boulder" of this game; it makes speed feel like the answer.
2. **Sluice Flush** (3): uses the aqueduct (our authored theme) and turns water into a conveyor; both a hazard and a speedrun tool.
3. **Seesaw Slab** (3): the best physics comedy and the most tool-like (load the far end, ride it); it works for the plane too.
4. **Censer Pendulum** (3): readable in 3D, rhythm-based, combos with everything (fire, enemies, wind).
5. **Draft Vents** (2): cheap to build, scales smoothly and adds the verb "use the wind", which feeds the glide and updraft the pilot already has.

Honourable: Jaw Slot (wall-kick payoff), Drum Run (slope drama).

## Weird wildcards

- **The Courteous Statue:** a stone guardian that bows when you enter; if you do not bow (crouch) back, it throws you (hurls you 8 m, a launch). Learning the etiquette is the gate; some are rude and swap the rule. Pure comedy, zero damage.
- **Tilt Isle:** a small isle on a central pivot: weight shifts the whole isle slowly (like a seesaw at isle scale) so pickups and the plane slide; the loot is on the high side. Pairs with any rolling hazard.
- **The Hungry Door:** a big carved mouth in a wall that swallows loose items (including a loose plane part or the parked plane's chock) and spits them out somewhere else on the map: a teleporter for stuff, a thief for the careless, and a speedrunner's mail system.
