# Round 4, k3: launch / carry (kit piece cards)

Lenses: verb = defend (one piece fends off or redirects an enemy without a
weapon); mood = sacred; shape among isles = a tall stack (isles over isles).

Sizes are in pilot terms: PilotMotor constants as `set_size` fits them
(`walk` 2.4, `run` 4.8, `jumps[0]` the plain jump 0.8, `jumps[1]` the pump
1.5, `gravity` 26, the long jump's reach about 4.2), RuinKit's Scale section
(`STAND`, `TOP_ROOM`, `SET_OFF` 1.6, `GRAB_TOP` 1.875, `CHAIN_TOP` 2.575)
and WorldScale. Metres in brackets are a reader's check at wanderer 1 only.
"Storey" below means one tier of a tall stack: 2 x `CHAIN_TOP` + `STAND`
(about 5.7), a rise no climb or jump takes in one go.

Not re-proposed: round 2's twenty (`well_sweep`, `haul_ferry`,
`bearing_stone`, `flue_well` and the rest). These four tie together:
the keystone (4) can't be climbed up a stack, so the pipes (3) and the
sally (2) are how it goes up, and the turnstile (1) bats it across a
floor.

---

# Ward Turnstile (relic_turnstile, family relic)
Verb: defend. Set the turnstile turning by running, sliding or kicking into
an arm. Its arms sweep an enemy off its line, or off the rim, and turn a
charging plinth ram aside. No weapon is involved.
Look: a pilgrims' gate-turn at the edge of a shrine precinct. It is a squat
drum hub carved with a ring of kneeling figures in low relief, under a
dull bronze cap. Four heavy stone arms stand out from the hub at chest
height, each one a squared beam with a worn bronze shoe on its tip. Round
it is a floor ring of slabs with a groove polished into it by centuries of
pilgrims walking it round. Lichen on the arms' tops, moss in the groove,
one shoe gone green.
Behaviour: moves (one axis, yaw), and the pilot drives it. A rest sits
still. Each shove adds to its spin along the tangent where he hit:
- a run into an arm's face adds 0.4 x his pace;
- a slide into it adds 0.6 x his pace;
- a wall kick off an arm's tip adds 0.4 x the kick;
- a slam onto an arm's top near its tip adds 0.25 x the "slammed" pace.

The tip speed is capped at `top`, `run` x 1.5. It loses `damp`, 25% of its
spin a second, so a full spin dies away in about 4 s. A spinning arm's
tell is a stone grind that rises with its pace, plus dust off the groove.
It never turns by itself. Knob `ratchet`, off by default, lets it turn one
way only (sacred: sunwise), so pushing against it stops dead.
Size: the tip radius is `reach`, `run` x 0.6 (about 2.9). Its sweep (two
reaches across) fills a precinct gateway on foot, and is no opening for the
plane: the hub's cap stands over WALL_TALL. The arm's top is at `SET_OFF`,
so a plain jump catches its lip and he climbs onto it. The arm's underside
is at about the pilot's chest (`SET_OFF` - 0.55). A slide passes under an
arm (the dodge), a standing walker is met at the chest, and a plain jump
does not clear it. The arm is `TOP_ROOM` wide. The hub is `STAND` x 2
across and its cap sits at `CHAIN_TOP` + `STAND`, a perch caught off an
arm's top.
Collision: the hub is a clean cylinder hull, wall-kickable. Each arm is a
clean box, `moving_ground` (pilot_physics_ground.gd `mover`): stood on, he
is carried round, and he leaves with its frame. The arm's tip face is a
WALL_TALL wall in the air only (it is under WALL_TALL from the floor), so
a kick off it works mid-jump. The floor ring is flat, true boxes. The plane
bumps the hub and the arms (ruin_bump.gd, a slab).
Motifs it enables:
- A shrine terrace at the top of a stack, the turnstile set in its only
  gate on the rim side. A ram that is lured through the gate in a charge
  is turned along the rim and over it.
- A stair landing midway up a tall stack with a turnstile across it. An
  inhaler head heaves up the stair, and each sweep grinds its face off the
  landing.
- A quiet precinct where the turnstile is only a gate you walk round, until
  something follows you in.
Catches / throws (source name "relic_turnstile" for all; the gate does no
harm, so it never calls `harm`):
- Standing (poised, on the floor in an arm's path): under `walk` at his
  point, `push_out` only (he is shoved round in front of it, no throw).
  From `walk` to `run`: `toss` along the tangent at the arm's speed at his
  point, plus a `jumps[0]` take-off up. Over `run`: `knock`,
  knock_velocity(tangent, out = arm speed x 0.6 s, up = `jumps[0]`).
  At `top` that is about 4.3 out (one long jump), a short tumble on the
  floor ring.
- Riding (stood on an arm): carried round as on any moving ground. A jump
  off keeps the arm's frame (the motor's `frame_v`), so a tip at `top`
  sends a long jump out at `run` x 1.5 flat pace plus his own. That needs no
  new throw code. No pace turns into height.
- Airborne: a pilot jumping into an arm is stopped by its face (a wall in
  the air, kickable), and adds his shove as above.
- Tumbling/stunned: an arm over `walk` meeting a stunned body gives it
  `toss` on along the tangent at the arm's speed. It stays stunned
  (`_throw_stunned`), and the restun lock is not touched.
- Enemies (the defend). The arm sets the enemy base's `vel`
  (scripts/enemies/enemy.gd, as `pilot_pushes` does) and `stun`s it:
  - Any enemy struck at `walk` or more is shoved along the tangent at
    arm speed x `push_carry` (0.85) and stunned `stun_knock` (1.5 s). Off a
    rim it falls as ever. The arm loses the share it gave (its spin x
    enemy mass over enemy mass + `mass`).
  - A plinth ram charging into an arm, spinning or still: the arm takes its
    blow (spun up toward `top`), and the ram's heading is turned onto the
    arm's tangent, up to 90 degrees. In "commit" or "skid" it keeps the new
    line blind, so a rim on that line is its "teeter".
  - The inhaler head is too heavy to shove. Each sweep at `walk` or more
    grinds it round one `notch` (its PIVOT, away from the arm), and in
    "inhale" a notch that takes its face off him breaks the draw back to
    "notice".
  - The headless body is swept at the shins: a stumble (`stun` 0.8 s), no
    shove.
- Loads (tumble stones, the keystone, kegs): tossed along the tangent at
  arm speed, with a `jumps[0]` hop.
Break kind: a registered cut, `turnstile`, toughness 0.8. `stands` is the
hub drum and floor ring. `parts` are each arm as a `slab` (kg 600, `TOP_ROOM`
x 0.55 x `reach`) and the bronze cap as a `drum`. A broken arm leaves a gap
in the sweep, and a turnstile with no arms is a perch.
Build cost: low-med. It is procedural from RuinKit.Build (drum courses, box
arms, slab ring), like the wind horn's pedestal. The spin is one float with
damping; arms are `moving_ground` as the seesaw's slab is. The new parts
are an enemy-side `swept(way, speed, source)` on enemy.gd, the ram's
heading turn and the head's forced notch (about 40 lines across three
enemies). No Blender model.
Model budget: silhouette geometry (chipped arm ends, the cap's broken
rim; the kneeling figures are a texture and normal detail, not geometry),
vertex-colour grime in the groove and under the arms, parallax depth for
the relief round the drum (it reads as carved at a walker's distance for
no triangles). Est. 2-3k tris. One draw call per material, under 0.05 ms.
Import LODs are not needed at this count.

---

# Sally Rope (belfry_sally, family belfry)
Verb: carry (himself, up a tall stack). Hang on a bell's sally rope and
ring the bell up. Each stroke hauls the rope higher, and when the bell
reaches the set, the rope has lifted him one storey to the rope hole in
the floor above, a lip he climbs out onto.
Look: a bell hung mouth-down from a wooden headstock and a big spoked
wheel, in an iron-strapped stone cage under the keel of the isle above
(or under the ringing floor of a belfry). From the wheel a rope comes
down through a rope hole cut in the stone floor, to a woollen sally of
faded red and cream bands at a walker's hands over the floor below, then
a tail. The rope hole is ringed by a worn bronze boss. The bell is
`belfry`'s own (BELL, BRONZE, VERDIGRIS) with the same dull green.
Behaviour: moves (the bell is a pendulum on one axis, and the rope's
height follows the wheel). Hanging on the sally (crouch held while the
rope goes down) pulls: PUMP, as the swing rope does, but only on the down
stroke. Each stroke swings the bell higher, and the sally rises higher on
the back stroke. From rest about four strokes (2 s each) bring the bell
mouth-up to the set: the rope stands at the top of its `draught`, and the
bell balances there `stay` s (1.5) on its old wooden stay, creaking. Then
it swings back and the rope runs down the whole draught in about 1 s.
The bell strikes on every stroke past 90 degrees: a "rung" event (and a
deep tone heard across the stack). Let go of, the bell swings down to
rest over about 8 s, ringing less and less.
Size: `draught` is one storey (2 x `CHAIN_TOP` + `STAND`, about 5.7). At
rest the sally hangs at a standing walker's hands (the swing rope's KNOT
rule). At the set his hands are HANG_DROP under the rope hole's lip, so he
hangs at a ledge and the motor's hang takes over: CLIMB_HOLD or Jump climbs
out. The rope hole is `STAND` x 3 across, so he and the rope fit. It is too
small for the plane, and the plane never meets it. The wheel's radius is
`draught` / (0.75 x 2π), so three-quarters of a turn is the draught.
Several sallies stacked climb several storeys, one bell per floor.
Collision: the cage is clean box hulls with a walkable top. The rope and
sally have no collision and are caught by reach (the swing rope's CATCH,
CATCH_BODY and RUN_IN). The rope hole's rim is a ledge with `STAND` of
floor behind it (RuinKit's `_stand_on` rule). The bell and wheel are
convex hulls that the plane bumps. The bell's swing does not reach any
floor he stands on.
Motifs it enables:
- A tall stack whose upper isle has no rim reachable on foot. A bell
  hangs from its keel, and its rope reaches down to a pit on the lower
  isle. Ringing up is the stair.
- A belfry tower of three ringing floors, each a sally to the next, the
  bells answering each other across the spires.
- A bell rung to lure: each "rung" is a sound the headless body's hearing
  takes (body_hearing.gd), pulling it to the bell pit while the pilot is
  already a storey up.
Catches / throws (source name "belfry_sally"):
- Standing: taken only by running into the sally (RUN_IN), as the rope.
  At the bottom of a down stroke a sally coming down at over `walk` onto a
  standing body is a `push_out`, never a knock.
- Airborne: caught as the swing rope catches (hands within CATCH). He
  rides (`hold` "swing", the motor's `rider`) and is lifted and lowered
  with the rope, its pace being his.
- Riding: Jump lets go with the rope's velocity at his hands (rising, up
  to `draught` per second, about 5.7, at mid stroke; falling, the same
  down) plus a small POP up. It is a `toss` with no timing boost: the
  rope carries, it doesn't launch. Crouch drops off. Still holding when
  the stay gives and the rope runs down, he is carried down with it. At
  the bottom of that fast stroke, holding on is fine; he is simply back
  where he started. At the set the hang hands him to the rope hole's lip
  (`release`, then the motor's ledge hang), so stepping off the top is a
  climb, not a throw.
- Tumbling/stunned: a stunned body falling down the shaft past the rope is
  snagged as the swing rope snags it (rides limp, the twirl arming the
  tech), and gets its poise back on it (`regain`) at the next stroke's
  top.
- Loads: the keystone (below) is carried up only on a laden pilot (a sally
  taken by RUN_IN, laden). Kegs and tumble stones aren't caught.
Break kind: a registered cut, `sally_bell`, toughness 0.8, after the bell
worked example in the break contract. `stands` is the cage and its iron
straps. `parts` are the bell as a `drum` (kg 900), the wheel as a `drum`
(kg 200) and the headstock as a `slab`. The rope goes slack and falls.
In a stack, the bell drops through to the isle below and is rubble there.
Build cost: med. The bell, cage and anchors exist in ruin_kit_belfry.gd.
The ride reuses swing_rope.gd's catch, hang, snag and regain with a 1-D
rope (height only) in place of the pendulum. The bell is a damped
pendulum with a one-sided pump and a stay. The new engine work is the
hand-off from rider to ledge hang at the set (`release` plus a forced
ledge catch) and a "rung" signal (round 2's tally: the bell sends none).
The wheel is a Blender model or procedural spokes. Procedural is fine.
Model budget: rigid parts on bones do not apply (no skin; the bell,
headstock and wheel are separate nodes on one pivot). Silhouette
geometry: chipped stone cage, wheel spokes as real geometry (they read
against the sky from below). The woollen sally is a short tube with
vertex-colour bands, not a texture. Import LODs and visibility ranges:
from the isle below the bell is seen up the stack, and a far copy is a bell
and a box (about 70% fewer tris). Est. 4-6k tris near, under 0.05 ms.

---

# Choir Pipes (horn_pipes, family horn)
Verb: launch (himself, a stunned body, an enemy, a load) up a tall stack:
stand on a pipe's mouth as its note sounds and it tosses you up a tier. A
rank of pipes of different lengths sound in turn on a slow cadence, each
throwing to its own height.
Look: the wind-horn builders' other device. A stone wind-chest, a long
low plinth of courses with a bellows lid sagged under ivy, and standing
out of it a rank of five tall carved stone pipes. Each is a ringed shaft of
staved courses like the horn's barrel, with its lip (the slot that sounds)
at its foot and an open top under a heavy iron grille worn bright where
feet stood. They step up in height left to right, like an organ's front.
No ornament glows.
Behaviour: launches, on a cycle. The pipes sound one note each in a set
`cadence` (default short to tall and back, a note every `beat` 1.6 s), so
any pipe sounds about every 13 s, and the rank is seen as a slow wave.
Tell (`tell` 0.6 s): dust flutters off the lip, a low hum rises in pitch,
and the grille rattles. Then the note: a `blow` of 0.3 s of air out of the
top. Knob `cadence` takes any order or a "held chord" (pairs together).
Knob `lean` (0 to 20 degrees) rakes the rank so its tosses carry across to
an isle above that is set out, not straight over.
Size: the pipe tops step by `SET_OFF` (the first at `SET_OFF` over the
plinth, the fifth at 5 x `SET_OFF`, about 8). The rank climbs on foot top to
top without the pipes. Mouth grilles are `STAND` x 3 across (room to stand
and to be missed). The pipe spacing is `STAND` x 4, a plain hop between
grilles. Each pipe's `lift` (the apex of its toss over its grille)
is one storey plus half its own length over the plinth, so a toss always
peaks over a storey above the pipe's top: pipe 1 lifts about 6.5, pipe 5
about 9.7 (its apex about 17.7 over the plinth).
The rank's foot needs WALL_TALL clear on each side for the hum and dust.
Collision: the plinth is clean boxes, a walkable top. Pipes are clean
cylinder hulls, wall-kickable (two pipes `STAND` x 4 apart are a kick
chimney). The grilles are flat, true boxes, walkable. The plane bumps the
pipes (slabs) and is not blown.
Motifs it enables:
- The foot of a tall stack whose next isle overhangs. The rank stands
  under its rim, and the tallest pipe's note throws him up past the rim to
  land on its turf (with `lean`).
- A stair of isles going up in a spiral, a rank on each, each toss
  catching the next rank's top grille: a hymn climbed.
- A choir loft on a mid tier where a ram is lured onto a grille and the
  note puts it in the air and over the edge.
Catches / throws (source name "horn_pipes"; the pipes do no harm, so they
never call `harm`):
- Standing (poised, on a sounding grille): `toss` straight up (raked by
  `lean`) at sqrt(2 x `gravity` x `lift`), about 18.4 m/s for pipe 1 and
  22.5 for pipe 5 (the pump's take-off is about 8.8), his flat pace kept. It is a toss, not a knock: the sail
  is ready, the twirl and wall run fresh, and he steers a little. A miss
  (no isle at the apex) is a fall of `lift` plus whatever the rank stands
  on. Every pipe's miss is past the fall stun, and pipe 5's is past
  FALL_HURT_PUMPS, so the sail is the answer.
- Airborne over a sounding top (within `STAND` x 1.5 and under a pipe's
  length over it): his upward pace is set to the toss's if it is lower.
  A jump timed onto a note is the same as standing on it, and a fall
  through a note is caught and thrown back up.
- Sailing: the sail is not tossed (it would tear). The note is an updraft
  through `air_at` (thermal `run` x 1.0 for the `blow`) that lifts the
  open sail a storey, gently.
- Tumbling/stunned: `toss` up as standing; it stays stunned
  (`_throw_stunned`) and gets its poise window again on the way up, so a
  knocked body that lands on a grille gets another chance to recover in
  the air.
- Enemies: an enemy on a sounding grille is given the toss's velocity on
  its `vel` and falls as stone. A plinth ram is thrown up, tumbling, and
  lands where its pace takes it: over the plinth's edge, off the tier.
  The inhaler head is too big for a grille. Heaved onto one, it chokes the
  pipe (that note is silent; the grille rattles), and the other pipes
  sound louder.
- Loads (kegs, tumble stones, the keystone): tossed as standing. Pipe 2
  set under a keystone is how it goes up a stack.
Break kind: a KIND_OF line, "horn_pipes": "pier". Each pipe cuts at its
courses as a pier does (RuinKit `keep_only`, from its `kit_piece` recipe).
A broken pipe is silent, so the cadence has a gap where its note was, and
its stump is a lower grille-less step.
Build cost: med. It is procedural from RuinKit.Build and the horn's stave
rings (ruin_kit_horn.gd). The toss is one `motor.toss` with a vertical
speed. The cycle is a timer like trap_wind's "vent" mode, and the sail's
draft goes through `push_air`, as the wind does. The new engine work is
an enemy-side `launched(v)` on enemy.gd (its `vel` in the air under
gravity, then "stun" on landing) and a "choked" test for the head. No
Blender model. The hum is a synthesized tone per pipe, like the sluice's
rumble.
Model budget: silhouette geometry (broken staves on the pipes' tops and
lips, flat faces textured), vertex-colour grime down each pipe from the
lip, parallax depth for the grilles' holes (a flat plate with depth, not
modelled bars). Import LODs and visibility ranges: the rank is seen from
tiers above and below, and a far copy is five cylinders and a box (about
85% fewer tris). Est. 5-7k tris near, under 0.06 ms.

---

# Keystone (relic_keystone, family relic; its seat is meta on an arch)
Verb: carry, to change the place. Lift the carved keystone off its plinth
and bring it to a broken arch's crown. Set there, it mends the arch, so the
stones rise back into place and a broken span is a walkable deck across
the gulf again. Laden, he can't climb, so getting it up a stack takes the
pipes or the sally.
Look: a wedge of pale dressed stone a head taller than the pilot is wide,
carved on its face with a worn halo and a hand raised in blessing. It lies
on a low plinth of three courses with a matching wedge-shaped socket on
top, and is chipped at its corners. The seat is the gap at a broken
arch's crown, where the two broken ends of the arch ring stand out over
the void with a wedge-shaped notch cut between them. The voussoirs and deck
slabs that belong there lie as rubble on the isle below in a stack, or are
gone in the void.
Behaviour: changes state (the arch). It carries like the cannon's kegs:
touched, it is picked up and hovers behind his shoulder
(scripts/carried_follow.gd). Carried, he is laden:
- no sail, twirl, ledge catch, wall kick or wall run;
- jumps at `jumps[0]` only (no pump);
- run at `run` x 0.8.

Crouch on the ground sets it down where he stands; it lies there as a body
and is picked up again by touching it. Carried within `STAND` x 2 of a seat
(standing at the broken end of the deck, facing the gap), it is set. It
slides out of the hover into the notch with a grinding settle. Then over
`mend` (3 s), with a low hum, the missing voussoirs and deck slabs rise
from below on curved paths and lock in, from each broken end in toward
the crown. The span is whole: a deck `TOP_ROOM` wide or more,
`moving_ground` only while it mends. Knob `hold` (default off): the mend
lasts until the keystone is taken out again (touching it in the seat lifts
it out, and the span falls as a break). With `hold` on, the mend lasts for
good.
Size: the keystone is `STAND` x 2 tall in the hover (it rides behind his
head and never blocks his view). The seat's gap is the broken arch's
span, 2 to 3 long jumps, which no unaided jump or laden walk makes. The
mended arch is an aqueduct span's or an arch's own size, so its opening is
the piece's own `opening` (ARCH_SPAN, THREAD). Mending never narrows a gap
the plane flew before, because the arch's opening is under the mended
deck, not in it.
Collision: the keystone on its plinth or lying set down is a convex hull,
light (kg 120), a body the turnstile, pipes and tumble stones move. In the
hover it has no collision. The mended deck is clean boxes, walkable. The
seat's broken ends are ledges with `STAND` behind them before and after.
Motifs it enables:
- A tall stack where the keystone lies on the bottom tier and the broken
  bridge is two tiers up. The pipes toss it (pipe 2, set down on the
  grille) and the sally carries him laden, so getting it up is the climb.
- A cloister whose broken arch, once mended, is the only way onto the
  gallery roof, with a second seat on the far side of the gulf for the
  same keystone. Mending one breaks the other.
- A shrine where the keystone lies at the turnstile. The arms bat it to
  the rim if it is set down in their sweep.
Catches / throws (source name "relic_keystone"):
- Laden, knocked (by anything): the keystone falls out of the hover with
  his throw's velocity x 0.5 and a `chunk`'s tumble. It is not destroyed.
  Lost into the void, it re-forms on its plinth after `return` (4 s) with a
  dust puff. Laden, tossed (a pipe, a turnstile's toss, a ride): it stays
  in the hover. A laden toss is the only way he takes it up a tier, apart
  from the sally.
- Set down (a body): tossed and shoved by the world as any load (turnstile
  arms, pipes, the seesaw's `loads`, a gust's push); it never stuns
  anything (a soft relic, kg 120, `toss` only).
- Standing / airborne / tumbling on the mended deck: plain ground. While
  it mends (rising slabs), a slab rising under a standing pilot is
  `moving_ground` and lifts him into place. A slab rising into him from
  the side does a `push_out`, never a knock.
- It throws nothing itself.
Break kind: the mended arch is the arch's own kind ("arch" or "slab" via
KIND_OF; for `aqueduct_broken` its mended rebuild Callable, `kit_breaks.gd
add`). A slam or the olmec breaking a mended span knocks the keystone out
as a `chunk` part that goes home after `return`. The keystone alone is
unbreakable (toughness INF), and so is its plinth (a dressing `slab`).
Build cost: med-high. The keystone and plinth are low (RuinKit.Build
wedge and courses). The carry reuses carried_follow.gd and the cannon
field's touch pickup. The cost is in two things. First, a "laden" state
on the motor that turns off the sail, twirl, catches and pump; it is new,
but only flags. Second, the mend: rebuilding a broken span whole with its
missing stones flown in from rubble positions, reversing the break's
`keep_only`, and the arch's whole and broken builds swapped under a tween.
The motif editor needs a linked handle (keystone and seat) to place it,
which round 2's tally already calls for.
Model budget: sculpt high, bake low for the keystone's carved face (the
halo and hand read up close as it hovers by his head, about 1.5k tris
with a baked normal map, against about 40k sculpted). Silhouette geometry
on its chipped corners. Vertex-colour grime on the plinth. The mend
uses the kit's own span meshes, so it adds nothing to the budget. Est.
under 2k tris for the piece, under 0.02 ms.
