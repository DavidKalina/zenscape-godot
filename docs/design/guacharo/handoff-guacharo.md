# Handoff: the guacharo remake (loop `guacharo`)

The bird was rebuilt in two parallel lanes, then joined by a trunk loop, all
on branch `iter/guacharo`. The trail is 28 `ITER(guacharo…)` commits. Every
agent had a 150k context budget. The lanes' own handoffs are in their last
commits (body `12ced99f`) and in `handoff-guacharo-hunt.md` (hunt).

## Play it

```
~/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1440x900 \
  res://studies/flyer_yard.tscn -- --no-title
```

`studies/guacharo_poses.tscn` lays out every clip, one row each. It takes
`--clip=`, `--n=`, `--view=`, `--far=` and `--live`.

## What's built

**The body** (`art/blender/guacharo/`, `assets/models/guacharo.glb`,
`scripts/enemies/guacharo_look.gd`):
- **The model:** a sculpted oilbird, 2088 triangles and 51 bones, with
  scattered white spots.
- **11 clips:** glide, flap, circle, stalk, scream, fold, stoop, flare,
  carry, pull and hurt. They're authored to the Animation bar and exported
  at 30 fps.
- **Driven by the hunt:** the body plays the clips from the hunt's states.
  Its head aims at the pilot, it clicks, and its talons reach for him.
- **It stays visible and out of the ground:** it has a fixed AABB, so the
  wings are never culled, and its model lifts itself above the ground.

**The hunt** (`scripts/enemies/guacharo.gd`):
- **It marks you,** with a call, then swings in so it stalks in view.
- **The tell lasts 0.95 s.**
- **Dodging:** keep going and you're hit; step 1.5–1.9 m on the scream and
  it misses.
- **Cover** breaks the stalk and the tell.
- **A gap in cover** is a real danger: it dives down through the gap.
- **It backs off** 13–19 s between dives.
- **The drop is survivable.** It carries you over the void only if you were
  exposed to it.
- **It's never buried:** it keeps clear of terrain, and the snatched
  pilot's feet stay out of the floor.
- **Readability:**
  - the shadow sharpens and grows as it closes, and pops on the scream;
  - the eye glare sits on the head bone;
  - each stage has its own sound cue, the scream the loudest;
  - turning is rate-limited, so the body doesn't pop.

## Open

- **The sound is unheard,** only logged. The user judges it.
- **The circle's turn rate** is now limited, which may soften how it
  banks. The user should judge it in play.
- **The bird is still out of frame** during its long flight in from home,
  before it swings round.
- **The stoop shudder** is under a pixel at range.
- **`flinch()`** (the hurt clip) is never called; nothing in the hunt hurts
  the bird.
- **Not yet in the Pilgrim's Ladder:** the orchestrator merges it there and
  runs a stand in the real pent hood's roof gap.
