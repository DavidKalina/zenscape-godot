# Spec: plane skins (loop `skins`)

Branch `iter/skins`, worktree `../zenscape-skins`. Cap and budget: the
skill's default.

## Done looks like

The shop's Paints list holds about 27 skins for the hero plane: the 7 there
today plus 20 new ones, across four rarities with prices to match. A skin
can be more than four colours: it can carry a finish (how the paint
shines), decals (stripes, numbers, marks, patterns laid over the paint) and
its own bake (a different painted atlas: factory fresh, weathered, bare
metal). Each has a name. The user opens the shop, scrolls the list, sees
each skin on the plane as they pick it, buys and wears it, and flies with
it. Rarity shows in the list.

Only the shop's stock changes. Season and time-of-day presets are a later
build; leave the shop room for more slots but add none.

## What is there now

- `scripts/endless/shop_stock.gd`: `ITEMS`, one row per item (`id`, `slot`,
  `name`, `price`, `livery` of body/dark/trim/wing colours). `dress()` puts
  the worn items on the plane. Ownership is saved by id in
  `user://pilot.json` (`scripts/endless/pilot_book.gd`).
- `scripts/endless/shop_view.gd`: the list, built from `ShopStock.items`.
- `scripts/plane_figure.gd:756` `repaint()` sets four shader uniforms;
  `_build_hero` (:343) gives each surface its own material copy.
- `assets/models/hero_plane/hero_surface.gdshader` tints the albedo through
  `mask_tex` (R body, G trim, B wing, A dark). **It is written by
  `art/blender/hero_plane/hero_plane_build.py`**: a shader change goes in
  the build script, or the next build overwrites it.
- `art/blender/hero_plane/hero_plane_paint.py` paints the atlas in numpy,
  region by region (the build's `REG`).
- `tools/view_plane.gd` is a live viewer; `tools/shot.py` takes stills.

## Stage 1: the skin system (the loop, Opus)

One or more iterations, in order. It ends with a contract the lanes build
on, written into this spec under "The contract" and committed.

1. **A skin row.** Keep `id`, `slot`, `name`, `price`, `livery`. Add:
   - `rarity`: `common`, `uncommon`, `rare` or `legendary`. Shown in the
     shop list (a word or a colour; keep the list uncrowded).
   - `finish`: optional shader values for how the paint shines and glows.
     Offer a small set that reads at flying distance, for example gloss or
     matte, metal, a pearl shift by view angle, and a glow that shows at
     night. Choose and name them; fewer that read well beats many.
   - `decal`: optional texture laid over the paint in the atlas's own UV,
     under the wear and dirt so it sits in the paint.
   - `bake`: optional replacement atlas maps (albedo, mask, orm; the normal
     map is shared) for a skin whose surface itself differs.
   Existing saves keep working: ids of the 7 paints don't change.
2. **Where skins live.** Each batch of skins is its own file under
   `scripts/endless/skins/<batch>.gd` with its textures under
   `assets/models/hero_plane/skins/<batch>/`. `shop_stock.gd` gathers the
   batches from one list, so a lane adds one line there and nothing else.
3. **Size and load.** Only the worn skin's textures (and the one being
   tried in the shop) are loaded. Pick texture sizes and formats so a skin
   with a decal or a bake adds little to the build: aim for the 20 new
   skins together under 25 MB on disk, and say what you chose.
4. **Authoring tools**, written up in `tools/README.md`:
   - A decal painter the lanes call from a short script: shapes drawn in
     the atlas's regions in the plane's own units (stripes along the
     fuselage, bands across a wing, a disc, numbers and letters, a checker,
     a scallop, a free mask from a function), mirrored left and right where
     the plane is. Building on `hero_plane_paint.py`'s regions is the
     obvious route.
   - A bake maker: the paint script run with other settings (less or more
     wear, bare metal, other cloth) to write a skin's own maps.
   - A skin sheet: one command that renders a named skin on the plane from
     a few angles in daylight, and at night when it glows, into one image.
     Rendered captures are allowed (AGENTS.md, Test execution): one window,
     short, a watchdog, `-- --no-title`.
5. **The shop.** The list scrolls and stays readable with 30 rows; trying a
   skin shows its finish, decal and bake on the plane.
6. **Three demo skins** that prove the system, one each: finish only, a
   decal, a bake. Their sheets are the stage's proof. They may ship or be
   replaced by the lanes.
7. **Prices.** Read the pay rates in `shop_stock.gd`'s header and
   `pilot_book.gd`, and set a price band per rarity so a common comes in
   minutes and a legendary takes many flights. Write the bands into the
   contract.

8. **Finishes told apart.** In iteration 1's sheet
   (`captures/skins/iter1_finish_day.png`) the gloss, matte and metal rows
   on the same colours read nearly alike at flying distance. Once the skin
   sheet tool exists, strengthen the sheens until each is named correctly
   from the sheet without its label, and keep a glow saturated (not washed
   to white) at the strength the lanes will use.

Checks: `tools/smoke.py` on `studies/endless_flight.tscn`; a throwaway
drive through the real shop (open, try, buy, wear, close, and the plane
wears it in flight; quit and reload keeps it); the three sheets, looked at.

## Stage 2: the batches (lanes, Sonnet, all at once)

Each lane makes 5 skins in its own batch file, in its own worktree branched
from `iter/skins` after stage 1 (`lane/skins-<batch>`), following the
contract. Per lane: 1 common, 2 uncommon, 1 rare, 1 legendary, except
`glow`, which is 2 rare and 3 legendary.

- `heritage`: old flying liveries: racing stripes, a number on the tail,
  checker cowls, mail-plane bands, a barnstormer's sunburst. Invented marks
  only: no real air force's or company's insignia.
- `wild`: animals and plants: a shark's mouth on the cowl, a tiger's
  stripes, a kingfisher, a bee, a moth's wing eyes.
- `metal`: bakes and finishes: polished bare aluminium, copper, gold leaf,
  a weathered rust bucket, a pearl white.
- `glow`: the night skins: lines that light after dark, a starfield, an
  ember, an aurora shift.

Every skin gets a short name in the style of the ones there (Homestead,
Harbour, Night Mail). Each lane looks at every skin's sheet and reshoots
until it reads at flying distance, not only close up. A lane's commit ends
with **Notes for merge** (the one line added to `shop_stock.gd`) and
**Look at** (its five sheets).

## After the lanes

The orchestrator merges the lanes into `iter/skins`, runs the smoke check
and one contact sheet of all the skins, writes the handoff beside this
spec, and opens the game for the user. Nothing merges to main until the
user says so.

## The contract

(Stage 1 writes this: the row's fields with one worked example, the finish
names and ranges, the decal painter's calls, the bake maker's command, the
sheet command, the price bands, the texture sizes.)
