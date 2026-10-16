# Kit k5: hide / light and dark (underground Olmec city)

Lenses: verb stay hidden + chase (shake a hunt off or mislead it); mood
oppressive; scale human; shape a tight cluster.

Sizes are named by their source: his height `unit` (PhysicsGround.HEAD
x WorldScale.wanderer, the enemies' `n.unit`), reach RuinKit GRAB_TOP /
CHAIN_TOP / SET_OFF / STAND / TOP_ROOM, the city's CELL, COURSE, LANE and
HIS_HEADROOM (scripts/city_kit.gd), the fall stun `fall_stun_height()`,
his noises' loudness in scripts/noise/wanderer_noise.gd, the Olmec's
reach in head heights (Hh) from his knobs.

What hidden means underground today (the code these pieces are built to):
- The Olmec's sight (scripts/enemies/body_sight.gd) casts three rays to
  his feet, chest and head (`pilot_points`, at fixed shares of
  PhysicsGround.HEAD, not lowered by crouch) and stops them on the ground
  mask (walker-only stone too with `sight_walker_only`). Light scales it
  (scripts/enemies/light_level.gd): the look's ambient, his torch and every
  lit SightLight summed, no occlusion, and a LightDrinker drinks it.
- Hunting and relentless, the whole Olmec sees further, the dark hides
  him less (`hunt_dark_*`), and lost for `hunt_search` (4 s) he takes his
  scent (`_scent`: where he is now) and comes on. Today nothing shakes
  that off but a refuge he can't enter.
- His ears (scripts/enemies/body_hearing.gd) turn a calm body to a noise
  as to a weak beacon, but only while `_beacon_free`: a hunting Olmec
  hears nothing. A lit Beacon draws only a calm one.
- The guacharo (scripts/enemies/guacharo.gd `_sense`) reads only stone
  over him (one ray up). It ignores light and noise.
- Existing city pieces already cover: lighting fires with the torch
  (cresset, runnel, beacon tower, wick spire), snuffing the torch (hush
  gallery's trough), a dark hall (hush `shade`), an echo that gives you
  away (hush), walker-only refuges (mouse run, niches, slotted wall), a
  beam that lights you (sun-mirror). None of the four below repeats them,
  nor round 2's pent hood, corbel shaft, catch net or hung screen.

The four are made to stand in one small court: a mat-hung gallery down
one side, a copal brazier in the sunk middle, a glare pan at the far end
facing the court's way in, and a serpent maw's ear by the gallery whose
voice speaks from the tier above.

---

# Copal Brazier (`city_copal`, family city, its fires)
Verb: stay hidden in its smoke; walk a relentless hunt into it and come
  out lost to him.
Look: a squat basalt brazier on a stepped plinth, its bowl heaped with
  lumps of pale copal under a stone hood like a jaguar's open mouth, the
  smoke slot its lower lip. The hood and the wall behind are black with
  soot, the resin crusted white round the slot. It stands in a court
  floor sunk a step, so the smoke pools in it.
Behaviour: changes state. Cold until lit by the torch (the CityFires
  TOUCH rule at its rim, from the plinth's step), by a burning runnel's
  tail, or by a mirror beam (CATCH). Lit, it smoulders BURN s (about 40),
  then goes cold; it can be lit again once cold. While it burns it pours a
  low smoke bank out of the slot, filling over about 4 s to its full lens
  and thinning over the last few seconds. The bank fills the sunk court,
  about 2 x unit deep: over his head, under the Olmec's neck, so the Olmec
  looks down into it from above. The heart of the bank by the bowl glows
  (a small SightLight on the embers), so its edge is dark and its middle
  is lit: the place to hide is the rim of the smoke, not the fire. Knob
  `bank` (the lens's radius in cells, 1-3), knob `burn`.
Size: plinth step SET_OFF high (a top STAND deep to stand at the rim with
  the torch); bowl rim under GRAB_TOP over that step. The sunk court is a
  RISER or two down and LANE across, so a whole Olmec can walk in after
  him. The bank's depth is two of his heights (it covers his head ray at
  a stand or a jump's top), and its radius is the knob's cells.
Collision: plinth and hood are hulls (the plinth's top a clean box, the
  hood wall-kickable). The bowl is a hull with no standing top: the coals
  are not a step. The smoke has no collision. It is a volume node
  (centre, radius, top, density) that sight reads, not physics.
Motifs it enables:
  - A court you cross with the Olmec hunting you: light the brazier in
    passing, wait at the rim of its smoke while he comes into it and
    gropes, and leave by the side he isn't on.
  - A smoke-filled processional lane of braziers, lit in turn as a runnel
    runs along them: a dark way that opens as the flame travels.
  - Under a guacharo's gulf it gives no cover at all: the bird hunts by
    clicks, and the smoke teaches that only stone hides you from it.
Catches / throws: standing: in the bank he is seen dimly (a ray from the
  Olmec's eye loses sight with every metre it runs through the smoke, so
  near and above he sees more of him than far off and level). Airborne: a
  jump's top can carry his head out of the bank (seen). Tumbling/stunned:
  nothing of its own. Outputs: no knock, no toss. Lit, the copal pops on
  the NoiseBus now and then (a sneak's loudness), so it is quiet but not
  silent.
Break: answers the hub (way 3) as the cresset does, with a registered
  cut `brazier` for its fall: `stands` the plinth, the bowl and hood go
  as one `drum`. Barged or hit lit, the coals spill as a short, thick puff
  (about half the bank, SPILL s) and it is dead for good. Unlit, it just
  falls.
Sight/hearing asks: (1) a smoke volume group that BodySight samples per
  ray, the share seen falling with the length of the ray inside smoke
  (`smoke_k`); (2) `_scent` and hunt memory masked by smoke: while his
  feet are in a bank the relentless Olmec can't take his scent. He goes to
  the bank's edge nearest where he lost him and seeks (`search_for`, not
  `hunt_search`), and the scent comes back only when he is seen again or
  has been out of the smoke `scent_lag` s; (3) the ember as a small
  SightLight, already supported.
Build cost: med. The plinth and bowl are the cresset's build. The smoke
  is a particle system plus a volume node. The sight sampling and the
  scent rule are small changes in body_sight.gd and headless_body.gd.
Model budget: silhouette geometry (chipped hood lips, the slot; flat
  faces plain); vertex-colour grime (the soot plume up the hood and wall,
  baked); the smoke as a capped count of soft billboard particles, low
  overdraw, with a visibility range (overdraw is this piece's real frame
  cost, not triangles); import LODs on the stone.

---

# Speaking Serpent (`city_echo_maws`, family city)
Verb: mislead a hunt. Make a noise into the ear and it comes out of the
  voice, elsewhere, and the Olmec goes there.
Look: two carved serpent heads joined by a duct you never see. The ear is
  a wide maw at floor level in a wall, a walk-in alcove its throat, a
  round drum stone sunk in its floor. The voice is a narrow maw high on
  another wall, round a corner or a tier up or down. A carved glyph band
  runs along the walls between them, tracing the duct, so you can read
  where the voice speaks from. Both mouths are soot-dark inside.
Behaviour: changes state (a relay). Any noise made within the ear's throat
  (his footfalls, a landing, a slam on the drum stone, the copal's pops)
  is heard at the ear only at MUFFLE (a share, the throat swallows it) and
  made again at the voice DELAY s later (0.4-0.8 s, the duct's length),
  at GAIN of its loudness, as a `relayed` noise (NoiseBus `emit(...,
  relayed)`, its source the voice). The drum stone is the call: a slam on
  it comes out of the voice about as loud as an Olmec's own landing. One
  relay every GAP s (the drum rings, then is quiet). Knobs: `two_way` (off:
  both maws are ears), `drum` (on), `gain`.
Size: the ear's alcove is TOP_ROOM wide and two STANDs deep, its headroom
  a little over PhysicsGround.HEAD: his size, far under HIS_HEADROOM, so
  the Olmec can't follow him in. The drum stone sits in a well a SET_OFF
  under the alcove's lip, so a hop off the lip into it has height under
  him for the slam. The voice is at least body_hearing NEWS (6 m) from the
  ear, and set so the Olmec's route to it leads away from the ear: 3 to 8
  cells off, or a COURSE up. Its lower jaw is a ledge at GRAB_TOP over the
  floor under it, a perch to look out from.
Collision: the alcove floor and drum stone are clean boxes, walker-only
  (scripts/walker_only.gd), so the Olmec never plans into the alcove. The
  heads are hulls; the voice's jaw top is a clean box (a ledge). The duct
  has no collision.
Motifs it enables:
  - Pinned in a dead end with him lost and seeking outside, you step into
    the ear and slam the drum; the voice booms from the tier above, and he
    climbs to it while you run the other way.
  - A two-way pair across a court (`two_way` on): each footfall too near
    either ear speaks from the other one, so the court is a place you
    sneak (under SNEAK of his run) or give yourself away twice.
  - A row of voices in one long wall, each fed from its own ear: a whole
    gallery that talks, and you pick which mouth he goes to.
Catches / throws: standing: covered (the alcove's roof is stone, so the
  guacharo reads it as cover) and hidden (stone on three sides). Airborne:
  a slam into the drum well is the call. Tumbling/stunned: nothing of its
  own. Outputs: noises only, no knock or toss.
Break: registered cut `maw`: a head knocked off its wall as a `chunk`,
  `stands` the wall face with the duct's mouth open. Broken, that maw
  goes dead (a broken voice relays nothing; a broken ear hears nothing).
  An Olmec fooled twice by one voice and hunting with `breach` on may
  smash it.
Sight/hearing asks: (1) a hunting Olmec must hear: in `seek` (and in
  `scope` and the climb-after), a relayed noise louder than his footfall
  resets his search to the noise's place (he goes there, then searches
  `search_for` there), and relentless `_scent` waits until that search
  ends. Today `_beacon_free` blocks all hearing while hunting. (2) Learning:
  a second relay from the same voice within `relay_wise` s is ignored (the
  Beacon `_tired_of` rule, keyed on the voice). (3) A relayed noise is not
  blurred (`BLUR` off): he goes to the mouth, not near it. (4) The
  headless body already heeds noise when calm, so this works on it today
  apart from (3).
Build cost: low-med. The two heads are procedural carved stone (the
  stair's serpent head build, scripts/city_kit.gd HEAD_LENGTH). The relay
  is a small node on the NoiseBus. The hunt-hearing rule is the real work,
  a few lines in headless_body.gd's `_beacons` and `_seek`.
Model budget: silhouette geometry (fangs and the flared lip are real; the
  glyph band is a texture, or the city stone's rune surface); vertex-colour
  grime (soot dark in each throat); import LODs on the heads.

---

# Glare Pan (`city_flarepan`, family city, its fires)
Verb: blind the Olmec for a moment with light, at the cost of being lit
  yourself if you stand in front of it.
Look: a wide, shallow basalt dish on three short feet, crusted with
  grey-white resin and powdered pyrite, set in a niche backed by polished
  obsidian tiles that face out across a lane: a reflector. Below the dish,
  the niche's stone is scorched in a fan.
Behaviour: one-shot per charge. Lit (the torch at its rim from the step
  behind it, a runnel's tail, a mirror beam, or a lit spill rolled into
  it), it flares: FLARE s (about 1.5) of white glare thrown out of the
  reflector in a cone, then a dull ash glow (a dim SightLight) for a
  while, then cold. Knob `charges` (1 by default, up to 3: relit after
  COOL s). A deep "whoomp" on the NoiseBus (about a slam's loudness).
  What the flash does:
  - a whole Olmec whose eye is in the cone and in range, facing it within
    his `half`, is dazzled DAZE s (3-4): his sight reads nothing and his
    awareness drains fast. He staggers, a hand over his eyes. A pounce
    windup or a suck's tell (`plant`) is cancelled. He still hears.
  - a headless body has no eyes to dazzle. The flash is a strong Beacon
    to it while the glow lasts, a lure.
  - a guacharo stalking within FLINCH of the cone balks (as under stone)
    and pulls up, and won't stalk him within the ash glow's reach for
    LINGER s.
  - him: in the cone, he glows (LightLevel `glow`, up to `glow_k`), the
    plainest he can be. Behind the reflector he is in its shadow.
Size: the dish rim stands about STEP_UP over the floor in front and
  under a STAND-deep step behind the niche, so the torch reaches it
  (TOUCH) from the step, out of the cone. The cone's half-angle is about
  the Olmec's `sight_half` and its reach about his `sight_near` (14
  units): enough to cover the lane he comes down, from his pounce range
  (`pounce_min`-`pounce_max` Hh) to the court's way in.
Collision: the dish is a hull with no standing top; the reflector niche
  is hulls (its outer faces wall-kickable); the step behind is a clean
  box.
Motifs it enables:
  - The Olmec comes down the lane at you, winds up to pounce; you touch
    the torch to the pan from behind it and the pounce dies in the glare.
    You have three seconds to be somewhere else.
  - A fuse wall: a runnel lights a row of pans in turn down a long
    gallery, a flash travelling ahead of you to blind whatever waits at
    the far end.
  - Over a gulf the guacharo hunts: a pan on the lip lit before the
    crossing keeps the bird off that stretch while its ash glows.
Catches / throws: standing/airborne: in the cone he is lit (glow). Not a
  hazard to him: no harm, no knock. Tumbling/stunned: nothing. Outputs:
  the flash (a dazzle on what it reaches), its noise, its Beacon while it
  glows.
Break: answers the hub (way 3) like the cresset, with a registered cut
  `pan`: `stands` the reflector niche, the dish knocked off its feet as a
  `slab`. A charged pan hit lit spills as a short ground fire (a Beacon,
  as the cresset's spill). A cold one just falls.
Sight/hearing asks: (1) a directional SightLight (a cone: `light_at`
  scaled by the angle off its axis) so the glare lights the lane, not the
  wall behind; (2) a flash event (a group call, `dazzle(from, axis, cone,
  reach)`) that a body's sight answers with a new `dazzled` state on the
  whole Olmec (sight off, awareness drained, his windup and plant
  cancelled; a new clip ask); (3) one ray from the pan to his eye so a
  wall between blocks the dazzle (SightLight has no occlusion); (4) a
  light-shy rule in the guacharo's stalk choice (a lit SightLight within
  FLINCH of the stalk point or the stoop line is a balk).
Build cost: med. The dish and niche are procedural; the flash is a
  SpotLight3D tween plus an emissive pulse; the dazzle state and its clip
  on the whole Olmec are the real cost (Opus: enemy behaviour and
  animation).
Model budget: silhouette geometry (the dish's chipped rim, the tile
  edges); the obsidian tiles as one mirror-ish material on flat quads,
  not modelled; vertex-colour grime (the scorch fan); import LODs.

---

# Mat Screen (`city_mat_screen`, family city)
Verb: stay hidden behind it, slip through it, watch through its gaps.
Look: a heavy basalt lintel across a gallery bay hung with long woven
  reed mats, frayed, blackened at the hems, weighted at the foot with
  knotted stone sinkers. Some hang whole, some in strips, some torn to the
  lintel. Behind them, a dark bay.
Behaviour: moves (sways). The mats part round him as he walks through
  and swing back. They keep swaying SWAY s after (a tell an Olmec looking
  that way may catch). Going through makes a rustle on the NoiseBus at his
  footfall's loudness, a sneak's if he sneaks through. The Olmec's inhale
  (`suck`) lifts the mats toward his mouth, so the bay's front is open
  while he sucks. Walked through with the torch lit, a mat catches: the
  screen burns BURN s (a Beacon and a SightLight) and is gone, the bay lit.
  So you go through with the torch doused, or burn it on purpose as a
  lure. Knobs: `torn` (0-3: mats missing, gaps the rays pass), `bay`
  ("walker": an opening only he fits; "his": hung at HIS_HEADROOM so the
  Olmec can push through too and tears it down).
Size: "walker" bay: TOP_ROOM to one CELL wide, the lintel a little over
  PhysicsGround.HEAD x 1.5 (it hides his head ray at a stand with a hand
  to spare). The mats hang to a hand over the floor, so the ray to his
  feet can pass under them: his feet show under a mat, and crouching
  doesn't hide them (his sight points don't lower; gap 6).
  "his" bay: LANE wide, the lintel at HIS_HEADROOM. Mats are a sinker's
  width apart; a torn gap is wider than his body (2 x BODY) so a ray to
  his chest passes it.
Collision: the lintel and jambs are hulls. The mats have no walking
  collision for him or the Olmec. Each mat is a thin box on a new
  sight-only layer (body_sight's mask takes it, routes and the walker's
  ground don't), following its sway, so the rays to his three points hit
  a mat or a gap. The bay's floor and the dark bay behind are plain floors
  (walker-only in a "walker" bay).
Motifs it enables:
  - A gallery down one side of a court with every bay matted: the Olmec
    walks the court, you shadow him bay to bay behind the mats, watching
    through the torn ones.
  - A bay he can enter (`bay` "his"): he pushes through after you and
    tears the screen down, so it hides you once.
  - Burned as a lure: light the mats and run; the burning bay draws a calm
    Olmec to it while you slip out the far side.
Catches / throws: standing: behind a whole mat he is hidden from sight
  (not from the guacharo: nothing over him). Airborne: passes through.
  Tumbling/stunned: passes through, setting the mats swinging. Outputs:
  the rustle, the sway tell, a fire (Beacon) when burned. No knock or toss.
Break: registered cut `mat`: `stands` the lintel and jambs, the sinker
  bars fall as small `chunk`s and the cloth goes as a shred effect. A swat,
  a breach or a slam on the lintel strips the bay. Burned, the same cut
  with ash in place of shreds.
Sight/hearing asks: (1) a sight-only collision layer (a mask bit like
  WalkerOnly, read by body_sight and nothing else) with moving boxes;
  (2) a "something moved" glance: a swaying screen in his cone bumps
  awareness a little (suspicious, never spotted), so pushing through in
  his view costs you; (3) crouch lowering `pilot_points` (round 2's gap),
  so crouching behind a hem that stops short of the floor hides his feet
  too; (4) the suck exposing the mats (a hook in the suck's pull on
  things in front of the mouth).
Build cost: low-med. The lintel is procedural stone. The mats are
  alpha-cut quads swayed in a vertex shader, with one spring per mat
  driving its sight box (no cloth sim). The burn is the cresset's fire
  shader along the hem. Cheap if the sight layer lands first.
Model budget: alpha-cut mats (a quad strip per mat with a woven, frayed
  texture, not modelled weave: thousands of triangles saved, some
  alpha-scissor overdraw); vertex-shader sway (no skinning, no bones);
  silhouette geometry on the lintel; vertex-colour grime (soot over the
  lintel, darker hems).

---

## Combines with

- `city_copal`: the city's runnel (`maker_runnel`, lights it in turn),
  the sun-mirror (lights it from far off), `colossus_ashbowl` (a sunk
  court to pool in), `city_mat_screen` (smoke behind mats: a double
  hide), the hush gallery (a snuffed torch can be relit at a lit
  brazier's rim).
- `city_echo_maws`: `city_slotwall` and `city_mouserun` (thick walls to
  run the duct through), the drum stair and the epic stair (a voice a
  COURSE up or down), `city_copal` (its pops in an ear speak elsewhere:
  a slow, quiet lure).
- `city_flarepan`: `maker_runnel` (a fuse that fires a row of pans),
  `maker_mirror` (a beam that fires one from far off), the great cresset
  (a lit spill rolled into it), the causeway and crossings the guacharo
  hunts.
- `city_mat_screen`: the hush gallery and votive niches (a dark bay
  behind it), the epic stair's landings (bays off a flight),
  `city_copal`.

## Engine gaps found

1. **A hunting Olmec can't be shaken or misled.** `_beacon_free` blocks
   every noise and beacon while he hunts, and relentless `_scent` finds
   him after `hunt_search` whatever he does. Two of the four (copal,
   maws) need a rule: smoke masks the scent, and a heard noise resets a
   seek. This is the one change the round leans on.
2. **Sight is rays and light only.** There is no smoke volume, no
   sight-only occluder layer, and no "something moved" sighting. Copal
   and mats need the first two, mats the third.
3. **SightLight has no direction or occlusion.** A glare that should
   light a lane lights the wall behind it and through stone. The pan needs
   a cone and one occlusion ray, and so would any shuttered lamp.
4. **No dazzle.** Nothing turns the whole Olmec's sight off for a time;
   the pan needs a `dazzled` state with its own clip.
5. **The guacharo ignores light and noise.** A light-shy stalk rule is
   the pan's only reach over it. Smoke deliberately stays no cover from it
   (it hunts by clicks).
6. **Carried from round 2, still open:** crouch doesn't lower
   `pilot_points` (mats' hem, any low parapet); cover is one ray straight
   up (the maws' alcove works only because it has a full roof).
