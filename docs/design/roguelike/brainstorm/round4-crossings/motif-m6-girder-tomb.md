# The Girder Tomb — "Laid in the road they walk, so the walking never stops."
Lenses: verb STAY HIDDEN · mood SACRED/OPPRESSIVE · shape A HANGING UNDERSIDE (inside the span) · purpose TOMB (also a processional way) · decay half-collapsed · scale a fragment of something bigger

Pitch: The Olmecs bury their dead in the causeway itself: a hollow box girder under the road, a gallery 2.4 m high and just wide enough for one small walker, lit only by lamp niches and by hairlines of light where the deck slabs meet. You cross a hundred metres of it in the dark with the sound of bodies treading the stone a metre over your head, and three times the roof is gone and you must cross the open bay under the sky of the city, where whatever is on top can look down.

Place:
- **Landform.** The causeway is the same colossal thing as the Underway (battered corbelled piers, level deck, `CityKit` module `CELL` 4.4 m), but thicker: a girder 6.4 m deep (4 `SET_OFF`s) instead of 3.2, so the box inside it has a floor 1.2 m thick, a gallery 2.4 m high and a 1.4 m roof. Four spans, 106 m, between a near landing and a far gate set in a sheer wall of the next isle. The far isle is *seen across* the gulf as a mass of cliff with the road driven into it like a nail, the gate a black square at the end of the line of cressets.
- **Arrival view.** From the near landing the Way is a long dark bar with a bright upper edge: the deck's cressets glint on the parapets, the girder below is a flat brown-black mass with one row of narrow windows (the gallery's slots, 0.4 m high) on the gulf flank, each with a smudge of lamplight. At two points (spans 2 and 3) the flank's black wall is simply missing for 8.8 m, and you see straight into a lit hall inside, with a body standing in it. That is the open bay: the roof fell, the floor stayed, and it is a chamber a body can use.
- **How it broke.** The roof of three bays fell at once (a quake, or a body standing too long). Their slabs lie in the gulf; their edges are ragged, bound with root. The gallery goes dark again past each. The stone is weathered basalt (`olmec_stone`) with water streaks where condensation runs down the inner wall; clay lamps at pilot height every 4.4 m in votive niches (`city_niches` language) burn low; the dead lie in long niches on both walls of the gallery, shrouded shapes of stone: a tomb you walk between at a crouch.
- **The gallery (walker-only).** 2.6 m wide, 2.4 m high, 106 m long. Walker-only (`scripts/walker_only.gd`), so the bodies never plan into it. In the open bays the gallery floor widens to the girder's full 9.4 m: shared ground, where a body can drop in.

Top (ASCII, 1 char = 4 m, the girder's plan; the gallery is '#', open bays 'A'):
```
 near      span 1        span 2          span 3         span 4        far
 landing  |#######|##AAAA##|#######|######|AAAA###|##AAAA##|#######|  gate
  [ 1 ]===|--o----|--------|-------|--o---|--------|-------|--o----|==[ 2 ]
  @  ^    | niche |  open  |       |      |  open  |  open |       |    @
 '#' gallery (walker only)  'A' open bay (shared)  'o' bearer on the deck
```
Side (one span; the girder in section):
```
 parapet   ▌                                    ▐        y 0   deck, bodies
 deck      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       y -1.4  roof (1.4 m)
 gallery   ░  ░  ░ lamp  ░  ░  ░  ░  ░ lamp ░  ░         2.4 m clear
 floor     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       y -5.0
 open bay  ▓▓▓▓▓▓       (no roof)      ▓▓▓▓▓▓▓▓▓▓▓       the chamber, 8.8 m
 slot (flank) ─  0.4 m high windows onto the gulf, every 2 cells
```

Play:
- **Route A, the gallery (hidden).** Go in by the near landing's low door (walker-sized, `city_slotwall` language: a slot only the wanderer fits). Creep the gallery: 1.9 m/s sneak, a noise of 1 to 1.5 m; a walk, 4 m; the hairline light slots at each deck seam (`maker_shaft` shafts, 0.3 m wide) fall on the floor every 4.4 m, and **crossing a shaft is seen from above** (it is a SightLight; the body above looks through the seam, only at the exact spot). So you time each shaft against the bodies' footfalls (a tread above shadows the shaft for a moment: their feet are in front of the light, and you see them cross as a flicker). Walk, wait, walk: the gallery is a rhythm game. The span is ~26 m at creep pace = 14 s per span.
- **The open bays (the exposed beat).** At an open bay the gallery's two walls drop away into a chamber 8.8 m long and 9.4 m wide, open to the sky of the city over a ragged roof edge. Three routes across:
  1. **Wall-hug.** A walker-only ledge (`SET_OFF` 1.6 m up the chamber wall, 0.6 m wide) runs the side wall, in the shadow of the broken roof's overhang. 8.8 m at the shimmy pace if the ledge is a lip to hang from (0.7 m/s, 12 s) or crouched on it (1.9 m/s, 5 s). A body on the deck at the bay's rim looks down; the overhang hides the ledge from straight above.
  2. **Run the floor.** 8.8 m at the run (4.8 m/s, 2 s): loud (14 m hearing), open to every body on the rim. The fast, risky line.
  3. **Out to the flank.** A window slot (0.4 m high is crouch-slide height) opens on the gulf face; slip out, drop-hang the sill (`HANG_DROP` 0.825), and shimmy the string course on the outside face past the open bay (8.8 m: 12.6 s at 0.7 m/s) over the haze. Silent, with the body's eye line over the parapet to the flank only if it leans out; a wrong move is the abyss.
- **Route B, the top (skip).** From a roof-fall hole climb out (the rim is a ledge a set-off up: `GRAB_TOP` 1.875) onto the deck and run 26 m of lane (5.5 s) to the next open bay and drop in. The bodies are on the deck. This is the shortcut for the nerve: it skips two spans of creep for 5.5 s in the open.
- **The choice.** The tomb's rhythm game (wait for the tread) against the open-air gambles. Both pay in time and sound; neither is a fight.

Threat: **the tomb's own keepers.** Bearers walk the deck above (headless bodies on a circuit as in the Underway). They hear through stone: noise travels the bus by distance only (noise-stealth-round1.md), so a body whose circuit passes within 4 m of a creeping pilot hears a walk. When one hears, it comes to the nearest open bay (the only way down) and **drops in** from the rim (about 6 m: well inside `drop_max`, ~22 m), landing in the chamber with a shockwave along the floor. The gallery is too narrow for it; it **stands in the chamber** (calm look dwell like `GLOW_DWELL` 10 s in the hush gallery), watching the gallery mouths, and *waits*. The chamber is now guarded by a body that won't leave and won't come in; you cross by the wall ledge above its swat, or you wait for it to go. That is the threat born of the place: the tomb has a door and a doorman.
Tool: a body standing in the chamber is a floor for a wanderer to land on from the rim (the shoulders ride, headless-body-round1.md); the chamber's shockwave reaches the gallery mouth but the gallery is walker-only (the wave runs under it); a lit lamp in a niche (`Beacon` via a lamp) draws it to the far end of the chamber while you cross the near end.

Could combo:
- A body drops into a chamber you are mid-crossing on the floor: the shock shoves you (`shock_out`) into the wall ledge or the flank slot, the opposite end of the chamber (airborne -> grab).
- A body on the rim, a body in the chamber, a pilot on the ledge between them, the roof edge breaking under the rim body (an unrepaired seam): the roof's piece falls into the chamber, lands on the body below. Loose, not a line.
- Ports in: a pilot or body thrown from the neighbouring isle can land on the deck or in an open chamber. Ports out: the far gate; a pilot knocked off the flank slot falls to the haze.

Mystery: The dead are not in the niches. The long niches are the *right size for bodies* but the shrouds are stone, carved hollow, and empty. Where did they go? The headless bodies that walk the deck stand on a floor of those who were laid below. The lamps are lit because someone still tends them, and the gallery floor has footprints (large ones, soft, dry, going one way, towards the far gate) under the dust. The far gate is the tomb's real door.

Kit used (verified):
- `city_causeway` with `bay` (scripts/city_kit.gd) as the base girder, deepened by opt.
- `city_hall` (scripts/city_kit_landmarks.gd): its walker-only aisle slots with screens are this card's gallery; its pillar/aisle language for the open-bay chamber.
- `city_slotwall`, `city_niches`, `city_hush`, `city_mouserun` (scripts/city_kit_refuges.gd): the door, the lamp niches, the dark gallery (`SightLight`, hush-gallery shade), the mouse run's slot-sized legs.
- `maker_shaft`, `maker_mirror` (scripts/city_kit_light2.gd): the hairline shafts; a mirror in a chamber that throws a beam on a plaque would be a solve.
- `maker_cresset`, `maker_runnel` (scripts/city_kit_fires.gd) for the deck and the lit lamps.
- `maker_corbel`, `maker_chock` (scripts/city_kit_breaks2.gd) for the open bay's roof edge and a chocked slab as a bridge across a chamber.
- `scripts/walker_only.gd`.

Kit asks:
- `city_girder` (family city): `city_causeway` with a hollow girder, a walker-only gallery (2.6 x 2.4 m, window slots, seam shafts, lamp niches), and `open` bays (roofless chambers 8.8 x 9.4 m with a ledge on the wall). Core; medium-high: procedural, collision of a hollow box, the gallery as a walker-only route the planner skips.
- `city_tomb_gate` (dressing): the far gate and the stone shrouds in the long niches. Low.
- A `SightLight` strip for the seam: reuse `scripts/enemies/sight_light.gd`. No new piece.

Family knobs:
- `spans` 3 to 5 (80 to 130 m).
- `open_bays` 1 to 3 (and which spans).
- `keepers` 0 to 2 bodies posted to stand in chambers from the start (frozen mid-ritual) vs bearers that arrive when they hear.
- `lamps` 0.3 to 1 (how dark the gallery is; lit by niche count).

Sockets:
- rim: the near landing (facing +Z), the far gate (facing back).
- arena: each open chamber (8.8 x 9.4 m, the body's room).
- cover: the gallery (walker-only), the chamber's wall ledge, the flank string course.
- perch: the roof edge over each open bay (a body's lookout and the pilot's climb-out).

Generator fit: **a crossing between two places (an edge)**, interior; a level causeway 80 to 130 m long with no height drop (the gate sits 0 to 1.6 m above the near landing). Needs a long edge and a floorless gulf; an "under" layer with `city_causeway`-sized gaps. The shorter version (3 spans) can work as the generator's short-edge bridge; the longer one is a long-edge motif.

Distinct from: the Bearers' Underway (the outside shelf, hang and shimmy under open sky) and from `city_hall` (the sundered hall's walker-only aisles are a whole hall on a plate; this is a long line, a corridor, with the open bays as rooms). Nearest greybox: `serpent_crossing` (a ride across a gulf) and `felled_colonnade` (a fallen run of columns); neither hides you inside the road.
