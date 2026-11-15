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
   contract. Finds are being made to pay on another branch
   (`finds-more`): about 80 finds paying roughly 10, 20 or 40 each by how
   hidden they are, once each, near 2000 in all. Count that income with
   the flying pay when setting the bands.

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

Written by Stage 1 (trail `ITER(skins)`). The demos in
`scripts/endless/skins/demo.gd` and `art/blender/hero_plane/skins/demo.py`
show every field in use; copy from them.

### A lane's files

- `scripts/endless/skins/<batch>.gd`: `extends RefCounted` and
  `const SKINS := [rows]`. Ids `paint/<name>`, unique across all batches.
- `assets/models/hero_plane/skins/<batch>/`: the batch's decals and bakes.
- `art/blender/hero_plane/skins/<batch>.py`: the script that paints the
  batch's decals and calls its bakes, committed so they can be remade.
- One line in `ShopStock.BATCHES` (`scripts/endless/shop_stock.gd`):
  `"res://scripts/endless/skins/<batch>.gd",`. Nothing else in shared files.

### The row

```gdscript
{"id":"paint/racer","slot":"paint","name":"Racer","rarity":"rare","price":650,
	"livery":{"body":Color("9e2a22"),"dark":Color("2a2224"),"trim":Color("e8d9a8"),"wing":Color("efe6d2")},
	"finish":{"sheen":"gloss","pearl":Color("9aa8ff"),"pearl_amount":0.4,
		"glow":Color("ff6a20"),"glow_on":["trim","decal"],"glow_power":1.0},
	"decal":"res://assets/models/hero_plane/skins/heritage/racer_decal.png",
	"bake":{"albedo":"res://assets/models/hero_plane/skins/heritage/racer_albedo.jpg",
		"mask":"res://assets/models/hero_plane/skins/heritage/racer_mask.png",
		"orm":"res://assets/models/hero_plane/skins/heritage/racer_orm.jpg"}},
```

- `id`, `slot` (`"paint"`), `name`, `price`, `rarity`, `livery`: required.
  `livery` is the four colours the atlas's mask tints: `body`, `dark`
  (deck, struts, the dark panels), `trim` (cheat line, cowl ring, tail
  cone), `wing`.
- `rarity`: `common`, `uncommon`, `rare`, `legendary`. The shop shows it as
  the name's colour.
- `finish`, `decal`, `bake`: each optional; any mix. Only the worn skin's
  and the tried skin's textures are loaded.

### Finishes

- `sheen`: `satin` (the atlas's own; the default), `gloss` (deepened colour
  under a lacquer, white edge-on, a streak of light along the fuselage),
  `matte` (greyed, chalky, no highlight), `metal` (a hard mirror in the
  paint's own hue: bright sky over dark land, a sharp horizon down the
  body). Each reads at flying distance; gloss vs satin is the weakest at
  chase range.
- `pearl`: a Color seen edge-on; `pearl_amount` 0..1 (default 0.6; 0.4-0.6
  reads without swamping the livery).
- `glow`: a Color lit after dark (full once daylight < 0.1, gone by 0.65).
  `glow_on`: any of `body`, `trim`, `wing`, `dark` and `decal` (the decal
  lit in its own colours; default `["trim"]`). `glow_power` 0..1.3 (clamped;
  1, the default, shows the glow as its own colour; above whitens it).
  Glowing paint is dimmed so the light keeps its colour. A glow stands out
  on a dark livery; on white under moonlight it barely shows.
- Not on bared metal or silver-doped cloth (mask 0): there a bake's look
  is all.

### Decals

One premultiplied RGBA PNG at half the atlas, 2048 x 1300, its own
colours (not slot-tinted), lossless import with mipmaps; ~120 KB. It is
laid over the livery on painted parts only, toned by the atlas's shading,
under the finish, the chips and the stains. Painted by a short script:

```python
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal
d = Decal()
d.stripe("body", "f2e8d2", z=(-0.48, 0.68), s=(0.075, 0.092))
d.save("assets/models/hero_plane/skins/<batch>/<name>_decal.png")
```

run with `python tools/blender.py run art/blender/hero_plane/skins/<batch>.py`
(a few seconds). Calls (`on` a region, `c` a hex colour; `mirror=True`
paints both sides alike, `soft` the edge's blur):

- `rect(on, c, a, b)`: all within a=(a0, a1), b=(b0, b1).
- `stripe(on, c, z=, s=)` along the body (or `x=, s=` on a wing/tail);
  a range left out is full length.
- `band(on, c, a)`: across (a span band on a wing, a ring round the body).
- `disc(on, c, at, r, ring=0)`: ring > 0 leaves the middle open.
- `checker(on, c, a, b, cell)`: the first square at (a0, b0) painted.
- `scallop(on, c, a, b, n, depth)`: a band from a[0] to n round bites
  past a[1] (negative depth bites back).
- `text(on, s, c, at, height, flip=False)`: 0-9, A-Z but J Q Z, `-`, `.`,
  space. Reads nose-ward on starboard and aft on port (body, fin).
- `mask(on, c, fn)`: `fn(a, b, side) -> 0..1`, a free pattern.
- Any shape with `c=None` cuts itself out of what is laid (a roundel's
  hole, a gap in a stripe). `save(path)` writes the PNG and its `.import`.

Regions and their (a, b) frames in the plane's units (about 1.2 long,
nose -z): `body` (z -0.5 firewall .. 0.72 tail, s round from the top, sides
near +-0.2, keel +-0.42; `girth(z)`); wings `up_top up_under lo_top
lo_under`, `wings_top`, `wings_under`, `wings` (x out 0..0.7 upper, 0.08..0.63
lower; c back 0..0.3; both halves share the atlas, so wing text reads
mirror-written on the port half); `tail` (x 0..0.26, c 0..0.135); `fin`
(z 0.47..0.76, y 0.05..0.3, rudder z > 0.685; each side its own atlas);
`cowl` (s round, half round ~0.49; l along the profile, `FRONT` the lip
.. `COWL_L` the skirt). The module's docstring has the rest.

### Bakes

The skin's own albedo, mask and orm (the normal is shared); any map left
out of `bake` stays the plane's own. Made by the bake maker:

```
python tools/blender.py run art/blender/hero_plane/hero_plane_bake.py -- \
	assets/models/hero_plane/skins/<batch>/<name> --wear 0.2 --dirt 0.3 --bare 1
```

or `bake(out, wear=, dirt=, bare=, bare_c=, rust=, cloth=)` from the batch
script. Settings: `wear` 0 fresh .. 1 (the plane's own) .. 2 battered;
`dirt` 0 clean .. 1 .. 2 filthy; `bare` 0..1, the livery's coat off the
forward body metal and the cowl (deck, cheat line and marks
stay painted); `bare_c` the bared metal's hex (aluminium if not given;
copper `b87333`, gold `d4a64a`); `rust` 0..1; `cloth` `doped` or `silver`.
It writes `<out>_albedo.jpg` and `<out>_orm.jpg` (2048 x 1300, JPEG 90,
imported lossy WebP) and `<out>_mask.png` (2048 x 1300, lossless: lossy
zeroes the livery), their `.import`s, and prints the row's `bake` value.
About 15 s a bake.

### Sizes

A decal ~0.12 MB. A bake 0.6 MB (fresh, clean) to 2.5 MB (rusty,
battered); Silverwing 1.2 MB. Under the 25 MB for the 20 new skins: decals
freely; bakes at most 2 a lane, `metal` up to 4, each under 2.5 MB.

### The sheet

```
python tools/skin_sheet.py paint/<name>     # captures/skins/paint_<name>.png
python tools/skin_sheet.py paint/a paint/b --views port,quarter,top,chase --out captures/skins/<batch>.png
```

Day (hour 11) and, when the finish glows, night (hour 1), one window
after the other; views `port starboard quarter top tail chase` (`chase` is
the flying view). `sheen:NAME[@id]` shows a sheen alone,
`glow:HEX[*POWER][@id]` a trial glow (the decal lights when the skin has
one). Judge a skin at `chase`, not only close up.

### Prices

By rarity (`ShopStock.PRICE_BANDS`; a batch row outside its band warns):

| rarity | price | earned in |
| --- | --- | --- |
| common | 60-150 | ten to twenty minutes |
| uncommon | 120-350 | half an hour to an hour |
| rare | 500-1000 | a few flights, one to two hours |
| legendary | 1500-3000 | many flights, three hours or more |

From the pay: decent flying 5-7 a minute, a wild line 30 or more
(`PilotBook.line_pay`), and the finds (branch `finds-more`) 10, 20 or 40
each once, 1760 for all 80, so about 10 a minute early on. All the finds
together buy about one legendary. Demos: Moonstone 700, Chequer 600,
Silverwing 2000.

### The shop

The list scrolls (about 19 rows at 1440x900) and keeps the chosen row in
view; trying a row shows its finish, decal and bake on the plane; Esc
puts the worn skin back. Rows sort by price, base stock first at a tie.
