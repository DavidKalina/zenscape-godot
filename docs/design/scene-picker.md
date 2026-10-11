# Scene picker

A dev and playtest menu for opening every study and greybox from the game's
title, with no `.command` launchers. It works in exported builds too.

## How to open it

1. Start the game as normal (`./run-cozy-flow.command`, F5 in the editor, or
   the exported build). Don't pass `--no-title`.
2. On the title card's foot, pick **Scenes**. It's a quiet small-caps entry
   before Settings. Nothing else on the title changed.
3. The picker shows one column per group. Mouse, arrow keys, or the pad's
   D-pad or stick move between rows. Return, Space or A opens the row. Esc, B,
   or **Back** on the card's foot returns to the title. The line under the
   columns describes the row you're on and lists its flags.

To get back to the title from a scene you opened, **hold Esc (pad: View + Menu)
for a second, then let go.** A line at the foot of the screen fills while you
hold. A tap of Esc still does only what it did before: frees the mouse in the
studies, or pauses the game. Quitting the window returns to the desktop as
always.

## Entries

| Group | Entry | Scene | Flags (after `--no-title`) |
|---|---|---|---|
| The game | Your world | studies/cozy_worlds.tscn | `--resume` (your last world, or a new plain; the normal hand/build start) |
| The game | Moments in the sky | studies/cozy_worlds.tscn | `--moments --skydive` |
| Ruins | Aqueduct isle | studies/aqueduct_isle.tscn | none |
| Ruins | The Sundered hall | studies/cozy_worlds.tscn | `--motif=sundered --no-clusters --skydive` (starts in the plane; the hall is 240–900 m out) |
| Ruins | Ruin kit gallery | studies/ruin_kit_gallery.tscn | none |
| Flight greyboxes | Every pack | studies/flight_study.tscn | `--station=lines_bend` |
| Flight greyboxes | Lines / Nature / Sky / Tokens / Moments | studies/flight_study.tscn | `--pack=<name>` |
| Flight greyboxes | Moments, crashing | studies/flight_study.tscn | `--pack=moments --crash=hard` |
| On-foot greyboxes | Character study | studies/character_study.tscn | none |
| On-foot greyboxes | Pocket sail | studies/pocket_sail_study.tscn | none |
| On-foot greyboxes | Ruins archipelago / Sky village / Starter islands | studies/character_study.tscn | `--pack=ruins_archipelago` / `sky_village` / `starter` |
| On-foot greyboxes | Test island | studies/test_island.tscn | none |
| On-foot greyboxes | Walk island | studies/walk_island.tscn | none |
| On-foot greyboxes | Collectible gallery | studies/collectible_gallery.tscn | none |

Launchers that were left out:

- `run-fidelity.command` and `run-fidelity-life.command`: an old study.
- `run-diorama.command`: the old diorama shell. The game supersedes it.
- `run-godot-comparison.command`: a tool script, not a scene.
- `run-cozy-flow.command`: this is the title itself.
- `run-flight-study.command` with no flags: covered by "Every pack". Every pack
  starts on lines_bend, the same as `run-flight-packs.command`.

## Adding an entry

Add one line to `ENTRIES` in `scripts/scene_catalog.gd`:

```gdscript
{"id":"my_study","group":"On-foot greyboxes","title":"My study","scene":"res://studies/my_study.tscn","args":["--pack=x"],
	"detail":"One line saying what it is and its keys."},
```

- A new `group` value becomes a new column, placed in order of its first
  entry. Four columns fit the card. A fifth also fits but is tighter.
- `args` are the flags that would come after `--` in the scene's launcher.
  `--no-title` is added automatically.
- Run `tests/test_scene_picker.gd`. It checks that every entry's scene exists
  and loads. Also run `tests/test_scene_picker_entries.gd -- --only=my_study`,
  which opens the scene and runs it for a few seconds with no script errors
  (tagged slow).

## How flags reach the scene

The command line can't change once Godot is running. `scripts/launch_args.gd`
holds a static `override`. Every `OS.get_cmdline_user_args()` call in
`scripts/` and `studies/` now goes through
`preload("res://scripts/launch_args.gd").user_args()` instead: 137 call sites
in 71 files, a mechanical replacement. With no override, `user_args()` returns
the command line exactly as before.

When you pick an entry, `scene_catalog.gd` `open()` does three things:

1. Puts `scripts/scene_return.gd` (the hold-Esc way back) on the tree root, so
   it survives the scene change.
2. Sets the override to the entry's args plus `--no-title`.
3. Calls `change_scene_to_file`.

The way back sets the override to the command line's own flags, minus the ones
that skip the title (`--no-title --resume --generated --seed N --atlas`). It
then changes to the main scene.

Note that `tools/` and `tests/` still read the real command line, and a few
lines that check `OS.get_cmdline_args()` (engine args) are unchanged.

## Release gating

The picker is on everywhere, including release exports. The user wants to boot
every scene from the menu in an exported build on their Windows PC until Steam.
`scene_catalog.gd` `enabled()` decides:

- Editor and debug runs: always on.
- Release exports: on while `const IN_RELEASE := true` in
  `scripts/scene_catalog.gd`. The project setting `zenscape/dev/scene_picker`
  overrides it if set.
- `--scenes` on the command line forces it on. `--no-scenes` hides it
  everywhere.

To hide it from players later, set `IN_RELEASE` to false, or add
`zenscape/dev/scene_picker=false` under `[zenscape]` in project.godot.

### Export check

`export_presets.cfg` (Windows and macOS) uses `export_filter="all_resources"`,
so all of `studies/` and `scripts/` are exported, including the island packs
that `character_study` loads by path. The scenes' runtime JSON lives under
`assets/zen_reference/`, which `assets/**/*.json` already includes. No entry
uses `tools/`, `docs/` or `tests/`, which are excluded. The native terrain
kernels ship through the gdextension, as before.

One change: `studies/character_runs/*.json` (the character study's saved
recordings, which F6–F8 replay) was added to `include_filter` so replays work
in an export. Saving a new recording (F5) writes to `res://`, which is
read-only in an export, so that still only works from the editor.

There are no export templates on this Mac, so an actual export wasn't built
here. CI's Windows job (`--export-release`) is the real check.

## Tests

- `tests/test_scene_picker.gd` (fast). Covers the catalogue (unique ids, scene
  exists, PackedScene and root script load), the launch-args override, the
  card's keyboard and pad navigation (focus never leaves the card; A and
  Return pick; B and Esc go back), and opening an entry with the hold-and-let-go
  way back.
- `tests/test_scene_picker_title.gd` (slow, about 70 s). Runs from the real
  title on the pad: Scenes is on the foot before Settings, A opens the picker
  with the focus ring, B goes back with Scenes in reach, and A on the ruin kit
  changes scene to it on its flags.
- `tests/test_scene_picker_entries.gd` (slow, about 3 min). Opens every entry
  in one process, as the picker would, waits for the game's shell where there
  is one (saves go to a scratch folder), runs for 6 s, and counts script errors
  through a `Logger`. All entries pass headless.

Headless can't show how the scenes look or how they run on a GPU, so that is
unverified beyond the two rendered captures of the title and the picker.

## Open issues

- **Scene teardown.** Leaving the title's world with `change_scene_to_file`
  had no script errors in the tests, including the title → ruin kit run. Static
  caches (`static var` meshes in sky_ambient_life, rock_variants, water_ball
  and others) do outlive scene changes. In one of three runs,
  `test_scene_picker_entries.gd` crashed **at exit** (SIGABRT,
  `~ArrayMesh` with no RenderingServer) after all its checks had passed. This
  is an engine-shutdown order problem with those static meshes, not with the
  picker, and it doesn't happen during play.
- **Static flags.** Scripts that read flags into a `static var`
  (water_ball, god_hand, desert_landscape, sky_cloud, quiet_guidance) keep the
  value from their first load. No entry passes those flags. An entry that
  needs one has to move that read out of the static.
- **"Your world" uses `--resume`.** It opens your most recent world straight
  in, or makes a new plain if you have none. There's no entry for a fresh
  plain; use the title's "Begin on a quiet plain".
- **The Sundered hall** is far out (240–900 m): you start in the plane and
  fly to it. Watch the console for its heading.
- The way back always lands on the title, never inside the scene you came
  from.
