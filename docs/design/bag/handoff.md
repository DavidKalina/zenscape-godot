# Handoff: the loot bag (greybox study)

Spec: `docs/design/bag/spec-bag.md`. Built on branch `iter/bag` over
seven rounds (`git log --grep='^ITER(bag)'`).

## Where to play it

`./run-bag-study.command` (or
`godot --path . res://studies/bag_study.tscn -- --no-title`).

The room is plain grey. It has the start floor with loot of mixed weights,
a 0.4 m low step, a 1.7 m climb ledge with loot on top, a raised platform
up a ramp, and the 1.7 m throw wall with a pocket behind it. A 12 m slope
of about 18 degrees runs east down to the lower floor (4 m lower), where
rocks and curbs stand. Every piece is named `bag_study/<piece>` for the
world view (F4).

## Controls

| Key (pad) | What it does |
|---|---|
| E (B) | by loot: put it in the bag (worn, or set down by him) |
| F (d-pad down) | worn: set it down. By a grounded bag: shoulder it (18 kg or under) or drag it (over 18). Dragging: let go |
| hold LMB or T (RT) | worn, 8 kg or under: aim a throw. The stick moves the reticle and the camera swings it. Let go to throw it (gold) or to cancel (red) |
| V (d-pad right) | by a grounded bag: shove it (rolls it down a slope) |
| 1 to 5 | start, ledge, throw wall, slope, lower floor |
| R | back to start. F1 numbers, F4 world view, Esc frees the mouse |

## What's built

- **The bag** (`scripts/carry/loot_bag.gd`, set up by
  `studies/bag_study.gd`): a procedural cloth sack on his back that swells
  as it fills and sways as he moves. Cap 24 kg, wear limit 18 kg.
- **Weight:** one continuous curve (free to 2 kg) scales walk, run, jump
  and turn, down to 0.6 / 0.45 / 0.4 / 0.55 at the cap. Moves drop by kg:
  wall at 5, ledge at 9, sail at 13, rope at 17. A barred move tried gives
  a balk and a line. A top-right readout shows kg, the bar, paces and what's
  barred.
- **Full:** a piece past the cap (or past the wear limit while worn) stays
  where it is. He shakes his head, there's a low "uh-uh" and a red line,
  and the prompt says so beforehand.
- **Set down / shoulder / drag:** when he sets it down it becomes a loose
  rigid body. Over 18 kg it can only be dragged by a rope from his hand: he
  goes slowly, it scuffs, and it catches on lips higher than about half its
  radius (the low step, curbs, rocks), which holds him back with "Caught:
  pull it another way".
- **Roll:** V shoves a grounded bag. It tumbles with thumps and puffs,
  and comes to rest on the flat. Shoved down the slope it rolls to the
  lower floor, about 6 m past the slope's foot, among the rocks and curbs.
- **Aimed throw:** hold to wind up and aim. A reticle sits on the surface
  under the spot, with a dotted arc to it. The arc is gold, or red when
  there's nowhere to land, the spot is too steep, or the way is blocked.
  Reach is 7 m empty and 4 m at 8 kg. When a wall stands just in front of
  the spot, the aim tries higher lobs before it turns red, so the spot just
  behind the throw wall takes a steep lob over it. Released on gold, it
  flies, tumbles, lands by the reticle and stays.

## Tuning in round 7

- **Aim camera** (`bag_study._frame`): while aiming, the camera eases back
  (x1.45), a little lower, and about 24 degrees round to the side, looking
  between him and the reticle. Seen from the side, the arc reads as a curve.
  The reticle and arc have a faint pass drawn through walls, so a reticle
  behind the throw wall shows.
- **Lob:** the base rise went from 1.3 to 1.5 m. When the plain arc is
  blocked, the aim tries lobs 1, 2, 3 and 4.5 m higher (`AIM_LOBS`). The
  throw re-sweeps from where the bag really leaves his hands. The sweep's
  ball is now a little bigger than the sack (it was 0.6x, which let a
  "gold" throw clip the wall's back edge). From 2.5 to 3.5 m in front of
  the wall, the pocket is gold from about 0.4 m behind the wall's back
  face. Closer than that, the sack can't fit.
- **The bag overhead:** in the wind-up and aim it sits above his hat
  instead of behind it. The wind-up's chest lean and arm keys are pushed
  (16 to 22 deg, -200 to -215 deg). From the play camera the arms are
  still mostly under the hat brim.
- **Roll:** `ROLL_DRAG` went from 0.2 to 0.08. Shoved on the flat it rolls
  about 4.3 m. Down the slope it rests at x 34 (the foot is at x 28), by
  rock_a and curb_a.

## What's stood in

- The room is greybox. Loot is `scripts/carry/treasure_models.gd` models
  with study weights.
- The throw and shove poses are bone turns on the figure (chest and upper
  arms), not authored Blender clips. The drag arm is a single bone turn.
- Sounds: the thud and gulp are reused, and the "uh-uh" is synthesised.
- One bag. Spare bags, a bag from the plane and hitching it to the plane
  are not built (out of scope).
- No committed tests (prototype). The checks were throwaway drivers in
  `scratch/` (bag_fill, bag_drag, bag_roll, bag_aim, bag_tune).

## Open questions (from the user's play, for later)

These are recorded as questions, not answered.

- Rolling has no point yet: when he's wearing the bag, he slides down the
  slope faster than the bag rolls.
- Throwing has no point yet: the throw is short, and walking there is
  faster.
