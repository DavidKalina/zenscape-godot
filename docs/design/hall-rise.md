# Hall rise: handoff

Branch `study/hall-rise`, from `study/hall-eruption` (a1e325bc). Not merged, not pushed. Greybox study only. The game, the moments world and the aqueduct isle are untouched.

The previous round (docs/design/hall-eruption.md) had the hall erupt in 92 pieces that flew in on arcs. You liked the effect but said it doesn't fit the game: each chunk should rise whole, fully formed, one after another. This round replaces the piecewise eruption with that. The old mode is not kept behind a flag. It lives on `study/hall-eruption` if you want it back.

## How to run it

```
./run-hall-rise.command                         # orbit camera, it plays at once
./run-hall-rise.command --watch=plane           # in the plane, 260 m out on the hall's way in
./run-hall-rise.command --rise-speed=7 --chunk-gap=2.5   # slower, further apart
./run-hall-rise.command --rise=40               # the hall higher over the cloud: a longer rise
```

It is also in the scene picker: Scenes, then Ruins, then "Hall rise".

Keys are the same as before: R again (Shift+R rebuilds too), Enter all in place, C camera (orbit, free, plane), F into or out of the plane, [ ] slower or quicker, O orbit turns or holds, M moments and line, Esc frees the mouse.

### Tuning flags

| Flag | Default | Does |
|---|---|---|
| `--rise=<m>` | 14 | how far the hall's lowest stone stands over the cloud top. Each chunk climbs this, plus its own height (14.6 m), plus `under` (6 m). |
| `--hall-y=<m>` | (from `--rise`) | the entry's height over home instead. `--hall-y=20` is the moments world's height, about 125 m over the cloud. |
| `--rise-speed=<m/s>` | 9 | steady speed through the cloud top |
| `--chunk-gap=<s>` | 1.5 | from one chunk's start to the next's |
| `--rise-ease=<m>` | 8 | how far it takes to slow to a stop |
| `--rise-over=<m>` | 0.35 | it stops this far over its place, then sinks in (0: it stops dead in place) |
| `--rise-settle=<s>` | 1.3 | how long the sink takes |
| `--rise-from=apse\|gate` | apse | which end rises first |
| `--keels`, `--stones` | off | the previous round's additions (see below) |
| `--build-upfront=<s>`, `--build-cost=<s>` | 0 | a deliberately slow worker build, as before |
| `--watch`, `--wait`, `--loop`, `--capture…` | | as before |

The rest (ease-in distance, lead, `under`) is in `RISE` at the top of scripts/hall_rise_plan.gd.

Headless:

```
godot --headless --path . -s tools/hall_rise_list.gd [-- <flags>]   # every chunk and its timing
python3 tools/run_tests.py --tests 'test_hall_rise.gd'
```

## The chunks

There are four, all runs of whole bays along the nave. Each one is fully formed: floor, columns, walls, arches, ties, screens and roof.

| Order | Chunk | Bays | Solids | What |
|---|---|---|---|---|
| 1 | apse | 12–14 | 32 | the far half's apse end, torn at the back |
| 2 | screens | 9–11 | 37 | the far half's screened bays, at the gap |
| 3 | torn | 5–8 | 37 | the gate half's broken, open end, at the gap |
| 4 | gate | 0–4 | 72 | the gate's roofed nave, where you fly in |

The chunks are split along the nave, not stacked as a base, then walls, then a roof. Every chunk rises straight up, so a roof or wall that stands over an earlier base would have to come up through the floor. Splitting along the nave means no chunk ever passes through another.

The rise starts at the apse, so from the plane on the way in the hall builds toward you and the gate comes up last, right ahead. `--rise-from=gate` flips the order. The split is the `CHUNKS` list in scripts/hall_rise_plan.gd: four lines of bay ranges, easy to regroup into 3, 5 or 6.

## Timing (defaults, from tools/hall_rise_list.gd)

| Chunk | Starts | Breaks through | Stops | Still |
|---|---|---|---|---|
| apse | 0.60 | 1.83 | 5.93 | 7.23 |
| screens | 2.10 | 3.33 | 7.43 | 8.73 |
| torn | 3.60 | 4.83 | 9.48 | 10.78 |
| gate | 5.10 | 6.33 | 10.98 | **12.28** |

The whole rise takes **12.3 s**, against 14.8 s before. Each chunk climbs 35–40 m.

## Motion

- Each chunk starts with its top 6 m under the cloud top.
- It speeds up over 5 m, still hidden under the cloud, and then rises at a steady 9 m/s. It is at that speed when it breaks through.
- It slows to a stop over 8 m (about 1.8 s), 0.35 m over its place, then sinks into place over 1.3 s.
- There is no spring, no bounce and no tilt.
- From the end on, it is exactly in its place.

The motion is `RisePlan.height_at` and `speed_at`, and it is tested: it never moves down before the stop, never goes more than `over` past its place, and ends exactly there.

## Placement

The previous weakness was that the breakthrough was 125 m below the plane and easy to miss. To fix that, the study stands the hall low: its lowest stone is 14 m over the cloud top, so the entry is 78.6 m under home.

The plane flies 8 m over the entry, so the breakthrough is about 25–35 m under your line. At 260 m out it reads clearly, a few degrees under the horizon, right ahead (captures/hall-rise/plane1, local only).

In the game the moments hall stands 20 m over home, about 125 m over the sea. So the rise either needs the hall placed low over the sea, or a local cloud bank or raised sea under it. That is open question 1.

## Cloud (greybox)

- **Swell.** The sea's shader takes up to six swells (`swells()`). For each, the sea heaves up to 3.5 m in a soft, boiling dome over the chunk's footprint as it nears the top, and settles after it is through.
- **Breakthrough.** A ring of up to 70 puffs bursts round the chunk's floor edges at the cloud top, and a cap of 24 puffs rides up on its wall tops and is left behind.
- **Streaming.** While the chunk's foot is within 5 m over the top, cloud streams off its sides at 40 puffs a second. The puffs are carried up at about half its speed and fall behind.
- At most 600 puffs, and about 350 at the peak. The previous round had about 1000 puffs plus 700 dust stones. The dust is gone.

## Kept from the previous round

- The plan and runner split.
- The worker build, chunk by chunk in rise order. The schedule holds if a chunk isn't built yet, and chunks already rising go on. A 1.5 s + 1 s simulated build held 0.88 s.
- The cameras, the plane, the replay keys, the cloud sea and the grid shader with its riding offset.

Collision only goes solid once a chunk is still. It now waits only if the plane touches one of the chunk's solids (each solid's box, grown 0.6 m), not just its whole box, which would be most of a nave. So a chunk settling round a plane that is inside its nave, clear of stone, goes solid at once. That is tested.

## Keels and floating stones: off

Both default to off, because neither is part of the in-world hall.
- `--keels` hangs each bay's rock keel under its floor, and the keel rises with its bay's chunk. This belongs to a chunk naturally.
- `--stones` adds the floating stones as a fifth and last chunk. They still keep clear of the line and every moment (tested).

`--rise` is measured from the lowest stone, so with `--keels` the hall stands higher and the keels stay clear of the cloud.

## Tests (headless)

`tests/test_hall_rise.gd` passes under the runner, as does `test_scene_picker`. It checks:
- 4 chunks (3–6), with every hall solid in exactly one;
- the chunks are whole bay runs in the order apse, screens, torn, gate (and the reverse with `--rise-from=gate`);
- the gaps and the lead, and a length of 6–14 s;
- no bounce, the overshoot capped, exactly home at the end;
- each chunk breaks through at its steady speed and starts under the cloud;
- the variants and the additions' clearance;
- in play: hidden till it begins, begins on time and in order, never solid while moving, breaks through, cloud and swells up, settles on time;
- settled: exactly in place, solid on the ruins' layer, every shape where the in-world hall has it (worst 0.00001 m), a ray hits the stone, the line keeps 0.9 m of room;
- the plane: a chunk waits while the plane touches its stone and goes solid once the plane is clear, and goes solid at once with the plane only in its nave;
- a slow build holds and keeps the order;
- the plane flies in while the hall rises and on through the settled hall for 30 s, never stuck and never inside stone.

The full suite was not run.

## What's weak

- **The puffs still read as balls** close up (orbit captures), and the greybox sea isn't the game's volumetric sea, so the real breakthrough look is unknown.
- **A rising chunk passes through the plane.** If you fly into one as it rises there is no shove; it just goes solid once you're clear.
- **From the plane, the gate hides the far chunks** once it's up. With apse-first they are all up before the gate, so you see each one rise, but from straight ahead the far half is a silhouette behind the gate.
- **The low placement is study-only.** In the game the hall is 125 m over the sea (open question 1).
- **No sound and no camera rumble.** A low rumble as each chunk breaks would carry much of the weight.
- **Not checked by hand:** the feel at 9 m/s against 6–7, and whether 0.35 m over and sink reads as "heavy" or as a tiny bob (`--rise-over=0` stops it dead).

## Open questions

1. In the game: stand the hall low over the sea (as here), raise a local cloud bank under it, or let it rise the full 125 m (`--hall-y=20`: about 18 s a chunk at 9 m/s, too long; it would need about 20 m/s)?
2. Order: apse first (builds toward you) or gate first (`--rise-from=gate`)?
3. Four chunks, or regroup: the two halves as two chunks plus the gate and apse ends split off, or five or six?
4. Speed 9 m/s and 1.5 s apart, 12.3 s in all: right, or slower and heavier?
5. Keep the keels for the rise (a rock underside rising out of the cloud reads well) or leave the hall bare?

## Files

- Renamed from `hall_eruption*` and rewritten:
  - `scripts/hall_rise_plan.gd`, `scripts/hall_rise.gd`
  - `studies/hall_rise.gd`, `studies/hall_rise.tscn`, `run-hall-rise.command`
  - `tests/test_hall_rise.gd`, `tools/hall_rise_list.gd`
- Shaders, renamed:
  - `shaders/hall_rise_sea.gdshader` (now with swells)
  - `shaders/hall_rise_grid.gdshader`, `shaders/hall_rise_puff.gdshader`
- `scripts/scene_catalog.gd`: the Ruins entry is now "Hall rise".
- docs/design/hall-eruption.md: a pointer to this doc at the top.
- Checks run: the headless import (clean), `test_hall_rise` (pass) and `test_scene_picker` (pass).
