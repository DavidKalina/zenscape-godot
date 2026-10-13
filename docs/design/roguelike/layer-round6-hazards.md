# The generated layer, round 6: gust arrows and the Broken Viaduct (2026-10-13)

> Branch `roguelike-hazards`, cut from `roguelike` at 682f7017, with
> `feature/viaduct-perches` merged at 6244e627. The sprawl is
> layer-round4-sprawl.md (with 4B-2) and layer-round5-roost.md. The crossing
> yard's pieces are crossing-viaduct-round1.md, -arrows.md, -heights.md and
> -perches.md.

The user, on the crossing yard: "these air cannon blasts... are actually
pretty freaking awesome. And they really up the difficulty." And: "quickly
wire up... adding these in various sections. Maybe they can also work them
onto the ground level. And maybe we can implement the crossing in some areas
because it looks pretty good."

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
```

Good seeds:

| Seed | What's there |
|---|---|
| 11 | **The viaduct** past the exit chain's threshold. 4 perches: 1 on the ground of a stair-to-the-clouds isle, 1 on the chain's stones (the one over the void), 2 on the climbs to the upper tiers. All four fired and knocked in the play check, and the viaduct was crossed. |
| 7 | The viaduct, **2 ground perches** (stair-to-the-clouds isles), 1 chain (voussoirs), 1 edge (bridge), 1 climb. None over the void. |
| 2 | The viaduct, 2 ground (bell spires, sundered gorge), 1 chain (voussoirs, over the void), 2 edge. |
| 13 | No viaduct. 2 ground (sundered gorge), 1 chain bridge, 1 greed stones, 1 climb. None over the void. |
| 5 | No viaduct. 2 ground, 1 chain, 1 climb, 1 bridge. |

The card gets a line, e.g. `Gust arrows: 1 ground, 1 chain, 2 climb (1
over the void) · The Broken Viaduct past the threshold (16 m up)`. When
the viaduct is there, the exit-side line lists `viaduct` before the gate.

Knobs:
- `--knob=arrows=<n>`: how many perches. Default -1 rolls 3-5. 0 turns
  them off.
- `--knob=viaduct=1` forces the viaduct, `0` turns it off. Default -1
  rolls it at 45%. Over seeds 1-13 it came up on 2, 4, 7, 11 and 12.
  Forced, it fit on every seed tried (1, 3, 5, 13) without a redraw.

Without `--shape=sprawl` nothing changes.

## What was placed where

All of it is in **`scripts/roguelike/layer_hazards.gd`** (new).
- `lay(plan, attempt)` plans the hazards as data. LayerSprawl `core` calls
  it once the exit chain is laid, before the spawn's view, the roost and
  the next region, so those all see the viaduct's new gate.
- `dress(stage, plan)` builds them as a child of the stage, which steps it
  after the pilot's motor.

### Gust arrows

The yard's GustArrows, perch and horn are reused as they are. The column is
the yard's `column`, "dark", `PERCH_TOP` square. The horn is
`HornStandIn`, and launchers are added with `add_launcher`. One GustArrows
holds every launcher in a layer, so they **take turns** (`TURN_GAP`, the
cooldown). That turn-taking is the timing window everywhere. On the isles,
the ruins are the cover: a ball meeting stone side-on pops.

There are three kinds of placement:
- **edge**: a perch 13-17 m off to one side of a neighbourhood edge
  (stones, a rope bridge, the voussoirs, the greed branch's hard stones),
  2-4 m above the highest point of the stretch it watches. It fires on a
  24 m stretch of the edge's path: his feet within 3.5 m of it, from 2.5 m
  under to 5 m over. The card counts the **climb** to the upper tier as its
  own kind; climb perches watch 30%, 60% or 85% of the way up, so they can
  sit by the bridge up.
- **chain**: the same, on a section of the exit chain (stones, a bridge or
  the voussoirs; never the cannon or the viaduct).
- **ground**: a perch just past an unused rim of an isle, 5.5-7.5 m out
  past its lip and 2.5 m above the higher of the rim and the turf. It fires
  on an open stretch of turf, a clear spot (perch or arena socket, room 2 m
  or more) 8-30 m inland, within 8 m of it and 3 m of its height. A knock
  throws him away from the perch, so inland. The ram's arena and the rune
  perch are skipped.

Each candidate must be clear of every isle's occupancy, every edge's path,
the ride tubes, the gulf piers and the cannons. The horn's mouth must see
the zone.

**Soft or void.** A placement is soft when, for most of its zone, the knock
direction (away from the perch, out to 15 m) or straight down finds a lower
isle 1-45 m under. Soft ones are picked first. At most 1 placement is over
the void (2 when 5 or more are asked for). Ground placements always count
as soft.

**Picking.** Placements are picked round the kinds (ground, chain, edge,
edge, ground, chain, edge), one per edge, each perch 30 m from the others.

**Reachability, by the yard's convention.** These perches are like the
yard's deck and low perches: no route out to them, so you can't slam them.
On these columns the routed and slammable kind needs a stone `slam_over`
(about 3.3 m) over the top, since a jump off the top itself is under
Slam LOW. I left that for a later round. The viaduct's own routed perches
stay slammable, with their routes.

### The Broken Viaduct

It is placed **past the exit chain's threshold**: its start rim a running
hop (the routes' `STEP_GAP`, 1.4 m) past the threshold's far edge, level
with it. It is turned so its chord (start rim to far rim, about 75 m)
runs along the chain's way. Turns of 0, ±12, ±24 and ±36 degrees are tried
until it stands clear: of every isle by occupancy, every edge but the
threshold's, tubes, piers and cannons. It is checked as lumps along its
start rim, run-up, far deck, turn platform, piers and stair, slot, slab,
far rim, perches and route stones, each down to its roots 26 m under. The
**gate moves to its far rim** (`exit().at`). The old threshold stays as a
waystone. In the plan it is one more chain edge, kind `viaduct`, whose path
is those lumps, so the roost and the next region keep clear of it.

It is built exactly as the yard builds it: `lay_out`, `build`, its own six
perches and their zones, its route stones as foot pieces (bobbing and
sinking, stepped through the stage), and its updrafts as sky currents on
the sail's air.

**Where it fits.** I didn't try it between neighbourhoods. A
neighbourhood link is 10-90 m between rims whose facings are fixed (isles
are only moved, never turned). The viaduct turns 145 degrees from its entry
to its far rim and climbs about 16 m over its 75 m chord, so a pair of rims
would rarely line up. A gulf is 110-220 m with a 25-60 m rise, too wide
and too steep for it. The chain's free-floating slabs take it with no
trouble, so that is where it goes.

### Small edits to shared files

- `layer_plan.gd`: two knobs in `KNOBS`: `arrows`, `viaduct`.
- `layer_sprawl.gd`: preload, the `lay` call in `core` (a forced viaduct
  that doesn't fit redraws), `dress` builds the hazards, the card line.
- `layer_stage.gd`: `hazards` var, forwarded in `before` / `after`.
- `studies/run_layer.gd`: the knobs in the header comment.
- `studies/crossings/*`: **untouched**.

## Checks done (headless)

- Import: no errors.
- Smoke: `run_layer.tscn --shape=sprawl` for 600-900 frames on seeds 11, 7
  and 4, seed 3 with both knobs at 0, and seed 13 with `viaduct=1
  arrows=6`. No script errors.
- Plans over seeds 1-13: every seed laid; the hazards cost no extra draws.
- Throwaway play check through the real loop (`study.tick`, the motor,
  scripted stick; left uncommitted), seed 11:
  - Every one of the 4 launchers wound up, fired and hit him:
    - the ground perch shoved him standing;
    - the chain perch threw him off a stone mid-hop into the void (its
      void placement);
    - a climb perch threw him and he landed 12.6 m lower on a lower piece
      (a soft placement);
    - the other climb perch shoved him standing.
  - The viaduct, hazards off:
    - the hop from the threshold lands on its start rim;
    - a chain of three long jumps lands on the far deck;
    - a jump then a pump on each landing reaches all 10 piers and the
      plinth;
    - the slide, long jump and twirl reach the far rim;
    - the gate stands on the far rim (`at_exit` true there).

## Unverified

- **The look**: nothing was run windowed. Perch and horn placement against
  the isles' art, whether the ground perches read as "off the rim", and
  the viaduct's greybox next to the painted isles are all unseen.
- **Fairness by hand.** Turns and cover exist, but nobody has played a
  layer with them. In particular:
  - a chain perch on the voussoirs (the trap falls behind you) may be too
    much;
  - several layers' void placement is that one.
- The viaduct's own arrows fire on top of the layer's. They are two
  GustArrows, so they don't take turns with each other. Placements keep
  apart from the viaduct by clearance, but the zones aren't checked for
  overlap.
- The sound of the launchers (the isle's beasts audio) was wired as the
  yard does, but not heard.
- The `K` toggle from the yard isn't wired. Use `--knob=arrows=0`.
- Ground spots come only from the motifs' baked or family sockets. The
  aqueduct base gets none.

## Tests this breaks (not run; prototype round)

- `tests/test_layer_sprawl.gd` (slow), on seeds that roll the viaduct:
  - the chain can be 6 long (LINKS.y is 5);
  - the gate isn't on the threshold slab;
  - its corridor and on-foot checks would try to drive the `viaduct` edge;
  - the roost and next-region numbers shift.

  On every seed, the gust arrows are on while it drives the edges, so a
  driven crossing may be knocked off. It needs the knobs (`arrows=0
  viaduct=0`) or to learn the new edge kind.
- `tests/test_run_layer.gd` uses round 3's shape, so it should be
  unaffected.
