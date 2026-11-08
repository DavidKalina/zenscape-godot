# Spec: ship (the Steam build)

Loop slug `ship`, trail prefix `ITER(ship):`. Branch `iter/ship`, worktree
`../zenscape-ship`. Cap and budget: the iterate skill's defaults.

Done is a build of `studies/endless_flight.tscn` a stranger can buy for
under five dollars and play on Windows or a Mac without the repo: a title
menu with settings, a pause menu, a first flight that teaches the near miss,
a shop whose prices read big and take real flying to reach, two or three
plane bodies to buy, and everything saved between runs. Nothing new in the
world: the wilderness as it is, the ships, the burrower, the tunnels and the
arches all kept. The amberlands stay behind for a later update.

## Already decided

- The default world is `wilderness` (world_profile.gd `PLAYS`). `--world=doors`
  still plays the two-region world.
- Pirate ships and the burrower stay in. Later they become collectibles; not
  this loop.
- Price under five dollars; no Steam SDK integration in this loop.
- Settings persist in the config files the code already writes
  (`user://look.cfg`, `user://sound.cfg`, `user://pad.cfg`, `user://hud.cfg`);
  progress in `user://pilot.json` (PilotBook). No new save formats.
- Fonts, colours and the drawn look of the title menu (`main_menu.gd`), the
  near-miss tag (`near_miss_hud_handoff.gd`) and the shop (`shop_view.gd`)
  are the shell's look. New screens use the same fonts and inks.

## Lanes (parallel, one agent each, branch `lane/<part>` off `iter/ship`)

### Lane `shell`: the menus

What the player sees:

- Title menu: Start, Settings, Controls, Credits, Quit. Start as today.
- Pause: Esc or the pad's Menu button in flight opens Pause over the frozen
  game (tree paused, sound ducked or held). Resume, Settings, Controls,
  Quit to Title, Quit. Esc or B resumes. The mouse is freed while it is up
  and captured again on Resume. No pause while the title menu, the shop or
  the logbook is up; Esc in those keeps its meaning today.
- Settings, one screen with sections, keyboard, mouse and pad all working:
  - Display: Fullscreen (toggle; window mode persists), Render resolution
    (`render_resolution.gd` CAPS), Graphics preset (`graphics_preset.gd`
    NAMES, applied as F3 applies it today), Frame cap or vsync as the
    preset code already exposes.
  - Sound: Master, Effects (sound), Ambience, each 0 to 100 against the
    buses `flight_sound.gd` and `genesis_audio.gd` already build; Mute;
    Controller vibration (`pad.gd`).
  - Controls: Mouse sensitivity, Invert pitch (mouse and stick each), and
    a note that the pad works. Rebinding is out of scope.
  Every change applies live and is saved on change.
- Controls: one static page of the flight's keys, mouse and pad buttons as
  README's Play section lists them, drawn with the pad glyphs where
  `pad_prompt.gd` has them.
- Credits: the audio credits `assets/audio/ATTRIBUTION.md` requires, the
  Godot engine notice (`Engine.get_license_text()` or the short MIT notice
  plus a link), fonts' licences, and the maker's name.
- Quit to Title returns to the title menu on the meadow without a process
  restart if the code can (`menu_stage.gd` and the title's `present`);
  else a clean scene reload is acceptable, said in the commit.

Where: new files under `scripts/endless/shell/` (pause, settings, controls,
credits), wired from `studies/endless_flight.gd` in as few lines as can be.
`main_menu.gd` grows the three picks.

Proof: the smoke check; a driven run (`tools/drive.py`) that opens and
closes Pause mid-flight with no errors; stills of each screen at 1440x900
and at 1280x800 (the Deck's), looked at.

### Lane `economy`: money that reads big

Today a banked line pays its points times `MONEY_PER_POINT` (1/1600) times
its multiplier to the half; a safe 10k line pays about 10, decent flying
5 to 7 a minute, the first paint (60) in about ten minutes, the dearest
(180) in half an hour.

Wanted: the same minutes to the same purchases, in money that reads in
thousands and millions, since the lines score in the tens of thousands.
Money on screen and in the shop is formatted with separators (12,400 and
1,250,000; never 1.25M). Pick one scale (a line's money about equal to its
points is the first candidate) and set every price in `shop_stock.gd` from
a short table in the commit: first paint about ten minutes, the dearest
paint about an hour, a ribbon in five, and a `plane` slot's bodies at about
two, four and eight hours of decent flying (the `planes` lane adds the
items; this lane owns the prices as a `PRICE` table or constant per tier
the other lane reads).

Also: the money shows in flight somewhere quiet and on the landing summary
as the earn of that flight; a purchase has a visible and audible moment
in the shop; the first shop is found by a stranger (a line on the HUD or a
marker at START_REACH on the first flight is enough; say what was done).
Old pilot books in `user://pilot.json` migrate once (a `money_scale` key,
or a version) so no one's balance is wiped.

Where: `pilot_book.gd` (pay and migration), `shop_stock.gd` (prices),
`shop_view.gd`, `landing_summary.gd`, `near_miss_hud*.gd` (money format).
Keep a `static func money(n: int) -> String` formatter in one place.

Proof: the smoke check; a driven run that banks a few lines and lands and
prints the pay against the table; a still of the shop and of the landing
summary with the new numbers.

### Lane `tutorial`: the first flight

The first time a book is fresh, Start rolls the plane off as today and
then a guide takes the first three minutes: a ribbon line (the shape
`place_lines.gd` draws through `rival_marks.gd`) laid ahead from the
takeoff over flat meadow that dips low over the grass for a few seconds and
pulls up; a hint says what the key is at each step (the pad glyph when the
pad was used last). Steps, each with its own hint, each ending when the
player does it:

1. fly level through the first two gates (steer);
2. follow the ribbon down to within a few metres of the grass and hold it
   through a gate (low; the meter starts filling, the tag's first pop);
3. pull up through a high gate (pitch);
4. one near miss past a tree or a rock the ribbon leads along (the chain);
5. bank the line (land, or however the line banks today) and read the
   landing summary's money.

Then the guide ends and the game is the game. Skip with a key shown from
the start. The book records `tutorial_done`; Settings or Controls can offer
"Play the first flight again" later (not in this lane). If the land at the
start seed has no run flat enough for the ribbon, lay it over the sea's
edge or pick the nearest meadow by `menu_spot.gd`'s search; say which.

Where: new `scripts/endless/first_flight.gd`, wired from
`studies/endless_flight.gd`; `pilot_book.gd` gets the one flag.

Proof: the smoke check; a driven run (`tools/drive.py`) through all five
steps on the default seed, and one that skips; stills of steps 2 and 3.

### Lane `planes`: bodies to buy

Two new plane bodies beside the hero plane, built through
`art/blender/hero_plane/hero_plane_build.py`'s pipeline (a copy per body or
a parameter), same size and holds (the flight, landing and the world's
openings are sized off them, so HOLDS don't move), each with its own
silhouette (a high-wing monoplane and a stubby racer are the first
candidates), its paints keyed so the shop's liveries still repaint them.
No new handling: the body is cosmetic. If one feel knob is wanted it is
`plane_speed` or `plane_turn` within ten percent, said in the commit, and
nothing else.

The shop gets a `plane` slot (`shop_stock.gd` SLOTS, SLOT_NAMES, ITEMS)
with the hero plane free and the two bodies priced from the `economy`
lane's tier table (use a placeholder constant `PLANE_TIERS` the merge
joins). `dress` swaps the body on the figure in place; the title meadow,
the chase camera and the landing all read the worn body.

Where: `art/blender/hero_plane/` (new build scripts), `assets/models/<body>/`,
`plane_figure.gd` (load a body by id), `shop_stock.gd` (additive rows).

Proof: the smoke check; rendered stills of each body on the title meadow
and in flight (`tools/shot.py`), looked at; a driven run that buys and wears
one and lands.

## Trunk (after the lanes merge, one task per iteration)

1. Merge the lanes into `iter/ship`; join `shop_stock.gd` (prices and the
   plane rows) and the wiring in `studies/endless_flight.gd`; smoke; a
   driven flight through title, first flight, pause, shop, quit to title.
2. Replace the six CC BY-SA clips named in `assets/audio/ATTRIBUTION.md`
   with public domain or CC0 recordings of the same birds (or the nearest),
   update the attribution, and the credits page.
3. Project identity: name, version, icon, Windows preset's company and file
   version, window title.
4. Fix `.github/workflows/desktop.yml`'s verify step (it runs a deleted
   test); export Windows and Mac locally; play each export outside the repo.
5. Handoff.

## Checks every iteration runs

- `python3 tools/smoke.py studies/endless_flight.tscn` must PASS.
- Anything played: a `scratch/` driver on `tools/harness/drive.gd`.
- Anything seen: `tools/shot.py` stills, opened and looked at.
- No committed tests, no full suite: this is prototyping (AGENTS.md).
