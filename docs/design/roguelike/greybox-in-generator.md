# Greybox motifs in the generator (2026-10-13)

> On `roguelike`, uncommitted. A prototype round: the pilot conversion (the
> Sunken Giant) plus the plumbing for the other nine greybox studies.

The greybox studies (`studies/greybox/<slug>.gd`, played from
`studies/greybox/hub.tscn`) can now stand in real generated layers as
isles, in the studies' own grey / orange / green look, with their traps and
inhaler heads live. It's opt-in: default runs are unchanged.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=4 --knob=greybox=sunken_giant
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=3 --knob=greybox=sunken_giant
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=3 --knob=greybox=sunken_giant
# the head-to-head relay without the headless bodies taking the heads away:
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=4 --knob=greybox=sunken_giant --knob=bodies=0
```

On Windows, use the same arguments with the Godot 4.7.2 exe from the repo
root.

- When you come onto a greybox isle, a small card shows bottom-left:
  **GREYBOX · its name**, its epithet and its brief (how to play it). After
  15 s it shrinks to one line. **G** hides it, or brings the whole card back.
- In the world, a big "GREYBOX · THE SUNKEN GIANT" label stands over the
  fingertips, and the study's station labels and chain labels are all
  there.
- The layer card (top-left) lists the isle as `gb sunken giant`.

### Seeds

Every seed tried places the giant (it is forced, see the knob):

| Seed | How the route uses the giant |
|---|---|
| **sprawl 4** | In at the fingertips (a climb of stones), out off the knee (stones and a bridge). The best one: the whole motif in order. |
| **sprawl 3** | In at the fingertips (a 204 m gulf on the serpent), out off the knee (a climb). |
| **ring 3** | In at the fingertips (the ring serpent), out off the knee (a 274 m gulf, serpent). |
| sprawl 1, 2, 6, 7 | In at the fingertips (the Loose Voussoirs). |
| sprawl 8 | In at the fingertips; the knee leads to the greed branch. |
| sprawl 5 | Backwards: in at the knee, out at the fingertips (a ferry gulf). |
| ring 1, 2, 4, 5, 7 | In at the fingertips (gulf rides). |
| ring 6, 8 | The fingertips lead to the greed branch only. |

## The knob

- `--knob=greybox=` takes `all`, a comma list of slugs (`sunken_giant`,
  `gb_` prefix optional), or nothing (the default: off, the pool as it was).
- Those motifs join the pool (weight 3.0, against the pool's 1-3), each at
  most once a layer, as a "hero" (one a neighbourhood, never the greed
  isle).
- `--knob=greybox_force=1` (the default when `greybox` is set): the layer's
  first draw is a greybox motif, and a plan with none placed is laid again
  (the next attempt). `greybox_force=0` leaves them to the draw.
- The generator's own inhaler heads and the Plinth Ram keep off a greybox
  isle (its chains are authored), and its heads keep 60 m from the greybox
  heads.

## What's in

New files:

- `scripts/kit_isle/motif_greybox.gd`: the base. A subclass gives data
  (parts in character_study's schema, rims, spots, heads, a `live` hook,
  name, epithet, brief). The base answers the motif contract from it:
  `footprint`, `height_span` and `occupancy` (per 2 m cell, ramps sampled
  along their slope) are **computed from the parts, no bake**; sockets from
  rims and spots; `build` makes the boxes, caps, ramps, cylinders, water
  and labels (nodes only, safe on a worker); role "hero". **Its header has
  the how-to-convert note.**
- `scripts/kit_isle/greybox/gb_sunken_giant.gd`: the pilot. The study's
  numbers and LAYOUT verbatim, same frame. Changes from the study:
  - The stand-in "next isle's catching rim" is **the knee** now, part of
    the giant. Head 2's blast lands you on it, as in the study, and the rim
    out (`knee`) is its far (south) edge, where a generated crossing
    attaches. That keeps the chain's landing fixed whatever the generator
    puts next.
  - Rims: `fingertips` (in, facing west over the drop, run-up 8.5 m) and
    `knee` (out, facing south, run-up 15 m). No rim on the shoulder deck,
    so the route can't skip the climb (except backwards, sprawl 5).
  - Spots: arena `lap`, cover `chest_niche` and `lap_column`, perches
    `thumb` and `neck`.
  - `live`: the rope (a plain swing rope) and the chimney updraft, the
    study's own `Updraft` class (`load(study).Updraft`), so it keeps its
    numbers.
- `scripts/kit_isle/greybox/registry.gd`: the list (`MOTIFS`, one line a
  motif), the knob parsing, the pool entries, the force rule.
- `scripts/roguelike/layer_greybox.gd`:
  - planning: `lay_heads` puts each greybox isle's heads into `plan.heads`
    at their authored spots and routes, with their bodies' cliffs
    (`LayerBodies.cliffs`);
  - the stage: one host a greybox isle for `live` (ropes, traps, enemies,
    cannons, in the world frame), stepped round the motor; the traps' air
    summed into the motor's; the HUD card.

Tracked files touched (small, additive):

- `scripts/roguelike/layer_plan.gd`: preloads the registry; KNOBS
  `greybox`, `greybox_force`; `draw_pool(knobs)` and `_most`; `_draw`
  takes the knobs (forced first draw); `_substitute` uses `draw_pool`;
  `_motif_isle` asks a motif's own `occupancy` before the box fallback;
  `_make` adds the problem "no greybox isle placed" when forced.
- `scripts/roguelike/layer_ring.gd`: `_draw` gets the knobs, `_another`
  uses `draw_pool`, the same "no greybox isle placed" check.
- `scripts/roguelike/layer_enemies.gd`: `lay` calls
  `LayerGreybox.lay_heads` (both exits); `build` merges a head's `knobs`
  (a greybox head keeps its study's knobs).
- `scripts/roguelike/layer_stage.gd`: `greybox` (LayerGreybox.dress),
  stepped in `before`, `after`, `pose`, `frame`, `reset`.

No bake: `data/layer/pieces.json` and `tools/bake_layer_pieces.gd` are
untouched.

## How it went in a real layer (headless, throwaway checks)

The harness is `C:\Users\Tenut\AppData\Local\Temp\claude\greybox-checks\generator\check_layer.gd`
(uncommitted). It loads `studies/run_layer.tscn` with run_layer's own
arguments, stands every isle (`flush`), and drives the scene's own `tick`
with the scripted stick and jump, as the greybox passes did, everything
moved by the giant's offset. `--check=climb|c1|c2|c3|label|onsmoke`.

| Check | Ring 1 (bodies on, the default) | Ring 1, `bodies=0` | Sprawl 4, `bodies=0` |
|---|---|---|---|
| Climb: knuckle jump, pump, jump; forearm; rope over the gap; chest set-offs; kick shaft; chimney | all 8 steps | | all 8 steps |
| Chain 1 (head 1 throws you back down onto the elbow ledge) | **10/10** (rest x 34.3-36.6) | | |
| Chain 2 (head to head, out onto the knee) | **2/10** | **10/10** (end on the knee at about (78.5, 23.6)) | **10/10** (head 2 gulps 4.5-6.0 s after head 1 blasts) |
| Chain 3 (stand still in the chimney updraft, tossed to the neck) | **10/10** | | |

Jitter as the greybox passes: start ±0.5 m, the heads run 1.0 ±0.2 s
before he's set down, a fresh trial each time (heads and traps reset).

- **Chain 2 with bodies on fails** because the headless bodies come for
  the giant's heads (that's how the bodies pair), take them onto their
  necks ("perched") and walk off. In 8 of 10 trials a head was on a body
  before the relay finished. With `--knob=bodies=0` it holds 10/10, with
  the same numbers as the study (head 2's gulp 4.5-6.0 s after head 1's
  blast). Head 1 took about 21 s to face east in every trial (its pacing;
  the study saw 5-30 s).
- Bodies **do find places on the giant**: every greybox head gets the full
  10 cliffs from `LayerBodies.cliffs` (on the giant itself and its
  neighbours), on every seed tried.
- **The label**: hidden off the isle; on arrival it shows the full card
  (logged "greybox: arrived on The Sunken Giant"); G hides it; after 15 s
  it's one line.
- **Smoke**: `run_layer` with the giant 400 frames headless (ring 1), and
  400 frames at `--fixed-fps 60` through the scene's own `_process` with
  the walker set down on the built giant (sprawl 3, sprawl 4, ring 3): no
  script errors.
- **Default runs unchanged**: `LayerPlan.describe` plus every head, the
  ram, the arrows, the exit and the spawn, for sprawl 1-6 and ring 1-6
  with no greybox knob, are byte-identical before and after the change.

Not verified: nothing was rendered or played by hand. The card's look and
the grid shader at layer distances are unseen. The knee-out crossing
wasn't walked. Chain 2's end was checked on the knee, not onward over the
generated crossing.

## How to convert the next greybox

The header of `scripts/kit_isle/motif_greybox.gd` has the steps. In short:

1. Copy `gb_sunken_giant.gd` to `scripts/kit_isle/greybox/gb_<slug>.gd`.
   Copy the study's numbers and LAYOUT verbatim, in its own frame (the
   generator moves an isle, never turns it).
2. `slug`, `isle_name`, `epithet` (from the card's title line), `brief`
   (one or two lines: what it's for and how to play it), `start`.
3. `parts()`: the LAYOUT as character_study parts. A stand-in "next isle"
   that catches the exit chain becomes part of the motif, its far edge the
   rim out.
4. `rims()`: at least the way in (the study's start, facing the drop) and
   the way out (where the exit chain ends). Keep rims off the top, or the
   route skips the climb.
5. `spots()`, `heads()` (inhaler heads: they join `plan.heads`), `live(g)`
   for the rest (traps, ropes, cannons, rams). Use `g.w(p)` / `g.wr(rect)`
   for world positions; use the study's own trap classes
   (`load(study_path()).Vent` etc.).
6. One line in `scripts/kit_isle/greybox/registry.gd` `MOTIFS`.
7. Check: headless import; `run_layer` with `--knob=greybox=<slug>` on a
   few sprawl and ring seeds (`describe.gd` in the harness folder prints
   the plans); the chains through the layer's tick with `check_layer.gd`
   (it is giant-specific: copy it and swap the stations).

Things the nine will meet:

- **Bodies take heads.** Any motif whose chain relies on inhaler heads
  staying put (Warden's Well, Astronomer's Hush, Plumb Well, Tithe Wheel)
  will break with bodies on. Prove chains with `--knob=bodies=0` and say
  so; if the user wants both, the cheap fix is to give greybox heads no
  cliffs (`layer_greybox.gd` `lay_heads`).
- **Other enemy kinds** (Plinth Ram, headless bodies as enemies) aren't in
  `plan.heads`: spawn them in `live` with `g.enemy(...)`.
- **Cannons**: `g.cannons()` is the stage's CannonField.
- **Water**: a "water" part becomes a pool the walker wades (the motif's
  `pools`), drawn blue.
- **The occupancy** is the parts' boxes per 2 m cell. Thin high things
  (gantries, posts) count as solid columns down to their bottom only.
- Only one greybox motif comes a layer per slug (`Registry.MOST`); with
  `all` several can come, one a neighbourhood (they're heroes).
- A non-inhaler enemy or trap that reads `study.<something>` the study
  had (its `stations`, `_hud`, `vents`) won't find it on run_layer. Keep
  `live` to the trap and enemy contracts.

## What broke, and tests

- `tests/test_run_layer.gd`: **passed** (473 s).
- `tests/test_layer_sprawl.gd`: **timed out** at 540 s with failures that
  predate this round: an exit chain of 6 crossings, the gate not on the
  threshold slab (the index error at line 133), the spawn facing, and the
  silhouette build-time budget. layer-round6-hazards.md and
  layer-round8-enemies.md list these as broken by the viaduct and heads.
  Default plans are identical before and after, so this round doesn't
  change them.
- `tests/test_motif_sky.gd`: **timed out** at 180 s with every check so far
  OK. The machine was loaded by other sessions' Godot runs; it doesn't load
  any file this round touched.
- No tests added. No existing test references the new files.

## Open questions

1. Bodies vs authored head chains: should greybox heads have bodies (as
   now), none, or bodies that wait until the walker has left the isle?
2. Should the generator prefer entering a greybox motif at its first rim
   (sprawl 5 runs the giant backwards)? It would need a rim tag the
   generator reads.
3. The card: bottom-left, 15 s, G. Right place, right length?
