# Motif brief

The shared instruction for brainstorming motifs and kit pieces (the
`/motif-brainstorm` skill reads it). Three parts: **lenses** rolled per
brainstorm so ideas spread apart, **coverage** (what exists, so new ideas
land where we're thin) and the **card formats**. Edit it as taste moves.

## 1. Lenses (roll two or three per brainstorm, or assign them)

| Axis | Values |
|---|---|
| Verb (what you do there) | climb, ride, stay hidden, time a crossing, solve, defend, fall/descend, chase, carry |
| Scale | intimate, human, colossal, a fragment of something bigger |
| Mood | quiet, oppressive, sacred, playful, wrong |
| Shape among isles | spread wide, a tight cluster, a tall stack (isles over isles), a hanging underside, a ring, a line |

## 2. Coverage (what exists)

**Motifs** (scripts/kit_isle/motif_*.gd):

| Motif | What it is | Family (knobs) |
|---|---|---|
| broken_ring | stone circle round a broken turret, spiral of 8 islets climbing 21 m, rope bridges, floating stones | yes |
| colonnade_spine | knife-edge ridge, processional colonnade, terraces, temple gate, live rope bridges | yes |
| sundered_gorge | two drifted halves, snapped bridge + rope bridge, gatehouse, leaning tower, chapel, spring pool | no |
| stair_clouds | stepped mesa, grand stair in 8 flights, shrines on landings, summit gate, pinnacle | no |
| bell_spires | rock spires, belfry with a swinging bell (rung by landing/plane/slam), four rope bridges | no |
| cloister_tarn | crater bowl round a still tarn, ruined cloister, crag stair, 4 satellites, curtain fall | no |
| drowned_nave | shallow basin, half-drowned gothic nave, apse with rose gable, causeway of fallen stones | no |
| hollow_keel | plate with a shaft; a colossus hall hung under it (fly-through undercroft), switchback stairs | no |
| dragon_roost | crag mountain with the dragon's nest ledge and hoard (set piece, the roost only) | no |

Hand-authored motifs from the motif editor: `motifs/authored/*.json`.

**Kit** (scripts/ruin_kit.gd FAMILIES, 25 pieces; "Mesh" + "Body", foot on
y 0):
- gothic (14): pier, arch, lancet_wall, rose_gable, buttress, wall, stairs,
  turret, vault, fallen_pier, tomb_chest, floor, grand_stair, stone_circle
- aqueduct (5): span, two_tier, broken, stump, end
- hall (4): colossus column, architrave beam, roof slabs, hall bay
- tower (1): tower_shell; horn (1): wind_horn
- outside FAMILIES: ruin_kit_cloister.gd (arcade ranges, lavabo, rope-bridge
  heads, slab bridge), ruin_kit_belfry.gd (belfry, bell, anchors)
- foot pieces: rope bridges (scripts/rope_bridge.gd, live sim), footbridge,
  floating/bob/drift stones, swing ropes, balustrade slide

**Threats built** (scripts/traps/, scripts/enemies/): seesaw (+drop,
dropper, slam), sluice, wind (+blaster), flip, logs, ray, tumble
(+tumble_run), voussoirs; inhaler head, headless body, plinth ram.

**Knocks and stuns:** PilotMotor `knock(v, source)` stuns and throws, `toss`
throws (a stunned body stays stunned), every trap acts on a stunned body
(scripts/pilot_motor.gd's header). One source can't restun for
`restun_gap` (1.2 s); after `stun_chain_cap` (3 s) the player can always
break out. The pilot's moves: run, jump, twirl, slide, rail slide, wall
kick, ledge grab and chain, rope swing, pocket sail (glide), flow charge
(updraft up, downdraft slam), binoculars.

**Hard limits.** The motif contract (scripts/kit_isle/kit_motif.gd:
sockets rim/arena/cover/perch, role, footprint, height_span, knobs). Sizes
from the pilot, never copied metres (AGENTS.md, Sizes; RuinKit's Scale
section; WorldScale).

## 3. Card formats

**Motif card** (one file per card):

```
# <Name>
Lenses: <the rolled ones>
Pitch: two sentences.
Place: the landform and what's on it; the view on arrival.
Top (ASCII, ~40x16, 1 char ≈ 4 m) and Side (ASCII) — symbols: digits isles,
  '.' route, '~' gulf, '@' landmark, '#' stone, '"' growth, 'o' threat,
  '^' rim, 'A' arena, 'C' cover, 'P' perch.
Play: the routes through it, beat by beat, naming the pilot's moves; what
  the player chooses between.
Threat (if any): the trap/enemy/hazard here.
Ports: what it catches from outside and what it throws out.
Kit used: existing pieces by id (verify each exists).
Kit asks: pieces it wishes it had (one line each), or "none".
Family knobs: 2-4 knobs and their values (what a seed varies).
Sockets: rims (where, facing), arenas, cover, perches.
Fit: role, rough footprint and height span.
Distinct from: the nearest existing motif and why this isn't it.
```

**Kit piece card**:

```
# <Name> (<proposed id>, family <name>)
Verb: what the pilot does with it (or "dressing").
Look: shape and surface.
Behaviour: static / moves / changes state / launches; trigger; timing.
Size: in pilot terms (reach, ledge, opening via WorldScale.opening).
Collision: what's walked (clean boxes), what's wall-kickable, hulls.
Motifs it enables: 2-3 one-liners.
Catches / throws: body states it accepts (standing, airborne, tumbling/
  stunned, riding) and what it does to each; what it outputs (direction,
  speed in pilot terms, `knock` or `toss`, its source name).
Build cost: low/med/high, and why (Blender model? procedural? physics?).
Model budget: which tricks in docs/art/model-budget.md apply.
```

## 4. From card to isle

1. **Card** (`/motif-brainstorm`): text and ASCII, cheap, many.
2. **Place** (`/motif-greybox`: `scripts/kit_isle/greybox/gb_<slug>.gd`,
   played in the motif yard, `studies/motif_yard.tscn --motif=<slug>`): on
   the real terrain from the start (`KitLand.island`: outline, stepped
   height function whose steps are grabbable cliffs, keel; RuinKit pieces;
   sky, light, flora, water), then the routes walked with the real pilot,
   then any hazards. Grey boxes only for a piece the kit lacks, labelled
   STAND-IN. The layout lives in one data table.
3. **Dressing pass** (`/motif-turf`, the picks only): growth, wear, life,
   the model budget.

## 5. Rounds

None yet. Rounds go in docs/design/motifs/brainstorm/roundN/.
