# The Sunken Giant — "He knelt to be buried and the oak took the rest."
Lenses: verb = climb; scale = a fragment of something bigger; purpose = tomb; decay = root-bound; twist = an Olmec piece as terrain, not enemy.

Pitch: You land at the foot of a stone arm as thick as a barn, bent at the elbow and sunk to the shoulder in turf, oak roots lacing it down like rigging. The isle is only the torso of a kneeling headless giant, and the climb is up its body to the raw-cut neck stump, where something is still looking for the head.

Top (1 char ~ 4 m):
```
   ........................................
   .      ^"""""""""""""""""""^           .
   .     "###3###############"""          .
   .   (forearm)     ###  ##  #####       .
   .  1==#########2===##### N #####4      .
   .  ^ ####"""" ####  ##### (neck) ##    .
   .  P  C  C          o  o  C   A A      .
   .       ~~~~ gulf below the lap ~~~~~  .
```
Key: 1 landing at the fingertips, 2 elbow ledge, 3 shoulder slab, 4 far shoulder (rim out), N neck stump (summit, @ landmark), '==' root cables (swing ropes), o the head's drift ring, C columns as cover, A arena on the lap, P perch at the thumb.

Side (the giant's profile, kneeling, facing left, head missing):
```
                       N  <- neck stump (summit, ~30 m)
                  ____|##|____
        shoulder /#####3######\ 4 -> rim out
   fist 1       |  chest/torso  |
   ___ 2 elbow  |   tomb niche  |
 _/###\_________|_______________|____
 ~~~ sunk into turf, roots over all ~~~
```

Play:
1. Land at the fingertips (1). The hand is a row of fallen hall columns, each a ledge a plain jump (GRAB_TOP) or a pumped jump (CHAIN_TOP) catches. Ledge-grab and chain up the knuckles onto the forearm, a long beam walked as a ramp.
2. Along the forearm a root cable slants across a gap to the elbow ledge (2). Rope swing across, or run the beam and drop to it.
3. The torso is a wall of stacked slabs with SET_OFF-spaced set-offs (1.6 m); wall kick between the chest and a fallen architrave to reach the shoulder slab (3). A tower shell lies half-buried through the chest: its chimney is the giant's throat, the fast wall-kick line to the neck; the slow way is the broken stair round the outside.
4. At the neck stump (N) the summit is a flat floor ring with a tomb chest in the middle, the reward. The far shoulder (4) is the exit rim: pocket sail off it to the next isle.
5. The inhaler head drifts its ring over the lap and neck, nosing at the stump. Hide behind a column (cover), cross when its face turns, or let its draw pull you across a gap you could not jump.

Threat: two inhaler heads (scripts/enemies/inhaler_head.gd): one on a route round the neck stump so it drifts as if searching for the body it came off, and a second on a short route over the far shoulder, facing the neck (the heads chain: one spits you into the other's cone). Its mouth cone is blocked by a pillar, wall or chest of stone (its own cover rule), so the giant's columns are the cover. Tool: its pull carries you across the elbow-to-shoulder gap if you stand in the cone on purpose and sail out before the gulp. The root cables are a second hazard-and-tool: live swing ropes, fine to ride, a long way to fall.

Combos (inhaler blast = `knock` out along its face, ~24 m unit-scaled, stunned, lands down ~1 s; tumbling block, voussoirs, seesaw, updraft, sluice all act on a stunned body; different sources chain, one source cannot restun for 1.2 s):
1. Accidental: swallowed by the lap head, blasted along its face toward the shoulder, lands stunned on the shoulder slab (3), rolls off the slope onto the root-cable sag, which is a live swing rope that catches nothing stunned, so you fall to the elbow ledge (2) still tumbling, a short fall; you lose the climb but not the run.
2. On purpose: a second inhaler head (see Threat) hovers over the far shoulder facing the neck. Stand in the first head's cone on the lap, get gulped, blasted toward the neck stump; the stump's rim is where the second head's cone starts: let it gulp you out of the stun (its own blast, a different source, so it restuns freely) and ride its blast out past the far shoulder rim (4), pocket sail open before you are laid down. Head to head, two sources, no climb.
3. On purpose, climbing: stand in the chimney throat (tower_shell) under the flow-charge updraft; the updraft launches you to the neck ring; the head's draw then pulls you over the stump into the cone's edge, you sail out of the pull toward the exit.
Ports: catches a body thrown in at the fingertips (landing rim, facing the fist): a cannon shot from a neighbouring isle, a head blast, the dragon's swipe all land on the hand, which is a low wide floor (the knuckles' columns), so a stunned body lands on grippable ledges and can roll off to the forearm. Throws out through the far shoulder rim (4) along the second head's face (toward the next isle) for a stunned, ragdolled flight; and a body tossed off the lap cone falls to the thumb perch (P).

Mystery: Not a statue of someone buried here but someone buried kneeling: the hand that carved the inhaler head carved a giant at full size and set a tomb chest in its chest. The head went hunting; the body stays. The stump is cut clean and unweathered, the one face the roots have not touched.

Kit used (all verified): hall_column, hall_beam, hall_slab, hall_bay (ruin_kit_hall.gd; limbs, shoulder, hand as fallen columns), tower_shell (ruin_kit_tower.gd; the throat chimney), tomb_chest, fallen_pier, floor, wall, stairs, buttress, stone_circle (ruin_kit.gd PIECES); foot pieces: swing ropes (root cables), floating/bob stones (off the fist); enemy: inhaler_head (+ inhaler_head_look).
Kit asks:
- A "limb" piece: a fat coursed basalt cylinder with a bend (elbow), so the arm reads as an arm and not stacked columns.
- A fist/hand piece with finger ledges at climbable sizes.
- A neck-stump cap: raw-cut, unweathered, ringed with runes.
- An updraft vent piece for the chimney throat (scripts/updraft.gd exists; a stone-ringed mouth in the tower_shell floor).
- A cannon-barrel stone plinth (scripts/cannon/ exists; a coursed plinth for a keg-cannon on the shoulder aimed across the gulf) so the exit chains onward.
- A thick dark "root cable" variant of the swing rope, anchored in turf.

Family knobs:
- `pose`: kneel / slump / lying (changes the profile and which limb is the route).
- `limb`: left / right arm to climb (mirror).
- `cover_count`: 2-5 columns on the lap.
- `rooted`: 0-1, how much the oak has taken (root cables and moss).

Sockets: rims at the far shoulder (4, facing out along the shoulder line) and at the fingertips (the landing, facing the drop behind); arena on the lap (stone_circle, radius from the pilot's reach for the head's drift); cover: 2-5 columns plus the chest niche; perch at the thumb ledge.

Generator fit: role hero; footprint about 44 x 24 m; height_span about 30 m; suits a tall single-isle layer or a line (landing one end, exit the other).

Distinct from: stair_clouds (a built stair up a mesa) and hollow_keel (a hall under an isle): this is a single figure with a body to read and a head that is somewhere else, climbed by grabs, kicks and swings rather than a stair, and the Olmec occupant is the story of the terrain itself.

## Greybox (Opus pass)
Run: `godot --path . res://studies/greybox/sunken_giant.tscn -- --no-title` (`--head-knob=k=v` for both heads; the layout needs none). Files: `studies/greybox/sunken_giant.gd` + `.tscn`; the whole layout is still the one `LAYOUT` table for the KitLand turf pass.

First build (Sonnet, round 1): climb proven; chain 1 worked (head 1 at x 66 blasts you west onto the chest); chain 2 broke on the ground-bound head (head 2 woke ~13 s after the blast); chain 3 was the stand-in vent only.

Stations (number keys): 1 fingertips (start) · 2 knuckles (jump, then pump) · 3 forearm · 4 elbow gap + rope · 5 chest set-offs · 6 kick shaft · 7 chain 1 (west of head 1, x 59.5) · 8 chain 2 (east of head 1, x 71.5, z 8) · 9 chimney mouth (chain 3) · 0 neck summit · - exit rim (4), now the deck's south-east edge · = head 1's landing (x 85, z 8: head 2 alone) · [ thumb perch.

What I rearranged, and why:
- **Head 2 moved to (86, 1), facing south, still** (a one-point route, default knobs). Head 1's east blast skids you to rest at x 84.5-85, z 7-9.5, every time (the blast is level and its rest is fixed at about 19 m from the gulp). Head 2 sits 6-8 m north of that spot, looking across it. From the chain-2 stand you are 14 m off and behind its shoulder, so it does not wake early or pull against head 1. Head 1's blast throws you into its sight: it notices in flight (+0.4 s), notches round while you skid and lie, tells, and draws you in once you're up (stand still). Its gulp lands 4.3-6.0 s after head 1's blast.
- **Rim (4) moved to the south edge of the deck's east end** (x 76-92, z 13-14, orange). Head 2 blasts along its face, south, so you go out over that rim stunned. You land on the stand-in next isle (x 72-96, z 16-34, 2 m down) at about (78-82, 24).
- **Shoulder deck 5 m longer east** (x 49-92). Head 1's route still swings it to x 68, which can put the landing at x 87, and that was the old rim.
- **Elbow ledge, forearm end and chest set-offs 6 m deeper south** (z -8 to 20). Thumb perch moved to z 22-26. With head 1 off-axis, chain 1 threw you south-west past z 14 into the void (3/12 at ±1.5 m). It now lands on the elbow or the steps.
- Dropped the `--head2=back` boomerang variant. Head 1 is unchanged (x 64.5-68 route, z 8), so chain 1 keeps its geometry.

Headless reliability, `chains.gd` (throwaway, kept out of the repo): the real motor and tick, start ±0.5 m, the heads run 1.0 ±0.2 s before he is set down, a fresh trial each time. "Wide" adds a random 0-10 s head phase. The pilot stands still (that is the play):
- **Chain 1 (accident): 12/12** (wide 12/12). Head 1 gulps you and blasts you west, down onto the elbow ledge (2) at x 34-35.5 or the chest steps at x 37-47. At ±1.5 m it lands 9/12; the other 3 times head 1 gulps from the deck's west end and you stay on the deck, unhurt.
- **Chain 2 (head to head): 12/12** (wide 20/20, ±1.5 m 12/12). Head 1 gulps and blasts you east, head 2 gulps and blasts you south out over rim (4) onto the next isle's pad. Head 1 can take 5-30 s to face you as it paces; the relay itself takes 4-6 s from the first blast.
- **Chain 3 (chimney): 12/12** for its first half. Walk into the throat and stand still: the stand-in vent tosses you to the summit. **The second half can't work** with ground-bound heads. The summit is 9.6 m over the deck, and a head's draw ignores anything above 0.8 of its height (and it can't climb up there). So "the head's draw pulls you over the stump" needs a head on the summit, which the card no longer has.
- **Climb: unchanged, holds.** Pump onto the knuckle, forearm walk, rope across the gap, four set-offs, the shaft (4 kicks) and the chimney (6 kicks). A plain jump still misses the 2.2 m knuckle and the 5.2 m gap, as designed.

Stand-ins (labelled in the world): the root cable (a plain swing rope on a gantry), the chimney updraft (a trap-contract vent: stand still 0.35 s), and the next isle's catching pad.

Engine changes still needed:
- None for chains 1 and 2: both are layout only, at default knobs.
- Chain 3's second half needs a head that can reach the summit. Either a head placed on the summit, which the generator/ground-bound head allows (a layout choice, not an engine change; the card would need a third head), or a draw that reaches up (`inhaler_head.gd` `_pull`'s `m.feet.y > position.y+height*0.8` cutoff). Not attempted.
- The flow-charge updraft (Q) in the throat, in place of the stand-in vent: not tried.
- Head ears (README blocker 1) would let head 1 wake without its 5-30 s pacing, but the relay doesn't need them.

Card was wrong / what changed from it: head 2 doesn't hover over the far shoulder facing the neck. It sits on the deck, across head 1's landing, and the exit rim is the shoulder's south-east edge. Both blasts are hard hits, so you can't open the pocket sail in either flight; you go out ragdolled and land laid down. The blast is level, so it can't throw you up to the shoulder or the neck.

Unverified: how any of it feels or looks (no window opened). Whether a real player reads "stand still twice" from the labels. The heads' behaviour near the rims (a head 2 recoil of 0.67 m north is away from any rim).

## Turf pass (Opus, 2026-10-13)
Run: `godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=4 --knob=greybox=sunken_giant` (also `--shape=ring --seed=3`, `--shape=sprawl --seed=3`; `--knob=bodies=0` for a clean head relay; `--giant-grey` builds the old grey boxes for A/B). Uncommitted, prototype.

What it is now (`scripts/kit_isle/greybox/gb_sunken_giant.gd`, its `build` overridden; stone in the new `scripts/kit_isle/greybox/giant_stone.gd`; `motif_greybox.gd` untouched, so the grey path for the other nine stays as it was):
- **Ground, kit terrain** (`KitLand.island`, the kit-isle turf, crags, hanging rock and keel, flora and the kit isles' default life): three islands, their ground functions the greybox tiers exactly. *Hand*: the fingertip pad, flat at 0 (keel 7 m). *Torso*: the elbow ledge, the chest's four set-offs, the shoulder deck (keel 14 m under the elbow). *Knee*: head 2's catch (keel 12 m). The set-off steps are the kit's cliffs (their lips grabbable via the cliff prisms). The islands' hanging sides are collided as drawn ("Sides"), as the greybox masses were solid: without that the headless bodies couldn't climb the flanks to the heads (found in the checks).
- **Body, Olmec basalt** (the heads' `olmec_stone` shader, vertex-coloured as the head: tone by facing and height, foot occlusion, moss on tops): the fist as three knuckle rows of four chamfered fingers, the forearm beam (top = the greybox ramp, 2.6 m thick), the elbow block, the chest as two courses of slabs with the kick shaft cut through, the shaft's end block, the broken stair, the neck stump with a band of lit runes round it under the cut (the rune serpent's band glyphs), the chimney fins, the chest niche, the four lap columns, the summit's paler floor ring, the thumb. Each collided as its greybox walk box. The tomb chest is the kit's `tomb_chest`.
- Where terrain meets plumb stone (the chest's west face, the shaft), the terrain steps up 1 m *inside* the stone (x 52, and round the shaft to x 54, |z| 2.6), so the kit's leaning cliff faces are hidden and the shaft is the stone's own 2.8 m.
- The station and chain labels are gone; the HUD card (layer_greybox.gd) still says GREYBOX.

Distances (probed: the isle built alone, raycast): every tier height exact (0.000 m off: knuckles 1.725 / 3.925 / 5.525, elbow 7.925, set-offs to 14.325, deck 20.325 flat over x 55-91, knee 18.325, neck 29.925, thumb 11). Unchanged by construction: knuckle rows, forearm top, elbow gap 5.2 and rope, shaft 2.8, chimney 2.2, set-off rises, head 1 and head 2 positions and facings, rims and spots. What the terrain moves: walked edges sit -0.2 to +0.3 m from the greybox edges (the outline's ±0.35 m wobble, plus the collided sides' lip); a set-off's face leans 0.15-0.2 m out at its foot (its lip stays put). Chain 1's rests come 0.2-0.7 m further east (elbow x 34.2-36.0, T1 x 37.2-37.6, against 34.0-35.3 and 37.1).

Re-proved headless in a real layer through the scene's own tick (`check_layer.gd`, one check per process, start ±0.5 m, heads ±0.2 s; grey and turf in the same tree, the same day):

| | sprawl 4 grey | sprawl 4 turf | ring 3 grey | ring 3 turf |
|---|---|---|---|---|
| Climb (8 steps) | 8/8 | 8/8 | 8/8 | 8/8 |
| Chain 1 | 10/10 | 10/10 | 10/10 | 10/10 |
| Chain 2, bodies=0 | 10/10 | 10/10 | 10/10 | 10/10 |
| Chain 2, bodies on | 0/10 | 5/10 | 2/10 | 2/10 |
| Chain 3 | 10/10 | 10/10 | 10/10 | 10/10 |

Chain 2's relay lands on the knee at (78.4-80.8, 23.5-24.3), head 2's gulp 4.5-6.0 s after head 1's blast, identical to grey. With bodies on it fails the same way in both (a body perches a head mid-relay); 5/10 against 0/10 is the bodies' timing, not the turf. The harness had to drop the sprawl run loop and its void (a fall laid a new layer under the later trials). Smoke: 400 frames on the giant, sprawl 3, sprawl 4, ring 3, no script errors; flora about 4,300 tufts grown in about 650 ms.

Generator: default plans byte-identical (sprawl and ring 1-4). With the knob, sprawl 3 and ring 3 plans are unchanged; sprawl 4 keeps the giant where it was (in at the fingertips by a climb, out off the knee by a bridge), but the keels in the occupancy move what comes after: the knee's bridge is now 12.1 m (was 26.5 m with stones), the next isle and the greed isle moved.

Model budget (docs/art/model-budget.md): 11.9k triangles (turf 3.9k, crags 1.1k, hanging sides 2.7k, giant stone 2.2k, the kit chest 1.9k), 2,857 collision shapes (nearly all cliff prisms), about 600-750 ms build headless. Sculpt high / bake low: not applied; it would be the way to the card's "limb" and "fist" pieces (a 10-15k sculpt baked to about 3k, replacing 2.2k of blocks, no saving, a big look gain). Import LODs: the stone is one mesh with no LODs; its blocks are already minimal, so a LOD saves under 1k triangles. A visibility range on the kit chest at 150 m saves 1.9k triangles far off. Under 0.05 ms either way. Silhouette geometry: applied, every block chamfered (2.2k against about 0.6k for plain boxes), on purpose. Rigid parts on bones: no (static). Parallax: no; the shader's pits and cracks already nudge normals. Vertex-colour grime: applied (foot occlusion and moss in the vertex colours, no triangles). Draw calls: about 13 (3 grounds, crags, 3 sides, stone and runes, chest, 4 gantry boxes); folding the gantry into the stone mesh would save 4.

Still greybox or stand-in: the root-cable gantry (dark boxes) and a plain swing rope; the chimney updraft (the study's vent, its box faded nearly invisible, no vent piece); the HUD card's GREYBOX title; the body is plain chamfered blocks, not a limb, a fist or a kneeling figure (the card's kit asks still stand). Not judged: how any of it looks (no window opened; rendered work for the user), the rune band's glow, the sides' collision against the plane.
