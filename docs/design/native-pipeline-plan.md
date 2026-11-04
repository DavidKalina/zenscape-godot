# Native pipeline plan

Status: proposed 2026-11-03, not started. A plan to make moving hot
GDScript into the C++ kernels (`native/terrain_kernels/`) cheap and routine.

## Where we are

The kernels already follow one pattern about ten times over (land, grass,
trees, erosion, the Peak, water, the ground broad phase): a C++ kernel, a
bind class, the GDScript kept as the reference, a version gate so a stale
library falls back, `--gdscript-kernels` to force GDScript, and
deterministic maths (fdlibm, contraction off). See
`native/terrain_kernels/README.md`.

The friction:

- **The data lives in GDScript objects.** Tunnel sites, hall stretches and
  arch shapes are GDScript classes and Dictionaries. The ground broad phase
  (`ground_bind.h`) only knows each owner's rectangles; the narrow `inside`
  tests stay GDScript, so a native march calls back into GDScript at every
  point. Each port invents its own publication.
- **Two copies to keep in step,** each pair with its own one-off parity
  check (`tools/ground_parity.py`, `tools/land_hash.py`, the erosion probe,
  scratch comparisons).
- **Builds:** the Mac and Windows build their own libraries, fresh
  worktrees copy them in (`tools/worktree.py setup`), and kernels built on
  a branch don't reach other worktrees.

The 2026-11-03 frame-time flights showed the cost: the chase camera's sight
near the burrower bore cost ~1.5 ms a frame with 5-7 ms spikes, and the
game's `_sight` march ~0.3 ms every frame, all GDScript point tests.

## The plan, in order

1. **The rule** (under an hour). AGENTS.md: code that runs per frame or per
   point keeps its data in packed arrays or plain structs from the start,
   with no Dictionaries or lambdas in the hot loop, so a port is mechanical.
2. **One parity tool** (1 round). A single runner where each native piece
   registers its GDScript function, its native function and a sampler; one
   command reports mismatches and the speed ratio for all of them. Move the
   existing checks onto it. This makes step 4 safe.
3. **Libraries built automatically** (1-2 rounds). A GitHub Actions job on
   Windows and macOS runners builds the kernels per commit; `worktree.py`
   and `play.py` fetch the matching build. Ends stale and missing kernels
   and the Mac lagging. Shipping on Steam needs these builds anyway.
4. **One shared world solid in C++** (4-6 rounds, owner by owner). Every
   owner publishes its exact shape (not just rectangles) in one format, so
   any query (camera sight, plane ground, near misses, landing, the
   burrower's probes) runs wholly native. Owners: tunnels (first, from the
   native sight round), halls, arches, rocks, the Peak's towers and stair,
   ice, bore spurs and plugs, wrecks, the ships' moving arches. Procedural
   ones (the bore profile, kit pieces) are the fiddly ones.

## What it buys, and costs

- Performance work gets maybe a third cheaper per stutter: today's loop of
  flight, guess, missed fix, more splitting was mostly finding and moving
  data. A slow new query becomes a small job.
- Probably 1-3 ms a frame on the Windows PC near busy places, and no more
  multi-millisecond spikes from point marches.
- Little direct effect on feature work, beyond publishing a new place's
  shape.
- Costs: two copies of every shape test for good (the parity tool keeps it
  bearable), and a build pipeline that must stay healthy.

These are estimates from reading the code, not measured. The native sight
and steering round (branch `claude/frametime-analysis-flight-77218b`) is
effectively owner one and will give real numbers.
