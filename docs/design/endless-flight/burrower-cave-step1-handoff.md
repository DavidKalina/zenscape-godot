# Burrower to the cave, step 1

The burrower now lives by the cave mouths. Random sightings are gone. A plane
within 1000 m of an opening (`--burrower-near=M`, 700-2200), out on its open
side and flying within about 78 deg of the way in, finds him 240-420 m off,
off the nose, already running. Near him he keeps ahead of it along a route
(`burrower.gd` `set_route`): to a point on the sinkhole's axis 70 m past the
rim, up the axis, to 16 m from the opening. There he goes in (`plunge`) and is
gone, with no chase yet.

- One at a time. 45-75 s rest (`--burrower-every=S`), and each mouth once until
  the plane has been 1400 m from it.
- Left behind, he goes on to the mouth at his own pace and doesn't wait.
  Only a catch, a landing or a crash stops him short. Nothing he does opens or
  hides a cave.
- Past the rim nothing turns him aside. Before it he still steers round what
  stands and sounds at walls, coming up 70 m on along the route.
- Three orbs still come up on the way; they no longer end the run. The
  catch works on the way (he still slows under a surge roll).
- `plume` stays on while the plane is over 22 m above him: from height the
  ridge doesn't show.
- A look tries one spot a frame (`_try_spot`): all at once cost up to 90 ms on
  a loaded CPU on the GDScript land path.

Meet him: `--at=3400,4384 --heading=90 --alt=60` (mouth `1_1/a`, on its axis),
`--at=-1486,6874 --heading=56.7 --alt=80` (`-1_1/a`, from the side).

Next round: `burrower.gd` `plunge` is where the chase starts. Route points and
`Tunnels.at_s` are both plain xz lines. `BurrowerFlight._mouth` holds the mouth;
`Tunnels.mouths(t)` lists a site's two. Flown at 6 of the 8 openings; `-2_1/a`
and `/b` are unflown. The rest is in the round's report.
