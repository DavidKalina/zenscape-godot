# Brief: the plane's arc

> Draft brief, 2026-10-11. Not fired yet: waiting on the scale and spacing
> work. Direction: docs/game-direction.md ("The plane", "The plane's parts",
> "The downdraft"). Split into rounds; one agent per round, each ending in
> commits and a handoff doc (docs/design/plane-arc/roundN.md), the next
> briefed fresh from it.

## The goal

The game opens with the plane broken. Region one's first goal is finding its
parts on foot, each found a different way. Every part is a ledger objective;
found parts seat in the plane and the repair shows; with all found, the
plane flies. It is the first piece of the spine (finds seat in the plane;
enough of them opens the beat).

## Builds on

- **feature/ledger** (branch from it, not main, until it is merged): the
  GameState autoload (`scripts/ledger/ledger.gd`, reached via
  `Ledger.shared()`), the registry (`data/ledger/ledger.json`,
  `data/ledger/ruins.json`), ids `<isle>/<slug>`, live isle cards. Its
  handoff: docs/design/ledger/round1.md.
- **The plane:** boarding, parking and leaving in `studies/kit_isle.gd`
  (`board_parked`, `_park`, `leave_plane`, `plane_home`); figures
  `scripts/plane_figure.gd` (single mesh, no per-part breakdown) and
  `scripts/stone_plane_figure.gd`; the lodestone seats in the plane today
  (`scripts/lodestone.gd`, `_carry_step` in kit_isle.gd) — the model for
  seating parts.
- **Pickups:** `scripts/kit_isle/kit_tokens.gd` (laid by name from isle
  geometry, `spots_for`), `scripts/glyph_pickup.gd`, `scripts/rune_token.gd`.
- **The motor:** `scripts/pilot_motor.gd` (crouch does nothing in the air:
  the downdraft's slot), `scripts/updraft.gd` (the flow charge; Q / pad RB).
- **The serpent:** `scripts/kit_isle/serpent_route.gd`,
  `scripts/kit_isle/serpent_rider.gd`, `scripts/rune_serpent.gd`.
- **Sky traffic:** `scripts/sky_traffic.gd` (ambient planes, used by
  `studies/aqueduct_isle_sky.gd`); rope sim in `scripts/interactables/
  swing_rope.gd`.
- **Water:** swimming in the motor; `scripts/kit_isle/kit_water.gd`.

## Rounds

### Round 1: the broken plane and the first parts

- **Plane state** in the ledger's save: broken until all parts are found.
  Boarding a broken plane plays a short "it won't start" moment (a cough,
  a sputter, the prop twitching) and doesn't take off. Repaired, it flies as
  today.
- **Part objectives:** a new ledger type "part" (card row "Plane", its own
  icon). Each objective in the registry gets a `needs_plane` flag (false for
  all parts; tokens default false), and the region query can count by it.
- **Parts as physical pickups:** the hovering pieces from look/plane-parts
  (`scripts/plane_parts.gd`, style "piece"); the parked plane's damage, seating
  and wear from look/broken-plane and look/broken-plane-2
  (`set_missing`, `set_found`, `set_wear` on `scripts/plane_figure.gd`).
  Merge those branches into the round's base first. Picked up on foot only; it stamps
  the ledger and seats in the plane.
- **Seated and visible:** each found part shows on the parked plane (hidden
  or dark until found; found ones present and faintly glowing at first).
  Crude is fine: show and hide pieces, or overlay simple meshes.
- **The wheel and the wingtip** (the mapping: docs/game-direction.md "The
  plane's parts"): the wheel out in the open on the aqueduct isle near
  spawn, high, a platforming climb; the wingtip under water at the cloister
  tarn (a swimming find). Placed
  by name from isle geometry like the tokens, never by hard world position.
- **Flags:** `--plane-fixed` starts repaired (so flying work isn't blocked);
  existing `--fly` implies it.

### Round 2: the downdraft

- **The downdraft** (docs/game-direction.md "The downdraft"): mid-air with
  crouch held, spend the flow charge on a burst of wind straight down. Shares
  the charge with the updraft. Visual in the breeze ribbons' brush, a ring of
  flattened grass on landing. It knocks nearby movable things outward
  (prepare a hook for enemies), and reveals buried finds.
- **Buried finds:** a faint shimmer in the turf; a downdraft over it blows
  the turf off and the find pops out. A general reveal any objective can
  use.
- No part rides on it yet (the cowl, under the bell spires' bell, comes
  after the ferries); a buried rune token on the aqueduct isle shows it off.

### Round 3: the tail fin and the propeller

- **The tail fin, ride the snake:** caught in the serpent's back ridges,
  visible as it passes the home ledge; picked up on its back, the ride
  strands you for a lap, carried to the cloister tarn.
- **The propeller, snag it from a passing plane** (study/snag is the
  greybox; the plane's loop dips through the Sundered gorge, grabbed from the
  rope bridge; follow "never wait-and-grab"): a sky-folk plane (sky traffic)
  flies a fixed, learnable low loop with the part on a rope beneath it
  (rope sim, pendulum sway). Where it dips near a high ledge or pier, the
  pilot can reach it with an updraft or long jump; grabbing the load jerks
  the plane (it lurches, the pilot looks back), the part tears free and
  falls with the pilot or into his hands.

### Later rounds

4. **The windscreen:** at dusk its glass glints as it streaks down; it lands
   in the drowned nave's water.
5. **Airship ferries, then the cowl:** jammed under the bell at the top of
   the bell spires; a downdraft on the bell swings it loose.
6. **The crash opening:** see docs/game-direction.md.

## Constraints

- **Scale.** Isles, arches and spacing are being rescaled. Place everything
  by name from isle geometry; never change placements, sizes or spacing.
  Expect to re-tune reach (ledge to snag, serpent boarding) after the scale
  lands.
- **House style:** `##` header prose like the surrounding scripts, same
  naming and idiom. Small hooks into kit_isle.gd and the isle scripts; logic
  in new files.
- **Worktree setup:** copy the gitignored `native/terrain_kernels/bin/`,
  `zenscape_kernels.gdextension` and its `.uid` from the main checkout, then
  `godot --headless --path . --editor --import`. No `timeout` on this Mac.
  Headless only; never open a window.
- **Tests:** only the headless import, a load check
  (`res://studies/zenscape.tscn --quit-after 300 -- --no-title`) and the
  round's own new tests. Not the full suite. Don't touch
  tests/known_failures.txt.
- **Commits** on the round's branch, not merged to main, ending with the
  session's attribution lines.

## Open for the user

- Part names (the brainstorm's repair-ledger entries, e.g. "The Prop Lost to
  the Tarn").
- Which plane: the wooden biplane or a salvaged look (look/plane-ruin,
  look/plane-stone branches)?
- Whether the snag's pilot is a named, recurring character.
