# Handoff: the Olmec as a mini boss (loop `olmec-boss`)

Spec: `spec-olmec-boss.md`. Trail: `git log --grep='^ITER(olmec-boss)'`.
Built on the Olmec field (`docs/design/olmec-field/handoff.md`). A
prototype: no committed tests.

## Play it

`./run-olmec-field.command` (the whole fight from the head), or
`godot --path . res://studies/olmec_field.tscn -- --no-title [flags]`:

- `--phase=2`: start whole (R then restarts phase 2).
- `--tilt-now`: with `--phase=2`, the tilt as soon as he's whole.
- `--head-knob=phase_hits=N`: hits to end phase 1 (default 6).
- `--whole-olmec`: the old whole-Olmec greybox. `--earn-charge`: the gust
  charge doesn't refill by itself.

Tab / R3 locks on, X fires the gust shot, Jump opens the sail, R restarts
from any phase. The top-left card shows the phase, his hits and his move.

## Built

- **Arena** (`scripts/olmec_boss/arena.gd`): 20 breakable pieces on the
  kit-breaks hub (a horseshoe of columns, a colonnade run, stacked stones,
  low walls); gust shots, his body and his attacks crack and topple them
  (`hit_at`, `watch_blast`). The plane's west run stays clear. Four crags
  hang off the rim for him to climb.
- **Phase 1, the head** (`scripts/olmec_boss/boss_head.gd`, `puffs.gd`):
  absorb (dust drawn in, a light pull, the old gulp up close), then a puff
  picked by range: gust volley, ground ring, whirlwind, long breath. Hits
  stagger it and break an absorb; 6 hits end the phase.
- **The arrival**: the body hauls up a crag behind the head, crosses the
  field breaking pieces, puts the head on, triumph. The lock's blur on the
  climbing body is wanted (the user's call).
- **Phase 2, whole** (`scripts/olmec_boss/boss_body.gd`): a shoulder-led
  run (new Blender clip `shoulder_run`), slam, bound, swat, puffs from his
  neck while he moves, and the charge (clips `charge_tell`, `charge_run`,
  `charge_skid`, `charge_stagger`; overrun window to shoot him). 8 hits
  crumble him.
- **The tilt** (steep mode in `scripts/enemies/olmec_tilt.gd`, additive):
  at 3 hits and then every 40 s or more, he bounds to the rim, slams and
  braces; the field tips to about 29 deg and the wanderer surfs down a
  cleared lane past edge-on wind slices (`scripts/olmec_boss/air_arcs.gd`:
  five sweeping, accelerating patterns that re-aim until 0.9 s out). The
  lock reaches him anywhere while braced (`lock_anywhere`, opt-in in
  `foot_lock.gd`); 3 shots break the brace (30 s fallback). He staggers
  off the rim, the field snaps back, the wanderer is flung ~24 m up and
  glides back on, and he climbs back up a crag.
- Shared code changed additively: `foot_lock.gd` (a target's own
  `lock_reach`, `lock_anywhere`), `headless_body.gd` (subclass hooks,
  `run_clip`), `headless_body_look.gd` (new clips), the body's glb and
  Blender build (clips added; existing clips checked unchanged).

## Open

- **Tuning, collected from play** (never run as its own step):
  debris that goes over the edge falls upright (should tip and tumble);
  the camera ends up inside his legs when a bound lands on the wanderer;
  the charge's dodge window is tight and it crowds out the bound; the
  card's text is small; the scrape and absorb dust are faint at range;
  the snap-back spring takes ~10 s to settle; the "scythes" slice pattern
  is too easy; ordinary column breaks may still miss buried bottom faces.
- **The player's side**: the user is using this study to see what the
  wanderer needs. Projectiles work, but melee (dodge him, then hit him in
  a weak spot) may suit the fight better than shooting him down; not built.
- Being swallowed by the head mid-fight, and the head's behaviour if he
  crumbles mid-puff, were never driven.
