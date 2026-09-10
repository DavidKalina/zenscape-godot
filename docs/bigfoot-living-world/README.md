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

This is a bounded first slice: fish are finite, play has three placements, and
food does not spoil. No new fruit flora or resource regrowth is simulated. Home
observation happens on entering the room, not through a general vision system
inside it. Existing tree interactions supply branches; a depletion model for
branch-producing trees is not yet implemented. The existing cave threshold still
transfers the actor to the downstairs room behind the entrance.

The new gestures reuse the authored SitDown/Sit/StandUp and carry clips with hand
and gaze targets. The character model and body scale are unchanged.

## Verification

- `test_bigfoot_life_mind.gd`: competing needs, fulfillment, cooldowns, familiarity,
  favorite places, bounded memory, corruption rejection and JSON round trips.
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
