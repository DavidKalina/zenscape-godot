# The Vigil of the Bellows — "The horn still blows at anything that moves; learn to be a stone."
Lenses: verb = stay hidden; purpose = observatory; mood = sacred; scale = intimate; shape in a layer = a tight cluster.

Pitch: A small cloister garth round a still pool, with the star-watchers' tower standing over it and a wind-horn on its roof that still turns to blow at anything that moves below. You arrive on a rope bridge into its blind side, and cross the court in the horn's pauses, because its breath is an old prayer and it never learned to forgive.

Top (1 char ~ 4 m; about 36 x 36 m for the mother, satellites beyond):

```
 ^ north
 ......................
 ..##C##|T|##C##.......      T tower_shell (observatory tube, wall-kick shaft)
 ..#...H|||H...#...1...      H wind_horn on the tower roof (over the garth)
 ..#..~~~~~~~..#---'          ~ the still pool
 ..C..~~@~~~..C......        @ lavabo pavilion on its isle in the pool
 ..#..~~~~~~~..#...          o dart lanes under the horn's cone
 ..##C##.....##C##..         C cover (arcade piers, wall-walk, chests)
 ..2---'.rim^..'---3         1,2,3 satellites on rope bridges
 ^ entry 2 SW, exit via the tower to 1 NE
```

Side (looking north into the garth):

```
                      H  wind_horn  (+14 m)
                    ##|##   tower_shell, kick shaft
   ################  | |  ################  arcade wall-walk (+4.5 m)
   #  #  #  #  #  #  #o#  #  #  #  #  #  #    arcade bays: cover
 ~~~~~~~~~~~[lavabo]~~~~~~~~~~~~  the pool
```

Play:
1. Arrive on satellite 2. Binoculars: the horn turns slowly on the tower, scorch rings on the turf mark its reach, dust trickles from its chest. The bridge you cross is a live rope bridge (scripts/rope_bridge.gd); a bridge swinging hard is a bridge that gets looked at, so cross it steadily, a stop-and-go walk.
2. The arcade (range_run, seven bays) is the hiding gallery: in a bay you are under stone, between bays there is open air. Count the horn's turn, slip bay to bay. The wall-walk above is faster but fully exposed: the greedy line.
3. The garth's middle is the pool and the lavabo pavilion (pavilion) with the prize. Wading is slow and loud and the horn turns to the sound; the quiet way is across fallen blocks (heap) laid as stepping stones, one beat of exposure each, slide or twirl-hop between.
4. The exit is the tower itself: in at the pointed door (tower_shell), jump at a side wall, wall-kick up the shaft to the breach in the torn back wall and a sill under the horn's lip. The horn's barrel pitches down only a little, so under its lip is the one place it cannot reach. It is also the place you must be quick to get to.
5. The bold line: stand in the cone and take the breath. The gust slides you toward the rim; with the right facing it sends you across the garth to the north-east satellite's bridge-head, skipping the court.

Threat: The wind-horn (scripts/ruin_kit_horn.gd, runtime scripts/wind_horn.gd), set to track a pilot who moves and fire after its tell, shoving him along the ground toward a rim (the force of scripts/traps/trap_wind.gd). It belongs: the star-watchers built it to keep the dragon off their lens, and it keeps blowing at shadows. Also a tool: the gust launches you across the court; a pier or arcade stone takes it; and the horn has `disabled(seconds)` (slumped, mouth tipped down), so a way to knock it out (the bell-style hit from below, a thrown rune, the plane's pass) opens a short window to cross in the open.

Combos (the goal is to stay unseen, so the best chains throw you into cover or out of reach):
1. Accident, hurled into cover: a splash in the pool turns the horn; it draws its breath (the tell), fires, and its gust (a `knock`, source = the horn) throws you stunned across the garth onto the arcade wall-walk (+4.5 m, under the fall-stun threshold). You are laid down on the open walk but the horn's pitch cannot drop below the arcade's top, so you roll off its inner edge into a bay, under stone. Noise cost you a stun and bought you the hiding place.
2. On purpose, the gust line: stand on the pool apron on the line to the tower and take the gust with the twirl armed (tech on); you cross the garth stunned, tech into the tower's east kick wall (wall jump, control back), then wall-kick up the shaft to the sill under the horn's lip, where it cannot point. Gust, tech, kick-shaft, sill: the whole garth skipped, and you are in the one spot the horn can't see.
3. Noisy chain that wakes the watcher: hit satellite 3's seesaw (an existing trap) from the rope bridge's head and its launch is a `toss` over the arcade; the airborne body is the horn's best target, so it fires mid-air and the gust tosses you on, still stunned, toward the north-east rim and satellite 1 (hands off to whatever motif sits there). Ridden well it is a shortcut; ridden badly the gust sends you into the pool (a swim, no fall stun) in full view.
Ports:
- Catches: a body thrown from the south-west satellite (a cannon or seesaw shot, the dragon's gust) lands on the arcade wall-walk, flat and wide; a body arriving low falls into the pool and wades out, noisily. A tumbling body on a rope bridge is carried with it; the horn shoves the bridge too.
- Throws: the horn's gust along the garth at the north-east rim (satellite 1's bridge head) when you stand south-west of the tower, and back at the south-west rim from the north side; blast height is low, so it chains into a glide or a footbridge, not a flight.

Mystery: The tower is an observatory: slit windows for each season's star and a shaft aimed straight up. The pool is the instrument's mirror: from the lavabo you see the tower's slit reflected, and in it a star. Carvings on the wall-walk show a serpent-shaped hole in the sky. So the horn was never a trap: it is a ward, the dragon has been hunting this tower for ages, and the player starts to see the dragon as a thing the builders feared, not a monster.

Kit used (ids verified):
- tower_shell (ruin_kit_tower.gd), wind_horn (ruin_kit_horn.gd, with Rig, Head, Barrel, Mouth)
- ruin_kit_cloister.gd: range_run (arcade ranges), pavilion (lavabo), heap (fallen blocks), slab_bridge
- gothic: pier, arch, wall, buttress, stairs, tomb_chest, fallen_pier
- traps: trap_seesaw (scripts/traps/trap_seesaw.gd) on satellite 3, for combo 3
- foot pieces: rope bridge (scripts/rope_bridge.gd, scripts/footbridge.gd), floating stones; pool water from scripts/kit_isle/kit_water.gd

Kit asks:
- A slit-window or oculus roof insert for tower_shell so the observatory reads.
- A corbel course on tower_shell, a named safe sill under the horn.
- Ear-flap and rune-groove dressing on the horn so it sits beside the Olmec.
- An audible, visible horn pause pattern (its tell as a long inhale) the generator can set per seed.

Family knobs:
- `horn_count`: one on the tower / two (a second on an arcade corner)
- `pool`: still (wading is loud) / reeds (slower, noisier) / dry (a sunken court)
- `arcade_gaps`: bays fallen, 0 / 1 / 2 (more open air to cross)
- `exit`: tower (kick shaft) / bridge (rope) / blast (ride the gust)

Sockets:
- rim: satellite 2 south-west (entry) and satellite 1 north-east (exit), facing out; optional east rim
- arena: the garth's apron round the pool (the horn's cone), room about 12 m
- cover: arcade bays, pier groups, tower door and base, tomb chests (a roofless garth is not cover from the sky)
- perch: the lavabo steps (a quiet trader)

Generator fit: role "hero" for a small layer or "filler" for a mid-height stretch. Footprint about 60 x 60 m with satellites, height span about 18 m (pool to the horn). Suits a tight cluster whose way up is a kick shaft, not a stair.

Distinct from: cloister_tarn (the same garth-and-tarn bones, but that is a scenic with a lodestone and a ring of islets; this is a stealth gauntlet with a live ward and a vertical exit) and bell_spires (there the bell is rung for noise; here noise is punished: the verb reversed).

## Greybox (Opus pass)

Round 1 (Sonnet) had one roof horn with a stand-in pitch of 1.0 rad and a 24 m / 3 m scripted gust. Chain 2 needed a second horn on the arcade. Chain 1 landed in a bay, not on the wall-walk. Chain 3 threw you off the map.

Run: `godot --path . res://studies/greybox/vigil_bellows.tscn -- --no-title` (`--gust-out=` / `--gust-up=` override the blow; `--no-tech` turns the tech off; it is on here for chain 2). Files: `studies/greybox/vigil_bellows.gd` / `.tscn`. The whole layout is in the const tables at the top (ISLES, POOL, RAMPS, BOXES, POSTS, RANGES, HORNS, TRAPS, LABELS, STATION_ROWS), ready for the turf pass.

**Stations:** 1 start (W satellite) · 2 west bays · 3 pool stones · 4 tower shaft · 5 the sill · 6 chain 1 · 7 chain 2 · 8 chain 3 · 9 chain 4 · 0 the wall-walk · - the lavabo. Keys: H gate horn, J tower horn, K knock both out 6 s (STAND-IN for the bell hit), F1 numbers.

**The shape now.** Two horns face each other across a 44 x 36 m garth and share one bellows. Each watches the far half and blows it away from itself.
- **The tower horn** stands on a corbel over the sill (north). With the real 0.3 rad pitch it can't reach anything within about 19 m, so it watches the court's middle (arc ±32°, range 32 m) and blows it south into the south bays.
- **The gate horn** stands on a 7 m gate tower in the south range (arc ±90°, range 36 m). It watches the north half and blows it north: into the NW/NE bays, into the tower's kick shaft, or out through the fallen NE corner to satellite 1.
- **Blind spots:** the south apron is under both horns' lips. A blind band runs across the middle by the lavabo. The bays (roofed, 4 m deep) hide you from both horns.
- **Ranges:** four arcade ranges with 4.5 m back walls (the south one is the 2.4 m wall-walk), so a gust inside the garth stops in a bay, not over the rim. The pool is off-centre to the west, with beaches north and south, so a gusted body skids out.
- **Catches:** the NE corner is fallen open onto a wide bridge-head deck and satellite 1. A 1.2 m-lower NE scree catches what the corner spills north. Satellite 1's south arm is the east rim. The south terrace (satellite 3, -3 m) holds the seesaw and catches the wall-walk.
- **The shaft:** 2.8 x 6 m, open south under a 2.2 m lintel, so the climb is out of the gate horn's sight. The sill sits behind a parapet under the tower horn. A slab bridge (STAND-IN) runs from the sill down to satellite 1.

**What I rearranged and why:**
- **Pitch.** I dropped the deep-pitch stand-in. With the real PITCH_DOWN, a roof horn reaches only far ground, so a second, lower gate horn is the one that can point at the north half.
- **Chain 2.** A gust goes away from its horn, so the horn that throws you into the tower must stand south of it. The gate horn does.
- **Gust size.** The gust is now the blaster's knock: 14.4 m in all, peak 1.2 m, of which 7.6 m is flight and the rest skid. That is too short and too low for the wall-walk, so chain 1 now aims at the NW bays and lands under stone.
- **Bays.** Every range was given a back wall so no garth gust leaves the map. The NE corner and the scree were opened as the one way out.
- **Seesaw.** Moved east of the gate tower, so the body passes the gate horn and is blown on toward the NE.
- **Lavabo.** Now one central pier: its corner posts shadowed the chain 1 spot from the gate horn.
- **Tower horn.** Moved 2.5 m south on a longer corbel so the whole sill is under its lip (it was gusting climbers off the sill's front).

**Chains** (headless, real motor and tick, 10 runs per seed, start ±0.5 m, timing 0-0.4 s, seeds 11 and 7):
- **Chain 1, splash into cover: 20/20.** Wade at station 6; the gate horn hears the splash, turns, tells, blows; you skid out over the north beach into the NW bay, out of both horns' reach.
- **Chain 2, gust into the kick shaft: 20/20 from the apron, 20/20 with the air tech.** From the north apron (station 7, hop to wake it) you are skidded into the shaft, get up and wall-kick to the sill (kicks 3-5). From the shaft mouth (z -11.2) the flight still reaches the back wall: tech off it, kick up. The tech only works in the air (the motor's wall tech is airborne only), so the tech variant must stand within about 7 m of the back wall. The card's "cross the garth, then tech" is not possible on a 7.6 m flight.
- **Chain 3, seesaw then mid-air gust: 20/20 lead on** (16 on satellite 1 or the bridge head, 4 in the NE corner). **Sailing on: 17/20.** The 3 misses were hit low (about 5 m up), and poise (about 1.1 s) does not come back before landing.
- **Chain 4, gust line out the NE corner: 20/20.** Hop at station 9; you are thrown through the fallen corner onto the bridge head.
- **Every gust leads on:** hop at 79 garth points; 0 lost. Each gust lands you in a bay, the pool, the shaft or tower foot, the NE corner or scree, satellite 1, or in front of the gate tower.
- **Stealth:** creeping under 0.8 m/s crosses the north half, the court's middle and the south apron unnoticed. Running there is gusted within 0.6-1.0 s. Running through the west bays, on the sill, on the wall-walk and over the arrival bridge draws no gust.

**Stand-ins (labelled in the script):**
- **The blow itself.** The horn's Rig only dresses. The study fires the wind blaster's own knock, with values read live from `trap_wind_blaster.gd`'s knobs: delay 0.5 s, blast_time 0.3 s, rearm 2.0 s, blast_out run x 3 = 14.4 m, blast_up run x 0.25 = 1.2 m. It goes along the barrel's flat facing, once per blow, with the horn node as the source.
- **The wake rule.** A ground mover over 0.8 m/s is seen within ±0.6 rad of where the horn looks. A splash or a body in the air is heard anywhere in its arc.
- **The rest:** the idle sweep, the yaw arc, the shared bellows, rope bridges as plain decks, the slab bridge, no slit windows or corbel dressing.

**Engine changes still needed:**
1. **The blow.** `scripts/wind_horn.gd` (or a `trap_wind_horn.gd` wrapping RuinKitHorn) needs `blast_out`, `blast_up`, `delay`, `blast_time` and `rearm` knobs. Default them as in `trap_wind.gd` defaults(): run x 3.0, run x 0.25, 0.5, 0.3, 2.0. In its blow window, the first frame the pilot's chest is within 0.25 rad of `Mouth` basis.z and in range, it calls `motor.knock(motor.knock_velocity(Vector2(f.x,f.z).normalized(), blast_out, blast_up), horn)`. Best done by lifting `trap_wind.gd` `_blast`'s knock into one shared helper that both call. The blaster's swimmer skip should be dropped for the horn: chain 1 hits a swimmer, because the pool's 0.6 m sets `swimming`.
2. **A wake rule on the horn**, as the stand-in above, with the real PITCH_DOWN and LOS.
3. **A yaw arc on the Rig** (`yaw_arc`, clamping `yaw` in `aim_at`). A horn set into a wall can't turn behind itself.
4. **Unchanged:** PITCH_DOWN (0.3) stays. The layout now works with it, and it is what makes "under its lip" real.

The shared bellows is the motif's own logic, not an engine change. `motor.tech` is on in this study only.
