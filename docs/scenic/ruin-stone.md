# Ruin stone: handoff

Branch `look/ruin-stone` (from `playtest/aqueduct-overgrowth` 69b61ff6), then `look/ruin-stone-eroded` (from d6f0cefe) for round 2. Not merged, not pushed.

## Round 2: eroded basalt (2026-10-10)

The user played basalt on the isle: "it kind of got stronger in some areas, but weaker in others… it's too flat now. It doesn't have that texture, the erosion." Compared with classic, they agreed to try an eroded basalt.

**The diagnosis held.** Classic did two things: shape erosion (worn arrises, chips, chunks gone, ragged breaks, blocks out of true, faces wobbling) and colour noise (per-block tone, stains, lichen, moss patches). The colour noise is what made it muddy. Basalt dropped both. Side by side, an eroded look in basalt's colours has the texture back while staying calm, because the erosion now reads only through light and shadow on the facets.

A second finding: the erosion was everywhere. Even without colour noise, wearing every arris and chipping every corner outlines each stone in a coursed wall (V-grooves at every joint), and that is where most of the brick-by-brick busyness comes from. So the eroded looks show wear **only where the stone is open**:

- A worn arris stays only between two open faces, not against a neighbour.
- A chip stays only where two of its corner's faces are open.
- A chunk always stays.

So the wear concentrates on wall heads, ends, steps' lips, corners and breaks, and the joints of a flush wall stay tight. Openness is judged at `finish`, when every block stands (Build `_erode`, `_covered`: a face counts as a joint when its middle and half its corners, drawn in halfway, sit inside a neighbour).

### The eroded looks

| Look | Name in the UI | Dial (share of classic's) |
|---|---|---|
| `eroded_light` | eroded basalt, light | arrises kept 0.6 top / 0.5 upright / 0.1 foot, ×1.5 deeper; wobble 0.25 (tops 0.15); chips 0.45 upper / 0.15 lower, ×1.5; chunks 0.5 |
| `eroded` (**default**) | eroded basalt | arrises 0.8 / 0.65 / 0.25, ×1.6; wobble 0.4 (tops 0.25); chips 0.65 / 0.3, ×1.6; chunks 0.8, ×1.15 |
| `eroded_heavy` | eroded basalt, heavy | arrises 1 / 0.9 / 0.5, ×1.7; wobble 0.7 (tops 0.4); chips 0.9 / 0.5, ×1.7; chunks 1, ×1.3 |

- **The dial keeps the boldest cuts.** The kept arrises, chips and chunks are the ones the classic drew deepest or likeliest, and they are cut deeper still: fewer, bolder cuts.
- **Colour.** Basalt's rule: the islets' dark stone, tone by facing only, tops one tone, 1.6 m bands, a darker foot, no per-block tone, stains, lichen or moss patches. A worn face (chip or arris) is 3% lighter (`worn`), so the cuts catch the light. Knobs: `ERODE_*` and `LOOKS.eroded*` in `scripts/ruin_stone_style.gd`.
- **Same pieces as classic, exactly.** An eroded look builds every block as the classic does, with the same draws, poses, returned faces, ivy solids and **collision hulls**. It then dials the classic's recorded cuts for drawing only (Build `_dial`). So plans, breaks, ruin lines, drifts, routes and physics are classic's, piece for piece, whatever the dial.
  - `tools/ruin_stone_dump.gd` now prints `draws` (every finished piece's random state, hashed). It matches classic at all 49 checkpoints in all three eroded looks.
  - The hull counts match classic's too: 2360 / 2499 / 760.
- **Out of true stays.** The blocks keep classic's tilt and shift. Truing them in drawing only would need the jiggle per block, but jiggled poses are reused for groups of blocks (capitals, hall columns in `ruin_kit_hall.gd`), so it was left alone. A first try that scaled the poses changed the stream: the weathered arch broke differently.
- **Collision.** The eroded looks use the classic's worn hull, which classic's routes already walk. A first try with the dialled hull failed the isle's grand stair at medium. The drawn wear differs from the hull by a few centimetres at most.

### Running them

```
./run-ruin-kit.command                          # eroded (the default); T cycles every look
./run-ruin-kit.command --stone=eroded_light     # or eroded_heavy, basalt, classic, ashlar, mass
./run-aqueduct-isle.command                     # eroded
./run-aqueduct-isle.command --stone=eroded_heavy
```

The T order is classic → ashlar → mass → basalt → eroded light → eroded → eroded heavy.

### Captures (round 2)

These are in `docs/scenic/ruin-stone/` at the game's noon, rendered with `--no-title`, one capture at a time (parallel captures drift: the camera lands oddly and the fly autopilot strays). Each is a 3×2 grid: **classic | basalt / eroded light | eroded / eroded heavy | (blank)**.

| File | View |
|---|---|
| `eroded_isle_close.jpg` | The rubble steps where the pilot starts |
| `eroded_isle_wide.jpg` | The aqueduct isle, the same eye as round 1 |
| `eroded_drum.jpg` | The henge terrace's drum wall, close (`--at=86,36,16 --look=66,32,2`) |
| `eroded_arch.jpg` | The pointed arch, intact and weathered |
| `eroded_aqueduct.jpg` | The gallery's aqueduct run |
| `eroded_hall_inside.jpg` | Flying the hall (`--fly=3`) |
| `eroded_hall.jpg` | The curved hall from above |

### Triangles (round 2)

From `tools/ruin_stone_dump.gd`, headless. Totals include growth.

| Build | classic | basalt | eroded light | **eroded** | eroded heavy |
|---|---|---|---|---|---|
| 12-bay hall, seed 12, in-world | 90,532 | 77,355 | 78,622 | **79,529** | 80,608 |
| 12-bay hall, seed 20, in-world | 94,842 | 83,399 | 82,533 | **83,529** | 84,748 |
| … of which stone (seed 20) | 85,211 | 72,763 | 72,902 | 73,898 | 75,117 |
| Aqueduct run (head + 4 spans) | 162,606 | 131,393 | 135,652 | 136,957 | 138,640 |
| … of which stone | 44,547 | 19,757 | 17,593 | 18,898 | 20,581 |
| All 46 pieces, detail 1 | 704,961 | 599,770 | 582,954 | 589,367 | 597,524 |
| Aqueduct isle, the whole art | 411,667 | 294,687 | 298,983 | 303,109 | 308,486 |
| 12-bay hall build time | 0.56 s | 1.0 s | 0.9 s | 0.9 s | 0.9 s |

Every eroded look stays well under `Hall.BUDGET` (100k) and costs about the same as basalt. Showing wear only on open stone drops most of classic's triangles.

### Pick: `eroded` (medium), now the default

- **Against basalt.** The texture is back: steps' lips and wall heads are chamfered, broken courses are ragged and chipped, fallen stones are chunky faceted lumps. Light and shadow carry it, as the user asked.
- **Against classic.** One calm colour family, no moss, stain or brown patchwork. The hall roof from above is as calm as basalt's. Flush walls read as cut stone with a few worn edges, not as a pile of outlined bricks.
- **Light** is close behind: calmer and nearly as good up close, but at the isle's wide view it starts to drift back toward basalt's flatness.
- **Heavy** rounds almost every open edge, so on coursed walls (the aqueduct head, the drum) the stones start to outline themselves again.
- **Overgrowth.** The ivy and curtains are classic's exactly (same solids and draws) and stand out well against the grey.

### Checks (round 2)

- The headless import is clean.
- With `eroded` as the default, these tests pass headless:
  - `test_ruin_kit`
  - `test_ruin_growth`
  - `test_sundered_hall` (known `exit_leak` only)
  - `test_aqueduct_isle` (24 OKs)
  - `test_island_pack_ruins_archipelago`
- `test_aqueduct_isle` was also run with `eroded_light` and `eroded_heavy` as the default: both pass.
- Classic and basalt stay byte-identical to d6f0cefe (`--digest`).
- The full suite was not run (as briefed).

### Still weak (round 2)

- **Coursed walls still show their stones a little**, most on the drum and the aqueduct head at mid distance. That comes from the classic's blocks out of true and in and out of the wall, which the eroded looks keep (see above). Next step: true the blocks in drawing only, by recording each solid's jiggle in `_jiggle` and un-applying it in `solid`. That needs care where one jiggled pose places several blocks.
- **The clean looks don't draw the same numbers as classic**, contrary to round 1's note. Basalt's and ashlar's `draws` part from classic's from the first weathered piece on (`pier w1`). One visible result: the weathered pointed arch keeps its crown in classic and loses it in basalt (round 1's `cmp_looks.jpg` shows it too). The likely causes:
  - their blocks give back their clean face to the code placing the next block;
  - the ivy tests the clean solids.

  Not traced further. The eroded looks don't have this problem.
- **Intermittent capture hangs.** A rendered gallery or isle capture sometimes stalls at startup (no log past the engine banner) under load. Rerun alone, it takes about 15 s. This is not specific to any look.

---

# Round 1

The ask: the ruin stone sat in an uncanny middle, "not detailed enough to look good, but too detailed to be stylized in a simplified way that reads like it was intentional". The reference is the game's own islands ("very simple, but very clean"). The goal: "everything should feel like it belongs in the same universe."

The user picked **islet basalt** from the first round ("I feel like that one's gonna look the best"). It was the default until round 2 (above) replaced it with eroded basalt. The other looks stay on T for comparison.

## The islands' style, as rules

Use this list to check any future kit. It comes from the plate and the sky islets at the game's noon (captures below) and from their shaders: `shaders/reference_surface.gdshader` (earth sides, `side_facets`), `scripts/strata.gd` and `scripts/rock_looks.gd`.

1. **One colour per material, varied only three ways:**
   - **By facing.** Each face is a step lighter or darker by its facing alone. The plate's sides vary ±7% (`side_facets` 0.14) and the sky islets' basalt ±22% (0.45). Flush faces of neighbouring pieces read as one plane.
   - **By broad height bands.** Strata are flat bands about 1–1.4 m tall, set by absolute height and warped only ±0.25 m over 12–19 m waves.
   - **Per object.** Each islet or cluster member is a variant: tone 0.86–1.1, a ±5% warm or cool lean, in 5 steps.

   There is no other variation: no per-block tone, no noise patches, no stains, no lichen and no streaks.
2. **Palette.**
   - The plate's bands, top down: topsoil 7a624b, clay a8784c, sand cfbd96, shale 6f6863 and 58524e, bedrock 7f7e7a. Granite core: a8a49b, bab5ab, 96928a.
   - The islets' basalt: 46474b, 515257 and 3a3b3f, lifted ×1.55 and cooled toward blue (×0.94, 0.98, 1.08).
   - The grass top is one living green.
3. **Values.**
   - The sunlit grass top is the brightest large area.
   - Sides are mid values, getting darker band by band.
   - Keels and basalt are dark, but never black, because the sky's hemisphere fills every shaded face.
4. **Facet size and detail per metre.**
   - Ground triangles are about 1.5–3 m. Side facets are about 1–2 m wide columns. Keel facets are 2–5 m.
   - Nothing that reads is smaller than about 0.3 m at play distance.
   - That works out to roughly one facet per m² on a side, fewer on a top.
5. **Light.** A plain Lambert sun separates the planes. The sky hemisphere is added as fill, so shade is the sky's colour, not black, with a faint sky rim on silhouettes. There are no textures.
6. **Growth meets rock with a clean edge.**
   - The grass is its own cap and ends at the rim, with a thin dark topsoil skin (0.22 m at 0.55) under it.
   - Rock faces carry no painted green patches.
   - Soft, moving growth (grass, overgrowth) is a separate surface laid over the faceted solid.
7. **Form comes from silhouette and big planes.** Ruin character (broken heads, fallen spans, arches) comes from massing, never from surface noise. This follows `docs/scenic/style.md`: neighbours carry similar detail.

## What was wrong with the classic stone (verified by looking)

Comparing the classic stone side by side with the islands:

- Every coursed block has its own random tone (±10%), and every face a further ±12%.
- Every arris has small random chamfers, which are paler (the "worn arris" mix).
- Each block has 1–4 corner chips and a 30% chance of a chunk missing.
- Faces wobble out of plane, and blocks tilt and shift out of true.
- Stains run down in noise bands, lichen sits on random faces, and moss is painted on tops by noise.

Together that is about 10–20 small facets per m² of wall, each with its own tone: the "middle zone". The hall roof from above is the clearest case, a patchwork of grey, brown and green slabs.

## The looks

All of the code is in a new file, `scripts/ruin_stone_style.gd`, plus small hooks in `scripts/ruin_kit.gd`. The aqueduct and hall scripts are untouched, so merges with the branches editing them stay small.

| Look | Name in the UI | What it is |
|---|---|---|
| `basalt` (default) | islet basalt | The islets' dark, cool, nearly neutral rock (5a5d63 to 52575f). Each face's tone comes from its facing; tops are one tone; quiet 1.6 m height bands; a darker foot. Blocks are **carved** (render only): a broad bevel on some open top edges (steps' lips, wall heads), broad facets on some open upright corners, and creases laid out by the world in 2.4 m stretches along each face's plane, so a wall or a slab top reads as a few broad planes rather than its stones. |
| `mass` | carved mass | The same rule in a pale warm stone (9e9586), with 1.25 m bands. No carving. |
| `ashlar` | big ashlar | Mid warm grey. Coursed stones are toned in groups of 3.2 × 1.25 m, so they read as fewer, bigger blocks. No carving. |
| `classic` | classic stone | The kit as it was, byte-identical. |

**Every clean look** (all but classic):

- Builds without wear: no chips, no wobble and no small worn arrises.
- Keeps blocks true and flush, with no sag, no in-and-out and butted joints.
- Colours faces by rule (`Style.shade`).
- Its collision is the clean block. The carving is drawn only and reaches at most a few cm into a top (`crease_flat` 0.035 m).

**Same pieces in every look.** The kit draws exactly the same random numbers in every look, so plans, breaks, ruin lines, drifts and breaches match. A clean block still computes its classic worn faces and their colours, only to draw the same numbers, then discards them.

- **Checked:** the hall's corridors and plans hash the same in every look.
- **Checked:** classic output (meshes and hulls of every piece, both weatherings, two 12-bay halls and an aqueduct run) is byte-identical to 69b61ff6. Use `tools/ruin_stone_dump.gd --digest`.

### Switching

```
./run-ruin-kit.command                     # basalt
./run-ruin-kit.command --stone=classic     # or ashlar, mass
#   T in the gallery: the next look, the same pieces rebuilt (classic → ashlar → mass → basalt)
./run-aqueduct-isle.command                # basalt
./run-aqueduct-isle.command --stone=classic
```

In code, call `RuinStoneStyle.use("classic")` before building, then `RuinStoneStyle.dress(RuinKit.materials().stone)`. The default is `RuinStoneStyle.current = "basalt"`.

### Basalt's knobs

These are in `ruin_stone_style.gd` (`LOOKS.basalt` and `CARVE`):

- **Tone.** `facets` 0.42 (the islets' rule), `top` 0.3 (all tops one tone), `band` 1.6 m at ±6%, `foot` 0.12 over 3 m, `fill` 1.45 and `rim` 0.2 on the stone material.
- **Carving.**
  - `edge` 0.6 and `corner` 0.7 are the odds an open arris is cut.
  - Depths are `edge_depth` 0.06–0.14 m and `corner_depth` 0.1–0.26 m, capped at `share` 0.3 of the block's least size.
  - Creases: `crease` 0.85 per 2.4 m `stretch`, turning 7–13°, at most 0.035 m deep on tops and 0.16 m on upright faces.
  - Lean stone (the halls) carves half as often (`lean`).
- **Tried and left off.** `facet_hash` (the islets' hashed facing rule) turns flush coursed stones back into a checker on walls (see "Still weak").

## Captures

All are in `docs/scenic/ruin-stone/`, at the game's noon, rendered with `--no-title`.

| File | What |
|---|---|
| `cmp_islands.jpg` | The reference beside the result. Top: the editable plate and the sky islets and peaks. Bottom: the aqueduct isle and the gallery aqueduct in basalt. |
| `cmp_isle_wide.jpg` | Aqueduct isle, the same eye. Left classic, right basalt. |
| `cmp_isle_close.jpg` | The rubble steps where the pilot starts. Left classic, right basalt. |
| `cmp_slabs_before_after.jpg` | The "greybox slabs" fix. Left basalt before carving, right basalt carved. |
| `cmp_stair.jpg` | The grand stair. Left classic, right basalt: every step's lip catches light. |
| `cmp_gothic.jpg` | The gothic family at mid distance. Left classic, right basalt. |
| `cmp_hall.jpg` | The 16-bay curved hall from above. Left classic, right basalt. |
| `cmp_looks.jpg` | The pointed arch in all four looks: classic, ashlar / mass, basalt. |
| `cmp_fly.jpg` | Flying the hall, inside. Classic, basalt (3 s), basalt (5 s). 0 bumps each. |

## Triangles

From `tools/ruin_stone_dump.gd`, headless (`--stone=`). Totals include the growth surface.

| Build | classic | ashlar | mass | basalt |
|---|---|---|---|---|
| 12-bay hall, seed 12, in-world detail 0.25 | 90,532 | 64,947 | 64,077 | **77,355** |
| 12-bay hall, seed 20, in-world | 94,842 | 69,094 | 69,640 | **83,399** |
| … of which stone (seed 20) | 85,211 | 58,855 | 59,004 | 72,763 |
| Aqueduct run (head + 4 spans), detail 1 | 162,606 | 126,504 | 125,704 | 131,393 |
| … of which stone | 44,547 | 13,810 | 14,068 | 19,757 |
| All 46 pieces (both weatherings), detail 1 | 704,961 | 559,764 | 571,699 | 599,770 |
| Aqueduct isle, the whole art | 411,667 | | | 294,687 |

- The 12-bay hall is now 83k at its worst seed. Classic was 95k against `Hall.BUDGET` 100k.
- At detail 1, weathered pieces are dominated by their growth (curtains): the run's growth is about 112k of its 131k. Growth is unchanged.
- The hull counts match across the clean looks.

## Checks

- The headless import is clean.
- These tests pass headless with basalt as the default:
  - `test_ruin_kit` (breaks, curved lanes, corridors, budget)
  - `test_ruin_growth` (collision identical with or without vines)
  - `test_sundered_hall` (known `exit_leak` engine signature only)
  - `test_aqueduct_isle` (all 24 OKs: the henge, the circle, the lintel ring, the summit, the aqueduct routes)
  - `test_island_pack_ruins_archipelago`
- The full suite was not run (as briefed).
- Classic is byte-identical to 69b61ff6 (`tools/ruin_stone_dump.gd --stone=classic --digest`, compared against the old `ruin_kit.gd`).

## Recommendation

**Basalt, carved.** It matches the islets' rock family (cmp_islands) and reads as a deliberate, simplified style. Silhouettes carry the ruin.

- **Legibility.** Arches, steps and edges stay legible: the steps' lips and corners are cut as broad, light-catching facets, and tops are one calm tone.
- **Overgrowth.** The greens sit well against the dark stone: the ivy and curtains pop without fighting it.
- **Hall interiors** read mid-grey, not crushed. The fill went from 1.2 to 1.45, and the shelter bounce is unchanged.
- **Cost.** It is cheaper than classic: about 12k fewer triangles in a hall.

## Still weak

- **The hall roof from above.** The settled slabs still read as a light grey patchwork of slightly tipped tops. Tops are one tone, but each tipped slab shades a little differently, and the gaps show. That is better than classic's grey, brown and green patchwork, but it is still the weakest view. A next step would be fewer, bigger slabs, or grass caps on whole roof stretches (the islands' "grass cap" rule).
- **Some aqueduct head walls and ruined edges.** Stones that are not flush (ragged heads, torn walls) each take their own crease, so up close a few block-sized tones show. It is calm at play distance.
- **Build time.** Basalt builds a 12-bay hall in about 1.0 s against classic's 0.56 s. A clean block still works out its classic worn faces so the same random numbers are drawn, and then the carving runs.
  - If classic is retired, drop that parity work: `solid`'s cleaned branch can skip `_polys` and `_shade` on the worn cut.
  - Doing so changes the random stream, so re-prove the isle's routes afterwards.
- **Carving is render-only.** A carved lip or corner sits a few cm inside its hull, so a foot can hang a few cm over a cut edge. The routes test passes, but by hand you may see it on a step's lip.
- **The gallery's fly autopilot** (`--fly=N` captures) sometimes drifts into the side aisle and grinds a wall (thousands of bumps) when two captures run at once on a loaded machine. That happened in classic and in the clean looks. Run alone, classic and basalt both fly the lane with 0 bumps. It is timing, not geometry: the lane is clear of hulls in both (checked in path space).
- **Ashlar and mass** were not polished after the pick. Ashlar's group tones still read a little patchy on long walls.
- **Not done: an in-game placement next to a real editable island.** The comparison is side by side in captures, not in one scene.
