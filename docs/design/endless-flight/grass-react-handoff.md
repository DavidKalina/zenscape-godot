# Endless flight: the grass reacts (prototype round)

## What changed

- `scripts/endless/grass_react.gd` (new) keeps a push map round the eye. It is 512 texels over 384 m, half float, and is redrawn every frame. Each push is a stamp (a MultiMeshInstance2D in a SubViewport, `shaders/grass_react_stamp.gdshader`). A stamp's spring comes from its age: the push rises as its front arrives, holds, swings back past rest and settles. Stamps add up, and their signed values carry the overshoot.
- `shaders/grass_react.gdshaderinc` (new) reads the map (globals `zs_react_map`, `zs_react_rect`, declared in project.godot). Three tiers read it, each through a small gated block:
  - The near tufts (`reference_surface`, the sway branch): blades lean and lie down.
  - The far tufts (`endless_tuft_far`): they bend too.
  - The painted ground (`endless_ground`): a tone.
- **The shading reads the lean's direction.** Grass laid away from the eye goes paler, grass leant toward it goes darker, and pressed grass goes paler. A stirred patch reads from height and keeps some relief.
- **The isles are untouched.** Nothing sets `zs_react_rect` there, so `zs_react_live()` is false and the block is skipped.
- **Prop wash.** Below WASH_UP (7 plane spans, about 20 m), with the engine running, the plane drops a puff about every 1/18 s where its wash comes down behind it. Each puff fans out at 11 m/s with a swirl and is blown back along the plane's way. Strength goes by height squared and by thrust: cruise 0.6, boost 1, and on the wheels 0.3 + 0.7 × throttle, so a run-up on the brakes lays the grass flat.
- **Walker.** `react.walker(at, velocity, sliding)` is a hook only. Endless flight has no getting out yet, so nothing calls it in play. Its stamp reach goes by `WorldScale.wanderer_tall`. When a walker comes, call it each frame he is on the ground. PilotWake's `zs_tread` would also part the near tufts if he publishes it.
- **Gusts.** Every 7 ± 3 s a gust comes down 35–150 m ahead of the view, on turf. It uses the endless look's own breeze, through `look.wind_direction` and `look._gust` (that is `zs_gust_distance`):
  - It goes into the breeze as a `zs_puff_N` parcel, so the near tufts' own sway leans with it as it rides downwind.
  - It lands as an 18–34 m fan, a pale ring that spreads at 6.5 m/s.
  - A band of downwind lean then rides on with the parcel for 7 s.
  - The plane does not feel it.

## Flags

`--no-grass-react` turns all of it off. Each part also turns off alone: `--no-prop-wash`, `--no-grass-gusts`, `--no-grass-part`. Knobs: `--prop-wash=X`, `--grass-gusts=X`, `--gust-every=S`, `--grass-bend=X` (every push's bend, 1). F1's numbers show the live stamps, the wash strength and the gust count.

Play: `./run-endless-flight.command --at=1640,580 --heading=0 --alt=6` (a long flat meadow, seed 1).

## Cost

- CPU: 0.06 ms a frame with about 60 stamps.
- Frame time: skimming at 2 m, real time, uncapped, in a window on this Mac (M5 Pro). With react on and off, the gap was within noise: 25.2 vs 24.4 ms and 33.0 vs 33.6 ms.
- GPU time: Metal reports none.

## Captures (`captures/grass-react/`)

| Capture | What it shows |
|---|---|
| `on_skim.gif` / `_sheet` | A still camera beside a 2 m skim. A pale and dark wake lies behind the plane and springs back. |
| `off_skim_sheet`, `off_chase_sheet` | The same views with react off. |
| `on_runup.gif` | Run-up on the brakes. |
| `on_takeoff.gif` | It rolls away; the laid patch stands back up. |
| `on_gust.gif` | A gust lands and fans out. |
| `on_walk.gif` | The stand-in walker (a capsule) parting grass. |
| `on7_chase_sheet` | 7 m up, where the wash is faint. |

The drivers are in `scratch/grass_react/` (`fly.gd --part=chase,skim,land,gust,walk`, `perf.gd`, `cpu.gd`).

## Left

- A real walker: getting out of the plane. Then feed `walker()` from the motor and judge the parting live.
- The plane feeling the gusts, through SkyPlane's `air` hook.
- From cruise height (45 m) there is no wash, by design. A gust there reads only as a faint ring.
- The gust can look like a pale disc when seen flat from far off.
- Tune all of this by playing it. The knobs are the consts at the top of grass_react.gd.

## Tests

None added. test_breeze, test_ground_look, test_gust_fronts, test_pilot_wake and test_sky_peak_look pass. No test is known to break.
