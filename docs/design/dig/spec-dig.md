# Spec: digging with a spade (loop `dig`)

In the wreck cluster (`studies/wreck_cluster.tscn`, `run-wreck-cluster.command`;
its handoff is `docs/design/wreck-cluster/handoff-wreck-colonnade.md`), the
wanderer finds a spade and digs up things buried at strange spots in the soil.
Digging is about finding: you walk up to a spot that looks odd, dig, and
something comes up. It is not a minigame (no meter, no timing, no repeated
presses). The fun is in the dig itself, its feel and the reveal.

A sibling loop, `carry` (`iter/carry`, `docs/design/carry/spec-carry.md`),
adds picking up and carrying things in the same cluster. The two will merge
later, so keep this loop's code in its own new files and its edits to shared
files (the motor, input setup, `studies/wreck_cluster*.gd`) small and
additive. Leave carrying to that loop.

## Done looks like (what the user plays and sees)

1. **The spade.** It lies by the wrecked plane. Walk over it or press the
   interact button and it's yours, carried on the wanderer's back from then
   on. A new deal (N) puts it back by the plane.
2. **Dig.** Its own input: a free key plus a gamepad button (find the input
   setup and the motor's bindings, and check for clashes). One press plays a
   short dig: anticipation, a couple of spade strokes, dirt thrown, a sound.
   It reads at a glance and feels good to do even where nothing is buried.
3. **Soil only.** The spade bites turf and soil. On rock or ruin stone it
   clanks and bounces off (a recoil and a spark or chip, no hole). In the air,
   mid-climb or swinging, it does nothing.
4. **Strange spots.** About 8–12 buried spots in the cluster's soil, each
   marked by a small surface tell that a curious player notices up close but
   that doesn't shout from far off. Vary the tells: a low mound of turned
   earth, a ring or line of small stones, a lone leaning marker stone, a
   patch where the grass won't grow, something poking out (a strap, a
   corner). Put them where exploring takes you (under an arch, at the foot
   of the tower, out on an islet's tip, at the end of a flank walk), not in
   the open middle of the strip. Name each through `scripts/layout_overrides.gd`
   as `wreck_cluster/dig_spot_NN` so the user can move them in F4.
5. **Finds.** Digging a spot brings its find up out of the ground with a
   small reveal (it pops up, a beat of dust, the collect sound). The deal
   decides what is buried: give part spots on soil a new holder type
   `buried` (beside `lying` and `cache` in `studies/wreck_cluster_art.gd`)
   so a plane part can be dealt into the ground, and fill the other dig spots
   with collectibles the game already has (runes, coins or whatever exists;
   don't invent a new currency). A dug spot stays dug for the rest of the
   deal.
6. **The hole.** A dug spot leaves a visible hole or scooped dirt with a
   spoil heap beside it, and digging plain soil anywhere else leaves a small
   scoop. The first task is a short probe of how the terrain is built
   (KitLand, NativeTerrainData, the terrain kernels): if a real dent in the
   terrain is cheap and safe, use it; otherwise fake it with a decal or mesh
   laid on the ground. Either way, write down in the trail what real
   deformation would cost. Holes never change the strip's collision; the
   strip stays a clear run to land on by hand (AGENTS.md).
7. **Re-deal.** N (or Esc, New deal) fills the holes, re-buries and re-deals,
   as the rest of the cluster does.

## Out of scope

Carrying things (loop `carry`), digging tunnels or into caves, digging
outside the wreck cluster, committed tests.

## Proof, per task

- The smoke check of `studies/wreck_cluster.tscn` passes.
- Anything played: a throwaway driver through the real play loop and input
  path (`tools/drive.py`; run `python tools/drive.py --api` first), left in
  `scratch/`: walk to the spade and take it, walk to a spot, press dig, get
  the find; dig on rock and get the clank.
- Anything seen: rendered stills or a short capture (`tools/shot.py`,
  `-- --no-title`), looked at before committing. The dig motion is judged in
  a capture, not a still.
- The dig motion may be procedural on the existing rig for now. List it in
  the trail as stood in: clips authored in Blender come with lock-in
  (AGENTS.md, Animation). The spade, if it's a new model, notes the
  `docs/art/model-budget.md` tricks that apply.
- Runs use `--ledger=/tmp/...`; drivers write only to `/tmp` or `scratch/`.
  Don't touch the user's saved layouts.

## Loop

Model Opus. Cap and budget: the skill's defaults. Size each task so it ends
in something the user can launch or look at, and get to a first playable dig
(spade, press, dirt, a find) as early as possible, then add the rest.
