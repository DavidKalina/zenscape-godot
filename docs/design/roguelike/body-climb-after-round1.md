# Body climb-after, round 1: he climbs after you over ledges

The ask: "yes, have him climb after you over ledges".

The city climb round found that when you lose the whole Olmec by climbing
something he can climb, he scopes at the foot, loses sight of you and gives
up. Before this round he only came over the hauling lip when the lit brazier
drew him there. An older bug was related: "he gives up on long stairs out of
sight".

Branch `body/climb-after`, off `roguelike` (rebased onto 2e2d8198).

## Play it

    ./run-city-climb.command --underground=haze --no-brazier

Press 3 for the hauling lip. Let him see you on the shelves, climb over the
cornice and walk inland. He walks to his part of the face, lays a hand on it,
climbs, hangs his hands over the edge and hauls himself up. Then he looks
about (his periscope) and searches.

The long stair:

    godot --path . res://studies/city_landmarks_yard.tscn -- --no-title --underground=haze --no-fault

Press 5 for the stair foot. Let him see you, then run up. In the haze he loses
you on the first flight. He now follows you up rather than standing at the
foot.

## What changed

All the changes are in `scripts/enemies/headless_body.gd` and
`scripts/enemies/body_routes.gd`.

**Climbing after you** is on by default wherever the whole Olmec hunts. It
isn't limited to the yards.

1. **He goes after you when he loses you above his walk.** That means more
   than about 3 m over his feet: a lip, a ledge, a stair. He plans a route
   with his own planner, which walks, climbs (up to `climb_max`) and leaps.
   The route goes to the place he fits that is nearest where he last saw you
   (`_after_try`).
2. **He follows it to the end.** When he's near the foot he does his
   periscope first, as before. On the route he climbs the face, hangs his
   hands on the lip and pulls over (the climb and mantle he already had).
3. **On top he looks again.** His periscope is fresh up there, so he lifts
   his head and looks about. Seeing you means the hunt is back on.
4. **If you're not there, he presses on along your last way, as long as it
   went up.** The new spot is where you would be now at the pace he last saw
   you, rising as your way rose. He doesn't scope again on these pushes.
   - Your way comes from a 2.5 s trail of your feet while he could see you.
   - A climb straight up a face has no flat direction, so he carries on away
     from where he started.
5. **He gives up sensibly:**
   - He makes at most `after_tries` (3) routes per loss. A failed leg
     re-plans to the same place around that move, and that counts as a try.
   - He stops once you've been unseen for `after_for` (60) s.
   - He drops a route that doesn't get him up there.
   - After that he searches where he stands, gives up and goes back, as
     before.
6. **Seeing you changes the plan.** If he sees you again at about his own
   level, he drops the route and comes straight at you. If he sees you
   further up and you've moved more than 6 m, he plans again (at most every
   `chase_replan` s).
7. **Under you and out of reach,** he used to look about after 3 s. Now he
   first tries a route up to you.

**Walls taller than his climb stay walls.** The planner never climbs past
`climb_max`, so there's no route and nothing new happens. The breaks-2 rule
(`_hunt_wall` → `_chase_plan` with `chase_routes`) is untouched.

**Safe rooms** have three guards:

- **His planner.** He never routes into a place he doesn't fit. That covers
  the riser's shaft, the lip's undercut, the wrap's cell, the terrace's
  undercroft, the wedge's hollow and the mouse runs.
- **Your walker-only stone (new).** Routes planned after you don't climb a
  face where your walker-only shelves or ledges stand within his breadth
  (`Routes.shun_hers`, `_hers_on`: a box query on the walker-only layer).
  - Before this, he climbed after you straight up the lip's shelves column.
    He was in your lane for 181 frames, then mantled onto the undercut's sill
    and stood in the undercut.
  - Now he climbs his own zone of the face.
- **No room over a lip (new, everywhere).** If he is about to haul onto a lip
  with less than half his neck height of room over it, he lets go and falls.
  An undercut's floor under the cornice is one such lip. Any climb that
  wasn't planned could have pulled him into the undercut.

**A planner bug fixed (everywhere):** `Routes.between` cast its ray straight
down at the line between two columns. When a stair riser stood exactly on
that line, the ray slid down the riser's face and met neither tread. That cut
the landmarks' epic stair in two at its third landing (14.0 → 14.4), so
routes went round the pyramid instead. Now a missed ray is tried again 6 cm
either side. This is most likely the "gives up on long stairs" bug.

**Small change:** a mantle onto a lip he doesn't fit stays in `chase` if he's
hunting on a route (it was `roam`, which dropped the route).

## Knobs (body knobs, `--body-knob=k=v`)

| Knob | Default | What |
|---|---|---|
| `climb_after` | 1 | 0 turns it all off: he scopes and gives up at the foot, as before |
| `after_tries` | 3 | Routes per loss |
| `after_for` | 60 | Seconds unseen before he stops going after you |
| `after_ahead` | 10 × unit (≈11 m) | The shortest push on along your way |
| `after_wait` | 0.6 | Seconds unseen before he plans (sight flickers while you climb) |

Read-outs for checks: `afters`, `after_got`, `after_fails`, `after_why`,
`no_room_lips`.

## Proof

All runs used the real play loop, with your climbing by stick and jump. The
drivers are uncommitted in `scratch/`:

| Driver | What it runs |
|---|---|
| `after.gd` | The climb-after cases |
| `hunt.gd`, `climb.gd` | The climb round's drivers |
| `safe.sh` | Runs both sets; `LOOK=haze` or `torch` |
| `stair.gd` | The long stair |
| `refuge_*.gd`, `refuge_proofs.sh` | The refuges round's drivers |
| `cb2_*.gd`, `cb2.sh` | The breaks-2 drivers |
| `film_after.gd` | The stills |

Logs are in `scratch/logs/`.

**He follows over the top, without the brazier.** You start on shelf 4. He is
45 m off and sees you. You climb the last shelves and the cornice, then walk
9 m inland.

| Look | Over the top at | Frames in your lane | What happened |
|---|---|---|---|
| Haze | 27.2 s | 0 | Up top he saw you and pounced |
| Torch | 26.6 s | 0 | He pounced, then scoped, searched, gave up at 48 s and went back |

With `climb_after=0` (the baseline): scope, lost, gave up at the foot at
30.8 s. He never climbed.

**Safe rooms: 0 catches and 0 frames in your lane, in both looks.**

- **The climb round's hunts:** `lip_over`, `lip_hide`, `riser`, `terrace`,
  `wedge` and `wrap` all had 0 catches. The `riser_open` control still
  catches you (26 times).
- **New, `lip_hide` after a chase.** He sees you on the shelves and you duck
  into the undercut.
  - He climbs his own zone and is over at 24.0 s (haze) or 22.5 s (torch).
  - He scopes and looks on along your way, then searches, gives up (about
    45 s) and goes back down.
  - Catches: 0.
- **New, `riser_door`.** You come out on the summit and go back in onto the
  shaft's platform: 0 catches. He never saw you on the summit, so this
  doesn't test him on the summit by the door.
- **Refuges yard** (`refuge_proofs.sh`, both looks):
  - The slot wall, niches, gallery and stele results match the refuges
    round's log.
  - Frames in the walls and in the tier: 0.
  - The gallery chase with a lit torch now shows `after` beats when he loses
    you. He still never enters the tier.
- **Refuges yard, two failures that were already there.** "The echo turned
  him" fails in the mouse run, and "he lost you: seek" fails in the haze
  gallery chase with a lit torch. Both fail the same way on the code before
  this round (checked by restoring the old `scripts/enemies/`).

**The long stair** (landmarks yard, `--no-fault`, haze). He sees you at the
foot from 22 m and you run up four flights to 19.2 m.

| | Highest he got | Afters | Result |
|---|---|---|---|
| `climb_after=0` | 2.8 m (first flight) | 0 | Gave up at 29.6 s |
| Default, before the `between` fix | 4.8 m | 3 | Gave up; his routes went round the pyramid |
| Default | 22.1 m | 7 | Up by you at 67 s; he pounced and caught you on the summit |

**Breaks-2 yard** (`cb2.sh`):

- Plug, chock, corbel and the skin's peel all pass as in that round.
- Two fail: `chock --leapcheck` and `skin --lane`. Both fail the same way on
  the code before this round. They have drifted since breaks-2; this round
  didn't cause them.

**Smoke checks** (`tools/smoke.py`, 0 errors):

- the climb yard (plain, torch and haze)
- `city_breaks2_yard`, `city_refuges_yard` and `city_landmarks_yard`
- `run_layer --shape=sprawl --seed=1` (112 s to stand)

## Stills

These are in `captures/climb_after/` (gitignored), from
`scratch/film_after.gd --rendered`. The look is haze, with no brazier. Each
moment has two views: `<moment>_haze_pov.png` from where you stand on the
top, and `<moment>_haze_side.png` side on. The moments are `climb`, `hang`,
`mantle`, `pop` and `over`. I looked at them.

- **`hang_haze_pov`** is the user's image. Two great stone hands come over
  the edge with the head's warm glow between them, seen across the turf from
  where you hide. It reads well.
- **`climb_haze_side`** shows him on his own zone of the face. Your shelves
  are clear to the right.
- **`mantle_*` and `over_*`** don't work yet. His mantle landing's dust plume
  (an existing effect, `Dust.plume`, hh × 2.6) whites out the view from close
  by. The haze's dust reads pale and bright, and you lose his eyes in it.
  This round didn't change it (see the open questions).
- The yard's sight overlay lines (red and green) show in every still. J
  turns them off.

## Tests

None were added (prototyping). No test under `tests/` loads
`headless_body.gd`, `body_routes.gd` or the chase studies, so I expect none
to break. Two changes reach beyond the hunt:

- the `between` fix applies to every body's planner (generator bodies
  included)
- the no-room lip guard applies to every climb

The full suite wasn't run.

## Limits and open questions

- **The riser.** He came up after you only through his routes. When he does
  see you on the summit (rare in the dark), his route goes up the west
  cheek's side. He stalls at the cheek's front corner (his shoulders are
  wider than his planner's fit, the climb round's known limit). He then gives
  up after his tries. Should the riser's cheek corner be chamfered, as the
  wrap's was?
- **The mantle's dust plume** hides his eyes coming over the edge, from close
  by and in haze. Should it be smaller or darker when he hauls over (or only
  in the underground look)? A peer beat, where he holds at the top of the
  pull with his eyes just over the edge, would sell the image more.
- **After you, he is relentless on stairs.** On the long stair he followed,
  saw you near the top and caught you. Is 3 tries and 60 s the right
  patience?
- **The lip's back drops into the abyss.** Come over the top after you, he
  pounced. Once his landing knocked you off the back of the lip.
- **Single seeds and single starts.** Every proof is one run per look.
