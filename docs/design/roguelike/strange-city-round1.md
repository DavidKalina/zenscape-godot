# Strange city, round 1: noise and five strange things (2026-10-15)

Prototypes from the round 4 brainstorm
(`brainstorm/round4-strange-city/README.md` on branch
`brainstorm/round4-strange-city`). Branch `proto/round4-strange-city`, cut
from `roguelike`. Everything was built and proved headless: each piece got
a smoke check and a throwaway drive through the real play loop. The looks,
sounds and feel have not been seen in the real renderer, so they wait on
the user's play.

| What | Play it | Write-up |
|---|---|---|
| Noise and stealth | the game, or `whole_body_chase.tscn -- --noise-debug` | `noise-stealth-round1.md` |
| h1 The Sun-Keepers | `run-strange-sunkeepers.command` | `strange-sunkeepers-round1.md` |
| h2 The Second Walker | `run-strange-second-walker.command` | (in the commit) |
| a5 The Earth Mouths | `run-strange-earth-mouths.command` | (in the commit) |
| x5 The Hollow Child | `run-strange-hollow-child.command` | `hollow-child-round1.md` |
| t1 The Day-Count | `run-strange-day-count.command` | `strange-day-count-round1.md` |

## New controls

- **Sneak.** Hold Ctrl or Alt (`walk_sneak`), or ease the stick under
  half. Sneaking is near silent.
- **Torch.** T or pad Y (`walk_torch`) puts the torch out or lights it.
  Only the Sun-Keeper and Hollow Child yards read it so far.

## Seams

- **Noise only reaches the Olmec.** The creatures' own sounds (the
  Walker's toks, the Day-Count's clacks, the Hollow Child's cry) are not
  on the noise bus yet.
- **None of it is in the generator.** Each piece lives in its own yard.
- **The torch douse is per yard.** Making it game-wide means moving the
  `walk_torch` poll into `scripts/underground/underground.gd` and removing
  the city yards' own T handlers.
- **Earth Mouths bait.** Standing in a mouth as bait gets you eaten,
  because his pounce stuns you. Luring him works by running across a
  mouth.
- **The Day-Count clicks every 4 footfalls, not every one.**
  `--knob=per_click=1` plays the card as written.
- **Tests.** No committed tests were added. The failures seen
  (`test_character_recordings`, `test_slide_carve`, `test_trap_giants`) also
  fail on the base commit. `test_run_layer` and `test_layer_sprawl` timed
  out under load and were not compared against the base.
