# Isle hall line: handoff

Branch `study/isle-hall-line`, from main (3ecaabec). Not merged, not pushed. It follows on from docs/design/isle-hall-chain.md: the ring, the pause, the pulse and the quiet arrow are unchanged. What rises after the pulse is new.

Your feedback on the chain: "I still think it's not quite as fun as the arrangement in the default scene. So, I want the chunks to come in in large pieces and to match more of the straight line, but maybe with some occasional bends." And: "the chunks come in tiny pieces. Which I don't love." Your sketch had three tall rectangles end to end in a column, a jog sideways, then three more in a parallel column.

So the moments hall (15 bays, bending 68°, rising in four bay chunks, a long S) is gone by default. In its place is the **Sundered line**: big pieces of straight nave, each on its own island, each rising **whole**, laid end to end along the flight heading. Every few pieces the line sidesteps to a parallel run.

## How to play

```
./run-aqueduct-isle.command --near-ring                # in the plane, 260 m before the ring
./run-aqueduct-isle.command --near-ring --autopilot    # sit back: it flies the line for you (any stick or key takes over)
./run-aqueduct-isle.command                            # the whole loop, from on foot
./run-aqueduct-isle.command --chain-style=halls        # the old hall chain, as before
./run-aqueduct-isle.command --near-ring --line-turn=mix        # sidesteps and bends
./run-aqueduct-isle.command --near-ring --line-run=3-3 --line-jog=70   # every third piece, a wider jog
```

### Flags

| Flag | Default | Does |
|---|---|---|
| `--chain-style=line\|halls` | line | the Sundered line, or the old hall chain |
| `--line-bays=<a-b>` | 8-11 | bays a piece (8 m each, so 64-88 m of nave). Sundered's own pieces are 7-12 |
| `--line-gap=<a-b>` | 14-26 | m of open sky between pieces in a run. Sundered's are 12-30 |
| `--line-run=<a-b>` | 2-4 | pieces in a straight run, so how often the line turns (on average about every 3) |
| `--line-turn=sidestep\|bend\|mix` | sidestep | what happens between runs. mix: 60% sidestep, 40% bend |
| `--line-jog=<m>` | 48 | how far to the side a sidestep puts the next run (±15%) |
| `--line-jog-gap=<m>` | 120 | the sky a sidestep takes (−7% to +15%) |
| `--line-bend=<deg>` | 26 | how far a bend turns the line (±20%); bends take a 34-46 m gap |
| `--line-band=<m>` | 8 | how far a piece's floor may stand over or under the first's (steps of up to ±3 m a gap) |
| `--line-ahead=<m>` | 260 | the next piece starts rising once its entry is this far ahead, or sooner at speed |
| `--line-keep=<n>` | 6 | pieces standing at once before the oldest behind you sinks (0: never) |
| `--line-seed=<n>` | 3 | the line's seed |
| `--line-look=real\|greybox` | real | the game's own Sundered hall on its island (round 2), or round 1's greybox |
| `--autopilot` | off | the line's pilot flies for you once the line starts |
| `--capture-high` | off | a capture's eye high behind the plane, looking down the line |

The ring's and timing flags (`--ring-near`, `--ring-pause`, `--chain-lead`, `--arrive-spare`, `--catch-up`, `--first-at`) and the rise's flags (`--rise-speed`, ...) work as before.

## The choice: Sundered's planner, greybox bays, one chunk

I reused the default scene's Sundered hall, but only its **planner**, not its build:

- **What a piece is** comes from `Sundered._plans` (scripts/sundered_hall.gd). For each piece it gives the act's roof pattern, breaches, slit screens, ties and inner columns, with both ends torn. The acts cycle through Sundered's middle acts: nave, shafts, cloister, nave, slit, shafts, cloister.
- **How a bay is drawn** is the flight course's greybox bay (`FlightCourse._bay`), the same boxes and columns the moments hall used. A broken roof loses two strips.
- **The island** is a greybox ridge: one faceted rock hull a bay, in the hall rise's keel format. It is about 31-39 m wide and 8-22 m deep, deepest in the middle and drawn in under the torn ends so they overhang, like Sundered's.
- **It rises whole.** The piece is one hall-rise plan with **one chunk**: every bay's solids plus the island. So the whole machinery (scripts/hall_rise.gd: worker build, the rise curve, collision only once still, the plane check, the sink, the game's puff bursts) is reused unchanged. HallRise gained two overridable counts, `burst_puffs` and `stream_rate`, so a 250 m rim gets more cloud (150 and 90/s here; the defaults are unchanged).

Why not the real Sundered build (`SunderedBuild.near` plus a SkyIslet terrain island): that is the dressed kit at in-world detail, with thousands of hulls stood over many frames and a terrain island per piece. It would mean a seconds-long build per piece and a dressed look, which goes against greybox-first. The plans are the same data, so a later round can swap the greybox bays for `SunderedBuild.far` (a cheap single mesh) or the near build without changing the layout or the timing.

The greybox piece is 64-88 m of nave and about 37 m from keel to wall top, with 61-174 solids plus 8-11 hulls. Drawing it takes about 0.3 ms, on a worker.

## The layout (scripts/hall_line_plan.gd)

- **Runs.** Pieces in a run stand end to end on one heading. The lane is Sundered's line: 2.3 m over the floor, 6 m right of the nave's middle, clear of the inner columns, low ties and slit screens. It runs dead straight through every piece and gap in a run.
- **Gaps.** A gap is 14-26 m of sky, with a step of up to ±3 m (grade ≤ 0.25), kept within ±8 m of the first floor.
- **Sidesteps.** After a run of 2-4 pieces (seeded), the next run stands parallel, about 48 m to one side, after about 120 m of sky:
  - the lane leaves the torn end straight for 8 m;
  - it makes an S sideways, eased at both ends (smootherstep), so you enter the next run straight;
  - it then runs straight for 8 m into the next piece.
  - The worst turn on it needs 0.61 rad/s at boost (the plane can do 1.6), and you swing at most 46° off the run's heading.
  - Sidesteps lean back: once the line is off the first run's axis, the next jog goes back toward it. In 40 pieces it never strays more than 47 m.
- **Bends** (`--line-turn=bend` or `mix`). The next run turns about 26° over a 34-46 m gap, on a curve tangent to both runs. Bends turn back toward the first heading, so the line never wanders more than about 25° off it.
- **Everything is seeded.** A piece's content (act, bays) comes from its own stream, separate from where it stands.

## Timing (tools/isle_chain_timings.gd, headless)

The plane flies at the ring from 600 m out and threads it, then the autopilot flies six pieces. Piece 2 comes after a sidestep. Each row shows seconds from the trigger to the piece standing still / to the plane reaching its entry / the margin.

| | Cruise (14 m/s) | Boost (~22 m/s) |
|---|---|---|
| Ring (it wakes) | 8.6 / 30.0 / **+21.4** | 8.6 / 19.1 / **+10.5** |
| Piece 0 (threading) | 8.7 / 14.6 / **+5.9** | 8.6 / 10.6 / **+2.0** |
| Piece 1 (gap, 17 m) | 8.7 / 18.6 / **+9.8** | 8.7 / 11.8 / **+3.1** |
| Piece 2 (sidestep, 111 m) | 8.8 / 18.6 / **+9.9** | 8.8 / 11.8 / **+3.1** |
| Pieces 3-5 | 8.6-8.7 / 18.3-18.5 / **+9.7 to +9.8** | 8.6-8.7 / 11.7-11.8 / **+3.1** |

Both runs: 0 bumps. A whole piece rises in about 8.7 s, against about 12 s for the old four-chunk hall. Every piece is still before you reach it, by about 10 s at cruise and 3 s at boost.

**Triggers.** The next piece starts rising once its entry (along the route) is `--line-ahead` (260 m) off. Sooner at speed, once the plane would be there within its rise plus `--arrive-spare`. Never before the newest piece has broken out of the cloud, so they come up one after another. At cruise you usually see the piece you are in, the next one standing, and the one after rising out of the sea. Catch-up (1.6×) is still there, but with the 260 m lead it barely acts.

**Cost.** A piece's main-thread cost is 0.5-1.1 ms in all, with its heaviest frame at 0.3-0.6 ms (headless). That frame is the one-chunk hand-over: its mesh and one body of up to about 185 shapes. Its solids are drawn on a high-priority worker as soon as the piece before is placed, and the trigger never waits on it. A first version waited, and at a busy moment one spawn blocked for 850 ms; that is fixed and tested. The rendered capture runs ran at 16.7-20.6 ms a frame (vsync off) with the line up.

**Cap.** Past 6 standing, the oldest piece sinks once the plane is 30 m past its exit. It is the rise reversed, as before.

## Captures (local, gitignored: `captures/isle-hall-line/`)

All from `--near-ring --autopilot`:

- `t24.png`: from the chase camera, just after the pulse. The first piece stands dead ahead: a big nave on a deep keel. It is backlit black at this hour, as before.
- `high_t44.png` (`--capture-high`): looking down from high behind the plane while it flies through piece 1. Piece 1's roofed nave runs straight away below, and piece 2 stands well off to the right after the sidestep. It reads as big pieces, with a jog to a parallel column. The next pieces had not risen yet at this moment.
- `jog_t50.png`: from the chase camera in the sidestep. The plane is banking across, and piece 2 stands beside it, its nave open end-on. Piece 3 is rising out of the cloud beyond it (seen through the sea's gap).

Judged by eye only. Headless can't check the look (the cloud volume and puffs need the GPU).

## Files

- **New:**
  - `scripts/hall_line_plan.gd`: the layout, the gap lanes, the greybox piece and island, the one-chunk template;
  - `scripts/hall_line.gd`: the runner (spawn, route tracking, triggers, catch-up, cap, autopilot);
  - this doc.
- **`studies/aqueduct_isle_chain.gd`:**
  - `--chain-style` (line by default);
  - `first_y()` and `lead_in()`, so either style times its first piece.
- **`studies/aqueduct_isle.gd`:** `--autopilot` and `--capture-high`.
- **`scripts/hall_rise.gd`:** `burst_puffs` and `stream_rate` (the defaults are unchanged).
- **`tests/test_isle_hall_chain.gd`:** the layout checks, the flight through 7 pieces, and the halls style.
- **`tools/isle_chain_timings.gd`:** pieces, gap kinds and costs.
- **`run-aqueduct-isle.command`:** the new flags in its comments.

## Tests (headless)

- The headless import is clean.
- Run through `python3 tools/run_tests.py`, all passing:
  - `test_isle_hall_chain`, `test_isle_lodestone`: pass, with the runner's known exit leak;
  - `test_hall_chain`, `test_hall_rise`, `test_aqueduct_isle`, `test_aqueduct_isle_plane`, `test_scene_picker`: pass.
- The full suite was not run.

New in `test_isle_hall_chain` (about 29 s):

- **Layout** (40 pieces, planned):
  - straight and end to end within runs;
  - gaps of 14-26 m with steps of at most 3 m;
  - a sidestep about every three pieces (14 in 40, mean run 2.7), each parallel, about 48 m to the side, over at least 100 m;
  - flyable at boost (0.61 rad/s, 46° at most);
  - no islands overlap, the line leans back, the same seed gives the same line;
  - a piece is one chunk holding all its solids and its island;
  - the bend line stays within 25°.
- **Flown:** the autopilot flies from the ring into 7 pieces, 4 at cruise and then 3 holding boost, with a sidestep among them:
  - every piece whole and still on arrival at both speeds;
  - 0 bumps, never inside stone;
  - the oldest sinks past the cap (at most 6 standing);
  - the heaviest hand-over frame is 0.47 ms.
- **`--chain-style=halls`:** still places the four-chunk hall dead ahead.
- **One check's margin changed.** "Threaded at boost, its way in would stand further on" now asks for 20 m more than at cruise, not 50 m (209 m against 180 m). The whole piece's rise is 3.4 s shorter than the old hall's, so it needs less lead at boost.

## What's weak

- **Backlit black.** At this hour the pieces are black silhouettes from the plane, as in the earlier rounds. The greybox reads as "a big block" more than "a ruined nave" until it is lit or dressed.
- **The lane is tight.** It is Sundered's own: 2.3 m over the floor, with the low ties 1.7 m above you and about 4.4 m between columns. The autopilot holds it with 0 bumps, but by hand at boost it may feel cramped, and nothing marks the lane.
- **The sidestep is an S, not your sketch's 90° jog.** You swing about 45° off and back over 120 m. A real right angle would need much more sky, or a slower plane.
- **You see 1-2 pieces ahead, not the whole line.** That comes from the 260 m lead. `--line-ahead=400` shows more of the line rising at once, at a little more cost.
- **The pieces are all the same straight shape.** Sundered's own pieces have curves (Sundered's `TURN`); here they are straight on purpose.
- **Greybox bays don't draw gables or fallen beams.** The torn ends are only low walls and snapped columns.
- **Not flown by hand.** Only the autopilot, headless and in three captures.

## Open questions

1. Sidestep size and pacing: 48 m to the side over 120 m, every 2-4 pieces. Bigger jogs (`--line-jog=70 --line-jog-gap=150`), or more often (`--line-run=2-3`)?
2. Sidestep only, or mix in bends (`--line-turn=mix`)?
3. How much of the line should be up ahead: 260 m (one or two pieces), or 400+ so you see the run laid out?
4. Next step for the look: the Sundered far mesh (cheap, real kit silhouettes) on each piece, or keep greybox until the flow is settled?
5. Should the line ever end (an apse piece with Sundered's release climb), or stay endless?

# Round 2: the real Sundered look

Your ask after flying round 1: "let's see if we can actually use like the real bake or like I guess like the version that we see with the actual overgrowth and textures. The basalt color. And then once that's done, we'll merge it."

Every piece is now the game's own Sundered hall, built the way `--motif=sundered` builds it in the default scene. The layout, the flags, the whole-piece rise out of the real cloud sea, the puffs, the triggers, the cap and the sink are all unchanged. `--line-look=greybox` brings back round 1's boxes.

## What a piece is now (scripts/hall_line_build.gd)

- **The same bays.** A line piece becomes a Sundered piece record (`hall_piece`): one straight stretch, both ends torn. Its bay plans come from the Sundered planner, from the same random stream the greybox used, so a piece has the same roofs, breaches and screens as in round 1.
- **The hall.** `SunderedBuild.near`: the ruin kit's bays at in-world detail, the podium, the hanging torn ends, merged into one mesh. The stone is the eroded basalt (the ruin stone's default on main), and everything is dressed in the swaying overgrowth (`SunderedGrowth`, `ruin_growth.gdshader`). The overgrowth parts round the plane through the isle's existing `RuinGrowthPush.stir`.
- **The island.** `SunderedBuild._isle`: a long ridge island authored like the game's islets, with its bed levelled under the hall and cleared of plants. It is laid like Sundered's islands, 21-24 m to each side, with the torn ends overhanging its tips. `SkyIslets.dress` gives it the isle's ground palette, trees, flowers and rock look. It is stood with `SkyIslets.stand`, which can now take a parent, inside the rising piece.
- **Near and far.** `SunderedBuild.far` is built too. A piece shows its near detail within 240 m of the camera (`NEAR_SHOW`) and the far mesh past that. This is Sundered's own streaming, except nothing is let go: a piece stays built until it sinks.
- **Collision.**
  - The hall's hulls are regrouped into bodies of 40.
  - The island's ground and rock become trimesh bodies of at most 1500 triangles.
  - All of them sit on the ruins' layer, solid only once the piece is still.

## How it avoids a hitch

- **Built on a worker, one at a time, in order.** A piece's content never depends on where it stands, so it is built before it is placed, two ahead of the newest piece standing (`PREFETCH`). The first piece starts building when the ring wakes, about 20 s before you can thread it.
- **A piece only rises once it is built.** The build takes 0.9-2.2 s on a worker. Pieces are due every 4-7 s, so the worker is idle most of the time.
- **Hand-over.** HallRise takes a made node as it is (`chunk.node`, signal `taken`). The node is handed over in one frame and its island is stood the next.
- **Collision is stood one body a frame while the piece rises.** It collides with nothing until the piece is still, and the piece only counts as "set" once every body stands. When a piece sinks, all its bodies stop colliding at once and are then freed one a frame.
- **First-use warm-up.** What an island first stands with (its plants' materials and the trees' far stand-ins) is made one key a frame after its build finishes. Without this, the first island cost about 6 ms.
- **Six pieces standing (`--line-keep=6`) stays.** Only the pieces within 240 m draw their near detail, so `--line-keep` did not need lowering.

## Cost (headless, tools/isle_chain_timings.gd, now flown in real time)

| | per piece |
|---|---|
| Worker build | 0.9-1.5 s alone, up to 2.2 s under test load (island 0.2-0.3 s, hall near+far 0.7-1.5 s) |
| What it draws | 1,330-2,565 hulls, 77k-127k triangles near |
| Main thread, whole piece | 22-42 ms in all, spread over 45-80 frames |
| Heaviest single frame | 0.8-1.8 ms (the hand-over 0.4-0.7 ms, the island 0.15-0.3 ms, a body 0.8-1.8 ms) |
| Heaviest whole frame once the line is up | 14.5 ms (process + physics, headless, the whole isle) |

The margins are as in round 1:

- at cruise each piece is still +9.6 to +9.7 s before you reach it (+5.8 s for the first);
- at boost it is +2.9 to +3.0 s (+2.0 s for the first);
- 0 bumps both ways.

Rendered captures ran at 16.7-25.9 ms a frame with vsync off, against 16.7-20.6 ms in round 1. The worst frames had two or three near pieces in view: 0.8-1.5 M primitives.

## Captures (local: `captures/isle-hall-line-2/`)

- `t24.png`, `t36.png`, `jog_t50.png`: from the chase camera with `--near-ring --autopilot`.
- `high_t44.png`, `high_t60.png`: the same with `--capture-high`.
- `default-sundered/`: the default scene's Sundered hall (tools/capture_sundered.gd), to compare against.

By eye, the pieces read as the same thing as the default scene's hall: dark basalt walls and roof slabs, ivy curtains, grass beside the nave, a dark faceted keel. From high up, the line reads as one long broken nave stepping across the cloud. All of this is judged by eye only: headless can't check the look.

## Tests

- `test_isle_hall_chain` (now `## suite: slow, serial`, about 78 s) flies the line in real time, a physics frame a step, because the pieces are built on a worker as they would be in play. It checks:
  - every piece is the real build and whole: one chunk holding its near, far and island;
  - every body stands on the ruins' layer once the piece is still (44-77 bodies a piece);
  - every piece is still on arrival at cruise and at boost;
  - 0 bumps through the real collision, never inside stone;
  - no frame's main-thread cost over 4 ms (worst measured 1.7-1.8 ms);
  - the first piece is built while the ring rises;
  - `--line-look=greybox` still gives the greybox piece.

## What's weak or missing against the default scene

- **The near pieces cost frames.** With two or three of them in view, a rendered frame took up to about 26 ms. A visibility range or a nearer `NEAR_SHOW` would help if that shows when you fly it.
- **Straight pieces only.** Sundered's own pieces curve; these stay straight for the line's layout.
- **No gate, apse or aqueduct pieces.** Every piece is a middle act with both ends torn, as in round 1.
- **The texture swims while rising.** The stone and growth shaders may sample world space, so the texture can slide on a piece as it rises. Not visible in the stills; check it in flight.
- **Backlit black** at this hour from the chase camera, as before.
- **Build timing under heavy CPU load is not guaranteed.** At four times slower than measured, a build would run near the boost interval. The test is tagged serial for that reason.
