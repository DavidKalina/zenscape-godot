# Ruin stone: handoff

Branch `look/ruin-stone` (from `playtest/aqueduct-overgrowth` 69b61ff6). Not merged, not pushed.

The ask: the ruin stone sat in an uncanny middle, "not detailed enough to look good, but too detailed to be stylized in a simplified way that reads like it was intentional". The reference is the game's own islands ("very simple, but very clean"). The goal: "everything should feel like it belongs in the same universe."

The user picked **islet basalt** from the first round ("I feel like that one's gonna look the best"). It is now the default. The other looks stay on T for comparison.

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
