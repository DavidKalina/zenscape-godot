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

### Lane `tutorial`: the first flight (round 1; superseded by round 2's tutorial lanes below)

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

## Round 2 (after the handoff of round 1; the user played the build)

The user's verdict on round 1: a good start; the ribbon tutorial was hard
to follow and felt like it did not work; the HUD is crowded (the guide
card and the shop pointer both sit top centre, the card hides the gates,
the key strip lists thirteen keys and runs off a 1440 window); the shop
and the landing summary are dense. Round 2 replaces the ribbon with a
tutorial the land itself teaches, and clears the HUD and the shop.

### The tutorial, as the user described it

A fresh book's first flight starts already in the air, low, skimming
flat grass, and never stops flying. There is no step list. The land ahead
is whatever the current lesson needs, and it keeps being that until the
player has done the thing enough times; then the land ahead becomes the
next lesson's land. The stages, in order, each with a requirement that
advances it (first values; one table, tuned later):

1. GRASS: endless flat meadow. Requirement: three pull-outs over land, or
   eight seconds of skim.
2. TREES: loose copses start appearing in the meadow ahead. Requirement:
   three grazes of a tree.
3. WATER: ponds and a straight river reach open up ahead. Requirement:
   two pull-outs over water.
4. GAUGE: all of it mixed ahead. Requirement: the surge meter fills once.
5. WALL: the ruin hall appears ahead with a cracked wall in its mouth.
   Requirement: a surge roll breaks the wall; the hall swaps the land to
   the wilderness at its start, the pointer to the first shop comes on,
   and the game is the game. `tutorial_done` is recorded.

The sky is closed and the ground is open: a flat cloud deck about 60 m
over the turf whites the view out when the plane climbs into it (the
doors world's whiteout, reused), with no wall, no bounce, nothing that
fights the stick. There is no range limit: the lesson's land is laid ahead
of the plane wherever it goes. The HUD during the tutorial is one short
line with a count ("graze a tree  1/3") and nothing else: no money, no
shop pointer, no key strip. Skip stays (Backspace, pad D-pad down), shown
small under the line. The parry is not taught (held for when the burrower
becomes a collectible).

### The contract between the two tutorial lanes

- `scripts/endless/tutorial/lesson.gd` (lane `tutorial-flow`): node
  `game.lesson`, null when no tutorial runs. `enum Stage {GRASS, TREES,
  WATER, GAUGE, WALL, DONE}`, `var stage: int`, `signal
  stage_changed(stage: int)`, `static func wanted(book) -> bool` (fresh
  book and no `tutorial_done`; `--tutorial` forces it in any run,
  `--tutorial=0` never; `--no-title` alone does not stop it).
- `scripts/endless/tutorial/tutorial_land.gd` (lane `tutorial-land`):
  node `game.tutorial_land`, present when the world is `tutorial`. It reads
  `game.lesson.stage` when `game.lesson` exists, else a `--lesson-stage=N`
  launch flag (its own scratch drivers set the stage by hand). `signal
  broke_through` when the wall is broken and the swap to the wilderness
  is done.
- Each lane connects to the other's signal only if the node exists
  (`game.get("lesson")`, `game.get("tutorial_land")`), so each runs and
  proves alone before the merge.

### Lane `tutorial-land` (Opus): the land that teaches

A world profile `tutorial` (`scripts/endless/world/profiles/tutorial.gd`,
`--world=tutorial`): flat meadow everywhere (no hills, no rivers, no
stones), the wilderness's grass and flowers, its hour and mood. Trees,
water and the hall are gated by the stage: chunks built while the stage
is below TREES carry no trees; ponds and the river reach appear only in
chunks built at WATER or later; at WALL the ruin hall (`hall_doors.gd`)
stands ahead of the plane within about 800 m with a cracked wall
(`cracked_walls.gd`) across its mouth, and a marker or line points to it.
Breaking the wall with a surge roll and flying through the hall swaps the
land to the wilderness (the doors machinery: `door_map.gd`,
`hall_doors.gd` `_swap`), landing the plane in the air near the
wilderness's start spawn so round 1's first-shop distances hold. The
cloud deck at about 60 m over the turf, whiteout on entry, clear on
descent. Changing the stage only changes chunks built from then on; say
in the commit how the seam between old and new chunks looks (ponds are
local features; trees are placed per chunk).

Where: new files under `scripts/endless/tutorial/` and the profile.
Additive edits only to the profiles list, `world_profile.gd` and the
world selection; `studies/endless_flight.gd` gets the one line that
builds `tutorial_land` when the world is `tutorial`. List every shared
line under Notes for merge.

Proof: the smoke check with `--world=tutorial`; a scratch driver that
flies ahead at each `--lesson-stage` and asserts no trees at GRASS,
trees at TREES, water at WATER, the hall and the wall at WALL, and the
swap after the wall is broken (`surge_smash.gd` with a full meter); stills
of each stage's land from the plane and of the hall with the wall, looked
at; a still inside the cloud deck.

### Lane `tutorial-flow` (Opus): the lesson

`lesson.gd` as the contract says, wired from `studies/endless_flight.gd`
in place of `first_flight.gd` (the ribbon is unwired, its file left or
removed, said in the commit). On Start with a fresh book the world is
`tutorial` and the plane begins in the air, low and level, over the grass,
at skim height, flying (the title's takeoff shortened or skipped; say
which). The stage advances off the near-miss events that already exist
(`near_miss.gd` moments: pull-out over land and water, graze of a tree,
the skim trickle, the meter at `surge_smash.gd`'s armed level) and off
`tutorial_land.broke_through` to DONE. One HUD line, top centre, the
fonts and inks of `first_flight.gd`'s card: the lesson's verb and the
count, a small skip hint under it, and "lower" appended when the plane
has been above 40 m for two seconds. While the lesson runs the money HUD,
the shop pointer and the key strip are hidden, and shown again at DONE.
The requirements table is one constant block at the top of `lesson.gd`.
`tutorial_done` on DONE and on skip; skip also swaps to the wilderness
(through `tutorial_land` if present, else by the world's own start).

Where: `scripts/endless/tutorial/lesson.gd`, `lesson_hud.gd` if the line
wants its own file; the wiring lines in `studies/endless_flight.gd`;
`pilot_book.gd` reuses `tutorial_done`.

Proof: the smoke check; a scratch driver on `--world=wilderness --tutorial`
(the land lane's world is not there yet) that drives the plane through
pull-outs, grazes and a water pass and asserts each stage change in order,
and one that skips; stills of the HUD line at two stages, looked at.

### Lane `hud` (Sonnet): room on the screen

One owner for the top centre: a single slot that shows the lesson line
while a lesson runs, else the shop pointer; nothing else prints there.
The bottom key strip shrinks to the three or four keys that matter now
(in flight: bank, pitch, boost, brake; stopped: the roll and back-up
hints it already shows; the rest live on the Controls page, with a line
"more: Controls in the menu") and fits inside 1440 wide with margin. The
money reads top right as now. Check the near-miss tag, the meter and the
find line against each other at 1440x900 and 1280x800 so nothing overlaps.

Where: `scripts/endless/near_miss_hud_handoff.gd` or wherever the key
strip and the pointer are drawn (`money_hud.gd` draws the pointer); small
edits, no new systems. Do not touch `scripts/endless/tutorial/`.

Proof: the smoke check; stills in flight and stopped at both sizes,
looked at, nothing overlapping or cut off.

### Lane `shop` (Sonnet): a shop that reads at a glance

The shop shows one group at a time with three tabs across the top:
Planes, Paints, Ribbons (A/D or the pad's shoulders switch; W/S choose
as now). Each plane row has a real swatch: a small rendered thumbnail or
a drawn silhouette of the body, not a blank square. The landing summary
is trimmed to the earn, the best line's one row, and at most two record
lines with "and N more in the logbook (J)" for the rest; sections that
are empty are not drawn.

Where: `scripts/endless/shop_view.gd`, `landing_summary.gd`; swatch
images under `assets/models/<body>/` or drawn in code.

Proof: the smoke check; the economy lane's driver pattern (`scratch/`
econ) to open the shop and land; stills of each tab and of the summary,
looked at.

### Trunk, round 2

6. Merge the four lanes into `iter/ship`; join the wiring in
   `studies/endless_flight.gd` and the HUD visibility (the lesson hides,
   the hud lane's slot shows); smoke on `--world=tutorial` and the
   default; a driven run from a fresh book through all five stages into
   the wilderness, and one that skips.
7. Play by the user; a tuning task from what they say. First play
   (2026-11-08, stopped at the trees stage), two points, both to fix:
   - "Waves are bleeding into the meadow." The sea's waves (foam, swell,
     or the sea mesh itself) show on the tutorial grass. Find why (the
     meadow's height against sea level, the coast band, the sea shader's
     shore reach) and make the meadow dry to the eye: a still from the
     plane at skim height over the grass with no water in it, and one at
     the WATER stage where ponds still read as water.
   - "Tree grazing needs to be easier to do. It's too stringent." The
     lesson's TREES count must move on a pass that feels close, not only
     on the game's scored graze (half a wingspan). Prefer the lesson
     counting its own looser tree pass (a wider distance, its first value
     in the NEEDS table) and denser copses nearer the plane at the TREES
     stage, leaving the game's scoring as it is; if the scored graze
     itself should loosen for everyone, that is the user's call, not this
     task's. Prove with the driver: a pass at the looser distance counts,
     and three such passes end the stage.
   Second play (2026-11-08, grass and trees done, quit at WATER): "I can
   never reach the water." At WATER the ponds come only in chunks built
   after the stage changed, and the land already stands for kilometres
   round the plane, so none is in reach. Every stage's land must be in
   reach within seconds of the stage starting, in the direction of
   flight: at WATER a pond or a straight reach lies ahead within about
   400 m (the land ahead rebuilt or replanned from a near radius, the way
   trees are from 160 m; the seam at the near edge must not show from
   skim height), and the same promise checked for TREES. If a rebuild is
   not possible, stamp a pond ahead and say so. Prove with the driver:
   the nearest pond's distance at WATER start and ten seconds later, under
   400 m, from several headings; and the full lesson end to end.
   Also from the second play: "I want the guidance lines to help guide the
   user to swoop down, and pull up." At GRASS and at WATER a ribbon
   (the shape `place_lines.gd` draws through `rival_marks.gd`, as round
   1's guide used it; its file `first_flight.gd` is in history at bf19fc2a
   for the leg-laying code) is laid ahead of the plane along its heading:
   level at cruise, dipping to skim height for a stretch, pulling up
   through a gate. At WATER the dip lies over the pond or reach the land
   put ahead. It is a guide, not a gate to pass: the stage still advances
   on the pull-outs the lesson counts. When a leg is flown or left behind
   (round 1's LOST rule) the next is laid ahead again, until the stage
   ends; no ribbon at TREES, GAUGE or WALL. Prove with the driver: a leg
   lies ahead within a second of GRASS and of WATER starting, flying it
   scores a pull-out, and the full lesson still runs; stills of the dip
   over grass and over water from the plane.
8. Handoff.
