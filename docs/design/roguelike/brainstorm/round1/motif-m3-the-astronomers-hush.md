# The Astronomer's Hush — "A head keeps the count of the stars; do not be a star it counts."
Lenses: verb = stay hidden; purpose = observatory; mood = sacred; scale = intimate; shape in a layer = a tight cluster.

Pitch: Four small isles huddle round a henge where the ruin-builders once counted the sky, and the thing that still counts it is an inhaler head, drifting its slow ring over the circle with its pale eye turned up. You arrive to nothing but its grinding turn, and cross the cluster from pillar to pillar a body's width outside its cone; the quiet is the whole motif.

Top (1 char ~ 4 m; the cluster is about 120 x 64 m):

```
 ^ north
 ..........................
 ..#C#...~~~~~~~~...#C#....      1 entry isle (rim ^ south-west)
 ..#3#--'~~ooooo~~'--#4#...      2 the Circle (hero): stone_circle + altar
 ..#C#...~~o @ o~~...#C#...      3 the Hall of Ties (hall bay, slab roof)
 ......'''~~ooooo~~'''.....      4 the Gallery (exit, rim ^ north-east)
 ....#1#---'.2222.'---.....      o the head's ring round the henge
 ....#C#...'.CCCC.'........      @ altar (the prize)
 ..........................      C cover (columns, drums, wall)
 ^ entry 1 SW, exit 4 NE         --- low links (ledge, stones, footbridge)
```

Side (looking east; 1 is lowest):

```
                           ____hall_slab roof (walked)____         4
        3  ##|col|col|##   ||                          ||      ###
 1     ###   ##########                  2 (henge)             ###
 ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  o~~~~~~~~~~~~o  ~~~~~~~~~~~~
 rim^                     head hovers a little over the turf
```
Heights over isle 1: isle 2 +2 m, isle 3 +4 m, isle 4 +7 m; a gentle spiral, each hop a ledge grab, a short glide or a footbridge.

Play:
1. Arrive on isle 1 at the rim. The head is across the henge, drifting its ring face-out over the gulf, never over the middle while it holds its ring. Its eye is dark; it is looking up. Binoculars show its pace. Nothing happens, and that is the tell.
2. The head's pull needs a clear line from its mouth to your chest and its cone is narrow, so you go behind stone. First sprint between two toppled drums (hall_column on its side) on the far half of its lap, a slide under a leaning hall_beam, a ledge grab up isle 2's low wall. Move on its blind half-lap, hold still behind a column on its near half-lap and listen to the grind turn.
3. On the Circle the stone_circle's uprights are the only cover on open turf. The altar in the middle (tomb_chest on a floor plinth) is the prize. Three strides in the cone's edge: wait behind an upright, count its turn, dash, crouch to brace if it notices (crouched, you hold against the pull).
4. The Hall of Ties (isle 3): a hall_bay on a plinth, columns two abreast, hall_slab laid across as a roof. Inside you are in the dim and the head can only look in at the door. Up a buttress, mantle onto the slab roof, run its length.
5. The exit is isle 4, 3 m higher across a gap. Pocket-sail it quietly, or the bold way: stand in the cone on the Circle's rim facing the head on purpose. It tells, inhales, swallows, and blasts you out along its face. Its face points at isle 4 only at one point of its lap; wrong lap, the blast is the gulf (a sail may save you).

Threat: One inhaler head (scripts/enemies/inhaler_head.gd), its `route` a ring round the henge, `sight` short and `sight_half` narrow so cover is a real answer. It belongs here: the henge's keeper, still doing its old job of watching the sky. Also a tool: its pull is blocked by pillar, wall or chest of stone, and its blast is the launch to the exit.

Combos (the goal is to stay unseen, so the best chains end in cover or in the quiet):
1. Accident, hurled into cover: a creep fails, the head notices, pulls, swallows (`seize`), holds, then blasts (`knock`, source = the head) along its face: stunned and ragdolled, you land on the hall's slab roof (isle 3's walked top, +4 m, under the fall-stun threshold), laid down for `tumble_down`, and roll off its low edge through the hall_bay's door into the dark. The head loses you (nothing between you and its mouth now but stone). The punishment ends in the best hiding place on the cluster. Wrong lap: the blast faces the gulf and you pay in height (a sail, if poise returns in time).
2. On purpose, the Odyssey line: stand on the Circle's rim in its cone at the lap point where its face aims at isle 4; take the swallow; blast (knock, stunned, fresh poise) over the gap; poise returns mid-air (about 0.8 s) so sail the last metres, or tech (twirl armed) into isle 4's wall for a wall kick onto its ledge. Head blast, tech, wall kick, ledge: one lap skipped.
3. Noisy, wakes the watcher: a flow-charge slam off the slab roof onto the Circle rings the world (the slam's ring) and the head turns its whole ring toward it and starts a run of fast laps. A cannon or seesaw shot into the cluster does the same. Used on purpose, a slam on isle 2 draws the head's face to isle 2 while you are already crossing isle 4's blind side: a decoy bought with a drop.
Ports:
- Catches: a body thrown in from a neighbouring isle (cannon, seesaw launch, the dragon's gust) lands best on the slab roof (wide, flat, walked, +4 m), the safest stunned landing on the cluster; one arriving over the Circle is drawn by `air_pull` toward the mouth (a jump near it is a mistake) and is swallowed mid-air.
- Throws: the head's blast along its face at isle 4's north-east rim (a stunned body, about 8 m/s out, peaking a few metres up), once per lap; a second face-point throws toward the south-east rim, back to a lower neighbour, so the generator can aim another motif at either rim.

Mystery: The Circle is a calendar. The uprights are notched where the sun and one star climb; the altar holds a shallow bowl that never held water. The head's eye is lit only when it notices you; the rest of the time it faces up. So the player works out it was a reader of the sky, not a guard of the stones, and that one notch lines up with the dragon's roost on the ledger map: they counted him too.

Kit used (each id verified in scripts/ruin_kit.gd FAMILIES):
- stone_circle (gothic): the henge on isle 2
- hall_column, hall_beam, hall_slab, hall_bay (hall): cover pillars, the hall on isle 3, the walked slab roof
- tomb_chest, floor, fallen_pier, buttress, stairs, wall (gothic): altar, plinth, rubble cover, climbing routes
- foot pieces: footbridge (scripts/footbridge.gd) between isles, floating and bob stones to isle 4
- optional cannon (scripts/cannon/cannon.gd) on a neighbouring isle as the outside thrower for the ports
- enemy: inhaler_head (scripts/enemies/inhaler_head.gd), unchanged

Kit asks:
- A tall notched menhir or gnomon pair (cover that also reads as an instrument).
- Check the head's `route` can be a closed ring about a point; if not, a ring-route helper.
- A low grind loop on the head so its turn is heard from behind cover (an audio asset).

Family knobs:
- `cover_density`: sparse / medium / dense (columns per isle)
- `ring_radius`: tight (head over the cluster) / wide (round it)
- `altar_exposure`: sheltered / half-open / open (strides in the cone)
- `exit`: sail / blast / climb

Sockets:
- rim: isle 1 south-west and isle 4 north-east, both facing out; optional third on isle 3
- arena: the Circle's turf, room about one isle (the head's ring)
- cover: column groups, the hall bay and its slab roof, toppled drums (roofed stone only; open turf is not cover from above)
- perch: the altar steps (a quiet trader)

Generator fit: role "arena" (hide-or-fight isle) or "hero" in a small layer. Footprint about 120 x 64 m with all four isles; height span about 10 m. Suits a tight cluster where the route funnels.

Distinct from: broken_ring (a stone circle you climb round a turret) and bell_spires (loud, tall): the Hush's circle is a floor, the verb is not being seen, and the whole cluster is low and silent. Not colonnade_spine, where columns are a corridor; here they are cover.

## Greybox (Opus pass)

First build (Sonnet, round 1): the hall flush with the Circle, its slab roof at +3.5 as the blast's landing (a narrow band: a few metres off and you hit its face or sailed under), the apron at +2.0, no decoy (the head can't hear).

Run: `godot --path . res://studies/greybox/astronomers_hush.tscn -- --no-title` (R start, F1 numbers and where the last blast left you, `--head-knob=<knob>=<v>`, `--no-tech`). Script `studies/greybox/astronomers_hush.gd`; the whole layout is still the one `LAYOUT` table at its top.

Stations: 1 start (isle 1) · 2 beat 1 the lip onto the Circle · 3 beat 2 the drum lane, west rim · 4 beat 3 the altar · 5 beat 4 the north rim · 6 beat 5 the hall's roof (+0.8) · 7 beat 6 in the hall (-1.0) · 8 exit gallery (+4.8) · 9 CHAIN 1 · 0 CHAIN 2 · - CHAIN 3 (on the sun gnomon) · = the apron. Chain stations set the head at the lap point the chain needs.

What I rearranged, and why:
- **A low catch round the north and east.** A blast carries a fixed ~17 m from the head (about 10 m of flight peaking 2.5 m up, then a 6 m skid) along its line to you. So the catch must be *below* the Circle, never above it: a terrace at +0.8, 1 m under the Circle's rim, runs round the whole north (isle 3) and east (isle 4's apron, flush with it). A body thrown over the rim lands on it from any lap point; one that lands short skids off the rim onto it. The head can't drop 1 m (its `drop` is 0.84), so it can't follow you down.
- **The hall sunk under the terrace.** Its slab roof is flush with the terrace (it is the catch's middle), its floor at -1.0 (1.6 m inside), its door down a stairwell on the north side, out of every line from the Circle. Gone: the back kerb, the buttress, the bench and the 3 m roof-to-bench jump.
- **Isle 4 rebuilt as apron (+0.8), ledge (+2.8), gallery (+4.8)**, 2 m lips between (grab height). The exit is still the highest.
- **Isle 1 wraps the Circle's west and south sides**, so a throw off the west or south rim lands back on the entry terrace, not the gulf. The south-east corner stays open as the port rim to a lower neighbour; the north-west corner between isles 1 and 3 is a gap, kept so isle 1 to isle 3 can't skip the Circle.
- **The decoy is sight.** The head turns to watch only you, and pulls nothing above 0.8 of its height (2.7 m over its turf). So the sun gnomon (and a star gnomon east, the same lure) stands 3.2 m tall outside the ring, with a 1.2 m step and a 2 m grab on its far side. Stand on its top in the head's sight: it notices, rears (1.8 s tell), inhales at you for 3.5 s and can't pull, then slumps blind (`after`, 3.5 s, its eyes going dark). That slump is the window: drop off the north-west and run the drum lane (two drums along the west rim at x -14.8, out of its line from the south-west arc) to the hall's terrace. You are the star it counts.
- **The ring has look-ins** (corners alternately r 10 and r 8). On each inward leg its face swings in across the uprights and out again, so its gaze sweeps the Circle every ~25 s instead of only skimming the edge.
- **Pace knobs** (in `head_knobs`): rest 0.1-0.35 s, pant 0.6 s, sags 0.1, heave 0.85. The default round-2 head laps the 10 m ring in about 237 s (measured); this one in about 152 s.
- The beam (slide under) moved to the south-west entry, out of the lane. The tech is on in this greybox (the motor has it off by default; `--no-tech` turns it off).

Chains (headless, through the real motor, head and physics; start ±0.5 m, timing +0..0.4 s, head lap point jittered):
- **Chain 1, caught on the north rim, thrown onto the hall's roof: 10/10.** Pilot standing in the open at (-1,-13), head at 300° ±12°: it notices, tells, inhales, swallows and blasts him onto the terrace at about (5..11, -21..-24), up on his feet there, the hall door one stairwell away. Across the whole arc where it can catch him there (280-330°, 3 each), 21/21. At 270° it tells but can't reach him.
- **Chain 2, the Odyssey line to the apron: 10/10.** Pilot at (12,-4), head at 20° ±12°: blasted east onto the apron at about (22..24, 1..4), at the foot of the ledges to the exit. With the tech (twirl about 0.1 s before the first touch), 9/10: he rolls up on the Circle's rim with no time down and runs on off it onto the apron. In the tenth trial the head never caught him.
- **Chain 3, the star it counts: 10/10** (lured 10/10, crossed unseen 10/10; 40/40 over four seeds). Going within 1.9 s of the slump's start it holds 10/10; at 2.0-2.4 s late, 6/10; later than that, 0/10. The same run without the lure (from the gnomon's foot): 0/10, seen within a second.
- **Catch map** (standing in the open on a 4 m grid of the Circle × every 30° of the lap): 20 catches. 11 landed on the north or east catch, 6 back on isle 1, 3 in the gulf (the north-west corner gap and the south-east port).

Is a ring that slow still tense? Not as a patrol. At ~4 min a lap you'd wait it out, and the head acts like a lighthouse on the far side. The tension has to come from its gaze: the grinding notch-turns you hear, the look-ins sweeping across the uprights, and its being on the side of the Circle you need. With the pace knobs (~2.5 min) and the look-ins it should read as busy, but that needs judging by hand. What I'd change next: let it stop at the inner corners and stare at the altar for 2-3 s ("counting"), a dwell the head's `route` can't express yet (engine, below). Or shrink the ring to about 8 m once the uprights move in.

Stand-ins (labelled in the scene): the uprights and altar, the drums and beam, the catch terraces, the hall (slab, columns, stair ramp), the gnomon pair, isle 4's tiers.

Engine changes still needed (not made):
- **Ears for the head**, for the card's slam decoy and a cannon shot into the cluster. Add `hear(at: Vector3)` to `scripts/enemies/inhaler_head.gd`: in `scoot` (not `after`), notch toward `at` and hold that facing for a `heard_hold` s before going back to its route, with no tell unless it then sees you. Call it from `scripts/enemies/enemy_field.gd` when the study's `slam` reports its ring (and from any `field.sound` tagged loud). The sight lure stands in for it here.
- **A dwell on a route point** (`route` entries with a rest, e.g. `[point, seconds]`), for the counting look-ins.
- The sail after a blast doesn't happen. Poise after a blast is about 1.2 s (`poise + poise_hit × 17 m/s`) and the flight is about 0.8 s, so it never returns in the air. The card's "sail the last metres" needs a higher `blast_up` (a head knob, local) or a lower `poise_hit` (engine).

Changed from the card: the cluster is about 86 × 64 m. Heights are isle 1 0, the Circle +1.8, the hall's terrace +0.8 (the hall floor -1.0), the gallery +4.8, so the hall sits *below* the Circle. The head faces the way it goes, and its ring is on the Circle only. The decoy is sight, not sound.

Existing tests: none reference this greybox, so none break.

Not verified (headless can't): climbing the gnomon by hand (1.2 m step, 2 m grab), the slide under the beam, the stairwell into the hall door, the 2 m lips up to the gallery, how readable the slump cue is (jaw shut, eyes dimming), and whether the look-in pace feels tense.
