# Handoff: the whale reveals a find (prototype, 2026-11-14)

Lane `reveal-whale`. Not locked in, so there are no committed tests.

## How often you saw the whale before

- The whale (`whale.gd`) is staged only when the plane is under 35 m over
  the sea, at 0.75 of cruise or faster, with the sea bed 20 m or more down,
  for 8 s. On top of that: 150 s into the flight at the earliest, a 0.35
  roll (a lost roll waits another 45 s of open sea), a spot 360 to 760 m
  ahead with deep water all round it out to 450 m, and then 600 s of
  cooldown.
- That caps it at one whale per ten minutes. A coastal flight above 35 m
  never meets it.
- Within 6 km of the start, 51 cells of a 250 m grid are fit. The nearest
  are 2.7 km north-east, in the bay north of the stacks.
- Best case, measured: skim that bay at 12 m, flat out, for ten minutes
  (`--whale-home=0`). Three sweep runs got one whale each (556 s of open
  sea). A timed rerun got it at 306 s, after about 30 spots were refused
  for shore.

## What's built

- `scripts/endless/whale_home.gd`: the whale's home water. `whale.gd` creates
  it and steps it (+12 lines). While the home holds the whale, the open
  sea's roll waits.
- The tell: when the plane is within 2.4 km of the bay, the whale lies at
  one of 7 fit spots. It blows every 5 to 8 s (the clip's blow at 3x, plus
  foam and a ring), and a dark shape sits under the water (the sea's
  `swimmers` slot).
- It surfaces when the plane comes within speed x 13 s (220 to 480 m) and
  is under 220 m, swimming away from the plane. Left alone, it surfaces on
  its own after 90 s. That clock only runs while the plane is more than
  1.3 km off.
- After surfacing it rests 75 s, then lies at another spot.
- Its back up with the plane within 450 m: `finds.anchor("whale/home", p)`
  sets the ring 10 m over the water where it first blew. The ring stays for
  the flight. If the plane was far, nothing appears, and the find waits for
  the next time it surfaces.
- Two rows in `finds_table.gd` (area coast):
  - `whale-ring` (relic).
  - `whale-tail` (event `whale/tail`). It fires on the whale's own near miss
    of the tail. It came nearly free.
- Flags: `--whale-home=0`, `--whale-home-wait=S`, `--whale-home-rest=S`.

## How to meet it fast

From the start, head north-east toward the stacks and keep over the water
north of them. The first blow shows about 13 s out. Fly at the spout, under
220 m, and it comes up about 45 to 55 s after takeoff.

## Open

- From 1.4 km the tell is a small white puff. The dark shape doesn't read
  from flying height. A taller or longer-lasting spout, or seabirds, could
  help.
- The ring stands about 31 m short of where the tail goes up, so a straight
  run takes the ring and then the flukes.
- No sound for the tell.
- The ring's spot isn't saved. Reload before you take it and it waits for
  the next surfacing. A ring already taken stays taken.
- The lake fish and the whale still share the sea's `swimmers` slot.
- Everything was driven, not hand-flown, so the feel is unverified.
