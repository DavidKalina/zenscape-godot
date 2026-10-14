# Motif brief

The shared instruction for brainstorming motifs and kit pieces (the
`/motif-brainstorm` skill reads it). Three parts: **pillars** every idea
keeps, **lenses** rolled per brainstorm so ideas spread apart, and
**coverage**: what exists, so new ideas land where we're thin. Edit it as
taste moves.

## 1. Pillars (always)

- **Rune-carved stone, overgrowth, mystery.** The ruins were made by someone,
  for something; the player pieces it together. Ancient and melancholy, not
  cozy (concept.md, Tone). Collapse and decay read as authored and hide the
  generator.
- **The Olmec bar.** The hovering inhaler head and the headless stone body
  (scripts/enemies/, docs/design/roguelike/olmec-weathered.md,
  inhaler-head.md, headless-body-round*.md) are the user's favourites: heavy
  weathered basalt, rune grooves, a pale polished eye that locks on, colossal
  and silent. New ideas should sit beside them: their makers, their homes,
  their kin, their ruins.
- **Every motif has a threat that belongs to it**: a trap, an enemy or a
  hazard born of the place, not dropped on top. Every danger is also a tool
  (shortlist.md, thread 4).
- **Everything chains (the spirit of the game).** A physics game where
  anything can happen: spat out of one Olmec head into another, shot from a
  cannon while ragdolled, caught by an updraft, dropped onto a seesaw that
  flings you on. Spelunky's chain: the world decides where you go, the cost
  is position. Every motif and piece is designed as a link: what it
  **catches** (a body standing, airborne, tumbling/stunned, riding) and what
  it **throws** (which way, how hard, still stunned or not). The machinery
  exists: PilotMotor `knock(v, source)` stuns and throws, `toss` throws (a
  stunned body stays stunned), every trap acts on a stunned body, the figure
  ragdolls procedurally (docs/design/roguelike/stun-round1.md). Different
  sources chain freely; one source can't restun for `restun_gap` (1.2 s);
  after `stun_chain_cap` (3 s) the player can always break out. So a combo
  is a hand-off between *different* things, and a good one is also a route a
  skilled player rides on purpose.
- **Physics, not damage.** Deaths are falls and knock-offs. Comedy from
  danger and physics, never jokes.
- **The pilot is fast and nimble** (concept.md, The pilot's tech): run, jump,
  twirl, slide, rail slide, wall kick, ledge grab and chain, rope swing,
  pocket sail (glide), flow charge (updraft up, downdraft slam), binoculars.
  Motifs are Odyssey/Galaxy playgrounds for that kit.
- **Hard limits.** The motif contract (scripts/kit_isle/kit_motif.gd:
  sockets rim/arena/cover/perch, role, footprint, height_span, knobs). Sizes
  from the pilot, never copied metres (AGENTS.md, Sizes; RuinKit's Scale
  section; WorldScale). The generator only moves isles, never turns them.

## 2. Lenses (roll two or three per brainstorm, or assign them)

| Axis | Values |
|---|---|
| Verb (what you do there) | climb, ride, stay hidden, time a crossing, solve, defend, fall/descend, chase, carry |
| Scale | intimate, human, colossal, a fragment of something bigger |
| Decay | intact and still working, half-collapsed, drowned, root-bound, frozen mid-ritual, dismantled on purpose |
| Mood | quiet, oppressive, sacred, playful, wrong |
| Purpose (what it was) | observatory, tomb, aqueduct, prison, shrine, mechanism, quarry, workshop, ballcourt, calendar, nursery |
| Shape in a layer | spread wide, a tight cluster, a tall stack (isles over isles), a hanging underside, a ring, a line |
| Twist on a pillar | runes that move, overgrowth as the threat, an Olmec piece as terrain not enemy, the threat as the only way across, the ruin still doing its old job |

## 3. Coverage (what exists)

**Motifs** (scripts/kit_isle/motif_*.gd; in the generator's POOL or not,
scripts/roguelike/layer_plan.gd):

| Motif | What it is | Family (knobs) | In pool |
|---|---|---|---|
| broken_ring | stone circle round a broken turret, spiral of 8 islets climbing 21 m, rope bridges, floating stones | yes | yes (1) |
| colonnade_spine | knife-edge ridge, processional colonnade, terraces, temple gate, live rope bridges | yes | yes (3) |
| sundered_gorge | two drifted halves, snapped bridge + rope bridge, gatehouse, leaning tower, chapel, spring pool | no | yes (3) |
| stair_clouds | stepped mesa, grand stair in 8 flights, shrines on landings, summit gate, pinnacle | no | yes (1.5) |
| bell_spires | rock spires, belfry with a swinging bell (rung by landing/plane/slam), four rope bridges | no | yes (1) |
| cloister_tarn | crater bowl round a still tarn, ruined cloister, crag stair, 4 satellites, curtain fall | no | no |
| drowned_nave | shallow basin, half-drowned gothic nave, apse with rose gable, causeway of fallen stones | no | no |
| hollow_keel | plate with a shaft; a colossus hall hung under it (fly-through undercroft), switchback stairs | no | no |
| dragon_roost | crag mountain with the dragon's nest ledge and hoard (set piece, the roost only) | no | roost |

Where they bunch: almost all gothic or classical (abbey, nave, colonnade,
belfry); verbs are mostly "climb stairs, cross rope bridges, hop floating
stones"; only hollow_keel hangs under; nothing is a true vertical stack;
nothing is built in the Olmec makers' own style; few motifs move.

**Kit** (scripts/ruin_kit.gd FAMILIES, 25 pieces; all stone with wear and
growth, "Mesh" + "Body", foot on y 0):
- gothic (14): pier, arch, lancet_wall, rose_gable, buttress, wall, stairs,
  turret, vault, fallen_pier, tomb_chest, floor, grand_stair, stone_circle
- aqueduct (5): span, two_tier, broken, stump, end
- hall (4): colossus column, architrave beam, roof slabs, hall bay
- tower (1): tower_shell; horn (1): wind_horn
- outside FAMILIES: ruin_kit_cloister.gd (arcade ranges, lavabo, rope-bridge
  heads, slab bridge), ruin_kit_belfry.gd (belfry, bell, anchors)
- foot pieces: rope bridges (scripts/rope_bridge.gd, live sim), footbridge,
  floating/bob/drift stones, swing ropes, balustrade slide
- the style gap: **nothing in the kit is the Olmec makers' architecture.**

**Threats built** (scripts/traps/, scripts/enemies/): seesaw (+drop,
dropper, slam), sluice, wind (+blaster), flip, logs, ray, tumble
(+tumble_run), voussoirs; inhaler head, headless body, plinth ram. Ideas
not built yet: ideas-traps.md (22), ideas-enemies.md (15), shortlist.md.

## 4. Card formats

**Motif card** (one file per card):

```
# <Name> — "<epithet in the ledger's voice>"
Lenses: <the rolled ones>
Pitch: two sentences, how it feels to arrive.
Top (ASCII, ~40x16, 1 char ≈ 4 m) and Side (ASCII) — symbols as
  LayerSprawl.overview: digits isles, '.' route, '~' gulf, 'R' roost-ish
  set piece, '@' landmark, plus '#' stone, '"' overgrowth, 'o' threat,
  '^' rim, 'A' arena, 'C' cover, 'P' perch.
Play: the route through it, beat by beat, naming the pilot's moves.
Threat: the trap/enemy/hazard that belongs here; how it's also a tool.
Combos: 2-3 chains through it, link by link (e.g. "head blast → tumble
  onto seesaw → toss into updraft → sail to rim"), at least one by accident
  and one ridden on purpose. Ports: what it catches from outside (a body
  thrown in from a neighbouring isle, the dragon's swipe) and what it throws
  out, toward which rim/isle, so the generator could aim one motif at another.
Mystery: what it was, what the player pieces together.
Kit used: existing pieces by id (verify each exists).
Kit asks: pieces it wishes it had (one line each), or "none".
Family knobs: 2-4 knobs and their values (what a seed varies).
Sockets: rims (where, facing), arenas, cover, perches.
Generator fit: role, rough footprint and height span, layer shape it suits.
Distinct from: the nearest existing motif and why this isn't it.
```

**Kit piece card**:

```
# <Name> (<proposed id>, family <name>)
Verb: what the pilot does with it (or "dressing").
Look: shape, carving, overgrowth, how it sits beside the Olmec.
Behaviour: static / moves / changes state / launches; trigger; timing.
Size: in pilot terms (reach, ledge, opening via WorldScale.opening).
Collision: what's walked (clean boxes), what's wall-kickable, hulls.
Motifs it enables: 2-3 one-liners.
Threat pairing: how it can be a trap as well as a tool.
Catches / throws: body states it accepts (standing, airborne, tumbling/
  stunned, riding) and what it does to each; what it outputs (direction,
  speed in pilot terms, `knock` or `toss`, its source name), and whether it
  can be aimed (so the generator can point it at the next link).
Chains with: existing traps/enemies/pieces it hands off to and from.
Build cost: low/med/high, and why (Blender model? procedural? physics?).
Model budget: which tricks in docs/art/model-budget.md apply.
```

## 5. From card to isle

1. **Card** (brainstorm round): text and ASCII, cheap, many.
2. **Greybox** (`studies/greybox/<motif>.tscn`): the character study's grey
   boxes in open sky with the real pilot, traps and enemies; judges
   distances and chains in minutes. The layout lives in one data table.
   Missing pieces and mechanics are labelled STAND-IN.
3. **Turf pass** (the picks only): the table becomes a `kit_motif` built
   on the real terrain (`KitLand.island`: outline, stepped height function
   whose steps are grabbable cliffs, keel) with RuinKit pieces, shown in the
   kit-isle look (sky, light, flora, water, weather, the plane). This is
   where the magic comes back, and the form the generator places.

**Later: the combo lab** (a skill, once enough links exist and the combo
blockers are fixed). Agents propose chains; a headless harness fires the
real pilot through placed links across many parallel Godot processes,
jittered, and logs each chain by its knock sources, landing and
reliability; agents tune aims and spacing and report the reliable chains as
greyboxes. Opus designs, places and reads the chains; the bulk trial runs
are scripted. Needs: every trap/enemy/piece answering `ports()` (where it
catches, what it throws; the kit cards' catches/throws fields are the
spec), and the harness. The same ports let the generator lay combos as it
lays crossings, checked by simulation.

## 6. Rounds

- Round 1 (2026-10-13): docs/design/roguelike/brainstorm/round1/ (10 motif
  cards, 26 kit pieces, a makers family; README has the tally and picks)
