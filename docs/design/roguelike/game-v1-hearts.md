# Game v1: hearts and damage (2026-10-14)

> Branch `feature/v1-hearts`, cut from `roguelike` at 76ee7b19. Part of the
> v1 stitch round.

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --underground=torch --seed=11
```

Drop off a high ledge, or find an Olmec body, and watch the corner.

## What was built

- **Hearts.** A run starts with 4 (`RunState.HEARTS`, the one constant).
  The gate doesn't refill them. A new climb (Space) or the same climb (R)
  starts at 4 again. They are kept per wanderer, keyed by his motor
  (`RunState.hearts`, `hearts_of`, `hurt`, `safe_for`, `cause_of`), so a
  second wanderer later gets his own.
- **One damage call.** `PilotMotor.harm(cause, amount, source)` emits
  `harmed(amount, cause, source)`. The motor keeps no hearts. The run loop
  listens (`RunLoop.watch(motor)`) and takes hearts off in its RunState.
  Every source calls `harm` next to its existing knock, so knock-back,
  stun and tumble behave as before:
  - **Fall**: in the motor's own landing code, both the normal landing and
    the knocked tumble's landing, with the same rules as the fall stun (no
    harm when sailing, and none from a slam unless `slam_stuns`).
  - **The Olmec** (`"olmec"`): the body's swat and pounce (`_catch`), its
    shove when it walks into him, its shockwave (both through
    `Enemy.shove_pilot`), and the head spitting him out (`_blast`).
  - **Other enemies**: `Enemy.shove_pilot` costs 1, named by
    `harm_cause()`. The plinth ram is `"ram"`; anything else is `"enemy"`.
  - **Traps and hazards**: the wind blaster and the wind horn (`Gust.knock`
    and the horn's ball, `"wind"`), the layer's gust arrows when they throw
    him (`"wind"`; the push he gets standing on the ground is free), being
    thrown off the tumbling block (`"trap"`), and Olmec-destruction stones
    and columns (`StoneBreak.hit`, `felled_column`, `"stone"`).
- **Safe after a hit.** He is safe for `RunState.SAFE` (1.6 s). While safe,
  his figure (the study's `body`) blinks at 12 Hz, shown 60% of each
  blink. Hits while he's safe still knock him but cost no hearts. **Falls
  always count**, even while he's safe: a knock off a ledge followed by a
  long drop costs both.
- **The void** still ends the run at once, whatever his hearts.
- **Death at zero hearts.** The run goes to a new `"dying"` state. He
  lies where he fell for 1.0 s (`DOWN_HOLD`), the dark comes in over 1.3 s
  (`FADE`, the void's own), and then the same card shows:
  - The title is `FELLED AT 412 m`; the void keeps `FELL FROM 412 m`.
  - The first fact names the cause: `by the Olmec`, `by the fall`,
    `by the ram`, `by a trap`, `by the wind`, `by falling stone`; the void
    says `into the void`.
  - All the words are in `RunLoop.WORDS` (`felled`, `cause_void`, `cause`,
    `causes`).
  - Retry and new seed work as before.
- **The corner.** Four hearts sit in a row under the height's hairline,
  drawn straight over the view with no strip behind them. Each is the
  HUD's faceted, carved glyph: a new `"heart"` icon in
  `scripts/hud_icons.gd`, a madder stone heart with a chevron and a stroke
  carved in it.
  - **Held**: the faceted glyph with a soft two-step drop shadow.
  - **Lost**: its pale silhouette (the `locked` variant) at 34%.
  - **Hit**: the lost heart pops. The lit glyph flashes, swells to 1.6x and
    fades off the empty one over 0.55 s. A low madder bloom shows at the
    screen's edge for 0.45 s.
  - **Last heart**: it beats gently, at 1.1 Hz.
  - The hearts never drop below 60% alpha while he moves; the height sinks
    to 28%.

## Numbers and why

| Number | Value | Why |
|---|---|---|
| `RunState.HEARTS` | 4 | The brief's number; one constant to change. |
| `PilotMotor.FALL_HURT_PUMPS` | 6 pumps (9 m at wanderer 1.0) | Half again the fall that stuns (4 pumps, 6 m). A 6 to 9 m drop is still only the stun's setback, so ordinary isle-to-isle drops stay free. About 7.5 times his height. |
| `PilotMotor.FALL_HARD_PUMPS` | 12 pumps (18 m) | Twice the hurt height, three times the stun's. A drop that really costs. |
| Roll out of a fall | -1 heart | The tech roll already cancels the stun. Making it save a heart rewards the skilled landing (rule 0). |
| `RunState.SAFE` | 1.6 s | Longer than the motor's `RESTUN_GAP` (1.2 s), so the bump that stunned him can't take a second heart while he gets up. Short enough that a fresh blow soon after counts. |
| Falls ignore SAFE | - | Being knocked off an edge is what makes a hit deadly (rule 3). |
| `RunLoop.DOWN_HOLD` | 1.0 s | Long enough to see him lying there before the dark comes. |
| Flicker | 12 Hz, 60% on | The classic readable i-frame blink. |
| `HEART` / `HEART_GAP` | 24 / 4 design px | Small but readable at 1080p. |
| `POP`, `BLOOM`, `BLOOM_A` | 0.55 s, 0.45 s, 0.4 | Quick enough to read without staying on screen. |

The fall thresholds are in pumps, his pump height times a count, like the
stun's. `set_size` scales the pump with the wanderer, so the thresholds
follow `WorldScale.wanderer`.

## Checks

These were prototype-round checks. No committed tests were added and the
full suite was not run.

- **Headless import**: clean.
- **Smoke** (`tools/smoke.py`): `run_layer --shape=sprawl --underground=torch`
  and `trap_yard`, 400 frames each, 0 errors.
- **Throwaway driver** (`scratch/hearts_check.gd`, uncommitted, through
  the real loop on seed 11 with `--knob=heads=2`): 22/22 checks pass.
  - **Falls**: a 7.2 m drop is free, 12 m costs 1, 20.4 m costs 2.
  - **Flicker**: he blinks while safe and is shown again after.
  - **The swat**: the body's own swat costs 1, tumbles him, and knocks him
    back 4.5 m. The cause is "olmec". A second hit at once costs nothing.
  - **The shockwave**: it costs 1.
  - **At none**: the run goes to `dying`, then the card reads
    `FELLED AT 0 m / by the Olmec`.
  - **Retry**: R gives back 4 hearts.
  - **The void**: it still ends the run with 4 hearts, and its card reads
    `into the void`.

  The driver forces the body's attack decision (`_attack`). The swat and
  the shockwave are then the body's own, and they land through its tick
  and the real motor.
- **Rendered stills** (`scratch/hearts_shot.gd`): the full row, the hit
  pop, the flicker, the last heart and the card. I looked at each one.
- `test_glyph_token.gd` passes with the new heart glyph.

## Existing tests this breaks

None known. The tests weren't run beyond `test_glyph_token`. `harm` only
emits a signal, and nothing listens outside the run loop. The only change
to the card's facts is that a cause line now comes first, at index 0;
none of the tests I searched reads them.

## Seams

- **Hearts are on the overlay's readout, not with the collectibles'
  tallies.** Per the user's late note, the hearts use the HUD glyphs with
  no linen strip. The rune count is still the old small-caps text; the
  `rune` glyph is in `hud_icons.gd` if the collectibles round wants it.
- **Wind costs a heart.** The brief says traps and hazards each cost 1, so
  the wind blaster, the horn and the gust arrows hurt even when used as a
  launcher. If that makes the blaster feel like a punishment rather than a
  tool, drop the `harm` in `scripts/traps/gust.gd`.
- **The motor's figure blink** toggles `study.body.visible`. Nothing else
  sets that today. If something starts to, the two will fight.
- **The record file**: my first two driver runs wrote the player's real
  `user://run_record.json` (runs and deaths went up by a few; the highest
  was not lowered). The drivers now point `RunState.record_path` at a
  scratch file.
- **Errors on retry**: retrying (R or Space) logs 9 freed-instance
  errors (`gb_stacked_court.gd:630`, `motif_isle.gd:339`). The same errors
  show on the base `roguelike` commit; hearts didn't cause them.
- **The shockwave check is a little flaky.** If the body is mid-climb, the
  wave can miss him (by design: jumped clear, or out of its band).
- **Shared code touched** (small, for the coordinator's merge):
  - `run_loop.gd`: the card title and facts (`card_title`, `card_facts`,
    the new `cause_line`) and `WORDS`. The record's wording belongs to the
    climb agent; only the cause line and `FELLED AT` are mine.
  - `run_overlay.gd`: the hearts row and the bloom.
