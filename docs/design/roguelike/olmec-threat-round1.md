# Olmec threat, round 1: one roaming Olmec, whole and relentless (2026-10-15)

> A prototype round on the worktree branch `worktree-agent-a08e37c3a243f1fe3`,
> cut from `roguelike` b7bd94d6. It has smoke checks and throwaway drivers
> in `scratch/` (git-ignored), and no new tests.

The ask, in the user's words: the Olmec "looks cool but doesn't do a whole
lot", isn't threatening, and there are too many of him. "Tune him up so he
feels more like a threat, an imposing force, more vision, chasing you, the
tilt... everything we talked about." Their concept: he climbs up over a
cliffside to get his head, and if he gets it, "good luck". He travels
between isles, so you see him climbing a cliff of an isle you passed or of
the one you're headed to.

## Play it

```sh
./run-game.command      # unchanged: the title, then the city run. The roaming Olmec is the default.
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --seed=3
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --seed=1 --knob=olmecs=places   # the old way
```

**Dev keys** (in run_layer):

- **O:** the Olmec now.
  - Headless: up a cliff by his head (one you can see if there is one).
  - Whole: he goes away and comes up a cliff of the isle you're on.
  - Away: he comes back now.
- **Shift+O:** his head on now (the beat), wherever he is.

**Good seeds** (region 1, sprawl, `--world=under`). From the spawn, the
first climb comes 12-32 s in. He has his head 26-61 s after that.

| Seed | Head | What happens |
|---|---|---|
| 3 | 113 m off (the Arrival) | He comes up at 32 s, about 80 m off, and is whole 55 s later. Then he comes for you. |
| 4 | 119 m off | He comes up at 32 s, about 90 m off, and is whole 30 s later. |
| 8 | 228 m off (on the Face's lap) | Whole 26 s after he comes up. |
| 2 | 74 m off | **Seen.** From the landing's rim, looking toward the head, he comes up a face about 20 m off, 12 s in. |
| 1 | On a coil cap | No clean face round it. He comes up a stepped face at 42 s and doesn't reach the head in 90 s (see the rough spots). Press Shift+O, then O, to play the hunt here. |

To try the hunt at once on any seed, press O, then Shift+O (head on), then
O again: he comes up a cliff of your isle, whole.

## What changed

### 1. Few Olmecs, roaming

**One per layer, two from danger 0.66** (region 3 on). Before, there were
6-7 per layer: each place's Keeper, plus the generator's heads by danger.

| Region 1 | Bodies at the start | Heads |
|---|---|---|
| Before (`--knob=olmecs=places`) | 6-7 | 6 |
| Now | 0 | 1 (2 at region 3) |

**The places keep their Olmec code but don't lay it by default**
(`scripts/enemies/olmec_places.gd`, `keepers(g)`). This covers:

- the Keepers of the stacked court, the face and the serpent crossing;
- the Feller of the felled colonnade;
- the coliseum pit's Player and Watcher;
- the lamplighters' stair's Keeper and far roamer;
- the haulway's riders;
- the procession's sleeper (its pier stays);
- the weir stair's tenders.

The places' own heads also stay out (LayerGreybox `lay_heads` isn't called
in roam mode).

- `--knob=olmecs=places` brings all of this back, with the generator's
  heads by danger as before.
- Alone in the motif yard, or in its own study, a place keeps its Keeper
  as designed.
- Each place's hub and breakables are still built. Its lure and break
  moments still work when the roaming Olmec is there, and are bonuses
  when he isn't.

**His head**, roam mode (`LayerEnemies.lay`):

- It goes on a route isle, near the start (`ROAM_NEAR`, rated down a
  point per 150 m from the spawn).
- `--knob=olmec_count=N` pins the number of heads.
- If none of the generator's spots fits, a place's own head is used.

**The director**, `scripts/roguelike/layer_olmec.gd` (new), runs his
entrances and travel.

- **Cliffs are found at run time**, by rays from the head, or from your
  feet. Each rim is fitted to the real face (BodySpawner `fit`). Two kinds
  of face are rejected:
  - one with a ledge or an undercut partway down, because he mantled onto
    the ledge and stood under the rim;
  - one he wouldn't fit on.
- **A rim you'll see comes first:**
  - its face turned to the camera;
  - him coming over the lip, on screen;
  - a clear line to him.

  He starts up to 9 m down the face, so you watch him climb. This is the
  main entrance: the plan's head cliffs are only a fallback.
- **The first entrance** comes 12 s into the layer.
  - For 20 s only a rim you'd see will do.
  - Then any clean rim.
  - Then the plan's reachable cliffs (the old spawner).
  - Then a stepped face.

  The spawner's own natural spawns are off in roam mode
  (`LayerBodies.ROAM_SPAWN`). It keeps the books.

**Travel.** Whole and hunting, he goes away when either holds:

- you're more than 34 m off (or 14 m up or down) and he hasn't seen you
  for 7 s;
- he's stuck (9 s in a 3 m box) and you're far.

How he goes:

- Out of view, he's simply gone.
- In view and near a rim, he leaps off it into the dark.
- A fall does the same: a span gone under him, or a leap off.

**He comes back** 6-16 s later (by distance) up a cliff of the isle you're
on, 16-48 m from you. A rim you'll see comes first. He starts down the face
and climbs with a rumble, then the haul-over, the tilt, and the hunt.

### 2. Headless searches, whole hunts

Headless, he is unchanged: hearing (noise) and the head's call. The new
body knobs, all on for the roaming Olmec (`LayerBodies.ROAM`), are below.

- **`relentless`.** Whole, he never falls back to idle searching.
  - Lost, he looks about `hunt_search` (4 s), then takes your **scent**:
    he goes to where you are now, not where he last saw you.
  - He doesn't give up and walk home.
  - Where you were about his level, he simply comes on: no periscope, no
    route.
  - He doesn't stop to scope a wall in his way.
  - Above him, he still climbs after you (`climb_after`, unchanged).
- **More vision while hunting:**

  | Knob | Hunting | Before |
  |---|---|---|
  | `hunt_range` | 67 m | 45 m |
  | `hunt_half` | 1.25 rad | 0.9 rad |
  | `hunt_grace` | 2.5 s | 1 s |
  | `hunt_drain` | 0.12 | 0.3 |
  | `hunt_memory` | 30 s | 16 s |

- **Big leaps:** `hunt_gap` 4.6 Hh (15.5 m, up from 10.1 m), and
  `hunt_rise` 0.9 Hh up.
- **The head-on beat** (the director's `_on_whole`):
  - slow motion at 0.3 for 0.7 s;
  - `olmec_roar`, heard across the layer (220 m), and a rumble;
  - a shock ring off his feet that throws you if you're near;
  - the stone under him tips;
  - a big camera quake;
  - the line "He has his head." on screen for 3.5 s;
  - the triumph clip (arms up, then fists down).

  Then he is spotted and hunting, with your scent: he knows where you are.
- **The torch** (the light part of his sight) is not deleted. While he
  hunts, the dark hides you much less: `hunt_dark_range` 0.85 and
  `hunt_dark_seen` 0.8, where it was 0.4 and 0.3. The torch now matters
  only for being spotted, never once he is on you. **What I'd cut:** the
  dark's cut to his reach and to what he sees of you, even before he
  spots you. Keep the light's glow making you plainer (`sight_glow`), so
  carrying fire is still a risk. That's a stealth decision for you to
  make, so it isn't done here.

### 3. The tilt

`scripts/enemies/olmec_tilt.gd` (new) ports the dragon's gale. Note that
the dragon's own walker slide isn't forced either.

**What tips.** When he hauls over a rim, lands a leap or a pounce, or his
head goes on, the stone under him tips toward his weight:

- It is the largest node over the collider under him that is 6-80 m
  across: a kit piece, a column top, a place's terrace piece, or a whole
  small place such as the 44 m landing.
- Its colliders tip with it, posed from rest about its middle each frame.
- When the stone is most of a place, that place's live host (its fires,
  lamps and hub) rides along.

**How far.** The rim dips 2.2 m x the weight's power, held to 2-9°. A
smaller stone tips more. It springs back with an overshoot (w 3.4,
ζ 0.32) and settles in about 2 s. While he stands out near its rim it
stays leaned up to 4°.

**The walker.** Standing on it, he is carried (`PilotMotor.carry`), and for
1.1 s after a kick he lurches toward the low side, along the fall line, at
up to 3.1 m/s. That is slower than his 4.8 m/s run, so running upslope
always wins.

**The tells:** a groan (`isle_groan`), rocks off the rim, the camera's
quake.

**Measured** on seed 1:

- On the landing (61 m across, pivot about 20 m from the rim), the peaks
  were 2.8° for a haul-over and 5.8-7.4° for a pounce landing.
- The walker was carried 1449 frames and lurched 212 frames.
- He didn't fall: the driver kited him round the middle.

### 4. Masonry doesn't stop him

`scripts/enemies/olmec_breach.gd` (new) is his `breacher`. The colonnade's
breaks were pre-cut; the city's stone isn't. Each kit piece is one merged
mesh and one body of convex hulls. So this cuts the stone where he hits it,
at run time.

**When.** Hunting, a wall meets him in `_hunt_wall`, and you're beyond it no
higher than 0.8 of his neck. If you're higher, he climbs to you instead.

**What goes.** The hulls in a breach box in front of him: 0.75 of his
breadth across, from a step to 2.4 neck heights up, 3 m deep. Any block in
that box stops the breach if:

- it is wider than 9 m (a pillar's mass or a terrace);
- it stands lower than his feet (his floor);
- it is the one you stand on.

**The beat.** The body's own `smash` state, so the tell is the punch: fists
up 0.42 s, then down.

- The hulls are switched off.
- Their triangles are cut out of a copy of the piece's mesh, so a shared
  mesh keeps them. This takes 1-2 ms a breach.
- Chunks of the same stone fly out the way he punched, bounce and lie as
  rubble for 30 s.
- A plume, a crack and a boom, a 6-frame hit-stop and a quake.
- Every body's routes forget the box (the hub's `changed`).
- You, right in front, are knocked back with no harm.

**Spans** (OlmecBreach `crack_under`). Whole and hunting, standing on the
crossings' stone (the layer's `Stones`):

- After 0.35 s it cracks: dust sifting, pebbles, a crack.
- 0.75 s later the blocks under him go: within 5 m, 10 m down, each 2-26
  m wide. Piers go with them.
- He falls, and the director takes him away, so he's cut off for 6-16 s.
- You on that stretch fall too. The crack is your tell.

**A hub per layer.** The director makes one Breakables hub and gives it to
every Olmec, now that the Keepers don't. It also puts the hub's quake on
the camera, which nothing did in layers before.

### 5. More forceful attacks

- **Thrown toward the void** (`scripts/enemies/olmec_void.gd`, new,
  `void_push` 0.6). The whole, hunting Olmec's shocks and swats, and his
  worn head's blast after a gulp, bend toward the nearest open edge
  within 9 m. Near a rim, a hit is the one that kills. In the middle of a
  top, it is only a knock.
  - Headless haul-over waves are not bent. On seed 2 one threw the walker
    off a rim, which was too harsh for a body he hadn't met yet.
- **Harder landings:** hunting, his leap's and pounce's waves are 1.35
  times stronger (`hunt_shock`). Leaps also tilt the stone.
- **The inhale reaches** 1.3 times further while relentless (to 30 m).
  - It pulls toward the mouth. With him across a gap or at his own rim,
    the pull takes you over yours. On a ledge your grip is torn off, as
    before.
  - Brace (crouch) halves it. Its tell (the plant, 1.2 s) is unchanged.
- **Throwing kit:** not done.

### Small fixes on the way

- **Head matching** (`BodySpawner.same_home`). A head set on a top that
  stands a little off its planned height (2.8 m on seed 1's coil cap) was
  never matched to its home, so no body ever came for it. Homes now match
  within 0.5 m flat and 4 m up or down.
- **The coliseum pit's `Keepers._physics_process`** has the main checkout's
  fix: the validity checks come before the typed assignment, and `_refind`
  loops untyped.

## Knobs

| Where | Knob | Default |
|---|---|---|
| layer (`--knob=`) | `olmecs` | `roam` (`places`: the old behaviour) |
| layer | `olmec_count` | -1 (1, or 2 from danger 0.66) |
| body (`--body-knob=`) | `relentless`, `breach` | 0 (1 for the roaming Olmec) |
| body | `void_push` | 0 (0.6 for the roaming Olmec) |
| body | `hunt_range`, `hunt_half`, `hunt_grace`, `hunt_drain`, `hunt_memory` | 67 m, 1.25 rad, 2.5 s, 0.12, 30 s |
| body | `hunt_dark_range`, `hunt_dark_seen` | 0.85, 0.8 |
| body | `hunt_gap`, `hunt_rise`, `hunt_search`, `hunt_shock` | 4.6 Hh, 0.9 Hh, 4 s, 1.35 |

Constants live at the top of each new file:

- **The director:** travel `TRAVEL_*`, entrances `ENTER_*`, rims `RIM_*`,
  `WIDE_*`, `CLEAN_*` and `SEEN_EDGE`, and the beat `BEAT_*`.
- **The tilt:** `TIP_*`, `DIP`, `LEAN`, `W`, `ZETA` and `LURCH`.
- **The breach:** `BLOCK_MOST`, `BREACH_*` and `SPAN_*`.

## Shared files (small marked hooks, for the merge)

| File | Hook |
|---|---|
| `scripts/roguelike/layer_plan.gd` | `knobs_from` accepts `olmecs` and `olmec_*` (marked `[olmec]`) |
| `run_loop.gd`, `layer_stage.gd`, `pilot_motor.gd` | Untouched |
| merchant, inhabitants, flyer, layer size code | Untouched |

Everything else is in the enemy and Olmec files, `layer_enemies.gd`,
`layer_bodies.gd` and the places' Keeper blocks. Note that `layer_enemies.gd`
now runs the director before the spawner (`before`).

## Captures

All are in `captures/olmec-threat-round1/` (git-ignored), rendered windowed
and quit by the drivers' timeouts.

| Files | What | How it reads |
|---|---|---|
| `sheet_beat.png` (`beat_*`) | The head-on beat on the landing | Headless, then the head on, the ring and dust, the game camera. The ring and the white dust wall read big, and the triumph pose reads. |
| `sheet_climb.png` (`climb_*`, `haul_*`) | Him coming up the landing's face after you, the haul-over from far | The dark mass on the face with a puff at each hold reads well at 26 m. From 70 m the plume over the rim reads. |
| `sheet_tilt.png` (`tilt_0_rest`, `tilt_1_peak`) | The landing level, then tipped toward his rim | Visible against the horizon, with the cressets riding it. This one is only 2.2° (captured mid-haul). |
| `sheet_breach2.png` (`breach_127_*`) | A break-through from behind him | The fists up, then a big plume. The chunks wear the mossy stone. The "after" frame is still in dust: shoot it later next time. |
| `sheet_far.png` (`far_*`) | Seed 2 from a stone by the landing | The game camera didn't have him in frame. The long lens shows the haul-over through dust and his landing near. A clean "seen far climb" still is not captured; see below. |

## Proven, and not

**Proven** (headless unless noted, the real loop at `--fixed-fps 60`,
drivers in `scratch/olmec_*.gd`):

- **Smoke, 4200 frames (70 s of play), 0 script errors:**
  - roam, seeds 1-6;
  - roam, region 3 on seeds 2 and 5 (two Olmecs);
  - `--knob=olmecs=places` on seed 3, and on seed 1 at region 3;
  - the motif yard with `stacked_court` and `editor_hill` (600 frames).
  - Plus 400-frame smokes on seeds 1-5 at regions 1 and 3. Seed 4 region 1
    once showed only exit noise (PagedAllocator, leaks) and passed on the
    rerun.
- **Counts** (`olmec_count.gd`):
  - roam: 0 bodies and 1 head at the start, 2 heads at region 3;
  - `places`: 6-7 bodies and 6 heads, with the Keepers.
- **Entrances** (`olmec_enter.gd`, seeds 1-8, the walker at the landing's
  rim facing the head):
  - 8 of 8 bring him up, at 12-42 s.
  - 7 of 8 have him whole 26-61 s later, with the beat.
  - Seed 2's was seen.
- **The hunt** (`olmec_flee.gd`, seed 1). Whole, he came back up a cliff of
  the landing (feel, climb, mantle and the tilt). You ran through the
  stick and kited round the middle, and he:
  - came over the dais step after you;
  - planted and sucked (pulled you from 14 m to 4.7 m);
  - pounced (missed);
  - leapt.

  You took 1 hit in 25 s and didn't fall. The tilt carried you 1460 frames
  and lurched you 212, peaking at 6.7°. Then you were set down on isle 1
  (as if you'd crossed). He went away and came up a cliff 39 m from you,
  28 s later.
- **Break-through** (`olmec_wall.gd`, seed 1). He was set hunting behind a
  wall, with you beyond. He smashed through 4 times (20 blocks, 597
  triangles) in 1-2 ms a cut.
- **Spans** (`olmec_span.gd`, seed 1). The span cracked and gave way under
  him in 65 frames, 3 of 3 times. On one of them he fell through and was
  taken away ("fell").

**Not proven:**

- **A skilled escape over a real crossing.** No driver crosses the
  generated crossings (round 14's pace driver is gone).
  - The escape rests on numbers: he chases at 4.32 m/s against your 4.8;
    he can't leap gaps over 15.5 m; and when he travels he's gone 6-16 s
    plus the climb (8-14 s).
  - Evidence: you survived 25 s of his hunt on the landing.
- **A whole layer played start to gate with him.**
- **A far climb captured in a still,** seen from a place you'd stand. Seen
  entrances happen when a clean face is on screen. They're rarer than
  hoped: from the spawn the landing's own top hides most faces, and many
  of the city's faces are stepped.
- **Audio** (headless, and the stills are silent).
- **Frame time:**
  - Tipping moves static bodies each frame (the landing has hundreds of
    hulls).
  - The wide rim search can cast about 2k rays on one beat.
- **The suite** wasn't run (prototyping). The two world-scale guards pass.

## Rough spots

- **Seed 1's head is unreachable.** It sits on a cap with no climbable face
  round it; he comes up a stepped face nearby and doesn't get there. The
  head's spot should require a face that `fit` takes. That needs geometry,
  so it can't be decided at plan time; a run-time move of the head would
  do it.
- **Travel is a teleport.** He's taken away out of view, or after a leap
  off a rim, and brought up a face near you. Nothing is simulated in
  between. The comeback took up to 28 s on seed 1, through the fallbacks
  (seen, then clean, then stepped).
- **The tilt moves the place, not everything on it.**
  - Runes, collectibles, the stage's crossings and heads on the ground
    don't ride a tipping stone, only the place's live host when the
    stone is most of the place. At 6-7° on the landing, a crossing's end
    steps by about 2 m for a second.
  - The tilt is strongest on the small landing. Consider less on
    `pounce`.
- **Wall picks are generic.** Any hull up to 9 m wide counts, so tall
  slabs of a stair or a coil can be the wall. In the city, most of what's
  in his way at his height are pillars and slabs.
- **Spans.** Sometimes a block under the span stays (it is over 26 m, or
  part of a place), and he drops 2 m onto it instead of falling.
- **The far-spawn rules** (round 10) still rarely fire, so the director's
  own rim search replaces them in roam mode.
- **The beat:** the dust wall of the shock ring reads as a white dome at
  close range.
- **The breach chunks** are plain boxes in the piece's material: mossy and
  bright under the dust.

## Animation notes (for a later round; no clips made)

- **The smash windup** (the breach's fists) pitches him far forward, like a
  dive, in `breach_127_1_fists`. A two-handed overhead hammer clip would
  read better and heavier.
- **Leaping off a rim** into the abyss uses the drop windup. It needs a
  "turn and go over" beat, with a look back at you.
- **The head-on beat** uses `triumph` (1.8 s). It wants a slower,
  heavier version for this moment: the head set, a long roar with the jaw
  open, then the fists. **Shift+O** pops the head on at once (dev only);
  in play it settles over `settle` (2.2 s).
- **Far climbs** take 9-14 s at 1.4 m/s. That is good spectacle, but the
  climb cycle shows its loop at that length.
- **No clip for crashing through a span:** a stumble and a grab at the
  edge before the fall would sell "cut off".

## Ideas for "harder for him to get his head" (not built; the user is musing)

- The head flees, scooting off its round, when the headless body is near.
  You can push it off a rim to delay him, and he climbs down after it.
- The head sits on a top you must pass. Taking its rune (or lighting its
  cresset) wakes the body; leaving it, he never comes.
- He has to carry the head up from below: it's on a lower isle, and the
  climb back with it in his arms is the window.
- A shrine you can break (a lid, a cage) holds the head. Breaking it costs
  time and noise, but locks him headless for the layer.
- He searches by hearing only; the head calls for him on a beat you can
  hear. Hushing it (standing on it, covering it) buys time.

## Model budget

No model was made or changed this round, so `docs/art/model-budget.md`'s
tricks don't apply. The breach and tilt add no geometry beyond the chunk
boxes (5-14 boxes a breach, freed after 30 s).

## Existing tests

- Nothing in `tests/` references the changed enemy, spawner, director or
  places code.
- `test_world_scale_guard.gd` and `test_world_scale_fit.gd` pass.
- Plans laid underground now hold 1-2 heads, not the old count. Their
  `heads` list differs from before, so a plan fingerprint taken under
  `--world=under` would change. No such test was found.
- The full suite wasn't run.
