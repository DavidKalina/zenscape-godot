# The colosseum grown, more ruins (2026-10-28)

Branch `claude/amberlands-map-expansion-940998`. A prototype round: proved
by smoke and throwaway drivers (in `scratch/col/`, uncommitted), no tests.

## Fly it

```
.\run-endless-flight.cmd --world=amberlands --at=-2050,1150 --alt=160 --heading=290
```

Seed 1's nearest colosseum is at (-2374, 1373), 2.7 km north-west of the
start, and the plane spawns 400 m short of it heading in. It's the only
one within 4 km of the start (`--sets=colosseum` finds no other within 3 km).

## What changed

- **The colosseum is twice the size** (`scripts/ruin_kit_colosseum.gd`,
  `K := 2.0`): 320 x 380 m, 100 m tall. Every length scales by K: the
  plan, the toy widths of its openings, the stone blocks (`_kbuild`), the
  collision grid and the far shell (now 850 m out). Its openings are twice
  as wide: arcade arches 12.8 m (were 6.4), tight ones 10.8, great gates
  20 m, ambulatory 28 m, trench 22 m.
- **More open**: fewer walled-up outer arches (6% of bays, was 13%) and
  fewer tight ones (7%, was 11%). The first-tier passages under the seats
  are open: from outside, straight through an outer arch, across the
  ambulatory, through the inner wall and under the seats into the arena
  (5 on seed 1; the broken side loses its own).
- **Things to fly through inside** (`works`, `_arena_works`):
  - the spina: three free-standing arches over the trench on the long
    axis (26 m clear, springing 18 m over the arena floor, open down to the
    trench floor), one with its crown fallen;
  - an aqueduct across the bowl on the short axis, rim to rim, 70 m over
    the foot. Its three middle arches stand over the arena and are flown
    (30 m and 26 m clear). Its end on the broken side has fallen: one
    falling arch, a pier stump standing on the seats, its stones tumbled
    on the seats.
  - The long-axis line now runs south gate, gate passage, spina, the
    aqueduct's middle arch, spina, north gate. The new arches are in
    `openings` (kind `arch`), so the rival's race can use them.
- **More ruins in the amberlands**: arch tries 1.8 -> 2.6, ruin share
  1.6 -> 2.2, ruins up to 1000 m from high ground (was 700), up to 3
  arches a cell (`arch_most` layer, new; other worlds keep 2). Set cells
  1400 -> 1000 m, so the gothic set pieces come about twice as often. The
  colosseum's spot is sized to its new footprint (236 x 208 m half), the
  ground allowed 12 m of spread under it (its footings reach 16 m), and
  its chance a cell is 0.22 (was 0.12; the cells are half the area).

Seed 1, within 4 km of the start: 248 -> 331 pieces (3.3 -> 4.4 per km²).
Gate ruins 45 -> 67, aqueducts 60 -> 90, nave/belfry/rose gate 22 -> 42.
The old handoff's coordinates for the set pieces no longer hold.

## Proof

- Smoke PASS, 0 errors: default, `--world=amberlands`,
  `--world=amberlands --sets=colosseum`, `--world=regions`.
- Lines swept with the wings (a 1.6 m ball every 1.5 m, wobbled up, down
  and to each side) against the real colliders in the running game:
  long axis at 28 m clear to 6 m of wobble, trench to 6 m, outer arcade
  arches to 4 m (at the old size, about 1.6 m of slack a side before any
  wobble), first-tier passage lines to 2-3 m, aqueduct side arches to 2 m
  (limited by the seats beyond them, not the arches).
- Rendered stills judged by eye: outside, above, down the gate passage
  through the spina, the aqueduct, the broken side.

## Cost (one colosseum, near level)

Stone and colliders cost the same as before (everything scaled together):
bays 130k triangles (135k), boxes 23.0k (21.2k). Growth went up because
the kit's moss cushions count by top area: rings growth 46k -> 165k,
bays' growth 191k -> 282k, so about 660k triangles in all (was 450k). The
build takes 5.8 s on a worker (was 3.2 s).

Model budget tricks: the colosseum already has generated LODs, visibility
ranges and the far shell (import LODs), silhouette breaks and vertex-colour
crevice AO. The one worth doing next is thinning the cushions on the
colosseum's Build to its old count, about 120k fewer growth triangles
(an estimated 0.3-0.5 ms on a low-end GPU while inside it). Sculpt-and-bake,
rigid parts and parallax don't apply.

## Open

- A headless exit hang predates this round: smoke at
  `--world=amberlands --at=-2050,1150` finishes its 400 frames, then never
  quits (on the unchanged commit c0bae118 too, with `--no-sets`). It looks
  like an arch-cell task still in flight when `land_arches` waits on it
  at `_exit_tree`. Play isn't affected as far as seen.
- Not hand-flown yet. The wobble sweep says the openings fit, not that
  the lines feel good.
- The seats' treads are 6.8 m deep and 3.8 m tall now, which reads chunky
  from inside the bowl. Doubling the tread count instead would cost seat
  geometry.
- No tests broke (none cover the colosseum or the plans).
