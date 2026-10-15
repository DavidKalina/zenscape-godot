# The linger serpent, round 2 (prototype): the hunt on the isles

Round 1 (`linger-serpent-round1.md`) was "really spooky" but felt like
ambiance: it struck from a poise in the void, standing still never got
you hit, its head looked bad, and it sometimes distorted. Round 2 makes
it a hunter you play against, and it stays huge (the same 2.4x rune
serpent: about 215 m long, 10 m through, a 15 m head).

It is still gated the same way: `RunFeatures.on(&"linger")` and
`--linger=serpent` (the default). `--no-linger`, `--loot=off` and
`--linger=colossus` leave it out. No shared files were touched; all the
work is in the three linger files.

## What changed

### It comes onto the isles

The clock stages are kept: below, then rising at 95 s, then "sees", then
level at 150 s. "Sees" now starts the hunt. At level it knows where you
are and hunts without needing to see you.

- **The climb.** It picks a rim of your isle about 28 m from you
  (`ENTER_OFF`), so it has the isle to cross, near where its head is. It
  goes under the rim (from far off, deep under first, as round 1 did),
  rears up over the lip and comes in toward you. Its body follows its
  head's exact path, so it pours up over the rim out of the void.
- **The chase.** Its body rests on the ground, its head path riding
  `RIDE_K` of its girth over the real colliders.
  - **Pace.** It goes at 0.9 of your run near you and 1.4x when more than
    38 m off. At level it matches your run.
  - **Steering.** It steers straight at you where the way is clear, which
    cuts your corners. Otherwise it takes an A* path round tall stone,
    string-pulled up to 30 m ahead.
  - **Ground and cover.** Low stone (walls, steps, terrace lips under
    5 m) it goes over. Pillars, thin high walls and arch spans it goes
    round.
- **The drape.** About 75 m of its front (`ON_ISLE`) lies on the isle.
  Behind that, the body is laid from there over the nearest rim and
  hangs down into the void. On a small isle it can't pile up.
- **Its body is solid.** Capsules over every 2 rings on layer 1 stop
  you; you can shelter behind a coil, and it cuts off routes. Where it
  slides into you it pushes you out, at most 9 m/s. The body is marked
  moving ground, so if you land on its back you ride it.
  - The head's capsule is off: it used to slide under you and lift you.
    The head acts on you only through the bite.
- **Between isles.** If you are on another isle for 0.8 s, it goes over
  its own rim toward you, down into the void, and climbs yours. That
  takes 5 to 15 s, so the gap jump is the escape. Bridges, stepping
  stones and viaducts are not its ground.
- **Giving up.** In stage 3 only, if it doesn't see you for 14 s
  (`GIVE_UP_T`) it sinks back into the void and coils. At level it never
  gives up.

### The strike, dodged by speed

The strike can begin only when all of these hold:
- your chest is within 13 m of its mouth,
- you are in front of it,
- the line is clear,
- it has slithered at least 12 m on this isle since it climbed on.

The beats:
1. **Rear** (0.55 s; 0.4 s at level). The head draws back 4 m along its
   own path and lifts 6.5 m on the neck's S. The jaw starts dropping and
   the head squashes. Halfway up the rear it takes its aim (`COMMIT`):
   where your chest is then.
2. **Hold** (0.22 s; 0.16 s at level). The jaw is wide and the head
   trembles.
3. **Lunge** at 48 m/s, at most 22 m. Its mouth (not the snout's tip) is
   carried to the aim, the head stretches to 1.24, and it rides over
   crests.
4. **Bite.** The jaw slams shut.
5. **Recover.** A 0.45 s beat, then it draws back 30% of the lunge.

There is no strike again for 1.6 s (1.0 s at level), or 3.2 s after a
bite, so a man who was knocked down can get up and run.

- **What lands.** A hit is your chest within 2 m of the jaws, or of the
  mouth's sweep. It costs one heart through `motor.harm("serpent")` and
  knocks you 6 m along the strike, a little toward your nearest rim. You
  are down for 0.6 s.
- **Cover.** Stone standing more than 1.6 m off the walkable ground
  (`COVER_TALL`) blocks the strike line. The isle's own rolling ground
  doesn't, because its head goes over it. If you get behind stone during
  the rear, it lets the strike go (`aborts`).

### The distortion fix

- Its head now turns at most a `TURN_R` = 8 m circle per metre travelled,
  never per second. Round 1 turned on the spot when slow: its turn rate
  was per second, and at near-zero pace that made a tiny-radius curl
  that folded the rings.
- Paths never go straight up or down, because a ring needs a way across.
  The drape leans out as it falls, and the climbs keep some horizontal
  heading.
- Ring spacing is the path's, unchanged: it stays constant because the
  head never doubles back on itself, and `rewind` is the only way back.

### The head

There is a new head, modelled in code (`linger_serpent.gd`
`_build_head`) in the same pebbled Olmec stone and shader as the body.
It replaces the rune serpent's flat-slab jaw.

- **Skull.** A broad viper's skull, 1.2x the rune serpent's girth,
  lofted from 10 sections (`SKULL`): wide jowls, a wedge to a blunt
  snout, a squared top. Smooth normals, pebbled scales.
- **Brows and eyes.** Heavy brow shelves overhang sunk eyes, which use
  the Olmec eye carving, dimmed to 0.4 (`EYE_DIM`). The eyes stay warm
  and dim, and light when it fixes on you.
- **Jaw.** A separate lofted lower jaw on its own bone, hinged low at the
  head's back. It opens on a soft, overshooting spring (weight) and shuts
  on a hard one: a slam with a small bounce (`JAW_*_HZ`).
- **Mouth.** A dark palate and floor, gums, a gape that stretches at the
  corners, and a throat.
- **Teeth.** Two pale stone fangs hang outside the lower jaw, with rows
  of teeth top and bottom.
- **Ruff.** Narrowed to four plus three feathers lying back over the
  skull. The side feathers read as ears from above, so they are gone.

Judged in rendered stills, close up and at play range (`scratch/head_view`
and in-layer captures). At play range it reads as a huge stone viper
coiled up over a walkway with its head at his level.

## Play it

```sh
# the whole climb, from the start (sees you about 100-120 s in)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
# at level: it climbs onto your isle at once and hunts
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --linger-at=150 --linger-debug
# the clock at 4x, to see the stages lead into the hunt
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --linger-pace=4 --linger-debug
```

The start pad of sprawl seed 11 is small. Cross to the broad green isle,
or along the Procession walkway, to play keep-away.

| Knob | Does |
|---|---|
| `--linger-at=<s>` | start its clock this far on (0; 100 rising, 150 level) |
| `--linger-pace=<x>` | everything runs x times as fast |
| `--linger-scale=<x>` | its size, as the rune serpent's times x (2.4) |
| `--linger-chase=<x>` | its pace near you, as a share of your run (0.9) |
| `--linger-debug` | stage and act changes, lunges, bite checks, give-ups in the log |
| `--no-linger`, `--linger=colossus`, `--loot=off` | leave it out |

The tuning constants sit at the top of `scripts/roguelike/linger.gd`:
- `STRIKE_AT`, `REAR`, `COMMIT`, `HOLD`, `LUNGE`, `BITE_R`, `COOL*`
- `CHASE_*`, `ON_ISLE`, `TURN_R`, `ENTER_OFF`, `GROUND_FIRST`,
  `COVER_TALL`

The head's sections, jaw springs and teeth are in `linger_serpent.gd`.

## Files

- `scripts/roguelike/linger.gd`: the threat. The coil stages are
  round 1's. Round 1's poise strike (approach, fix, wind, snap) is gone,
  replaced by climb, chase, rear, hold, lunge, bite, recover and descend,
  plus the drape and the push.
- `scripts/roguelike/linger_serpent.gd`: the body. It is now solid, with
  the new head, the hinged weighted jaw, the drape (`trail_at`
  overridden), the quicker look springs and the dimmed eyes.
- `scripts/roguelike/linger_nav.gd` (new): the isles' ground for its
  head.
  - **The grid.** 3 m cells, each ray-cast against the real colliders on
    layer 1, with its own body left out.
  - **The bake.** It bakes incrementally, nearest you first, 220 rays a
    frame, and keeps re-baking isles until two passes find nothing new.
    The layer streams in round you, so this is needed.
  - **What it gives.** Tall-stone cells, rims, `clear_line`, and A* on
    Godot's `AStarGrid2D`.

## Proved (headless and rendered, through the real loop and stick input)

- **Smoke.** `run_layer` sprawl seed 11 plain, sprawl seed 11
  `--linger-at=150`, and ring seed 3 `--linger-at=150`: 400 frames each,
  0 errors.
- **The clock** (`--linger-pace=4`, from the layer's start): stage 2 at
  95 s, it sees him at 117.5 s, climbs, chases from 21 m, strikes; level
  at 150 s.
- **Standing still is struck** (start pad, and the big isle): it climbs
  on and slithers to him. Strikes connect every time he stays put. Two
  hearts went in about 6 s on the pad, and the big-isle stand run ended
  with him dead.
- **Dodged by speed** (`scratch/hunt2.gd --mode=dodge`: he waits, then
  runs across the strike when it rears). It missed every strike in which
  he moved 3.0-4.2 m during it. It hit when he managed only 1.2-1.5 m
  (boxed in by stone or its body).
- **Other bots on the big isle:**
  - Fleeing at a run: 1 bite in 4 strikes.
  - Walking (45% stick): 3 bites in 7 strikes.
  - The fleeing and walking bots are crude and sometimes run off edges.
- **His collision with its body** (`scratch/bump.gd`, walking straight
  into a ring behind its neck): he stops at its girth and never gets
  inside its capsules.
- **Cost.**
  - The serpent's own frame: 0.3-0.5 ms average, 1.3 ms at worst in
    headless runs. In the rendered run, 0.30 ms average and 0.97 ms at
    worst.
  - The nav bake adds up to 220 rays a frame while isles near him are
    unsettled.
  - The whole rendered frame during a chase averaged 9.8 ms.

## Rough

- **Narrow isles.** On walkways and causeways it can't lie on the ground,
  because its 10 m body is wider than they are. It rides alongside and
  over them, its body rising out of the void beside them. Dramatic, but
  not "lying on stone".
- **Small isles.** On the start pad (about 45 m) it mostly hangs over the
  rim, and one bite can knock you off the pad.
- **The drape.** It slides sideways across the isle as the head moves on.
  Its rim is kept with hysteresis, but it can still swing when the
  nearest rim changes.
- **Self-overlap.** Its head path can cross its own body on the isle. It
  doesn't climb over its own coils yet (no self-collision).
- **Clipping.** The lunge rides over crests, but the open jaw can still
  dip into the ground at the end of a downward strike.
- **Climb time.** Climbing from far off takes 15-20 s at level. It looks
  good, but it is slow to arrive.
- **Narrow gaps.** Tall-stone detection is "5 of 8 neighbours more than
  5 m lower". Gaps narrower than its body (between two pillars 6 m apart)
  are still treated as passable, so its flanks pass through stone there.
- **Sound.** It reuses round 1's kit clips: a growl on the hold, a whoosh
  on the lunge, a slam on the bite. Not heard (headless).
- **Not proved.** The stage-3 give-up and the ride on its back are not
  proved by a driver.

## Model budget (`docs/art/model-budget.md`) for the new head

The new head is about 1.6k triangles, against the rune serpent's head of
about 0.4k. The ruff is about 340 triangles (it was 500). The whole body
is about 2.35k plus the ruff. Assessed:

- **Sculpt high, bake low.** Not used. Pebbles, washes and cracks come
  from the procedural `olmec_stone` shader, with no texture memory. A
  baked normal map could drop the skull loft from 13x14 sections to about
  8x10: roughly 0.8k triangles saved, about 0.01 ms. Not worth it yet.
- **Import LODs / visibility ranges.** These would apply. Past about
  150 m, a 6x8 head and a 24-ring body would save about 2k triangles,
  under 0.05 ms. The mesh is built in code, so a LOD would mean a second
  `ArrayMesh` swapped by distance.
- **Silhouette geometry.** Used. The brow shelves, fangs, teeth and the
  ruff's blunt plates are real geometry on the outline.
- **Rigid parts on bones.** Used. The skull, fangs and upper teeth are on
  the head bone, the jaw and lower teeth on the jaw bone, the ruff on a
  BoneAttachment3D. There is no skinning blend cost.
- **Parallax depth.** Not used. The pebbles' bump is enough at its size.
- **Vertex-colour grime.** Used. Occlusion is in the vertex colours,
  darker underneath; the mouth, gums and throat are painted dark.

## Existing tests it may break

None were run (prototype). These are at risk:
- `test_run_layer.gd` and long scripted `run_loop` runs that stand him in
  the open for more than about 100 s of layer time, or start at level.
  It now climbs onto his isle, pushes him with its body and bites, which
  costs hearts, knocks him back and can knock him off small isles.
- Tests that cast rays on layer 1 near the serpent. Its body is solid
  now; its RID is `body.solid_rid()`, as round 1's tests may have used.
- Any test that relied on round 1's acts: `approach`, `fix`, `wind`,
  `snap`, `recoil` and `_poise` are gone.

Pass `--no-linger` in such tests if needed.
