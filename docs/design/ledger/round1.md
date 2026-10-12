# The ledger, round 1

Progress now persists. Taking a token saves it, a token you've taken stays
gone on the next run and after Back to the title, and every isle's card
counts from what you've actually done.

## What's built, and where

- **`scripts/ledger/ledger.gd`** is the game state autoload, registered as
  `GameState` in `project.godot`. It holds what's done, keyed by objective
  id, and saves it to `user://progress.json` on every objective done. As an
  autoload it outlives scene changes. It answers:
  - `is_done(id)` and `mark_done(id)`
  - `card(isle_id, base)`: the card with its `finds` rows
  - `isle_progress(isle_id)` and `region_progress(region_id)`, each
    `{done, total, types: {type: {done, total}}}`
  - `reset()`, and a `changed(id)` signal

  Scripts reach it with `const Ledger = preload("res://scripts/ledger/ledger.gd")`
  and `Ledger.shared()`, not by the autoload's name. A `--script` run
  compiles its scripts before the autoloads are up, so the global name
  breaks every test that loads an isle.
- **`scripts/ledger/ledger_registry.gd`** reads `data/ledger/`.
  - `ledger.json` is the index: the types (`token` → row `glyphs`), the
    card rows in order (`{id, icon, label}`) and the region files.
  - `ruins.json` is region one: the aqueduct isle and the 8 motif isles,
    with 57 token objectives in all.
  - Bad data (a duplicate id, an unknown type or row, a slug that isn't
    one) is reported in `errors` (a warning at boot), and the bad entry is
    left out.
- **Hooks** (small, no placement touched):
  - `scripts/kit_isle/kit_tokens.gd`: `setup` skips tokens that are already
    done and pre-fills `taken` with them, and `take` calls `mark_done`.
  - `isle_card()` in the 8 `motif_*.gd`, `studies/aqueduct_isle.gd` and
    `studies/kit_isle.gd` now returns
    `Ledger.shared().card(id, {name, epithet})`.
  - A `Ledger` const in `kit_motif.gd` and in `kit_isle.gd`, next to its
    `isle_card`.
  - `data/ledger/*.json` is added to the export include filter.
- **`tests/test_ledger.gd`** covers:
  - registry and ids, and that the registry matches the tokens the isles'
    code actually lays
  - the save and load round trip
  - card counts
  - a taken token persisting, with the HUD's count
  - the region query
  - surviving a scene change
  - three headless child runs that check `--ledger` and `--fresh-ledger`
    across processes

## Ids

An objective's id is `<isle_id>/<slug>`, the same key style as
feature/challenge-recorder's `challenge_progress.gd`.

- **Isle ids** come from `Ledger.isle_id_of(isle)`. For a motif isle (placed
  or standalone) that's its motif's `id()`, e.g. `bell_spires`. Anything
  else gets `isle_name()` in snake case, e.g. `aqueduct_isle`, which is what
  the challenge recorder uses.
- **Token slugs** are the `name` each isle's `spots_for` already gives its
  token (`slot`, `chimney`, `landing_3`, ...).

Nothing in an id depends on a position, so the isles can move and rescale
freely. Renaming a token's `name` in code does change its id.

## Declaring an objective

1. Add it to the isle's `objectives` in its region file:
   `{"slug": "...", "type": "token", "name": "Beneath the Keel's Shadow"}`.
   `row` is optional and defaults to the type's row.
2. In the isle's code, call `Ledger.shared().mark_done("<isle>/<slug>")`
   when it's done. Use `is_done` to decide whether to set it up again.

The card picks it up with no further code. A card row only shows if the
isle has at least one objective under it.

## A new objective type (challenges, plane parts next)

1. In `data/ledger/ledger.json`, add the type under `types` with its row,
   and add the row to `rows` (icon id from `scripts/hud_icons.gd`, plus a
   label). The order of `rows` is the order on the card.
2. List the objectives in the region file with that `type`.
3. Hook the place where it's completed.
   - **Challenges:** call `mark_done(id)` from `challenge_progress.completed`.
     Their ids are already `<isle>/<name>` with the same isle ids. Best
     times and tries can stay in `challenges.json`, or move into the
     ledger's records later (the record dict has room).
   - **Plane parts and deliveries:** the same pattern.

The registry also accepts any `type` string that `types` declares.

## Save format and flags

`user://progress.json`:

```json
{"format": 1, "saved": "2026-10-11T20:41:00",
 "objectives": {"aqueduct_isle/slot": {"done": true, "at": "2026-10-11T20:40:12"}}}
```

It's written to `progress.json.tmp` first and then moved over the real
file. An unreadable file loads as nothing done (with a warning). Ids that
the data no longer lists are kept but not counted.

- **`--ledger=<path>`**: keep progress in another file (`user://...` or an
  absolute path).
- **`--fresh-ledger`**: start with nothing done. The file is left alone
  until the first objective is done, and that save overwrites it.
- **Script runs** (`--script`: tests and tools) keep progress in memory
  only unless `--ledger` is given. `user://` is shared by every checkout and
  worktree of the project, so this stops tests from reading or writing the
  player's save.

## Card rows: dropped

Each card now has a single row: Glyphs, from the on-foot tokens. These
placeholder rows had nothing behind them and are gone:

- Bells
- Lanterns
- Echoes
- Lodestones
- Hidden ways

They come back by declaring objectives under a row for them.
`kit_isle.gd`'s base card, which no listed isle uses, now has no rows.

## What's weak

- **A taken token simply isn't laid.** There's no faint "already found"
  version: `glyph_pickup.gd` has no faded look, and a headless run couldn't
  check one.
- **The plane's token lines aren't objectives.** Those are the sky
  collectibles that motifs feed in through `plane_tokens`. They still reset
  every run.
- **Unlaid tokens still count.** Three tokens are only laid when the isle's
  geometry is present (`aqueduct_isle/trilithon`, `bell_spires/belfry_head`,
  `colonnade_spine/cleft`), and so are the ones behind `if not
  x.is_empty()`. If the art ever stops providing them, they still count
  toward the card's total. The test only cross-checks them by name.
- **Renaming a token's `name` in code orphans its save** and makes the test
  fail, which is intended. There's no migration map yet.
- **The id helper is a guess.** `isle_id_of` checks for a `motif`, then
  falls back to the snake-cased name. An isle with neither gets an id of `""`.
- **Saving is synchronous.** It runs on every objective done, which is fine
  for a handful a session but not for something frequent.
- **Not verified headless:** the card's look with one row instead of three.
  `tests/test_isle_card_marks.gd` covers drawing, but nobody has looked at it
  rendered.

## Open questions

- Should a region beat gate on the total, or on a count per type (say, so
  many parts plus so many tokens)? `region_progress` returns both.
- Should isle names and epithets move into `data/ledger/` too, so all
  naming lives in one place? They're still in the isle scripts.
- Should the challenge recorder's `challenges.json` merge into
  `progress.json`, or stay separate and report into it?
- Do plane token lines become one objective per line, or one per token?
- Do you want an in-game "new game" (a `reset()` behind a menu item)?
  Today the only way is the `--fresh-ledger` flag.
