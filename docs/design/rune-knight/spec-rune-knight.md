# Spec: the rune knight, a greybox enemy (loop `rune-knight`)

A new enemy, greyboxed so the user can play it and judge whether it fits.
The rune knight is a stone knight, taller and broader than the wanderer
but nowhere near the Olmec head's bulk (about 1.6x the wanderer's height,
from `WorldScale`, not a copied number). He patrols the aqueduct on the
aqueduct isle. He grabs wind out of the air and throws it at you as an
arc. When you shoot a wind blast at him, he catches it and blasts it back:
tennis.

Branch `iter/rune-knight`, worktree `.claude/worktrees/iter-rune-knight`.
Cap and budget: the skill's default.

## Done looks like

`./run-aqueduct-isle.command --rune-knight` (or `godot --path .
res://studies/aqueduct_isle.tscn -- --no-title --rune-knight`) puts you on
foot on the isle, and:

1. **He patrols the aqueduct.** He stands on the aqueduct's deck (its
   walkable top, the one the foot route's rope beams hang from;
   `studies/aqueduct_isle_art.gd` `TOP` and the deck's ends) and walks it
   end to end, turning in planted steps at each end. He collides with the
   wanderer: you can't walk through him. Heavy, deliberate walk.
2. **He sees you.** In range and in sight (from the deck or the meadow
   below), he stops, turns to face you and tracks you. Out of sight long
   enough, he goes back to patrolling.
3. **He grabs wind and slashes it at you.** His main attack is an arc of
   air, like a sword beam: a crescent blade of wind cut off his arm, not a
   ball tossed on an arc. The tell, readable from a distance: the air
   visibly streams into his right gauntlet and builds along his forearm
   into a blade of wind (about a second, runes lit). Then a big sweeping
   slash, wound up and followed through, and the crescent leaves along the
   slash's line: wide, thin, flying flat and fast-ish in a straight line,
   its curve the slash's curve. Horizontal slashes you jump over; diagonal
   or vertical ones you sidestep; he picks between them, and the pose
   tells you which before it leaves. A hit knocks the wanderer with the
   shared gust knock (`scripts/traps/gust.gd`), so it can throw you off
   the aqueduct or across the meadow. The lobbed ball built in task 2
   stays as a knob (`attack`: `slash` the default, `lob`), not his main
   move.
4. **Tennis.** The wanderer has a wind blast (see "The player's blast").
   A blast that comes at the knight from in front of him, within his
   reach, he intercepts: he catches it (the wind wraps round his hands, a
   short hold so you see it), then wraps it onto his blade and slashes
   it back at you as a crescent, faster than it came. You can blast the returned shot back at him. Each return in a
   rally is faster and gives him less time; past his limit he misses it,
   it hits him, and he staggers back heavily (a few steps, off balance; at
   the deck's edge, over it). A blast from behind or the side hits him
   without a catch. How a hit wears him down and how he dies: "His runes,
   his deaths, his drop" below.

Every shot, his and yours, is a visible thing in the air with a readable
silhouette, and every phase (patrol, notice, gather, slash, catch, return,
stagger) reads at a glance in a still.

## The player's blast

The real one is on main now (merged at b6602a4f): **lock-on**
(`scripts/lock_on/foot_lock.gd`: R3 / Tab / middle mouse locks the nearest
`lock_targets` member that answers `aim_point()` and `tall()`) and the
**gust shot** (`scripts/lock_on/gust_shot.gd`: X with updraft charge; a
locked shot homes and calls `hit(at, way, strength)` on its target, its
strength from the charge spent). Read `docs/design/lock-on/handoff-lock-on.md`.
These are the player's side of the knight; extend them additively and
keep the target stone working as before.

- **He is a lock target.** In `lock_targets`, `aim_point()` his chest,
  `tall()` so the marker hangs over his helm, while he stands; off the
  list while he's down off the deck only if that reads better in play.
- **The gust shot knocks him back.** `hit()` shoves him along the shot's
  flat way, farther with more strength, into a heavy stagger (the
  `stagger` clip, planted steps, real weight); at the deck's edge, over
  it, as task 4 built for a miss.
- **Tennis on the real shot.** A gust shot that reaches him from in front
  while he is under his rally limit he catches instead (the task-4 catch,
  then `_send_return`). From the side or behind, or past his limit, it
  knocks him back. Fired while his return is coming at you, your gust
  ball meets it in the air and sends it back at him, the way the stand-in
  does. The gust shot's balls have to be readable by the knight for that;
  the smallest additive seam in `gust_shot.gd` (e.g. its live balls in
  the `wind_shot` group, or a query) is fine.
- **From the meadow:** the deck's buttresses pop a shot aimed from below
  (found in task 4). A locked homing shot should be able to reach him
  from the meadow; fix the line, not the stone.
- **The Z stand-in stays** as a dev key that needs no charge, for checks
  and quick play; X is the game's blast.

## The parry (spec change after the user played the slash)

The wanderer's answer to wind thrown at him. **RB (Q on keyboard), the
updraft button, pressed at the right moment parries a shot and he absorbs
its wind** into his wind gauge (`scripts/updraft.gd`, `scripts/wind_gauge.gd`;
read `docs/design/wind-gauge/handoff-wind-gauge.md`).

- **What can be parried:** any `wind_shot` thrown at him that isn't his:
  the knight's crescents (level and high), his rally returns, the lob.
- **Tricky but satisfying** (the user's words). The window: the press
  counts as a parry when the shot will reach him within 0.15 s (time to
  contact, a knob). A fair cue: a shot entering parry range gives a small
  flash or ring just before contact, so the player times a cue, not a
  guess. A press outside the window with charge is the plain updraft, as
  today (spends a segment, lifts him), so a mistimed parry still has its
  own use against a level slash. An empty press (no charge, outside the
  window) locks the parry out for about 0.4 s, so mashing fails. A parry
  press needs no charge.
- **Absorb:** the shot is gone, its wind visibly spirals into him (the
  crescent unwinds into streaks drawn to his chest), about 0.1 s of
  hit-stop, a camera punch, a flash and a sound sell the timing, and the gauge gains a full segment (capped at
  full), pulsing as a filled segment does. A late press is a hit as now.
- **The loop it closes:** the segment he absorbs pays for the X focus
  blast back at the knight, so parry then blast is the rally from the
  wanderer's side. Blasting a crescent back mid-air (Z, or X when the
  ball meets it) stays as built.
- **A pose:** a quick guard-and-draw-in on the wanderer while he absorbs
  (procedural is fine for this round; the wanderer's clips are authored,
  so keep it a light layer over them).
- **Code:** its own file (e.g. `scripts/wind_parry.gd`), hooked into the
  updraft press additively: the updraft asks the parry first, then does
  what it does today. Off the isle and without `--rune-knight` nothing
  changes, except that a parry seam other wind can join later.

## His runes, his deaths, his drop (spec change: the user's go)

The fight has a goal: wear him down or knock him off the aqueduct.

- **His runes are his health.** Three: chest, left gauntlet, right
  gauntlet. No health bar; you read him off his body. A **rally miss** (a
  return past his limit hits him) cracks one rune: it splits, flickers
  and goes dark. Hits from the side or behind crack nothing; they shove.
- **Knockback is a heavy skid**, not a stumble: he stays on his feet and
  scrapes back along the deck, dust off his heels, fighting to stop.
  Starting values (knobs, tune by play): a side or back hit (X) 3 to 4 m;
  a rally miss 6 to 8 m plus the crack. The deck is narrow, so a hit
  from the side is the way to put him off it.
- **The teeter.** A skid that ends at the deck's edge leaves him
  teetering about a second: arms wheeling, runes flickering, over the
  drop. Any hit during it sends him over. A skid that carries well past
  the edge sends him straight over.
- **Death one, broken:** all three runes dark, he drops to one knee, the
  wind going out of him. One more hit and he crumbles to a heap of
  blocks, and the last of his wind bursts out of him: a wind shot the
  wanderer can parry to absorb (a full gauge, every segment).
- **Death two, off the edge:** he falls from the deck and shatters on
  the meadow below (his blocks thrown apart, runes out), whatever his
  runes.
- **The drop: his core rune.** Where he dies (in his heap on the deck, or
  where he shattered on the meadow) his core rune rises and hangs,
  glowing, until the wanderer walks into it. Taking it marks a ledger
  objective (`scripts/ledger/ledger.gd`, `data/ledger/`; read
  `docs/design/ledger/round1.md`): a new type `rune` with its own card row
  (e.g. "guardians"), the objective `aqueduct_isle/rune_knight` in
  `data/ledger/ruins.json`. Additive: tokens and every other row
  unchanged; the ledger's registry errors stay empty.
- **Staying dead.** Once the rune is taken he is gone for good (not
  placed on later runs, as a taken token isn't). Killed but his rune not
  taken, he reforms on the deck when the isle is next loaded.
- **Contract additions:** clips `skid` (`plant`, `end`), `teeter`
  (`end`), `kneel` (`end`), `fall` (`land`), `shatter`, `crumble`; effect
  `rune_crack` with a form per rune (`chest`, `hand_l`, `hand_r`).
  Procedural on the stand-in this loop; the Blender body lane authors
  them later.

## The brutal parry, the riposte, the brace (spec change after the user played task 8)

The user played the parry of task 7: "way way too easy. I want it more
like dark souls. Like you have to eye it. Satisfying, brutal window."
This section overrides the parry's window, cue and lockout above.

- **No prompt.** The cue ring is off (kept as a knob, `cue`, default
  off, for checks). The player reads his windup and the crescent itself.
- **A brutal window:** about 0.1 s (six frames) of time to contact, a
  knob. Tune it by play, not by drivers.
- **Whiffs are punished.** While one of his shots is coming at the
  wanderer (it will reach him within about 0.6 s, a knob), RB / Q is a
  parry attempt only, never the updraft. Inside the window: the parry.
  Outside it: a whiff: the guard pose held about 0.5 s with no other
  action, and a hit taken in it knocks harder. With nothing coming at
  him, RB / Q is the updraft (and the slide boost in a slide) as always.
  The 0.4 s lockout of task 7 goes; the whiff replaces it.
- **The payoff stays and grows:** the hit-stop, camera punch, sound, the
  wind unwinding into him, the gauge segment. Make the landed parry the
  best-feeling moment in the fight.
- **The riposte.** A parry rips his own wind from him: he reels (a new
  clip `reel`, beats `open`, `end`), runes flaring, open about a second
  (a knob). An X gust shot that reaches him in the reel can't be caught,
  and from any side it cracks a rune and skids him as a rally miss does.
  It needs the segment the parry gave. Parry then riposte is the skilled
  way to wear him down; the rally the patient way; the edge the
  positional way.
- **The brace.** A hit from the side no longer throws him straight off
  the 2.5 m deck: he braces and his skid turns along the deck, so the
  side shove ends at the lip as a teeter at most. A knock-off from the
  side takes a teeter and a second hit. A rally miss from the side still
  carries him straight over; a riposte never does (see below).

## The riposte spills his runes; no kill on a parry (spec change after the user played task 10)

The user: "we need the runes to spill out of him on riposte. But you
shouldn't be able to kill on parry. But you should be able to get him
down to a one-shot."

- **The spill.** A riposte that lands bursts the cracked rune out of
  him: glowing rune shards and its light pour out of the groove and
  scatter round him on the deck, flaring then guttering out over a few
  seconds. The best-looking hit in the fight; bigger than a rally miss's
  crack.
- **No kill on a parry.** A riposte never ends him. It cracks runes down
  to the last state (all three dark, kneeling: one hit from death), and
  its skid never carries him off the deck: a riposte from the side stops
  at the lip as a teeter at most (the brace, for this hit too). The kill
  is always a separate hit after: X on the kneeling knight, or a hit
  while he teeters.

## The leap: down to the meadow and back up (spec change: the user's ask)

So the fight has room, he isn't stuck on the deck: he leaps down to the
meadow to come for you, and if you climb onto the aqueduct while he's
below, he leaps straight back up to it.

- **Down:** when the wanderer is on the meadow near the aqueduct and he
  has had no clean slash at him for a while (the buttresses in the way,
  a knob in seconds), or the wanderer is close below, he walks to the lip
  over him and leaps down, landing near him on the turf.
- **Up:** when the wanderer is on the deck and he is on the meadow (after
  a leap down, or after a teeter he recovered from below), he goes to the
  aqueduct's foot below the wanderer, crouches and leaps straight up onto
  the deck. The deck is about 10 m above the meadow; a huge, deliberate
  leap for stone: a deep crouch (the tell), the launch, a hang at the
  top, a landing that shakes.
- **The landing hits.** Each landing throws a ring of dust and wind: a
  wanderer within a few metres is knocked (the gust knock, a knob). It's
  a wind shot in every other way, so it can be parried, a brutal one
  timed to the touchdown.
- **On the meadow he fights as on the deck:** patrol is off, he tracks,
  slashes, catches, rallies, skids (no lip, so no teeter; a skid into the
  aqueduct's wall stops him). Knocked off the deck is still a fall and a
  shatter; a leap is controlled and he lands it.
- **He goes home:** with the wanderer gone a while, he leaps back up and
  walks his patrol again.
- **Contract additions:** clip `leap` with form `down` or `up`, beats
  `crouch`, `launch`, `apex`, `land`, `end`.
- **Routes:** find the leap spots from the aqueduct's real shape (where
  its foot meets turf on each side, clear of the buttresses, the stair
  and the foot-route ropes), not from guessed numbers. The landing strip
  stays clear (AGENTS.md, Motifs): he never stands on it as a rule.

## Runes that really spill; he moves while he fights (spec change after the user played the real body)

The user: "I want runes to actually spill out. And I want him to
actually be able to walk a bit while on the ground. And kinda strafe
around you."

- **The runes spill out, as the collectible runes.** The user: "I want the
  real, physical collectible runes that we litter throughout the map to
  spill out." A riposte that cracks a rune bursts out a real glyph token,
  the same pickup the isles lay (`scripts/glyph_pickup.gd`, laid by
  `scripts/kit_isle/kit_tokens.gd`; same look, halo, pickup reach, readout
  climb and chime). It pops out of the tablet, arcs out and bounces to rest
  on the deck or turf near him (never off the deck's side or the island's
  rim, never inside stone), and waits there to be walked into, mid-fight
  or after. Each is a ledger objective in the isle's glyphs row (the
  `token` type), one per tablet: `aqueduct_isle/rune_knight_hand_l`,
  `_hand_r`, `_chest` in `data/ledger/ruins.json`, so the isle's glyph
  count grows by three. A token taken stays taken (saved); a knight who
  reforms cracks that tablet again without spilling it. A spilled token
  not taken is gone when the isle reloads and spills again next fight.
  Only a riposte spills one (a rally miss cracks without a spill), so the
  skilled way pays. The crack seam and a short flare of light stay; the
  task-12 shards go or shrink to a little grit round the token.
- **He walks while he fights.** Engaged on the ground (the meadow, and
  along the deck as far as it allows), he doesn't stand planted between
  moves: he closes or opens distance at a walk toward the range he slashes
  from, and **strafes round you**, side-stepping in a slow circle while
  he keeps his helm on you, changing direction now and then, stopping to
  gather and slash. On the 2.5 m deck the strafe is a step along it, never
  off it; on the meadow a real circle, kept off the aqueduct's wall and
  the island's rim and clear of the landing strip.
- **Clips:** `strafe` with forms `left` and `right` (a heavy side-step
  with planted feet, `plant` per footfall, helm and chest kept on you)
  and `walk` with form `back` (backing off a step at a time), authored in
  Blender in `art/blender/rune_knight/rune_knight_clips.py` to the same
  bar as the rest, exported to the glb, wired in the body script; the
  stand-in gets plain procedural versions so `--rune-body=standin` still
  plays.

## Where code goes

- `scripts/enemies/rune_knight.gd`: the knight (body, patrol, sense,
  gather, throw, catch, return, stagger).
- `scripts/enemies/wind_shot.gd`: the shot both sides throw (flight on an
  arc or straight, look, hit, catch, reflect).
- The stand-in blast in its own file.
- `studies/aqueduct_isle.gd`: the `--rune-knight` flag and a small,
  additive hook that places him (the way `--watcher` is placed). Off by
  default; nothing else on the isle changes.

He is not an `enemy.gd` field enemy and not in the motif editor in this
loop (the `editor-enemies` loop is queued separately); keep his knobs in
one dictionary at the top of his script so either can adopt him later.

## Look and animation (greybox)

Greybox: his body from primitives (a blocky helm, a broad chest, pauldrons,
gauntlets big enough to read the catch, legs), stone material from the
kit's look, a few rune lines on chest and gauntlets that glow when he holds
wind. Animate by procedural key poses on those parts (anticipation before
the throw, a hold on the catch, follow-through after the throw, a heavy
settle on each step), not authored Blender clips: those come if the user
keeps him. Note in the handoff which `docs/art/model-budget.md` tricks
would apply to a real model.

## The contract (skill `enemy-build`)

This loop is the mind lane. A Blender body lane opens after the user has
played the greybox and keeps him, so the greybox body is a **stand-in**
behind the API below, and the real body drops in without the mind
changing. Names here are final once built on; change one only by a
`spec change` commit.

- **Body API** (`scripts/enemies/rune_knight_body_standin.gd`):
  `play(clip, form := "")`, signal `beat_reached(clip, beat)`,
  `socket(name) -> Node3D`, `set_effect(name, on)`. The mind drives the
  body only through these. A clip's `form` picks its variant: `gather`
  "blade" (the wind drawn into the right gauntlet; "" the two-handed ball
  of the lob), `slash` "level" or "high".
- **Clips and beats** (lengths are the stand-in's starting values; the
  mind waits on beats, never on its own timers for body motion):
  `idle` (loop), `walk` (loop; beat `plant` per footfall), `turn`
  (`plant`), `notice`, `gather` (`grab`, `full`), `slash` (`release`; the
  windup tells horizontal or diagonal), `throw` (`release`; the lob knob),
  `catch` (`contact`, `hold`), `return` (`release`), `stagger`
  (`plant`, `recover`). Every one-shot clip (all but `idle` and `walk`;
  `turn` loops too) also sends `end` at its length, so the mind can wait
  on a clip with no beat of its own (`notice`) or on its follow-through.
- **Sockets**: `hand_r`, `hand_l`, `hands_mid` (where a held shot sits),
  `blade` (along the right forearm, where the wind blade forms),
  `chest_rune`, `eye`.
- **Shape**: capsule radius and height, eye height, reach (the catch
  range) and stride, all from `WorldScale` and his knobs.
- **Effects**: `rune_glow` (lines lit while he holds wind),
  `wind_gather` (streaks drawn into `hands_mid`, or into `blade` before
  a slash), `wind_blade` (the blade of air along his forearm).
- **Contract additions (task 12):** effect `rune_spill` (form: the rune's
  name; one-shot: the riposte's spill), clip `gone` (over the island's
  rim, out of sight below: the body hides; `death` "gone").

## Tasks (the first iteration orders these; keep each one a checkpoint)

1. His body on the deck and his patrol, with the flag. Still of him on the
   aqueduct.
2. Sense, the wind gather tell and the arcing shot that knocks you.
   Stills of the gather and the shot in the air; a play-loop check that a
   hit knocks the wanderer.
3. The stand-in player blast and the shot group seam. Still of your shot.
4. Catch and return, the rally speeding up, the miss and his stagger.
   A play-loop check of a rally (blast, catch, return, blast back) and of
   a miss; stills of the catch and the stagger.
5. Lock-on and the gust shot on him (spec change after the user pushed
   lock-on and the gust shot to main): lock target, knockback from
   `hit()`, catch and rally on the real shot, the meadow line. Play-loop
   checks through the real inputs (lock key, X with charge set): lock
   him, a hit from the side knocks him back, a hit from in front is
   caught and returned, X blasts the return back, a hit at the edge puts
   him over. Stills of the lock marker on him and the knockback.
6. The slash (spec change after the user played task 2): the blade
   tell, the `slash` clip (horizontal and diagonal), the crescent shot
   (a shape of `wind_shot.gd`, same group and seam), the `attack` knob,
   and his return in a rally becomes a slash. Stills of the blade tell,
   both slashes and the crescent in flight; play-loop checks that a
   jump clears a horizontal crescent, a sidestep a diagonal one, and a
   hit knocks.
7. The parry (above): the window, the absorb into a gauge segment, the
   look and hit-stop, the pose. Play-loop checks through the real RB / Q
   press: a timed press on a level and a high crescent absorbs it and
   fills a segment; an early press is the plain updraft; a late press is
   a hit; parry then X lands a blast on him. Stills of the absorb.
8. His runes and the heavy knockback: three runes, the crack on a rally
   miss, the skid (side or back 3 to 4 m, miss 6 to 8 m), the teeter at
   the edge. Play-loop checks: a miss cracks a rune, a side hit skids him
   3 m or more, a skid to the edge teeters him and a hit then puts him
   over. Stills of a cracked rune, the skid and the teeter.
9. Both deaths: kneel then crumble after the third rune, with the last
   wind burst you can parry; the fall and shatter off the edge. Play-loop
   checks of each death; stills of the kneel, the heap and the shatter.
10. The brutal parry, the riposte and the brace (above). Play-loop checks
   through the real presses: a press 0.05 s before contact parries, one
   0.2 s before is a whiff that holds him and the shot knocks him harder,
   Q with nothing coming is the updraft, parry then X in the reel
   cracks a rune, X after the reel is caught as before; a side X on
   the deck teeters him at the lip rather than throwing him over, and a
   second hit then puts him over. Stills of the reel and the riposte.
11. The leap (below): down to the meadow, back up to the deck, home again,
   the landing's knock. Play-loop checks: the wanderer on the meadow
   with no clean line draws him down; climbing the deck brings him up;
   the landing knocks a wanderer near it and a timed parry takes it;
   he fights on the meadow (slash, catch, skid into the wall). Stills of
   the crouch, the apex and the landing.
12. The riposte's spill and no kill on a parry (above). Also the
   island's own rim (found in task 11): a skid on the meadow that would
   carry him off the island is an edge like the deck's (brace, teeter,
   a hit puts him over; a riposte never does), and a knight gone over the
   rim falls a little way, then is dead (gone below, his rune with him). Play-loop checks:
   a riposte from the side at the edge leaves him teetering, not over;
   three ripostes leave him kneeling, alive; X then crumbles him. Stills
   of the spill.
13. The core rune and the ledger: the drop where he dies, taking it marks
   `aqueduct_isle/rune_knight`, he stays gone once it's taken and reforms
   if it wasn't. Play-loop checks across two runs (`--ledger` /
   `--fresh-ledger`, as tests/test_ledger.gd runs them); still of the
   rune hanging and of the isle card's new row.
14. A feel pass on the mechanics, on the stand-in (the real body is coming
   from the body lane, so leave poses alone): timings from the stills and
   checks; the known bugs (a fall that "lands" without dropping leaves him
   down for good; the leftovers in the trail's notes); the camera shake on
   a leap's landing; the shatter and the spill read from the game camera
   (bigger shards, a shatter clear of the arch bays where it can be);
   bring the scratch drivers up to today's rules (the brace, the brutal
   parry) so every one passes again, and list them in the commit so the
   body lane and the trunk can rerun them.
15. After the body lane merges (skill `enemy-build`, Trunk): the real body
   in behind the API, procedural layers (feet on the real ground, hands
   to the real target, the eye glow on notice), timings re-tuned to the
   real clips, every driver passing on the real body, and a short
   rendered clip (a few frames strung) of one full fight: slash, parry,
   blast, rally, a parry and riposte, a crack, the knockoff.
16. The collectible runes spill (above): a riposte bursts out that
   tablet's glyph token. Play-loop checks through the real presses: a
   riposte spills one token that comes to rest on the deck; walking into
   it marks `aqueduct_isle/rune_knight_<tablet>` and the readout climbs;
   next run (a named `--ledger` file, as rk_core does) a reformed knight's
   riposte on that tablet spills nothing; a rally miss spills nothing;
   no token rests off the deck or in stone. Stills of the burst and the
   token at rest. The ledger's registry errors stay empty (the test that
   counts objectives will need its numbers; list it).
17. He walks and strafes while he fights (above): the `strafe` and
   `walk back` clips in Blender and the stand-in, the mind's footwork on
   the meadow and the deck. Play-loop checks: on the meadow he circles
   the wanderer both ways keeping his facing, closes to slash range and
   backs off; on the deck he steps along it and never off; he never walks
   into the landing strip, the wall or the rim; every older driver still
   passes. Stills and a short clip strip of the strafe.

## Checks

- Smoke: `studies/aqueduct_isle.tscn` with `-- --no-title --rune-knight`,
  and once without the flag (unchanged isle). Both PASS.
- Play-loop checks through `tools/drive.py` (scratch, uncommitted) for
  every played behaviour above.
- Stills with `tools/shot.py`, always `-- --no-title --rune-knight`.
- Prototype rules: no committed tests, no full suite. The handoff lists
  any existing test the change breaks.
