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

- **Home comfort:** tree gathering carries a branch through the cave threshold.
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
favorites and remembered supplies. Main-game loading restores that controller. Imported scenery keeps its learned
familiarity when upgraded into editable objects. Editable trees offer fallen
material collection without borrowing their physics or rendering ownership.
Legacy documents start with the original routine and fresh living memory.
Unfinished activities resume safely idle; already committed consumption remains
committed, and unfinished source-backed fish carries retain the existing rollback.
Cave regeneration preserves room progression and supplies.

The fish document (`fish_state`) also carries the restock accumulator and the
pond's capacity. Its shape is checked key by key rather than by size, so a
document written before restocking — with or without `homes` — still validates
and loads; it simply starts its next fish from nothing and keeps the capacity
the scene seeded. Because caught fish keep their identity forever, the stored-id
and home limits rise from 128 to 512 now that the pond refills. Reopening a
saved world reseeds one fish per slot and then restores the stored ones, so the
exact live count of a long session is not reproduced; the pool level is, which
is all the food loop depends on.

This is a bounded slice: play has three placements and food does not spoil.
Fish are no longer finite — the pond restocks (see Food) — but only while world
time is moving: with the day cycle switched off the clock is frozen and so is
the pond. No new fruit flora or resource regrowth is simulated. Home
observation happens on entering the room, not through a general vision system
inside it. Existing tree interactions supply branches; a depletion model for
branch-producing trees is not yet implemented. The existing cave threshold still
transfers the actor to the downstairs room behind the entrance.

The new gestures reuse the authored SitDown/Sit/StandUp and carry clips with hand
and gaze targets. The character model and body scale are unchanged.

## Verification

- `test_bigfoot_life_mind.gd`: competing needs, fulfillment, cooldowns, familiarity,
  favorite places, bounded memory, corruption rejection and JSON round trips, plus
  the time-of-day modifiers, their need overrides and the no-clock defaults.
- `test_fish_restock.gd`: pure, with a stub scene — the two-day base rate, the
  night and post-rain multipliers and the rain's memory, the capacity ceiling,
  carried and reserved fish holding their slots, the saved accumulator's round
  trip, legacy documents, and the size of the `plenty` term.
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
