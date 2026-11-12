# Flight UI: build spec (loop `flight-ui`)

The game's menus and flight HUD rebuilt in Godot from the mock-ups the user
chose on 2026-11-11. The mock-ups are the design; this file says what to
build, in what order, and what is left alone.

## The design sources (read these, do not redesign)

- `docs/design/ui/mock/Main.dc.html`: the menu shell ("slip and tick"):
  title, pause, settings, controls, credits, and the flight tab's corners.
- `docs/design/ui/mock/Hud.dc.html`: the flight HUD, the full set: finds
  chip, region tag, money chip and the coin flight, the charge cells, speed,
  the fading hint, with the chain tag in place.
- `docs/design/ui/mock/Chain.dc.html`: the chain HUD ("plate and trail"),
  every state of a line.
- `docs/design/ui/mock/glyphs.json`: the new glyph set as polygons on a
  24-unit grid (tone 0 lit, 1 mid, 2 shade), its palettes, the per-kind
  tints, and each glyph's `maps` to today's ids.

Each `.dc.html` is one template: its `<style>` holds the exact sizes,
colours, weights and timings, its script the states and the sequence. Sizes
there are px in a 1280x800 frame; in the game scale them by the window
(the existing HUDs use `min(w/2560, h/1440) x SCALE`; keep one scale rule
for all of the new UI and say which). Rendered stills of the mock-ups and
of today's game are in the launch worktree's `scratch/ui_fable/`,
`scratch/ui_glyphs/` and `scratch/launch_shots/` (git-ignored: read them by
absolute path under
`C:\Users\Tenut\zenscape-godot\.claude\worktrees\game-launch-readiness-2e7006\`).

## What done looks like

Launching the game with no flags:

1. **Title**: the name as text (one constant, the name is changing) top
   left over a hairline, and a small cream slip lower left with Start,
   Settings, Credits, Quit. Keyboard, mouse and pad all work.
2. **Pause**: Esc or pad Start in flight opens a left-column slip (Resume,
   Logbook, Photo mode, Controls, Settings, Quit to title, Quit) with the
   plane still visible; the game is paused under it; Esc resumes.
3. **Settings** that work and persist: graphics preset (Performance /
   Quality / Full), 3D resolution (100 / 85 / 75 / 67), Fullscreen /
   Windowed, VSync, Master / Effects / Ambience volume, mouse sensitivity,
   invert pitch, HUD hints. Use the settings files that exist
   (`user://look.cfg`, `user://sound.cfg`, `user://pad.cfg`) where a value
   already lives there; add what is missing.
4. **Controls** and **Credits** pages as in the mock-up (credits built from
   `assets/audio/ATTRIBUTION.md`, the fonts' licences, and Godot's licence
   notice, which the mock-up lacks).
5. **Flight HUD**: finds chip and region tag top left, money chip beside
   it, the charge cells with the speed in one plate lower right, a short
   hint lower left that fades after takeoff. The 20-item key line is gone.
6. **Chain HUD**: the dark plate off the plane's upper left with its one
   strip, the multiplier's segments, the "about to bank" state, the
   half-size pennant, the lost state; on a bank the coins travel to the
   money chip and the total ticks up.
7. **Glyphs**: the new set, drawn from `glyphs.json`, with a colour per
   kind (the json's tints), everywhere the HUD shows a glyph.
8. `--ui=old` brings back today's title, key line, ring HUD and glyphs, so
   the two can be flown side by side.

Defaults for the choices the mock-ups leave open (each stays a setting or a
launch flag, named in the handoff): money shows around a bank, when landed
and when paused; speed shows when it matters; the bank timer is the ring;
"flight best" on, "flight earned" off.

## Left alone

- Scoring, payouts and shop prices: no rule changes. The money beat is
  built on the real numbers (most banks pay +1).
- The logbook, shop, landing card and photo mode keep their look this
  round. They open from the pause menu as they are.
- The dev keys (V, P, T, L, [, ], C, G, K, H, F1, F2, F3) keep working;
  they only leave the on-screen hint.
- No new pad bindings beyond pad Start for pause (`menu` is already bound
  in `scripts/pad.gd`); the controls page shows a dash where none exists.
- The project's name in `project.godot` and the save folder.

## Fonts

The design uses Barlow Semi Condensed 500 upright and 600 italic, which
the repo lacks (it has 800 and 800 italic, Newsreader variable, Spectral
400). The kit loads `assets/fonts/barlow-semi-condensed-500-latin.woff2`
and `barlow-semi-condensed-600-italic-latin.woff2` when present and falls
back to the 800 files when not, so the build runs either way. Adding the
two files waits on the user.

## Split

**Trunk 1, the kit** (first, alone): `scripts/endless/ui/ui_kit.gd` and
whatever small files it needs: the colours, the font loader above, the one
scale rule, and draw helpers for a slip (cream, ink spine, one slanted
edge), a dark chip/plate, a row with the selection tick and lean, a value
row (options underlined, slider hairline with slanted mark and numeral),
key plates and keyboard/pad prompts. New files only. Proof: a throwaway
scene or driver that draws each helper, rendered stills beside the
mock-up's.

**Lanes** (after the kit, at once, one agent each in its own worktree):

- `lane/glyphs` (does not need the kit, may start at once):
  `scripts/endless/near_glyphs.gd` drawing the new set from the polygon
  data, per-kind tints, the same ids, the new ids added; `--ui=old` (or a
  switch the trunk can drive) keeps today's drawing.
- `lane/menus`: title, pause, settings, controls, credits, with the
  settings wired through to the game and saved; pad Start and Esc.
- `lane/hud`: finds chip, region tag, money chip (without the coin flight),
  charge cells and speed plate, fading hint.
- `lane/chain`: the plate-and-trail chain HUD as a new HUD class beside
  the ring (`near_miss_hud_plate.gd`), fed by the same `show_state` calls.

Lanes keep their code in new files; edits to `studies/endless_flight.gd`,
`scripts/endless/main_menu.gd` and other shared files stay small and
additive and are listed under **Notes for merge**.

**Trunk 2..n** (after the lanes are merged, in order): make the new UI the
default with `--ui=old` as the way back; the bank-to-money coin flight
(chain pennant to money chip); glyphs into every new HUD piece; a pass over
every screen at 1440x900 and 1920x1080 against the mock-ups, and over
bright water, pale rock, dark forest and dusk; the handoff.

## Proof per step

Smoke `studies/endless_flight.tscn` (no flag, and `-- --ui=old` once that
flag exists). Rendered stills of what the step draws, looked at beside the
mock-up; menus and pause through the real input path with a driver
(`tools/harness/drive.gd`: `tap`, `press`, `shot(path, true)`); the chain
HUD fed through the real scoring path as
`scratch/ui_fable_hud.gd` in the launch worktree does. No committed tests,
no full suite. Rendered runs pass `--no-title` unless the title is the
subject (`--title` among a driver's scene args keeps it), and use
`--pilot=fresh` or `--pilot-file=` so the player's book is never written.

The cap and budget are the skill's default.
