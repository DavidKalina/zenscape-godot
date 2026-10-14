# The Plumb Well — "Where they lowered the stone, the stone still waits to be lowered"
Lenses: verb = fall / descend; purpose = quarry (the well the cut stone was lowered down); decay = half-collapsed; mood = oppressive; shape in a layer = a tall stack (isles over isles), a closed column rather than an open pit.

Pitch: Five round plates hang in a column, each pierced by an oculus that does not line up with the one below, so every drop is a small decision and the daylight comes down in one thin bar. At the very bottom, in the dark, something pale looks up the shaft and finds you.

## Top (1 char ~ 4 m; the cap plate, with the lower oculi shown offset below it)
```
          ####################
       ###""""""""""""""""""""###
     ##""      cap plate (1)    ""##
    #""    ________________       ""#
    #"    /    oculus 1     \  P    "#
    #"   |   (hole in turf)  |      "#
    #"    \________________/        "#
    #""          ^ rim N            ""#
     ##""    lower oculi (2)(3)(4)(5) ""##
       ###""  step round the spine @ ""###
          ####################
```
## Side (1 row ~ 4 m; cut through the oculi)
```
 1  ~~~#=======(oculus)====#~~~~    cap, rim N, daylight bar
              :   /|
 2     #=====(oculus)========#      plate 2: flip hatch
        ::  @ spine of hall_columns down the shaft
 3  #=======(oculus)=====#          plate 3: dropper seesaw ledge
              :
 4     #====(oculus)=======#        plate 4: loose slab floor
              :
 5   ####=====A==========^ rim S    floor plate, arena, void under rim S
       the head, hovering at the well's foot
```
Five plates about 12 m apart. Each oculus is about 3 walker-spans across and shifted a fifth of the plate's radius from the one above, round the central spine. Footprint about 48 x 48 m, height span about 66 m.

## Play
1. **Arrive on the cap (rim N).** Overgrowth, one shaft of light. The oculus is a hole in the turf with a rope-worn lip.
2. **Drop through.** A 12 m fall to plate 2. Pocket sail steers the fall toward the next opening; the dark is the plate above closing over you.
3. **Plate 2, the flip hatch.** The next oculus is covered by a stone leaf turning on a rhythm (`trap_flip`): drop through when it is open. Caught on it as it turns, you are thrown. A miss lands on the rim; ledge grab and chain over the lip.
4. **Plate 3, the dropper ledge.** A seesaw ledge across the oculus with its heavy block hung above (`trap_seesaw_dropper`): the block falls every few seconds on the near end, flinging a standing pilot across the hole to the far lip, or down it early. Time a crossing, or take the throw.
5. **Plate 4, the loose floor.** Slabs over the next oculus (`trap_voussoirs`) go a beat after you land, taking you down with them. A fall is the route; a careful pilot skirts the slabs on the rim and grabs the lip, spending time.
6. **Plate 5, the floor.** An arena at the foot of the well. The inhaler head hovers there, turns its face up the shaft as you come into the daylight bar, and breathes in. Rim S is behind it, over the void. A twirl or a flow-charge slam at the lip is the get-out.
Going back up: the central spine of columns is wall-kickable on its ties, and each oculus lip is a ledge catch (rim thick enough for GRAB_TOP), so a pilot on the floor can climb the column back out, plate by plate, by ledge grab and chain.
Moves named: pocket sail, ledge grab and chain, wall kick, twirl, flow-charge slam, run.

## Threat
- **The inhaler head** at the well's foot, eye pale and lit as it locks on. It inhales, gulps and blasts him out along its face (`blast_out`, `blast_up`, laid down on landing): a cannon with a bad temper. Also a tool: stand on the line from the head through rim S and its blast is the exit, a stunned fling out over the void toward the next isle. (Check that its inhale cone reaches a pilot dropping into the daylight bar: it faces him flat, it does not look straight up, so he comes into its cone as he lands on the floor plate.)
- One trap per plate: flip hatch (plate 2), dropping block (plate 3), loose slabs (plate 4). Each fails down one plate, so each costs 2; the floor is 4 (void under rim S, a lit watcher).
- The real fail is overshooting: reaching the floor with no sail and no slab left. Generator rule: leave one clean beat per plate.

## Combos
1. **By accident: the whole column.** You drop through oculus 1 and land on plate 2's hatch as it turns: the leaf's flip throws you (stunned, tossed up and back); you come down on plate 3's seesaw at its low end, a landing that counts as the block's; the dropper block falls on the other end and flings you (a toss, still stunned, a fresh poise) across the oculus, which you tumble down; you hit plate 4's loose slabs as they go and fall with them onto plate 5, laid out in front of the head. It inhales, gulps, blasts. Five different sources, so the restun gap never gates it, and the 3 s cap guarantees a break-out; the cost is position, 48 m down, in the watcher's cone.
2. **On purpose: the threaded drop.** Drop through oculus 1 at the offset that puts you over the hatch's open window; pocket sail to plate 3's near lip, run the seesaw's high end as the block falls on the *low* end so you ride the throw to the far side of oculus 3; sail over plate 4's slabs to the floor; twirl out of the head's cone; run to rim S. The plan of the column is the player's: the skill is reading five beats.
3. **Ridden on the head: the Olmec cannon.** On the floor plate, let the head inhale you (don't run), take the gulp and the blast, and you leave the well along its face, out of rim S, stunned and tumbling, toward whatever the generator hung there (an updraft, a seesaw on the next isle, another head). The head is the exit, if you aim it with where you stand.
**Ports.** Catches from outside: the cap's oculus catches any airborne body above it (a cannon shot or a head blast from a neighbouring isle that falls short drops through the oculus, onto plate 2: a thrown body is *caught* into the column rather than lost); the E adit on plate 3 catches a body flung in from the side. Throws out: rim S, along the head's face (a stunned throw, 24 units out, 2.4 up) toward the next tier's isle, so a neighbour placed south and below can catch it (a net: a seesaw, another head, an updraft); the E adit on plate 3 throws sideways when the dropper's block flings you out of it.

## Mystery
Cut stone was lowered down this well on the hook above the seesaw to the floor where the masons worked. The head hovers at the foot: it was lowered and no one came back. Clues down the way: lifting-hook scars on every plate's underside, a chalk line of runes down the wall that shortens plate by plate, a rope groove worn into each oculus rim, all in one line, ending at the head.

## Kit used
- hall: `hall_column` (central spine, stacked), `hall_beam` (ties), `hall_slab` (hatch leaves, spoil slabs), `hall_bay`
- gothic: `floor`, `wall`, `stone_circle` (the cap's oculus rim), `stairs`, `grand_stair` (cap to plate 2), `fallen_pier`, `buttress`
- ruin_kit_cloister: `heap`, `range_run` (a short arcade wall, the masons' gallery on the floor plate)
- foot pieces: one rope bridge across plate 4's oculus, swing ropes (a hook line over a hole)
- traps: `trap_flip`, `trap_seesaw_dropper` (and `trap_seesaw_drop`), `trap_voussoirs`; enemies: `inhaler_head`

## Kit asks
- A plumb block that really runs down the shaft on a chain (the dropper only falls over a seesaw).
- A windlass for the cap, so the first plate reads "lowering".
- A shaft wall: a stone cylinder or ring wall round the column (today the plates would be isle keels and open air), plus a daylight-bar light piece.
- A plate-with-a-hole isle shell as a motif helper (a cut oculus in the turf, as hollow_keel cuts its shaft).

## Family knobs
- `plates`: 4 / 5 / 6
- `trap_order`: which of flip / dropper / slabs sits on plates 2-4
- `offset`: how far each oculus is shifted from the one above (0.1 to 0.4 of the radius)
- `wreck`: 0..1, how much of each plate's rim has fallen (a bitten rim lets you drop round the hole)

## Sockets
- rim: N on the cap (arrive), S on the floor plate (exit, over the void, behind the head); optionally an E adit on plate 3 (a side door)
- arena: the floor plate (the head's, room about 6 walker-heights); the plate 3 ledge as a small one
- cover: under the cap and in every plate's overhang, the whole shaft (a quiet place away from the dragon)
- perch: the plate 3 ledge or the masons' gallery on the floor plate (a trader next to the head's lair)

## Generator fit
Role: arena (the inhaler head's home) or a hero in a tall layer. Footprint about 48 x 48 m, height span about 66 m. The tightest stack: a narrow column, with neighbours' rims at the top and bottom only.

## Distinct from
Benchfall (sibling): that is an open, lit, spiral pit you descend by many lines (walk, glide, slide); this is a closed, dark column descended by one line, through the holes, one trap per plate. `hollow_keel`: a hall under one plate you walk down to; this is five plates fallen through with a watcher at the end. `cloister_tarn`: a bowl round water, no depth to it.

## Greybox (Opus pass)
First build (Sonnet, round 1): oculi offset round a central spine, a five-leaf "gone" hatch, the timed seesaw dropper and the head at (5, 4); each link ran by hand, but the chain broke at the hatch toss (1.7-12 m/s by where he lay, onto the seesaw's far end, off it before the 4 s block fell), the dropper's fling (across oculus 3, not down it) and the head (its tell ended after he was up).

Run: `godot --path . res://studies/greybox/plumb_well.tscn -- --no-title` (`--well-log` prints the chain log). Code: `studies/greybox/plumb_well.gd`, the layout one const table at its top (PLATES with holes, SPINE, WALLS with bottoms and tops, TRAPS, ENEMIES, STATIONS_AT, LABELS).

**The shape now.** The column stands against one tall wall, the plumb wall (north, z 12), and every oculus runs down it in one line: the rope groove and the chalk runes have one wall to go on, and the line ends at the head. Plates at 35 / 26 / 17 / 8 / 0 m (9 m apart, the last 8 m). The spine moved off the drop line to (6, -4).

**Stations:** 1 cap (oculus 1 ahead) · 2 plate 2 (the leaf) · 3 plate 3 (the seesaw along the wall) · 4 plate 4 (the slabs) · 5 the foot (head to the NW) · 6 combo 1 start (cap, 2.6 m south of oculus 1: walk north and let go) · 7 combo 2 leg (on the seesaw's fuse plate) · 8 combo 3 start (the foot, 3.6 m in front of the head's mouth) · 9 the leaf's lip. R resets; F1 shows trap state and the chain log.

**What I rearranged, and why (link by link):**
- **Cap to leaf.** Oculus 1 (3.6 x 3.9 m) sits over one stone leaf (2.4 x 3.6 m, `trap_flip`, `count` 1) whose way in faces the wall with a 0.8 m slot between them. A walk off the oculus lands mid-leaf, fall-stunned (9 m, 1.15 s down).
- **Leaf to seesaw.** The flip always throws back along its own +z: I turned it so +z is north, into the plumb wall. Whatever the toss speed (2-14 m/s by where he lies), the wall stops him and he drops down the slot on the wall's line, onto the seesaw. The leaf is walkable both faces (`underside` "safe"): the "gone" face dropped him through 1.5 m short of the line, and a "slick" face slid him off its edge on his feet, where he caught the edge as a ledge and hung (1 run in 12). It never stands open now, so "drop through when it is open" becomes "the slot beside it is the way down; the leaf throws you into it". It flips every 3 s, so a body on it is thrown within 3.7 s, at any phase.
- **Seesaw (swapped to `trap_seesaw_drop`, the card's alternate).** The timed dropper fell on its own 4 s clock, so the hand-off depended on when he arrived. The drop's fuse plate is event-driven: lie on the far plate 0.5 s (`fuse`, the trap's 1.0) and the block falls, 0.95 s after he lands, while the fall still has him down (stunned throw, fresh poise). The seesaw lies along the wall, route west, and its far end butts a kerb (a stone stop, top flush with plate 3), so the tilt can't slide him off its end. Its `veer` (0.45, sideways) points south, away from the wall, over oculus 3: he goes up 2.2 m and comes down 6 m south, 1.9 m west, down oculus 3 onto the slabs. The launch is capped, so the throw is the same every time.
- **Slabs.** Oculus 4 (6 x 5.4 m) is all voussoirs, under where the throw comes down. He lands stunned (11 m), skids ~0.9 m, they go (0.13-0.4 s), he falls 8 m.
- **The head.** Plate 4 is 8 m over the foot, not 9: the head tells only if he is within reach x 0.8 = 8.5 m of its mouth when it first sees him (seen farther, it heaves after him instead, a 1.25 s act that blinds it). The slabs hide him until they go; the head sits at (-2.4, 6.7) facing south, square under the fall line, its mouth 0.3-0.9 m north of where he falls and its chin clear of it. It sees him the frame the slabs go, tells at once, and gulps him as he comes past its mouth (or the instant he lands, still down); it blasts him south out of rim S (the foot's south edge, z -4).

**Chains (headless, the real tick and motor, no input past the stated presses; jitter: start +-0.5 m, timing +-0.2 s; throwaway checks outside the repo):**
- **Combo 1, the whole column: 10/10**, and **20/20** over a sweep of the walk-off across 6 s (two leaf periods), so it doesn't depend on any trap's phase. Every run: leaf toss, seesaw fling, slabs, gulp, blast out of rim S, in that order. The head gulped him still stunned in 30/30 (mid-fall in 23); gulp 6-9 s after the walk-off.
- **Combo 2, threaded (scripted skill line): 10/10.** On the seesaw's fuse plate on his feet, take the fling (a plain toss: he keeps control), roll onto the slabs (no stun), fall with them steering south (out of the mouth's reach), roll at the foot, run out of rim S before the inhale. Never stunned, never gulped. Not scripted: the cap-to-seesaw part (run off the cap past the leaf, down the slot) and any sail.
- **Combo 3, the Olmec cannon: 10/10.** From station 8, no input: drawn, gulped 2.3-2.7 s in, blasted out of rim S.

**Stand-ins (labelled in the scene):** the plumb block is the seesaw's own block on its hook; windlass = a drum; daylight bar = a translucent column; one plumb wall, the other three sides open; the kerb is a plain box; the spine is a plain cylinder (kicks not tested); no E adit, no ports built.

**Knobs off the traps' defaults (in the TRAPS table):** leaf `count` 1, `length` 2.4, `width` 3.6, `underside` "safe", `period` 3.0; seesaw drop `fuse` 0.5, `hook` 3.6, `cap_mul` 1.0, `ledge` 0, `along` 0.15, `veer` 0.45; voussoirs `count` 3, `width` 5.96. The head is on its own knobs (only its stub route).

**Engine changes still wanted (none needed for these chains):**
- `inhaler_head.gd _pull`: `if m.feet.y > position.y+height*0.8: return` is meant for standing on the head, but it shuts its air (and its gulp) for any body above 2.7 m, wherever he is. A falling body can't be drawn across, so the catch is only as wide as the gulp reach (1.3 m), which is why the layout has to drop him at its mouth. Test "over its footprint" instead of height alone.
- `inhaler_head.gd _notice`: seen but beyond reach x 0.8, it heaves after him (1.25 s blind). That is why plate 4 is 8 m, not the card's 12 m. Letting it tell at sight range when he is above it (falling toward it) would free the plate height.
- A downed body barely moves under the pull (TUMBLE_SKID 14 m/s^2 against its air pull); a stunned body that lands 2 m off the mouth waits for him to stand.
- `trap_flip`: a pilot carried off a leaf's edge on his feet catches the edge as a ledge and hangs with no input (why the leaf isn't "slick"). Maybe a ledge on a moving trap should not be caught.
- Kit asks unchanged: a plumb block on a chain, a windlass, the shaft's ring wall and a daylight light piece.

**Not verified:** the sail steering a drop, ledge grabs round the lips, the wall-kick spine climb, the blast landing on a neighbour tier (only that he leaves rim S), cover behind the spine, and any look in a rendered capture. By the numbers, not run: a run off the cap at full pace carries past the leaf into the slot (onto the seesaw from 18 m, the leaf skipped), and a slow step off drops onto plate 2's rim beside the leaf (oculus 1 overhangs the leaf's pit by 0.5 m).
