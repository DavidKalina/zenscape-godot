# Kit brainstorm K1: things the pilot grabs and climbs (family `makers`)

A new family, `makers`: the Olmec makers' own building, the kit the coverage
says is missing. Where the gothic kit is many small coursed blocks (piers of
shafts, arches of voussoirs, walls of courses) that weather by falling apart,
the makers built in **few huge monoliths**: rounded, heavy, smooth-shouldered
basalt, carved in low relief and deep-cut rune grooves, and it weathers by
wearing and being swallowed by roots. All of it wears the Olmec's own stone
(`shaders/olmec_stone.gdshader`, `weather` ~1.0, `runes` on for the grooves),
and only a few pieces carry the Olmec's pale polished eye. Next to the gothic
kit it reads as older and stranger: the abbey was built on top of these. Its
climbs are the gothic kit's numbers (RuinKit STAND, SET_OFF, GRAB_TOP,
CHAIN_TOP; the tower shell's KICK_GAP), so the two families mix on one isle.
Each piece follows the kit contract: a Node3D with its foot on y 0, front +Z,
"Mesh" and "Body", and a stood-on or kicked face on a clean, true hull (as
`_walk_box` and the tower's kick walls do), never on the worn drawn stone.

The numbers below come from the code. Hang and climb, from
`scripts/pilot_motor.gd`: HANG_DROP 0.825, GRAB_LOW 0.25, CLIMB_IN 0.3,
SHIMMY 0.7 m/s, DROP_HOLD 0.12, REGRAB 0.4. Walls: WALL_TALL 1.2,
WALL_JUMP 1.4, WALL_KICK 5.2. Air: JUMPS [0.8, 1.5], TWIRL_RISE 2.8. Kit
sizes, from `scripts/ruin_kit.gd`: STAND 0.58 (CLIMB_IN + BODY 0.28),
TOP_ROOM 1.16, GRAB_TOP 1.875, CHAIN_TOP 2.575, SET_OFF 1.6, WALL_THICK
1.2. Kick shaft: KICK_GAP 1.98 at the defaults (`scripts/ruin_kit_tower.gd`).
Swing rope, from `scripts/interactables/swing_rope.gd`: LENGTH 5.6, KNOT 0.9,
GRAVITY 20, MOST 1.35, REGRAB 0.45, RUN_IN 3.0. Openings:
`WorldScale.opening(TOY_THREAD 3.5)` is 7.0 and `WorldScale.knife()` is 1.9
at the defaults.

One constraint shapes every card: `scripts/pilot_ledge.gd` finds a lip only
where ground that can be stood on ends in a drop, and the motor catches only
a lip with a top behind it (`_stand_on`). So a "handhold" here is always a
real shelf at least STAND (0.58) deep. A shelf that is meant to be walked
along is TOP_ROOM (1.16) deep. The pilot also has no hop from a hang. A
ledge chain is: hang, climb (CLIMB_HOLD or Jump), stand, jump, catch the next
lip at most GRAB_TOP above the shelf. Going down is faster: let go (DROP_HOLD)
and the hands catch the lip below on the way past.

Grab pieces are the **catchers** in the chain (the brief's "Everything
chains"). Today's rules, from `pilot_motor.gd` and stun-round1.md, decide
what a grab piece can catch:
- A tumbling body catches no lip until its poise returns: `poise_for(v)`
  is 0.5 s plus 0.04 s per m/s of the blow, capped at 1.2 s. After that,
  falling past any shelf catches it as usual. So a tall face of stacked
  shelves is a net, but only for a body that has fallen long enough.
- With `tech` on (it is off by default), a twirl pressed within
  `tech_window` 0.2 s of meeting a lip in reach catches it mid-tumble
  (`_tech_grab`, "teched" "ledge"), whichever way he faces or flies. Every
  shelf here is a tech target for free. A wall face catches a tech the same
  way: he kicks off it.
- A swing rope refuses a tumbling body: `swing_rope.gd` line 192 returns
  if `move == "tumble"`. So a piece that snags a ragdoll needs something
  new. The tool exists in `seize()`, which the inhaler head uses to swallow.
- A rope let go is a `toss`: a fresh airtime, not stunned. A `toss` of a
  stunned body throws it still stunned. A `knock(v, source)` stuns, unless
  the same source stunned him within `restun_gap` 1.2 s, in which case it
  only throws him. After `stun_chain_cap` 3 s stunned in a row, any press
  breaks out.

So different pieces hand a body to each other freely, while one piece
can't juggle him. In each card, "source" means the piece instance that
passes itself to `knock`.

---

# Sleeper's Face (maker_face, family makers)
Verb: climb. It's a colossal makers' head sunk to the chin in rock, built
as terrain: a slow lip chain up its features, a fast kick chimney beside its
cheek, and its breath as hazard and lift.

Look: the inhaler head's own face (heavy lids, broad flat nose, down-turned
thick lips, helmet with a banded brow and ear flaps), at terrain size and
buried to the lower lip in a crag or an isle's rim. It stands upright and
does not hover. Roots come down over the helmet, and moss sits in the eye
sockets and on the lip shelves. The eyes are almond-shaped pale polished
stone (the serpent's `rs_eye` look) and glow faintly until you are on the
face. This is the Olmec as ground: the player may wonder whether the
floating heads were cut from faces like this.

Behaviour: it changes state on a breath cycle, and only while the pilot is
within about 12 m of its face (the eye lights to the Olmec's lock-on glow, as
the head does).
- Inhale (2.0 s): a draw toward the mouth through the `air` wind field. A
  climber hanging below the lip is pulled flat against the face, so the
  inhale helps the climb.
- Hold (0.6 s): this is the tell. The lips tighten and dust spills off the
  shelves.
- Exhale (0.8 s): a gust out along +Z in a band SET_OFF above and below the
  mouth. It `knock`s a hanging or standing pilot off the shelves in that band.
  Above and below the band he is safe.

Then it rests for 3 s. The sequence knobs set the period (6.4 s, down to 4).

Size: every feature shelf is one stage of a climb. Each rises SET_OFF 1.6
over the last, which is under GRAB_TOP 1.875, so one plain jump catches it.
Each is at least STAND 0.58 deep (0.7 drawn, worn round at the arris but
with a true box under it):
- chin, 1.6
- lower lip, 3.2: TOP_ROOM deep, the rest shelf
- cheekbones, 4.8, left and right, joined by the nose's bridge
- brow band, 6.4: a continuous lip round the face that bends gently. It is
  the shimmy route (SHIMMY 0.7 m/s, so about 10 s across a 7 m brow; slow,
  which is the point).
- helmet crown, 8.0, TOP_ROOM and more

Everything else on the face is steeper than SLIDE_AUTO, so nothing can be
stood on where it shouldn't be. Between the cheek and each ear flap is a
slot KICK_GAP 1.98 wide with flat faces. That is the fast way up: kick
straight to the crown in about four kicks (WALL_JUMP 1.4 a kick), the tower
shell's chimney in the makers' dress. The mouth is a dark slot on the
lower-lip shelf, about 1.4 m wide and 0.8 m tall. It is not flown. It
swallows, as the inhaler head does.

Collision: the shelves are clean walk boxes, and the cheek and flap faces
are clean kick hulls (WALL_TALL 1.2 and much more). The rest of the face is
a few convex hulls kept steep. The eye sockets are not ledges: the hull is
filled flush there.

Motifs it enables:
- A crag isle whose summit is the head: the safe way up is the lip chain
  across the breath band, the quick way is the ear-flap chimney.
- A ring of three buried faces looking inward over an arena. Their breaths
  cross, and a pilot sailing in the middle rides whichever exhale is on.
- A broken face sheared off at the nose, so the brow is a cantilevered
  shelf over the void (a perch socket).

Threat pairing: the exhale clears the shelves in its band, so the climb is
a timing climb: hang below the band during the exhale and pass through it
on the inhale. It is also a tool. A pilot who opens the pocket sail in front
of the mouth during the exhale is blown out and up (a thermal share in the
`air` answer), reaching the next isle. The inhale pulls enemies (Cairnling,
Plinth Ram) off the lower lip into the gulf. Sharing the breath with the
inhaler head means its pull and push already exist.

Catches / throws:
- **Standing or hanging** on a shelf in the breath band: on the exhale,
  `knock(v, face)` throws him straight out along +Z at about 6 m/s, up
  2 m/s.
- **Riding the sail** in front of the mouth: the exhale lifts him (an `air`
  thermal), and he is not stunned.
- **Airborne or tumbling into the mouth during the inhale**: swallowed. The
  face calls `seize()` and holds him inside for the hold (0.6 s). On the
  exhale it spits him: `knock(v, face)`, with `v` from
  `knock_velocity(away, out, up, drop)` so it lands where the motif points
  it.
- The spit is aimable by two knobs: its pitch, and its reach (`out`). Its
  heading is the face's own +Z, which the motif sets when it places the face
  on its isle; the generator never turns isles.
- An example spit: 20 m out and 4 m up is about 20 m/s flat and 14 m/s up,
  about 1 s in the air. Its poise is capped at 1.2 s, so he arrives still
  stunned. The spit lands a ragdoll on the next link, or into a second face's
  inhale.
- Face to face chains freely, since each face is its own source. The same
  face swallowing him again within 1.2 s only throws him on, and the chain
  cap lets the player break out after 3 s.
- **Tech**: every shelf is a lip, so a pilot knocked off the brow can tech
  onto the cheekbones or the lip on the way down.

Chains with:
- In: the inhaler head (its blow-out, aimed at this mouth); the wind
  blaster; a seesaw's or rope's launch into the inhale; the Holder's
  captive knocking a climber off.
- Out: a second Sleeper's Face (the spit relay); a seesaw at the foot,
  where a ragdoll lands stunned and is launched on, still stunned, with a
  fresh poise; a Root Curtain under a cantilevered brow, which snags the
  spat body; the Sky Ray passing, where a floor tech on its back latches
  him.

Build cost: high. It needs a Blender model (the inhaler head's face resculpted
as terrain, at least 9 m tall), hand-placed shelf boxes and kick hulls that
match the sculpt, and a breath driver reusing the wind trap's `air` answer.
The breath and the eye can be cut from a first version: the static face
alone is medium cost.

Model budget:
- Sculpt high, bake low. This applies most: a face this big wants a 6-10k
  mesh with baked normals and AO (perhaps 60-80k triangles saved against a
  sculpt-direct mesh, at no real frame-time cost).
- Silhouette geometry: only the nose, lips, brow and flaps break the outline.
- Vertex-colour grime: in the shelf undersides and eye sockets, which the
  olmec shader already reads as alpha.
- Import LODs, for the face seen across a layer (about 0.1 ms saved with
  three faces on screen).
- Parallax depth: rune grooves on the helmet band.
- Rigid parts on bones: not applicable.

---

# Basalt Palisade (maker_palisade, family makers)
Verb: climb by pillar-hopping and chimney kicks, with one column that
topples into a bridge. It's procedural: it rhymes with the stone circle and
fills a different gap.

Look: a fence of natural columnar basalt laid upright and side by side. It
is La Venta's column-tomb, so the "fence" was once a tomb wall. The columns
are hexagonal (some pentagonal), dark and almost black under the olmec
shader's lichen, packed in a ragged line or a horseshoe. Some have fallen
and lean on their neighbours. The tops step in height like organ pipes.
Strangler roots knit the bases together. A few column ends carry a single
deep glyph.

Behaviour: mostly static, plus one rocking column a piece (knob, 0 to 2).
- It stands on a rounded foot. Landing on it tilts it toward the
  pilot's side (seesaw-trap kin): a dust puff and a grind are the tell.
- After 1.5 s with weight on it, or at once when slammed, it topples the way
  it leans. It falls onto the next column or across a gap and stays as a
  sloped beam.

Size:
- Tops: hexagons TOP_ROOM 1.16 across the flats or more (1.3 drawn), so a
  landing has room.
- Heights: from 1.6 to 8 m. Each neighbour is within SET_OFF 1.6 of the
  next, so from any top the next is caught with one jump. A step of
  CHAIN_TOP 2.575 appears only where a pump from a wide top is meant.
- Gaps between tops: 0.4 to 1.5 m, so a standing jump clears them.
- Chimneys: wherever two tall columns face flat-to-flat, they are set
  KICK_GAP 1.98 apart. Kicks then run up them as in the tower shell.
- Toppled column: lies at 15-20 degrees. That is under SLOPE_SLOW 22, so it
  can be walked up, and over SLIDE_FROM 10, so crouch surfs down it: a rail
  slide back to the ground.
- Horseshoe form: its mouth is `WorldScale.opening(TOY_THREAD)` (7.0) wide,
  so the plane can fly into the court.

Collision: each column is one true hexagonal prism hull, with no chips on
the hull (chips are drawn only). The top is the prism's own face. The
faces are kickable wherever they stand WALL_TALL 1.2 clear. The leaning and
fallen columns are true prisms on a slope. The rocker is a RigidBody3D
or an animated body with a single hull.

Motifs it enables:
- The tomb court: a horseshoe of columns round a sunken stone sarcophagus.
  You climb the columns to its single tall glyph column (a perch) and see
  the rune ledger's clue on its top.
- The organ: a line of columns rising along an isle's rim, climbed as a
  stair, with two rockers that turn it into a ramp when they go.
- A floating raft of five columns bound by roots: a stepped islet (a
  bridge piece between isles).

Threat pairing: the rocker throws a careless lander into the gap. Toppled on
purpose, it is the bridge to a top that was out of reach, or it falls across
a Plinth Ram's lane and knocks it off. The gaps between columns are also a
Cairnling's hiding place.

Catches / throws:
- **Tumbling or downed** on a column top: the tops are flat true faces, so
  a ragdoll that lands on one is laid down there instead of in the gap. The
  palisade is a stepped catch-net for anything thrown over it.
- **Tumbling past a column face** with the tech armed: the face catches a
  tech, and he kicks off it (WALL_KICK 5.2). Between two columns KICK_GAP
  apart, that kick carries straight into the chimney.
- **Falling past a top edge** once poised, or with a tech: the top is a lip.
  The tops are TOP_ROOM wide and so always `_stand_on`.
- **The rocker** carries a grounded body, as the seesaw does, so a downed
  ragdoll's weight tips it as a lander's would. When it topples, a body on
  it is thrown by `toss`, along the fall, at the column top's speed: about
  4-7 m/s for a 4-8 m column, and up a little. A stunned body is thrown
  still stunned, with a fresh poise.
- The topple is aimable. Its lean (and so its fall direction) is fixed by
  the piece's yaw on the isle and a knob, so the generator can point it at
  a gap, a lower isle or a seesaw.

Chains with:
- In: the Sleeper's Face spit and the wind blaster, which throw ragdolls
  onto the tops; the Plinth Ram, which charges a column foot (a ram strike
  on the rocker topples it at once).
- Out: a toppled rocker throws onto a seesaw, a Root Curtain or into the
  logs trap's lane. A fallen column becomes the tumble trap's ramp. A
  chimney top leads to a Holder's shoulder.

Build cost: low. It's procedural (`Build.solid` prisms with the olmec
material, weathering cuts, the kit's existing growth), plus one rocking body
in the seesaw trap's manner. No Blender work.

Model budget:
- Silhouette geometry: the chips on the column ends and arrises are the
  read. The flats stay plain.
- Vertex-colour grime: in the joints between packed columns (no triangle
  cost).
- Visibility ranges: for distant copies when a layer places several
  palisades.
- Import LODs: not applicable to procedural meshes, since a prism is already
  about 20 triangles.
- Sculpt and bake: not applicable.
- Saving: next to nothing per column (it's already cheap). The draw-call
  saving from merging the whole palisade into one "Mesh" is the real one.

---

# Glyph Register Wall (maker_glyph_wall, family makers)
Verb: ledge-chain across and up, reading as you climb. It's a wall of
carved cartouches standing out in rows, where the protruding glyphs are the
handholds and the wall is still a calendar that turns.

Look: a long, slightly battered (inward-leaning) wall of big smooth basalt
panels. Across it run registers of square cartouches in deep relief. Each
cartouche is a block standing proud of the wall, with a rune sign cut into
its face as lit grooves (the serpent's runes, `runes` on). The registers are
staggered like brickwork, so cartouches climb diagonally. Roots fall in
curtains over parts of it and hide some cartouches. At its head is a heavy
rounded coping, and at one end a seated maker figure in a niche (the La
Venta altar pose) holds a carved rope that runs into the wall.

Behaviour: the wall is static, and each register can be live (knob 0 to all).
- On a live register, cartouches turn in and out on a slow calendar cycle:
  one at a time, each sliding into the wall over 0.8 s, holding there 2 s,
  and sliding back out.
- The tell: grinding, and a pale ring of dust round the cartouche that is
  next.
- A pilot hanging on, or standing on, a cartouche as it goes in loses the
  lip and falls. He catches the lip below on the way down, if it is there.

Size:
- Cartouches stand STAND 0.58 proud (0.65 drawn), are 1.2 m wide, and each
  top is a true box, so each is hung from, climbed onto and stood on.
- Registers sit SET_OFF 1.6 apart, so from a cartouche's top the one above
  is in GRAB_TOP 1.875.
- The stagger is half a cartouche, so the next one up is offset about 1.2 m
  across. That is a standing jump with a diagonal stick, to be tuned in the
  study. Where the offset is wider (a missing cartouche), a twirl
  (TWIRL_RISE 2.8, TWIRL_PUSH) carries it.
- Some registers are joined into a continuous band, TOP_ROOM deep, which the
  pilot walks or shimmies along (SHIMMY 0.7 m/s). Shimmying stops at each
  band end (`pilot_ledge` stops where the lip ends).
- The wall is WALL_THICK 1.2 thick, 8 to 12 m long, and 4 to 5 registers
  high (6.4 to 8 m).
- The face between cartouches is a clean, plain hull, so wall slides and a
  kick back off work under any lip.

Collision: one clean box hull per cartouche and one for the wall face. The
batter is under 5 degrees, so the wall face still answers `wall` as
upright. The root curtains have no collision; they only hide things.

Motifs it enables:
- The calendar court: four glyph walls round a square, each register
  turning in its own rhythm, and the climb to the coping is a reading of
  the four.
- A glyph wall along a cliff's face where the isle is only its top: the
  route up from the lower isle is the wall.
- The fallen register: a glyph wall toppled flat and broken, its
  cartouches now a field of low stepping blocks (dressing and cover).

Threat pairing: the turning cartouches are the threat (lips that leave),
and also a tool. A cartouche sliding back out shoves whatever stands on the
wall face in front of it off the wall: a throw out over the drop, and the
quick way down to the isle the wall faces. A cartouche turning in under a
Cairnling or a Gong Toad drops it. A root curtain hides a dead cartouche, so
the player who looks first (binoculars) climbs safe.

Catches / throws:
- **The wall is a vertical net.** Each register is a lip every SET_OFF 1.6,
  so a body falling down it once poised catches the first lip below. With
  the tech on, the twirl catches any cartouche in reach mid-tumble.
- A plain poise rarely saves him on this wall. A fall from 8 m (5
  registers) takes only about 0.65 s at GRAVITY 26 times FALL 1.5, which
  is less than an 8 m/s knock's 0.8 s poise. So on a wall this short, the
  tech is the catch. A wall used as a net wants extra height under it (a
  cliff face, below).
- **A cartouche moving in** drops whoever hangs on it or stands on it. That
  is a fall, not a knock, so he catches the register below as usual.
- **A cartouche thrusting out** (the calendar's return, 0.4 s, quicker
  than the turn in) throws a body in its path or standing on the band
  beside it. It uses `toss`, along +Z and up: about 5 m/s out and 3 m/s up,
  a knob. A stunned body is thrown still stunned, so a ragdoll slid down
  against the wall is flung off it. Since it is a `toss`, a standing pilot
  is thrown, not stunned: rideable on purpose.
- The throw is aimable by which cartouche (its height) and the thrust
  knob. The heading is the wall's +Z.

Chains with:
- In: a Sleeper's Face spit into the wall (caught by tech on a
  cartouche); the Holder's chain release, whose long swing reaches high
  registers.
- Out: a thrust cartouche throws onto a Basalt Palisade's tops, a seesaw,
  or into a Root Curtain hung from the coping. The sluice flush pours down
  the wall face and washes a hanging pilot off a register. The Spindle hung
  under the coping uses its thread as the reel across the registers.

Mystery: the signs on the cartouches are the rune ledger's signs. The seated
figure's carved rope ends in the register that never turns.

Build cost: medium. The wall and cartouches are procedural (`Build.solid`
blocks, the serpent's runes for the cuts). The calendar driver is new but
simple (animatable bodies on a timer). A rune decal or shader input per
cartouche is needed. The seated figure in the niche is a Blender model, but
optional; it's dressing.

Model budget:
- Parallax depth: for the cartouche signs, rather than cut geometry (about
  200 triangles a sign saved, perhaps 10-20k a wall).
- Silhouette geometry: only the cartouche blocks and the coping's breaks.
- Vertex-colour grime: under each cartouche, where rain doesn't reach.
- Sculpt high, bake low: the seated figure only, 3-5k.
- Rigid parts on bones: not applicable (the cartouches are bodies, not
  bones).

---

# Holder's Chains (maker_holder_chains, family makers)
Verb: ride (swing) and counterweight. It's a squat stone idol on a rim
holding two chains out over the void, threaded through its fists, so
riding one down lifts the other.

Look: a seated makers' figure (a broad, headless-body build, but sitting,
massive and calm) on a throne-altar block at an isle's rim. Its two arms are
held out level like a ferryman's, fists closed round iron chains that run
over its shoulders through a worn groove. At one chain's foot is a
grabbable knot ring. At the other's is a carved captive, a curled stone
figure tied in rope relief, about 1 m across, hanging as the weight. The
iron is rust-stained down the stone. The idol's eye socket on its chest
(it's headless, like the body) is the pale almond.

Behaviour: both chains are swing ropes, the rider of `swing_rope.gd` in a
heavier chain look, and they're coupled.
- The pilot's weight on the ring chain pays it out: the ring lowers at
  0.8 m/s, up to 2.4 m, and the captive rises the same amount.
- Let go, and the captive's weight draws the ring back up over 3 s.
- While the ring chain is paid out, the rope length grows from 5.6 to 8 m.
  The pendulum slows and its launch lengthens. Riding the long chain is
  the way to the far isle.
- The captive is the hazard. Raised, it swings free as a censer pendulum
  (trap idea 3) across the rim stair it now hangs over. At the bottom of
  its arc it stands as a 1 m block that `knock`s.

Size:
- Chains: LENGTH 5.6 from the fists, so the knot ring hangs at KNOT 0.9
  over the throne deck. RUN_IN 3.0 takes it running off the deck.
- Arms: at deck + 6.5, so the ring hangs at the walker's hands. The fists
  are 3 m apart either side of the idol, so the two chains never cross.
- Throne deck: TOP_ROOM and more on every side.
- The idol: 4.5 m seated, its knees two SET_OFF stages (1.6, 3.2). Its
  lap and shoulders are shelves (STAND and more), so the pilot can climb the
  idol itself to its shoulders and drop onto either chain from above.
- The payout's 2.4 m is under CHAIN_TOP 2.575, so a raised captive is still
  a catch from the deck: a pumped jump onto its back.

Collision: the idol is a few convex hulls, with its knees, lap and
shoulders as clean walk boxes. The chains are not collided (the rope rider
handles them). The captive is a moving body with one hull: the
pendulum's shove volume.

Motifs it enables:
- The ferryman's rim: the only crossing to a satellite isle is the long
  chain at full payout. Someone must make the captive rise, and the captive
  then swings over the way back.
- Two Holders facing across a gulf. Ride one down and the other's captive
  rises into reach as a stepping stone.
- An idol on a hanging underside, holding its chains down into the void
  under an isle: a swing beneath the floor.

Threat pairing:
- The captive's swing guards the rim stair once a chain is ridden: the
  tool you use arms the trap.
- Riding the captive itself (hop on at the apex, as the censer's speedrun
  note says) is a second crossing.
- Gnaw rats chew the ring chain's wrapping (rope rats on iron: they chew the
  binding cloth at the fist, and the chain slips 1 m at a time).
- A slam on the captive when it's raised drops the ring hard. A pilot on
  the ring is jerked down and launched off the bottom, a bigger launch
  than any pump.

Catches / throws:
- **Running or airborne into the ring**: taken as a swing rope (RUN_IN 3.0,
  CATCH 0.3).
- **Tumbling into the ring**: refused today, since the rope rule turns away
  a tumbling body. With the Root Curtain's snag hook (below), the ring
  could snag a ragdoll too. That is a knob, off by default, so the Holder
  stays a skill piece.
- **Letting go** is the rope's release: `toss` with the swing's velocity,
  BOOST 6.0 for a release timed within WINDOW 0.5 rad of BEST 0.75 rad past
  the plumb, POP 1.5 up, capped at TOP 24.
- The long chain at full payout (8 m, against the 5.6 m rope's launch of
  about 18 m/s and 19 m out) throws further. It is aimed by the player
  steering the swing plane (STEER 3.0), round the direction the arms point,
  which the motif sets.
- **The captive** knocks anything in its arc, standing or tumbling:
  `knock(v, captive)` along its swing's tangent at its own speed. That is
  about 8-10 m/s at the bottom of a 1 rad swing from 5.6 m. It is a source of
  its own, so a body the face just spat that meets the captive is stunned
  again: a clean hand-off.
- **Riding the captive's back** (hopped onto at its apex): it carries a
  standing or downed body as the seesaw does, and sheds it at the far end
  of its arc with a `toss` at the swing's speed.
- **The slam-jerk**: the ring rider is thrown by `toss` downward and
  outward. He is not stunned, so the sail is fresh.

Chains with:
- In: the Root Curtain's snag swings a body into the ring's reach; the
  Basalt Palisade's chimney top reaches the Holder's shoulder.
- Out: the long release flies to a Sleeper's Face's lower-lip shelf, a
  Glyph Register Wall's high register, or a rope bridge. The captive knocks
  a climber off the rim stair into a seesaw or a sluice spill. Gnaw rats
  ride the chain. A swing rope placed in the release's line makes a
  rope-to-rope relay (another rope is caught at once).

Build cost: medium-high.
- Blender model of the seated idol, 4-6k triangles.
- Coupled-length swing ropes: swing_rope.gd now has a fixed anchor
  and length, so a varying grip length and the coupling are new physics.
- The captive as a pendulum trap: the censer has not been built.
- Chain look: a faceted link strip, cheap.

Model budget:
- Sculpt high, bake low: the idol (4-6k, bake saves the sculpt's ~100k).
- Rigid parts on bones: none unless it ever moves its arms. If a later round
  makes it pass the chain hand to hand, its forearms and fists go on
  BoneAttachment3Ds, not skinned.
- Import LODs: the idol, perhaps 0.05 ms at range.
- Silhouette geometry: knees, fists and the shoulder groove.
- Vertex-colour grime: under the arms and the rust trails.
- Parallax depth: the rope relief on the captive.

---

# Root Curtain (maker_root_curtain, family makers)
Verb: swing from root to root, under things. It's a fall of strangler-fig
aerial roots hanging from an underside, each bundle a short swing rope, and
some of them dry enough to snap.

Look: thick grey-brown root bundles pour from the underside of an isle,
an arch, a Sleeper's Face's chin or a Holder's arm, braided and forking.
Some end in a tangle that still grips a carved stone (a cartouche or a
fallen glyph block wrapped in roots like a fist), which is the knot. The
dry ones are pale and brittle with flaking bark, the Ivy Fuse's tell carried
over: the dry ones are the dangerous ones. Live ones are dark and wet with
moss. This is overgrowth as the route and the threat at once.

Behaviour: each root is a swing rope (`swing_rope.gd` rider, a root mesh
instead of the rope).
- Live roots are static anchors.
- Dry roots change state: a dry root holds for one swing. Past the plumb
  the second time, or after 2.5 s held, it creaks and drops bark (a 0.5 s
  tell), then snaps.
- A snapped root keeps the pilot's arc if he lets go before the snap (the
  Gnaw rule). After the snap he falls with the root.
- A snapped dry root does not grow back this run (a run-state change: the
  route home may be gone).
- **The snag**: the curtain's headline. A tumbling body that passes within
  CATCH_BODY 0.32 of a live root is caught in it. The root calls `seize()`
  and carries him as its pendulum bob for SNAG 0.5 s, swinging on from his
  pace across it. Then it hands him to the rider hold with his poise back:
  he hangs on the root as if he had jumped into it, and plays on.
- A **dry root** snags too, but holds only 0.3 s before it snaps. It then
  throws him on, still stunned, along its swing's velocity: a redirect, not
  a rescue.

Size:
- Root lengths: 3.0 to 4.5 m, shorter than LENGTH 5.6, so the
  pendulum is quicker (period about 2.4 to 3.0 s at GRAVITY 20 against the
  5.6 rope's 3.3) and launches a little less far.
- Knots: at least GRIP_HIGH 0.35 of the length down. Where there is ground
  under them they hang at KNOT 0.9 over it.
- Spacing: 3 to 6 m, well inside a released swing's reach. The rope
  launches about 19 m at 5.6 m, and a 3.5 m root still clears several
  metres.
- A second root is caught at once (REGRAB 0.45 applies only to the same
  rope), so a curtain is a chain of swings: a monkey-bar crossing under an
  isle. MOST 1.35 caps each swing.
- Under a flown underside (hollow_keel's undercroft), the roots hang no
  lower than leaves `WorldScale.opening(TOY_THREAD)` (7.0) clear below
  them, so the plane still threads the undercroft past the curtain.

Collision: none on the roots (the rider grabs by distance, as the rope
does). The wrapped stone knots have no hull either, or a small one when
they rest on the ground.

Motifs it enables:
- The hanging underside: an isle whose route is under it. You drop off the
  rim, catch the first root, swing four roots to a cave in the underside or
  across to the next isle. This is the coverage's "a hanging underside" with
  a foot route.
- The face's beard: roots from a Sleeper's Face's chin over its lower
  shelves, a swing line round the breath band.
- The strangled arch: a gothic arch the makers' fig has swallowed (the two
  families meeting), with roots from its soffit replacing a bare swing rope.

Threat pairing: dry roots are a timed crossing: swing through without
dwelling, release early. Gnaw rats live in the dry ones. A Spindle's thread
strung between roots becomes a rail. The Ivy Fuse burns along a curtain in
seconds, and its smoke's thermals lift the sail under the isle. A snapped
root falls onto whatever is below: a Cairnling, a Plinth Ram or the
Holder's captive swing.

Catches / throws: this is the chain's net.
- **Airborne or running** into a root: taken as a swing rope.
- **Tumbling**: snagged (live roots) or redirected (dry roots), as above.
- **Riding**: as a rope, with a second root caught at once.
- **Let go**: `toss`, as the rope's release, with BOOST and POP. A shorter
  root throws less far: roughly the rope's 19 m scaled by the root's
  length.
- **A dry root's snap**: `toss` of a stunned body, still stunned, with a
  fresh poise.
- The curtain's facing (the way the roots are combed by the wind, a knob)
  sets which way a snagged body swings out. So the generator can point the
  curtain's throw at the next isle, and a skilled player rides the snag
  into the release on purpose.
- The snag is a catch, not a stun, so it shares no restun key. A pilot
  snagged, released and knocked again by the next link is stunned afresh.
  The chain cap's 3 s still lets the player break out.

Chains with:
- In: the Sleeper's Face spit, the wind blaster, the inhaler head's
  blow-out, a seesaw's or a toppled rocker's throw. Anything that throws a
  ragdoll under an isle can aim at a curtain.
- Out: a release onto the Holder's ring or a rope bridge; a dry snap's
  redirect into a sluice spill or a Glyph Register Wall (tech-caught).
- Others: the Ivy Fuse burns it; Gnaw rats nest in it; the Spindle strings
  rails across it.

Build cost: medium.
- Reuse the swing rope rider.
- A procedural root mesh: tapering faceted strands braided round the rope's
  line, two LOD levels.
- A dry/snap state: a timer and a toss, close to Gnaw's planned behaviour.
- The snag needs one motor hook: hand a seized body to a `rider` with its
  poise back (today `seize` ends only in a `knock`, and the rope refuses
  `move == "tumble"`). That is a small motor change touching input and
  stun, so it goes to Opus.
- No Blender work, except optional wrapped-stone knots taken from kit
  blocks.

Model budget:
- Silhouette geometry: a few forking strands carry the read, with no fine
  rootlets in geometry.
- Visibility ranges: a curtain's back strands drop at range, about 40% of a
  curtain's triangles beyond about 40 m.
- Vertex-colour grime: dark at the root's crown, pale and dry tips.
- Sculpt and bake, rigid parts on bones, parallax depth: not applicable.
- Saving: the strands are procedural, about 150-300 triangles a root, so a
  20-root curtain is 3-6k. Visibility ranges save the most.
