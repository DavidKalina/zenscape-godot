# First-open authoring stalls

The product scene now prepares the appearance and landscape panels, object
thumbnails, and palette rows during startup. A tiny offscreen viewport renders
the palette's canvas shader materials once. Panels remain hidden until opened;
preparation does not change world data. Study scenes retain lazy initialization.
Palette searches reuse rows and headings instead of rebuilding them every time.

## Measurement

Godot 4.7.2, Metal Forward+, Apple M5 Pro, 1440×900. One before/after run of
`tools/profile_panel_opening.gd`, opening each panel twice after a one-second
settle. These are local measurements, not Windows results or statistical bounds.

| First action | Open CPU before → after (ms) | Peak frame gap before → after (ms) |
| --- | --- | --- |
| Enter build mode | 57.715 → 0.202 | 68.246 → 14.466 |
| Open object palette | 12.172 → 3.286 | 17.894 → 14.244 |
| Open landscape panel | 22.737 → 0.089 | 33.581 → 19.411 |
| Open appearance panel | 49.914 → 0.233 | 73.736 → 17.897 |

The first build transition previously recorded three canvas pipeline compilations;
after preparation all measured transitions recorded zero canvas and draw
compilations. Reopening the palette fell from 12.526 to 3.149 ms of CPU work.
Peak frame gaps cover the following twelve process frames, so include unrelated
rendering and scheduling work. Raw results are in `panels-before.json` and
`panels-after.json`.

Run with a native renderer (headless cannot measure shader compilation):

```sh
godot --path . --script tools/profile_panel_opening.gd -- --out=/tmp/zs-panels.json
```

## Validation and limits

- `test_authoring_preparation.gd`: preparation, hidden panels, unchanged world
  data, idempotence, row reuse and filtering pass headless.
- `test_diorama_flow.gd`: passes headless.
- `test_command_palette.gd` and `test_native_build_palette.gd`: zero failures
  with the native renderer. Logs also contain renderer/resource cleanup warnings.
- `git diff --check`: passes.

This moves work into initial loading and retains the prepared controls and
thumbnails in memory. The shader viewport draws once, with no continuous update.
It addresses measured UI-opening stalls across maps; it does not establish the
cause of the occasional Redwood camera hitch. Confirm on Windows, using the F9
performance capture if that hitch persists.
