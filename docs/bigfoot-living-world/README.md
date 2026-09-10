# Bigfoot makes a home

Run `run-bigfoot-living-world.command` for the first living-world iteration built
on the two-story cave chunk. The older cave and lair launchers retain their
original routines. No campers, bridges or mountain climbing are added here.

Bigfoot now weighs hunger, tiredness, curiosity, comfort and the desire for
activity against available opportunities. Once he starts, he keeps the activity
until it succeeds or is interrupted. Unavailable routes back off, and quiet gaps
still allow wandering. His optional thoughts panel shows the last candidate
scores and reasons alongside his current needs.

## What to watch

- **Dead wood:** wind and storms tear branches out of the canopy and leave them
  on the walkable ground under the trees (`scripts/dead_wood.gd`). They are
  visible traces — a stick with a fork on the forest floor — that grey and settle
  as they age and are gone about four world days after they fell. While wood is
  lying within his reach it *is* the gather source: he walks to one branch, sits,
  picks it up and carries that one home, and the ground loses it. Watch a windy
  night, then the morning: branches under the trees, cleared one at a time.
- **Home comfort:** gathering carries a branch through the cave threshold.
  He sits and tends his bedding; one stored branch or leaf supply is consumed.
  The bed becomes visibly fuller through three stages. Once comfortable, it
  stops motivating further material trips.
- **Food:** existing fish catches retain their source identity through carrying,
  storage and consumption. He eats from his stash when hungry, with a hand-to-mouth
  gesture, and the visible supply shrinks. Fruit is preferred when supplied,
  though fruit-producing plants are not introduced in this iteration.
- **Fish return:** every seeded fish home is a slot, and a slot emptied by a
  catch fills again. The pond restocks toward its seeded capacity over about two
  world days (`RESTOCK_DAYS` in `scripts/fidelity_fish.gd`), twice as fast while
  `daylight < 0.35` and twice as fast again while the ground is wet, for half a
  world day after the rain stops. Progress is measured in world seconds from
  `scene.world_clock.elapsed`, so a paused or frozen sky holds the pond exactly
  where it is and a fast day breeds fish at the same visible pace; a scene with
  no clock at all falls back to a world day of 480 real seconds. A fish that is
  reserved, carried or merely swimming still holds its slot, so restocking never
  doubles a catch in progress and never passes capacity. Watch: he fishes at
  dawn, and a few days later there is something to catch again.
- **Curiosity:** nearby interests are filtered by distance and a conservative
  terrain/solid sight check. He approaches, pauses and looks. Completing an
  inspection makes that object familiar, reducing its appeal on later choices.
- **Ritual:** a successful short outdoor rest becomes a remembered favorite
  place. Future visits recheck the ground and choose another safe spot if needed.
- **Home awareness:** a visit compares belongings with what he last saw. Taking
  a stored item or disturbing the bed while he is away does not remotely alert
  him. He reacts when he returns and can inspect the changed belongings.
- **Play:** when fed and rested, he arranges three existing loose stones beside
  his bed into a small cairn. The arrangement persists.

## Time of day

The world clock (`scene.world_clock`, optional) contributes `hour` and
`daylight` to the decision context. Time only *bends* the utility scores; it
never schedules or forces an action, and a real need still overrides the
rhythm. With no clock the mind uses `hour = 12`, `daylight = 1`, and every score
is bit-for-bit what it was before time existed.

Two derived quantities drive everything:

- `darkness = 1 - daylight`
- `twilight = clamp(1 - |daylight - 0.5| / 0.25, 0, 1)` — a smooth bump peaking
  at the light/dark crossover and reaching zero outside `daylight` 0.25..0.75,
  roughly a ±1.5 h window around sunrise and sunset.
- `wary = darkness * (1 + caution)` — a cautious Bigfoot fears the dark more.

| Action | Modifier | Magnitude at full night (`daylight = 0`, `caution = 0.40`) |
| --- | --- | --- |
| `sleep` | `+ darkness * 0.45`, and the consideration threshold drops from `fatigue >= 0.30` to `fatigue >= 0.30 - darkness * 0.12` | `+0.45`; threshold `0.18` |
| `fish` | `+ twilight * 0.28`, and `+ plenty * 0.05` | `0` at night, `+0.28` at the crossover |
| `investigate` | `- wary * 0.26` | `-0.364` |
| `play` | `- wary * 0.20` | `-0.280` |
| `gather` | `- wary * 0.14` | `-0.196` |
| `ritual` | `+ twilight * 0.12`, dusk only | `+0.12` at dusk, `0` at dawn |
| `eat` | none | — |
| `check_home` | none | — |

The one term that is not about time is `plenty = clamp(fish_available / 3, 0, 1)`,
from the count of catchable fish the living world now puts in the decision
context. It is deliberately the smallest modifier in the table: a full pond
makes fishing slightly more tempting, and must never outweigh the gather term's
own comfort spread of `0.22`, or he stops improving his bed. A context without
`fish_available` scores exactly as it did before restocking existed.

The gather term carries the other non-time modifier,
`fallen = clamp(branches_nearby / 3, 0, 1)`, from the count of branches lying
within his 11 m gather reach: `+ fallen * 0.08`, and the reason becomes
"Branches are down under the trees". Like `plenty` it is deliberately small —
wood on the ground makes the errand easier, never necessary, and it stays well
inside the `0.22` comfort spread so a nearly finished bed still loses to a bare
one. A context without `branches_nearby` scores exactly as it did before dead
wood existed.

`mind.time_note(hour, daylight)` names the light for the player: `night`
(`daylight < 0.35`), `day` (`daylight > 0.85`), otherwise `dawn` before hour 12
and `dusk` after. Three reasons change with it: sleep becomes "Night has come;
returning to a familiar bed", fishing becomes "The fish bite at dawn/dusk" when
`twilight > 0.5`, and ritual becomes "A quiet evening ritual at a favorite
place" at dusk.

`mind.advance(delta, resting, comfort, daylight)` also feels the dark: fatigue
grows `1 + darkness * 0.30` times as fast when he is *not* resting, and
enrichment grows `1 - darkness * 0.25` times as fast. Both stay inside 30% so
the established need-timing expectations still hold, and resting recovery is
untouched — a bed restores the same amount at any hour.

## Weather

The sky (`scene._precipitation`, optional) contributes three more keys to the
decision context: `weather` (the current preset name, `"clear"` when there is no
weather), `wet` (`surface_weather.ground_wet`, 0..1, `0.0` when unknown) and
`sheltered` (true only while he is actually standing in his cave, i.e.
`routine.cave.sheltered()`). Like the clock, weather only *bends* the scores.
Without a sky, under a clear one, or on dry ground, every number is bit-for-bit
what it was before weather existed.

Two derived quantities drive everything:

- `storm = 1.0` for `storm`, `0.5` for `rain`, `0` for every other preset —
  only falling water counts, so `mist`, `overcast` and `autumn` change nothing.
- `exposed = storm` while he is outdoors, `0` while `sheltered` — weather he is
  standing in is the only weather that pulls him home.

| Action | Modifier | Magnitude in a storm he is out in |
| --- | --- | --- |
| `sleep` | `+ exposed * 0.50`, and the consideration threshold drops from `fatigue >= 0.30 - darkness * 0.12` by a further `exposed * 0.12` | `+0.50`; threshold `0.18` at noon |
| `investigate` | `- storm * 0.30` | `-0.30` |
| `ritual` | `- storm * 0.30 - wet * 0.15` | `-0.30`, and up to `-0.15` more on soaked ground |
| `play` | `- storm * 0.25` | `-0.25` |
| `fish` | `- storm * 0.25` | `-0.25` |
| `gather` | `- storm * 0.22` | `-0.22` |
| `eat` | none | — |
| `check_home` | none | — |

The errand penalties use `storm`, not `exposed`: setting out into the rain is a
poor idea whether he is currently dry or not. The shelter bonus uses `exposed`,
so a Bigfoot already in his cave gets no extra nudge toward bed. When
`exposed > 0.5` — a real storm, outdoors — the sleep reason becomes "Taking
shelter from the storm"; rain keeps the ordinary tired/night wording.

A need still wins: hunger 0.9 eats through a storm, and fatigue 0.95 sleeps
through a bright clear noon.

**Storms disturb the bed.** While he is outside, `bigfoot_living_world.advance`
accumulates storm hours from the world clock (`day * 24 + hour`, never engine
seconds, so a pause or a load cannot conjure weather). Every
`STORM_HOURS_PER_STAGE` (2.0) accumulated hours — a storm counts full, rain at
half, so about 2 storm hours or 4 rain hours — the room loses one `bed_stage`
through the same `lair.disturb_bed()` the study's **Disturb the bedding** button
uses, down to a floor of 0. The accumulator is capped at 4 banked hours and
catch-up is capped at one world hour per call. His remembered `_observed_bed` is
untouched: he discovers the loose bedding on his next `observe_home()`, which is
what turns `material_needed` back on and makes gathering attractive again. That
is the loop the slice adds — storm, damage, discovery, gather.

**The wind drops branches.** `scripts/dead_wood.gd` keeps a list of drop sites:
one walkable point under each tree the habitat reports, found with
`navigation.nearest_safe` and rebuilt whenever the habitat is. Every tick it
credits world days from `scene.world_clock.elapsed` (never engine seconds, and
at most `MAX_STEP_DAYS` = 1 per call, so a load or a fast-forward cannot bury the
forest) and adds `days * _drop_rate()` branches to an accumulator: 6.0 a day
under `storm`, 2.0 under `rain`, 0.35 otherwise, each multiplied by
`0.4 + 0.6 * (wind / 0.4)` from the precipitation study's own wind, capped at
twice the still-air rate. Whole branches fall onto a free site, at most
`MAX_BRANCHES` (12) at a time and never two within 1.1 m. Each one ages, greys
and settles from `WEATHERED_DAYS` (2.5) and is removed at `ROT_DAYS` (4.0).

`_material_targets()` returns those branches whenever at least one lies within
his gather reach; only when the floor near him is bare does it fall back to the
old tree list, so studies with no dead wood, and the first calm hours of a fresh
garden, gather exactly as they did before. A branch target always takes the
walk-and-sit path rather than the authored tree shake: `take_for_carry()` hands
the branch's own node to the carry, a cancelled trip puts it back where it lay
at the age it had, and a delivery removes it from the world for good.

## The season

The world clock's year (`clock.season`, 0..1; see docs/world-clock/README.md)
contributes four more keys: `season`, `season_name`
("spring"/"summer"/"autumn"/"winter"), `cold` (the winter chill curve,
`WeatherScheduler.season_cold`) and `harvest` (the autumn gold curve,
`WeatherScheduler.season_autumn`). Both curves are **zero through spring and
summer** and zero for a scene with no clock, which is why a study without a
calendar ranks bit-for-bit as it always did.

| Action | Modifier | Magnitude at the peak of the season |
| --- | --- | --- |
| `sleep` | `+ cold * 0.12`, and the consideration threshold drops a further `cold * 0.05` | `+0.11`; threshold `0.255` at noon in deep winter |
| `gather` | `+ harvest * 0.10` | `+0.09` in mid autumn |

Both are deliberately smaller than the weather's terms: a storm outranks the
season, and a need outranks both. The reasons name the year when it is the
loudest thing in the score — "The cold is in; a warm bed is worth the walk", and
"The leaves are down; good bedding is lying about".

The season also reaches him indirectly, through the world rather than the
scorer: the weather mix he lives under, the gold and cold on the ground, and how
fast the pond restocks (`fidelity_fish.SEASON_RATE`).

## Study controls

Compact **View**, **Activities**, and **Experiment** menus keep the landscape
visible. **Activities → Watch him choose** releases a manual invitation and
resumes utility choices. **Check his
home**, **Make the bed**, **Eat from his stash**, **Arrange his stones**, and
**Visit his quiet spot** invite the same actions the chooser uses. Invitations
need the actual resources and a safe route; they do not create meals or bedding.

**Disturb the bedding** removes one comfort stage. **Take one stored item**
removes a supply. Both leave his remembered state untouched until he observes
home again. **His thoughts** opens the developer inspector; H hides the study controls.
**Build / Enjoy** opens the existing terrain tools. P pauses
needs, movement and cave performances together.

## Persistence and limits

The existing world document saves room comfort/stone stages under the cave
state, plus a separate versioned `bigfoot_living` state for needs, familiarity,
favorites, remembered supplies and the storm-hour accumulator (`storm_hours`;
a document written before storms could reach the bed resumes with a dry
accumulator rather than being rejected). Main-game loading restores that
controller. Imported scenery keeps its learned
familiarity when upgraded into editable objects. Editable trees offer fallen
material collection without borrowing their physics or rendering ownership.
Legacy documents start with the original routine and fresh living memory.
Unfinished activities resume safely idle; already committed consumption remains
committed, and unfinished source-backed fish carries retain the existing rollback.
Cave regeneration preserves room progression and supplies.

The bed is the one belonging that can now degrade on its own: rain and storms
undo comfort stages while he is away, so bedding is no longer a one-way ratchet
to stage three. Nothing else decays — food does not spoil, the cairn stays
arranged, and the weather never damages the room itself.

The fish document (`fish_state`) also carries the restock accumulator and the
pond's capacity. Its shape is checked key by key rather than by size, so a
document written before restocking — with or without `homes` — still validates
and loads; it simply starts its next fish from nothing and keeps the capacity
the scene seeded. Because caught fish keep their identity forever, the stored-id
and home limits rise from 128 to 512 now that the pond refills. Reopening a
saved world reseeds one fish per slot and then restores the stored ones, so the
exact live count of a long session is not reproduced; the pool level is, which
is all the food loop depends on.

The forest floor saves as its own versioned `wood_state`: every branch's id,
place and age, plus the drop accumulator. It is validated key by key, so a
garden written before the wind dropped anything — carrying no `wood_state` at
all — loads onto a bare floor rather than being rejected, and a later slice may
add a key without invalidating today's documents. A branch in his hands when the
garden is saved is saved as a branch on the ground where it lay.

This is a bounded slice: play has three placements and food does not spoil.
Fish are no longer finite — the pond restocks (see Food) — but only while world
time is moving: the day cycle is on by default, but with it switched off (or a mood pinning the sky) the clock is frozen and so is
the pond. No new fruit flora or resource regrowth is simulated. Home
observation happens on entering the room, not through a general vision system
inside it. Branches now come off the weather rather than out of a tree on
demand, but the trees themselves are not depleted by losing them, and the drop
and rot rates do not yet follow the season (slice 4 multiplies `_drop_rate()`
and `rot_days()` in `scripts/dead_wood.gd`). The existing cave threshold still
transfers the actor to the downstairs room behind the entrance.

The new gestures reuse the authored SitDown/Sit/StandUp and carry clips with hand
and gaze targets. The character model and body scale are unchanged.

## Verification

- `test_bigfoot_life_mind.gd`: competing needs, fulfillment, cooldowns, familiarity,
  favorite places, bounded memory, corruption rejection and JSON round trips, plus
  the time-of-day modifiers, their need overrides and the no-clock defaults, and
  the weather modifiers, the shelter exemption and the clear/absent-sky defaults.
- `test_weather_bed.gd` (scene, Forward+): a storm he is out in loosens the real
  bedding on world time, his remembered bed does not change until he walks in,
  the discovery re-opens gathering, and the accumulator survives a save.
- `test_fish_restock.gd`: pure, with a stub scene — the two-day base rate, the
  night and post-rain multipliers and the rain's memory, the capacity ceiling,
  carried and reserved fish holding their slots, the saved accumulator's round
  trip, legacy documents, and the size of the `plenty` term.
- `test_dead_wood.gd`: pure, with a stub scene — the storm/rain/calm drop rates
  and the wind factor, the frozen clock, the one-day step guard, rotting, a
  simulated week whose branch count rises and falls, the carry's take/release/
  commit, the saved document and its legacy and junk cases, and the size of the
  `fallen` term.
- `test_dead_wood_scene.gd` (scene, Forward+): a storm over the real Fidelity
  world leaves visible branches on its terrain, `branches_nearby` counts the ones
  in reach, the branch replaces the trees as the gather source, and a real
  gather walks to one, carries it through the cave threshold and clears it from
  the ground.
- `test_bigfoot_lair_supplies.gd`: material/food consumption, visible bedding,
  persistent stone positions, capacity and source transactions.
- `test_bigfoot_living_world.gd`: real actor/cave performances, observations,
  interruptions, pause, saved state and an unprompted simulation run.
- `test_bigfoot_living_store.gd`: actual study-to-main save/reopen, editable-tree
  gathering, physical pickup interruption, and persistent home improvements.
- Existing cave, foraging, fishing and store tests protect threshold navigation
  and exact source ownership.

Scene integration uses native Metal Forward+ rather than the dummy renderer.
`tools/check_bigfoot_living_regressions.py` runs the repository tests sequentially,
retaining per-test logs and JSON results. Known Godot light-unpair teardown
messages are classified separately from clean passes and real failures.

All four new test scripts and the five post-fix scene checks passed. The full
197-test sweep remains non-green because of existing and unstable checks;
[the baseline audit](regression-baseline-audit.md) explains the comparisons.
[Verification results](verification.json) and [per-test evidence](regression-results.json)
retain the original failures alongside the follow-up checks.
