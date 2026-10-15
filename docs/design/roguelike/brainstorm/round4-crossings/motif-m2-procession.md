# The Procession — "They were halfway over when the road went out from under them."
Lenses: Verb = stay hidden / time a crossing; Scale = colossal; Decay = frozen mid-ritual, half-collapsed; Mood = quiet, sacred, then wrong; Twist = an Olmec piece as terrain, the threat as the only way across (round 4 contrarian: the Olmecs ARE the crossing).

Pitch: Across a gulf too wide for any jump, a line of headless Olmec bodies lies toppled face-down along the road they were walking, each wedged against the next like fallen dominoes, and their backs are the bridge. You cross on the shoulders of the giants in near-silence, because one of them is only pretending.

Place: A gulf of about 110 m between a high, rune-cut arrival terrace and a low far isle that carries a lit gate (a single cresset; the one warm point in the haze). The old causeway (city_causeway) that joined them has fallen almost entirely; only its piers (city_pillar stumps) and the odd beam stub still stand, in a line, going down into the haze. The procession was crossing it when it went: eleven colossal bodies (3.9 m across, 2.2 m deep, 6.7 m to the neck: headless_body's own numbers) toppled forward, one after another, and each fell onto the heels of the one ahead and stayed, hands braced on the calves in front, a long sawtooth of backs tilted about 14 degrees, stepping down about 1 m at every joint where one back ends and the next begins. The silhouette from the arrival terrace is a stone spine of shoulders and heels running out into fog, each back a long dark whaleback with a lichen-pale shoulder blade, no heads anywhere: just the cut neck stumps, each with a seat for a head that is not there. Under the line, the old piers rise to meet the bodies' bellies like trestles. Same weathered basalt as the Olmec (shaders/olmec_stone.gdshader), the rune grooves worn along their spines. Moss and a few pale ferns have taken the hollows between shoulder blades. The first thing you see on arrival is the length of it, and the far gate small and yellow at the end. The second thing: they are all lying in the same direction. The third, if you look, is that the sixth one's back rises and falls.

Top (1 char ~ 4 m; line runs west to east, 110 m is ~28 chars):
```
  ^^^^^^^^                                        
  ^ A    ^   ===1==2==3==4==5==6==7==8==9==X==Y   
  ^  P   ^~~~~~~~#####################~~~~~~~~~~ 0@
  ^^^^^^^^   .   piers 'o' under each joint   .    
              (~ gulf below, fog; the line is drawn as ======)
```
1..9, X, Y: the eleven bodies, head toward the far gate; 6 is the live one; 0 the far isle; @ the cresset gate; A arrival terrace (arena for a lone watcher), P perch (a broken pier top to look from).

Side (1 char ~ 4 m wide, 2 m tall):
```
 arrival +12                                       
 ####\                                             
 ####  \__/\__/\__/\__/\__/\__/\__/\__/\__/\__     far isle 0
 ####   | |  | |  | |  | |  | |  | |  | |  |  \____####
 ####   piers (city_pillar stumps) down into haze      ####
 sawtooth: each back tilted 14 deg, 1 m step down at every joint
```
About 12 m drop over 110 m (an easy long run), the joints are 1 m steps, the steps with a gap are 2.5 to 4.5 m.

Play:
- Route A (the quiet crossing, the intended one). From the arrival terrace, step onto the first back by the low shoulder (the first body's feet are a mantle: its heel rests 1.6 m below the terrace lip, a short drop, noise ~ 15 m at landing; crouch pressed low before the touch x0.6, per noise-stealth-round1). Then walk. WALK 2.4 m/s over 110 m is about 46 s of footfalls at about 4 m of noise; at a sneak under 0.45 of run speed, 1 to 1.5 m. Every joint is a 1 m step down (a small step: STEP_UP 0.45 means steps down are free; it is a drop, not a jump) and every third joint is a real gap where one body rested its hands not on the calves but on the air: 2.5 to 4.5 m. A standing long jump covers it; the landing is the loud part. The choice is where to jump, and from what speed: a crouch-to-land costs a beat; a run and a chain lands quicker and carries 14 to 30 m to the sixth.
- Route B (the loud run). Slide down the first back's tilt (a 14 degree whaleback is a slide lane, Shift/C at a run), long-jump the gaps (LONG_SPEED 7.6 m/s, gap catch at a 1 m drop far over 4.5 m), twirl at the peak to carry the long one. All eleven backs in about 25 s. The sixth hears the first landing and rises while you are still on the fifth; you cross over it as it stands up, and that is the point.
- Route C (the underhang). Drop between the first and second bodies onto the pier stumps and work along the old causeway's beam stubs and the bodies' own forearms (each arm is a rail 3.3 m long you can slide, since the arms lie along the calves of the next) under the line, ledge grab and chain (GRAB_TOP 1.875) pier to pier: slower, in shadow, never above the sixth's ears; but it is the only route where the live body's rise throws the whole line above you and the stone starts to move overhead. Quiet, but a wrong move is a fall into the haze (the pier tops are 3 to 5 m apart under each joint).

Threat: The sixth body is a real headless_body (scripts/enemies/headless_body.gd), asleep in the line with the same lichen and the same cut stump as its kin. Its ear is the noise bus: set `hear` low (knob) so only a run, a hard landing (5 + 6 a metre fallen) or a slam carries to it; a walk does not. It does not hunt while the crossing is quiet. When it rises (hearing a landing nearby, or the player standing on its back for more than a few seconds at all, since a nearer body feels more), the whole line moves: it plants its hands, the bodies that rested on it ride up and settle, the joints on either side shift 1 to 2 m, and the back you stand on tilts and lurches. Then it stands to its full height, 6.7 m neck, and the crossing is a body-length of thick stone in front of you and behind you: run for the gate. It is also the tool: it can swat or shock you (`swat_out`, `shock_*` knobs) across the gulf; a toss from its shock lands you three or four bodies ahead, stunned, and the nine bodies still lying are a long soft floor. The clever player wakes it on purpose from the fifth, using noise, and crosses as it walks away, using its back as the bridge it has just vacated (the others stay, the line has a hole it left).
Could combo: the sixth's landing shockwave (`_shock`, olmec_land noise) tosses you forward into the seventh's back (stunned, an easy hand-off); a slam from the player near the eighth (noise 30+) turns its head: it looks at the wrong spot while you slide past it. With the underhang, the rise of the sixth drops you from a pier into a thrown fall (down), onto the beam stub three joints down. Ports: it catches a body thrown from the arrival terrace (a launched ragdoll lands on one of the backs and does not roll off, the tilt is 14 degrees, under the slide lane's threshold in the stun case) and it throws forward (toward the far isle) because the Olmec faces the gate.
Mystery: Eleven bodies, one direction, no heads, and the hands of each braced on the next as in a drill or a prayer: a procession in a ritual crossing, not a stampede. Their heads were taken before they fell (the neck stumps are cut, with a head seat) or flew; the far gate is where the heads wait (the hovering inhaler heads, elsewhere in the layer). The live one may be the only one who still has the order to arrive.

Kit used: city_causeway (the old road's beam stubs, dressing), city_pillar (the stump piers under the joints), maker_felled and colossus_drum (as dressing: broken drums, rubble in the gulf), city_lip (arrival lip), city_riser (the far isle's way up to the gate), city_slotwall (cover at the far gate), city_mouserun (a walker-only niche on the far isle so a hunted pilot has a place to be lost), headless_body (scripts/enemies/headless_body.gd), the noise bus (scripts/noise/noise_bus.gd).
Kit asks:
- A toppled body piece (proposed `maker_toppled`, family breaks): a lying headless body as a static terrace of backs, with the cut neck seat, clean back collision (a 14 degree tilt is a lane, no snag), arms as rails, and a swap for the live one (the same mesh, replaced by the headless_body when it rises). Without it the body cannot be both bridge and enemy.
- A `rouse` state in headless_body (lying, then stands) with its own clip; today it only starts upright.
- A joint filler (hands braced on calves) so the sawtooth reads as one giant mass, not eleven.
Family knobs: `bodies` 7 to 12 (the length, 70 to 130 m); `live` which one (2 to bodies-2; or 2 when the tuning wants a nasty one); `gap_every` 2 to 4 (how often the joints are real gaps); `tilt` 8 to 18 degrees (more tilt, more slide); `ear` the live one's hearing, 0.4 (a run wakes it) to 1.2 (a walk does).
Sockets: rims at the arrival terrace (east-facing) and the far isle (west-facing, at the gate); arena: the arrival terrace (small, the watcher's), the far isle's gate yard; cover: the pier stumps under the line (a dark underside route), the far isle's slot wall; perch: the broken pier top 12 m back from the first body (to see the length and to see the sixth's back breathe).
Generator fit: a motif with its own two shores, role "crossing set piece" (a sparse isle, two ends) at a layer's mid-point; footprint ~ 120 m by 24 m, drop about 12 m (arrival high, far isle low); it suits a spread, line-shaped layer in the city world ("under") and not the sky. A cheaper variant (7 bodies, 70 m) works as an edge between two places in a layer: its plan would carry `bodies` instead of the plain column-top stones of scripts/roguelike/city_crossings.gd, a rare edge that replaces the stones.
Distinct from: serpent_crossing (a rune serpent that carries you; here the thing is still, and the danger is waking it); felled_colonnade (one column you fell on purpose; here the bridge is already fallen and may already be awake) and the Broken Viaduct (a pure-skill route over a built structure; here the structure is a body, and silence is a verb).

## Place (round 4)

**Yard:** `python3 tools/smoke.py studies/motif_yard.tscn -- --motif=procession` (PASS). For a look: `--underground=haze`. Add `--no-sleeper` to cross without the threat. Code: `scripts/kit_isle/greybox/gb_procession.gd` (one LAYOUT table), registry `procession` (WORLD "under"). Stills: `captures/shots/proc/v7_{three,terrace,side}.png`; on a back with the play camera, `v7_game_fifth.png`; reference `ref_lamp_three.png`.

**The place.**
- **A (arrival):** a turf headland about 73 x 60 m. It rises west in a long slope and a broken rock band, with knolls, to the rim in (+9 m).
  - Where the procession set out: rune-cut treads sunk in the turf up the slope, a broken balustrade on the south lip, two leaning stelae at the tip, the causeway's abutment.
  - The perch is a broken pier with a fallen block for a step.
- **The line:** eleven lying bodies over 116 m (A's lip to F's lip). It bows north across the terrace's view: heading +22°, turning -3.5° a body.
  - **Bodies 1.45x headless_body's real size,** so they read as colossal from the rim. The live stand-in stays real size.
  - Each is tilted 15° head-up. Each back is one carved mass: a mantle over the model's block back, with a spine groove, raised shoulder blades and the cut neck stump facing the walker.
  - Every joint is a dark 3.7 m drop. At a braced joint the arms bridge a 0.5 m slot onto the next one's thighs. At joints 3, 6 and 9 the hands hang into the air over a crushed stump with a rubble wedge.
- **The road:** no pier grid any more. A few causeway stumps at uneven heights and leans, broken off top and bottom, four of them carrying nothing. The old deck lies in slabs (8 to 12 m long) slumped between some of them on the line's north side, 4 to 5 m under the backs.
- **F (far isle):** about 12 m down. A lit place: three crown lamps up the approach, stairs cut into its two rock steps, a kerb at its lip, two stelae. The corbel gate sits in the saddle between two knolls, with a great cresset by it. A north spit catches the road.

**Routes** (proved rim in to rim out through the real input, `scratch/procession_routes.gd`):
- **Backs** (48 s at a run): each back, then a 3.7 m drop off the stump at a braced joint (the slot is under a walk's carry) and a running jump at a gap. Then F's stair to the gate.
- **Quiet** (88 s at a walk): the same backs, dropping off the stumps, with a short run-up only at the three gaps. The arm rails, the card's quiet way, have collision but were not driven.
- **Road** (77 s): from the terrace's north tip, a 4.4 m drop onto the first slab. Slab to slab (gaps 1.0 to 1.5 m, each a 0.1 to 0.3 m hop up). A grab onto F's north spit.

**Sizes from the motor** (WorldScale 1, Trap.pilot(): run 4.8, jump 0.8, walk 2.4). `reach()` in the file: a plain running jump goes about 3.5 m at a 3.8 m drop and about 2.4 m at 0.4 m. Changes to the card's numbers:
- Gaps are 2.49, 2.83 and 3.16 m (0.70, 0.80 and 0.90 of the reach) at 3.8 to 4.0 m drops.
- Braced joints are a 3.7 m drop, not the card's 1 m step. The bodies are 2.8 m thick before scaling.
- **No long jumps off a back.** PilotMotor only long-jumps off ground under SLIDE_FROM (10°), and the backs tilt 15°. The card's long jump and Route B's slide lane need a tilt under 10°.
- Road gaps stay under about 1.5 m.
- The gulf is 116 m (the card said 110). The drop is about 12 m to F, 9 m to the gate floor.

**Threat.** The sixth body's mesh breathes: 10 cm, 5.5 s. A real headless_body (STAND-IN for the rouse) sleeps on its own stump under the sixth's chest, south of the line, held at its post. It has `hear_noise` 0.6, and standing 4 s on the sixth's back also wakes it. Checked: it builds and holds asleep. A quiet walk on the fifth back doesn't wake it. A 4 m drop onto the sixth wakes it (heard), and it roams. On its small stump it moved only 1.3 m in 10 s: it doesn't reach the backs yet (no rouse, no climb route checked). It has the breakables hub (the gate's cracked bay, not checked).

**Real vs stand-in.**
- Real: KitLand shores with turf and flora, the city stone (stumps, slabs, treads, stelae, balustrade, abutment), the corbel gate, the cressets, headless_body, the noise bus.
- STAND-IN `maker_toppled`: the real headless_body.glb, arms posed and skinned by hand once per pose, laid face-down, 1.45x. Over it a procedural carved mantle (rounded back, spine groove, shoulder blades), both dressed through HeadLook `_dressed`. It has a clean hull and arm-rail collision.
- STAND-IN rouse: `Sleeper_STANDIN` plus `SixthBreath_STANDIN`.
- Not stood in: the line shifting when it rises, the shell swap, the slot wall and mouse run cover, family knobs.

**Read against the city places.**
- **Better than last pass:** from the side it is a sawtooth of colossal backs with arms reaching forward, over a few uneven stumps fading into the haze. On a back with the play camera it reads as walking on a body. F reads as a lit, distant goal between two knolls.
- **Still weaker than the Lamplighters' Stair:**
  - From the terrace, the far bodies blur into a rubble ridge at range; the near stelae and stumps take the eye.
  - The treads still read a little as loose slates.
  - In the three-quarter view, the shores are two discs and the gate a cube.

**Model budget** (docs/art/model-budget.md):
- Import LODs: applied. The lying meshes and mantle keep LODs regenerated by `_dressed` (11 x about 88k triangles at full detail; most at 5 to 15% at range).
- Static bake over skinning: applied. No skeleton per body (saves 11 skinning passes).
- Vertex-colour grime: inherited.
- Next: visibility ranges or impostors past about 60 m (estimated 0.5 to 1 ms GPU), and a decimated lying mesh baked in Blender with the mantle sculpted in (about 20k triangles each).

## Polish (round 4)

Dressing pass; land, routes and the sleeper unchanged. `--procession-plain` builds the plain round-4 place for A/B (same routes). Code: `gb_procession.gd` (`polish()`, the `POLISH` table, `ragged`, `_break_crown`, `_hang_roots`, `_make_growth`); no shared file touched.

- **Shores:** both outlines get noses and bays (`ragged`, edges kept at the tip and the lip the line leaves), `stable`/`cliff_drop`/`fine` kit options (the Lamplighters'), slumps and knolls west of A's terrace, bumps on F off its ways, a swell on A's slope. F has two more lit lamps. More fallen stone sunk in both shores.
- **Treads:** sunk 0.05-0.2 m, askew, fewer, no floating rune lines.
- **Stumps and perch:** three crown corners sheared off at steep slants (one deep), loose chunks on the crown, roots hung from the top edge. The perch pier is broken, its cap fallen, rubble banked at its foot.
- **Bodies:** one shared growth mesh over each mantle: moss cushions in the spine groove and the hollows between and beside the blades, pale lichen on the blades and in specks.
- **Roots:** one MultiMesh of the sky forest's root strand hung from both lips into the abyss (longest on F's lip facing the line), and from the stumps.
- **Routes re-walked** (`scratch/procession_routes.gd`): backs 47.8 s, quiet 88.8 s, road 51.4 s, all OK. Sleeper check: builds and holds; "awake, it goes" fails (moved 0.1 m) as before (no climb/rouse yet).
- **Stills:** `captures/shots/proc/r4_before_three.png` / `r4_after_three.png`, `r4_terr_plain.png` / `r4_terr_after.png`, play camera `r4b_game_*` / `r4a_game_*`, reference `ref_lamp_three.png`.
- **Budget:** triangles (built, all LODs-0) about +13k on ~983k (growth mesh 11 bodies, roots); one extra MultiMesh draw; ~2 extra lights; build time within noise (stood 2.1-2.5 s). Tricks: growth is one shared mesh (instanced per body), roots one batch, no per-stump geometry loop beyond cut planes.
- **Not done / open:** ferns in the joints (no stone-side fern path), the far gate still reads as a block from above, stumps remain near-vertical (lean fixed by collision), no full-layer (`--world=under`) run.

**Polish (round 4), second pass.**
- **The line bowed** (polish only: `POLISH.heading` 46 deg, -7 deg a body, was 22 / -3.5): from the terrace it swings out north and the backs read in profile, each with its dark joint (`r4g_top.png`, `r4h_three_three.png`). The gulf in x is now about 108 m (F's lip 20.7 m north of the line's start), so the motif's footprint and the generator's occupancy change with polish (plain unchanged).
- **Bodies:** body 8's arms hang down into the gulf (`hang` pose); ferns at every body's shoulders and heels, with the moss and lichen (`r4h_arm_three.png`).
- **Gate:** its flanks banked in two big turf knolls (up to the roof's shoulders), lintel-sized blocks slid on its roof (visual only: no collision, so the cracked bay and the roof slam are unchanged), roots hung from them. The corbel piece itself is not changed, so the gate is dressed, not rebuilt.
- **Stone:** foreground blocks sunk 1.8x, tipped 1.7x, bevel doubled; the perch and the stelae snapped at the crown on slants.
- **Full layer** (`--world=under`, sprawl seed 1, procession at isle 1, `tools/bg.py`): the backs route rim in to rim out OK, 48 s, 0 errors. The driver needs about 120 frames after the layer stands before the first leg (it fell through unstood ground without). Routes re-walked in the yard after the bow: backs 47.8 s, quiet 87.8 s, road 52.9 s, all OK.
