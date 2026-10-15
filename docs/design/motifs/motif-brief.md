# Motif brief

The shared instruction for brainstorming motifs and kit pieces (the
`/motif-brainstorm` skill reads it). Three parts: **pillars** every idea
keeps, **lenses** rolled per brainstorm so ideas spread apart, and
**coverage**: what exists, so new ideas land where we're thin. Edit it as
taste moves.

## 1. Pillars (always)

- **A place first.** A motif is a beautiful place before it is a level:
  a landform and a silhouette (a ridge, a split gorge, a mesa, a crater
  bowl), seen whole as you arrive, with ruins sitting *in* the terrain,
  broken unevenly and half taken by growth. Mostly land with stone on it,
  in the same world as the original kit motifs (sundered_gorge,
  colonnade_spine, stair_clouds: the bar for effortless beauty). Play
  comes from moving through it: platforming, the view, the threat. The
  greybox round 1 motifs (2026-10-14 verdict: good, but "a different
  game") began as box layouts tuned for chains and were dressed last;
  grids, stacked plates and placed collapse are what that looks like.
- **Rune-carved stone, overgrowth, mystery.** The ruins were made by someone,
  for something; the player pieces it together. Ancient and melancholy, not
  cozy. Collapse and decay read as authored.
- **The Olmec bar.** The hovering inhaler head and the headless stone body
  (scripts/enemies/, docs/art/olmec-weathered.md) are the user's favourites: heavy
  weathered basalt, rune grooves, a pale polished eye that locks on, colossal
  and silent. New ideas should sit beside them: their makers, their homes,
  their kin, their ruins.
- **Every motif has a threat that belongs to it**: a trap, an enemy or a
  hazard born of the place, not dropped on top. Every danger is also a tool.
- **Anything could chain.** Physics where anything can happen: spat out
  of one Olmec head into another, caught by an updraft, dropped onto a
  seesaw that flings you on. Combos are **emergent**: they come out of consistent
  systems, not out of the layout. Every *piece* is a link: what it
  **catches** (a body standing, airborne, tumbling/stunned, riding) and what
  it **throws** (which way, how hard, still stunned or not). A *motif* sets
  hazards and enemies loosely within reach of each other (a seesaw in
  throwing range of an updraft, a head that can see where a trap lands you)
  and lets them meet wherever the player is; threats that hunt or aim at
  the player do this best. The route never depends on a chain, and no
  combo is a line the motif was built along (the Plumb Well, crossed out
  2026-10-14: "too scripted of a combo sequence"). The machinery
  exists: PilotMotor `knock(v, source)` stuns and throws, `toss` throws (a
  stunned body stays stunned), every trap acts on a stunned body, the figure
  ragdolls procedurally (scripts/pilot_motor.gd's header). Different
  sources chain freely; one source can't restun for `restun_gap` (1.2 s);
  after `stun_chain_cap` (3 s) the player can always break out. So a combo
  is a hand-off between *different* things, and a good one is also a
  shortcut a skilled player can choose to ride.
- **Physics, not damage.** Deaths are falls and knock-offs. Comedy from
  danger and physics, never jokes.
- **The pilot is fast and nimble**: run, jump,
  twirl, slide, rail slide, wall kick, ledge grab and chain, rope swing,
  pocket sail (glide), flow charge (updraft up, downdraft slam), binoculars.
  A motif is a playground for that kit.
- **Hard limits.** The motif contract (scripts/kit_isle/kit_motif.gd:
  sockets rim/arena/cover/perch, role, footprint, height_span, knobs). Sizes
  from the pilot, never copied metres (AGENTS.md, Sizes; RuinKit's Scale
  section; WorldScale).

## 2. Lenses (roll two or three per brainstorm, or assign them)

| Axis | Values |
|---|---|
| Verb (what you do there) | climb, ride, stay hidden, time a crossing, solve, defend, fall/descend, chase, carry |
| Scale | intimate, human, colossal, a fragment of something bigger |
| Decay | intact and still working, half-collapsed, drowned, root-bound, frozen mid-ritual, dismantled on purpose |
| Mood | quiet, oppressive, sacred, playful, wrong |
| Purpose (what it was) | observatory, tomb, aqueduct, prison, shrine, mechanism, quarry, workshop, ballcourt, calendar, nursery |
| Shape among isles | spread wide, a tight cluster, a tall stack (isles over isles), a hanging underside, a ring, a line |
| Twist on a pillar | runes that move, overgrowth as the threat, an Olmec piece as terrain not enemy, the threat as the only way across, the ruin still doing its old job |

## 3. Coverage (what exists)

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
(+tumble_run), voussoirs; inhaler head, headless body, plinth ram.

## 4. Card formats

**Motif card** (one file per card):

```
# <Name> — "<epithet in the ledger's voice>"
Lenses: <the rolled ones>
Pitch: two sentences, how it feels to arrive.
Place: the landform and silhouette; the view on arrival (from where, what
  you see first, what draws the eye); how the ruin sits in the land and
  how it broke; what the land is and what the stone is.
Top (ASCII, ~40x16, 1 char ≈ 4 m) and Side (ASCII) — symbols: digits isles, '.' route, '~' gulf, 'R' roost-ish
  set piece, '@' landmark, plus '#' stone, '"' overgrowth, 'o' threat,
  '^' rim, 'A' arena, 'C' cover, 'P' perch.
Play: at least two routes through it, beat by beat, naming the pilot's
  moves; what the player chooses between.
Threat: the trap/enemy/hazard that belongs here; how it's also a tool.
Could combo: which hazards and enemies sit within reach of each other, and
  one or two things that might happen when they meet (a hunch, not a
  sequence). Ports: what it catches from outside (a body thrown in from a
  neighbouring isle, the dragon's swipe) and what it throws out.
Mystery: what it was, what the player pieces together.
Kit used: existing pieces by id (verify each exists).
Kit asks: pieces it wishes it had (one line each), or "none".
Family knobs: 2-4 knobs and their values (what a seed varies).
Sockets: rims (where, facing), arenas, cover, perches.
Fit: role, rough footprint and height span, the shape among isles it suits.
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
  can be aimed (so it can be pointed at the next link).
Chains with: existing traps/enemies/pieces it hands off to and from.
Build cost: low/med/high, and why (Blender model? procedural? physics?).
Model budget: which tricks in docs/art/model-budget.md apply.
```

## 5. From card to isle

1. **Card** (brainstorm round): text and ASCII, cheap, many. The Place
   field comes first.
2. **Place** (`/motif-greybox`: `scripts/kit_isle/greybox/gb_<slug>.gd`,
   played in the motif yard, `studies/motif_yard.tscn --motif=<slug>`): the land
   and the ruin first, on the real terrain and in the kit-isle look from
   the start (`KitLand.island`: outline, stepped height function whose
   steps are grabbable cliffs, keel; RuinKit pieces; sky, light, flora,
   water). Judged first by rendered stills from the arrival view: does it
   read as a place, beside the original kit motifs? Then the routes,
   walked with the real pilot, distances from the pilot's numbers. Then
   the hazards and enemies, set in loosely where the place gives them a
   reason to be. Grey boxes only for a piece the kit lacks, labelled
   STAND-IN. The layout still lives in one data table.
3. **Dressing pass** (`/motif-turf`, the picks only): growth, wear,
   collapse, life, the model budget; the finished form. A motif greyboxed under the old pipeline (grey boxes tuned to
   chains) gets its place made here instead: the land leads, and the
   hazards move to suit it.

**Later: the combo lab** (a skill, once enough links exist and the combo
blockers are fixed). A headless harness drops the real pilot into placed
motifs across many parallel Godot processes, jittered, and logs which
hazards meet by themselves: their knock sources, landings and how often.
It tunes pieces (throw strengths, reach) so systems combo more often; it
never lines a motif up along one chain. Needs: every trap/enemy/piece
answering `ports()` (where it catches, what it throws; the kit cards'
catches/throws fields are the spec), and the harness.

## 6. Rounds

None yet. Rounds go in docs/design/motifs/brainstorm/roundN/.
