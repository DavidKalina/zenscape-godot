# Strange inhabitants, round 1: build brief (2026-10-14)

> Handoff for a cloud agent. Build four new inhabitants of the underground
> Olmec city as playable prototypes, each in its own test yard with the
> Olmec present. The user plays them in the morning.

## Setup

- Repo `zenscape-godot`. Branch from `roguelike` (pushed 2026-10-14).
- Act as the coordinator. Spawn **four Opus subagents in parallel**, one per
  inhabitant, each on its own branch `enemy/<slug>` (`echo`,
  `tithe-taker`, `jade-mask`, `sun-keepers`).
- Push each branch. Don't push to `roguelike` and don't merge.
- **Godot 4.7.2** (standard, not .NET) must be available.
  - `python3 tools/godot.py --where` finds it.
  - If the cloud machine has none, download the Linux x86_64 4.7.2 build
    and point `GODOT` at it.
  - The native terrain kernels are optional; the GDScript versions run
    without them.

## Every subagent reads first

- `docs/design/roguelike/game-v1-brief.md`, all of it. It is the game.
- `AGENTS.md`: Prototyping, Sizes, Art direction, Animation, Models,
  Subagent models.
- `tools/README.md`: the harness (smoke check, play-loop driver, stills).
  Use it; don't rewrite it.
- Its neighbours in code:
  - the headless Olmec body (`headless-body-round*.md`);
  - his sight, hearing and attention (`beacons-light-sight-round1.md`:
    `SightLight`, `Beacon`, `scripts/enemies/`);
  - `scripts/enemies/enemy_field.gd` (`sound(name, at)`);
  - hearts and damage (`game-v1-hearts.md`: `PilotMotor.harm(cause,
    amount, source)`);
  - the run's runes (`scripts/roguelike/run_state.gd`);
  - a city yard to copy the shape of, e.g. `studies/city_breaks2_yard.gd`.

## The bar (the user's words)

The user hates cliché mechanics: "latch on, shake them off", reskinned mob
packs. The model is **Lethal Company**: each enemy has one weird rule and a
unique pattern. The other model is the user's own Olmec: a body hunting its
head, then insane once it has it.

Every inhabitant needs:
1. **One strange rule.**
2. **A readable tell.**
3. **A change of state.**
4. **A hook into the game's systems.**
5. **A way a clever player uses it as a tool, at real risk** (rule 0).
6. **Co-op in mind.** v1 is single player, but don't hard-wire one
   wanderer where that's cheap to avoid.

Look: Olmec / Mesoamerican, weathered and real (AGENTS.md "Art direction":
menace from material, weight and restraint; no horns, spikes or edgy red
glows). Reuse existing stone shaders and kit pieces; a greybox body with
the right material is fine for a first round. Motion should read at a
glance (AGENTS.md "Animation"), though procedural motion is fine for
round 1.

## The four

### The Echo (`echo`)
It makes no sound of its own.
- **Rule:** it drifts near the wanderer and records the sounds he makes
  (footsteps, landings, torch crackle, breaks; whatever goes through
  `EnemyField.sound` or the motor's own events). A few seconds later it
  replays them from **where it is**, as real sound events the Olmec
  hears and goes to.
- **Danger:** your own noise follows you around.
- **Tool:** make noise past it, slip away, and the Olmec chases your ghost.
- **Tell:** a faint shimmer or distortion, the replayed sound slightly
  wrong (pitched or reverbed).
- **State change:** for example it grows bolder (follows closer, replays
  sooner) the more it has recorded, or it goes quiet when you hold still.
- If the Olmec's hearing doesn't take sound events yet, add the smallest
  hook that lets it, and say so in the handoff.

### The Tithe-Taker (`tithe-taker`)
- **Rule:** it ignores you until you carry more than N runes (a knob,
  default about 12). Then it follows whoever carries the most.
- **Feeding it:** drop runes into its bowl (or let it take them on touch)
  and it calms. It settles longer the more you give.
- **Escalation:** the longer it follows unfed, the faster and closer it
  gets. Its touch costs a heart, or knocks you back hard; pick whichever
  reads better and say why.
- **Tell:** it turns toward your rune count. The HUD runes could glint
  when you cross its line.
- **Tool:** for example, it pushes through things, or it scares the Olmec
  off. Find one.
- Give the yard rune pickups so the player can cross the line.

### The Jade Mask (`jade-mask`)
- **Rule:** an empty jade mask drifts through the halls. Whatever it lands
  on animates:
  - a stone statue stands and walks, slow and heavy, toward the wanderer;
  - a leaning pillar topples, using the city breaks where they exist.
- **State change:** knock the mask off (a slam, a hit, the Olmec's swat)
  and the host goes still. The mask drifts to the nearest new host.
- **Tool:** lure it onto something useful, for example a statue that walks
  into a sealed door and breaks it, or one the Olmec fights.
- **Tell:** the mask's eyes and the host's stirring before it moves.
- Place several possible hosts in the yard: statues, a pillar, a breakable.
- Interesting open question: what if it lands on the headless Olmec body?
  Try it.

### The Sun-Keepers (`sun-keepers`)
Stone attendants that move **only in light**: the inverse of a coil-head.
- **Rule:** use the existing light model (`SightLight.light_at`, the
  torch, cressets, beacons). In light above a threshold they advance; in
  the dark they freeze mid-pose.
- **Dilemma:** your torch wakes them, so you cross them dark, blind over
  the void. Lighting a cresset to draw the Olmec also wakes them.
- **Tell:** dust trickling off them in light, a grinding sound.
- **State change:** for example a keeper caught in light too long wakes
  fully and keeps moving even in dark for a while.
- **Tool:** for example, lit keepers block the Olmec's path, or one can be
  walked into a gap to bridge it.
- The yard needs a stretch with keepers, a torch-snuffing trough or a
  dark lane, and a cresset to light.

## Each subagent builds

- The inhabitant: its script and greybox model or materials, with every
  number in named constants and knobs.
- A yard, `studies/<slug>_yard.tscn`: a basalt plaza over the abyss in the
  underground look (`--underground=torch`), with the Olmec body hunting, the
  real pilot, station keys, and an R reset. Copy a city yard's shape.
- A launcher, `run-<slug>-yard.command`, shaped like the other `run-*.command`
  files.
- A handoff, `docs/design/roguelike/<slug>-round1.md`, covering:
  - how to run it;
  - the rule as built;
  - every number and why;
  - what the player can exploit;
  - seams;
  - any existing test the change breaks.

Stay off the generator (`scripts/roguelike/layer_*.gd`, `run_layer.gd`,
the greybox registry, `gb_*.gd`). Another session is landing city layers
there.

## Prove it

This is a prototype round (AGENTS.md "Prototyping"):
- No new committed tests. Don't run the full suite.
- Run the smoke check: a headless import, then the yard loaded for a few
  hundred frames with no script errors (`tools/smoke.py`).
- Add a throwaway check through the **real play loop and input path**
  (`tools/drive.py`; drivers in `scratch/`) proving the strange rule
  works. For example:
  - the Olmec walks to an Echo replay;
  - the Tithe-Taker turns on at N runes and settles when fed;
  - the Mask animates a host and moves on when knocked off;
  - Sun-Keepers advance lit and freeze dark.
- Rendered stills only if the machine has a GPU. If not, say the look is
  unverified.

## Finish

Coordinator's final message:
- each branch and commit, with a three-line summary;
- what the user should play first;
- any hook added to the Olmec (hearing, etc.).
