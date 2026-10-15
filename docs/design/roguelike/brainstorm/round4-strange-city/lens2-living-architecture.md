# Lens 2: Things that change the level (living architecture)

Round 4, strange inhabitants of the city. This lens covers the movers, the
rebuilders and the stone that is still alive: whatever bends the layer's
geometry while you play it. Each card has to balance the Olmec (one or two
per layer now) and work with the breakable kit, not just add another hunter.

Verbs named below are the wanderer's real moves (`scripts/pilot_motor.gd`):
run, double jump, long jump (crouch-run), wall kick, wall run, twirl, the
slam (crouch in the air, its ring) and the roll, ledge hang and shimmy,
swim, the pocket sail, the torch, and the stun with its poise. The Olmec's
moves are the ones in the docs: listen, climb, mantle, ledge jump, drop,
shockwave, swat, pounce, inhale, periscope, his breaks, and the beacon pull.

Several cards share a **noise bus**: one layer-wide stream of loud events
(Olmec landings and mantles, breaks, falling pieces, the wanderer's slam
and hard landings, bells). The Olmec's hearing already takes these as
bearings. a2 and a4 listen to the same stream, so it is built once.

---

## a1-jade-mask: The Jade Mask — "It has no face of its own, so it borrows yours, and late."

A pale jade face that makes whatever it sits on copy you, 1.5 s late and at
its own scale.

**Look & movement.** A face of grey-green jade about the size of the
wanderer's torso. It has the Olmec down-turned mouth and drilled pupils, and
an old crack across it, laced shut through drilled cord holes. Off a host it
moves like a dropped plate: it rolls on its rim in a long clattering curve,
tips, spins flat and lies face up, still, looking. To take a host it skips
across the stone in two or three low hops and seats itself where a face
would be. A green-black patina then creeps out over the host's basalt, like
damp spreading. Hosts are statues (seated or standing lords), pillars and
the drum stairs.

**The strange rule.** **The host does what you just did, 1.5 s later, in its
own body**, but only what you did inside the mask's gaze, and always facing
you. You step toward it and it steps toward you. You jump and the 7 m statue
jumps, landing with the Olmec's shockwave. You crouch and a pillar bows its
capital toward you. You back away and it backs away. You learn it by
jumping for a rune on a rim near a masked statue, and the wave of its copy
throws you off a second and a half later.

| Host | Your move | What the host does |
|---|---|---|
| Statue | walk, run, jump, crouch | strides, jumps (with a landing wave), kneels |
| Pillar | crouch / stand | bows 35° toward you / rises again |
| Pillar | jump | hops on its drum foot: a small wave, and a crack |
| Drum stair | crouch / jump | the treads fold flat into a ramp / the treads rise |

**Tell.** You see two pale points in the drilled eyes catching your torch,
and the patina on the host. You hear a dry jade *tick* as it turns to
follow you, and each of your moves comes back as stone grinding in the same
rhythm, 1.5 s behind. From the high camera the delay is what reads: you
see your own move again, done big.

**States / escalation.**
- **Loose.** It rolls to the nearest host in its view, which takes about
  6 s, and is harmless while it rolls.
- **Hosted.** It copies you.
- **Thrown.** A break, a fall or an Olmec hit throws the mask off. It
  clatters off and seeks the next host.
- **History.** Every host it leaves keeps the last pose: a statue stopped in
  mid-stride, a pillar left bowed. The layer collects the mask's history.
- **On the Olmec.** The headless body takes the mask for a head (through the
  head's call channel) and seats it on his stump. He becomes **whole and
  wrong**: he stops hunting by sight and copies you at his size. Your jump
  is his pounce, and your run is his charge.

**Hooks.**
- **Light.** It only records you while you're lit. Torch out, and the host
  freezes where it is.
- **Sound.** A masked statue's strides and landings are loud, and the Olmec
  goes to them, so it is a decoy you drive.
- **Breakables.** A pillar bowed again and again cracks at a drum joint and
  falls, through the existing break.
- **Knock-back.** Copied jumps make landing waves at rims.
- **The Olmec.** The stump seat above.

**Rule 0.**
- Walk backward and the masked statue walks backward off its plinth into
  the void.
- Crouch to bow a pillar across a gap. When you stand to run, it rises
  1.5 s later, so the delay is your window to cross. Too slow and the
  rising capital flicks you up and out.
- With the mask on the Olmec, lead him: walk toward a wall and he walks his
  copy of it over a rim.
- **The risk.** Every move you make near it, it makes too, and it is bigger.

**Co-op story.** The mask copies whichever of you it watched last. One
friend crouches in its gaze to hold the pillar-bridge down while the other
runs it. Then the crouching friend sees a rune and jumps for it. The pillar
hops, and the runner is thrown into the dark.

**Counterplay & fairness.**
- It never acts unless you act first, and the delay is the tell.
- Douse the torch to freeze it.
- Knock it off by luring the Olmec, or a felled column, into the host.

**Where it lives.** Statue courts, colonnades, the drum stairs. One mask per
layer with 3 to 6 possible hosts in reach. From the second layer up.

**Build cost: L.** It needs a recorder of the wanderer's moves, a small
verb table per host kind (the statue needs a walk rig), the rolling seek,
and the Olmec's stump seat (the head's `perch` hook already does this).

**Cliché check.** Mimics are a known trope (the Cosmic Clone, Dark Link),
and that part is plainly stock. Here it doesn't chase your path. It replays
your verbs at a different scale on the architecture, so it is mostly a
crane you operate badly.

---

## a2-sleeper: The Sleeper — "Do not wake the floor. Everyone wakes the floor."

The plaza is the back of a basalt earth-caiman, and it wakes from the noise
of the whole layer, not from yours.

**Look & movement.** A wide plaza of square scute-slabs, each carved with
the cleft-and-band glyph. A spine of squat pillars runs down its middle
(its dorsal row), and a low rim of plated stone bounds it. Its head is
buried under a far stair, its tail is lost over the void, and you only ever
see the back. It breathes: the plaza rises about 1 m and sinks again over
9 s, as moving ground (the serpent round's engine). On each in-breath the
seams between the scutes open a finger's width. On each out-breath warm
haze seeps from them and hangs in the torchlight.

**The strange rule.** **It doesn't hear you. It hears everything on the
layer, summed.**
- Every event on the noise bus fills a ledger, and the ledger drains
  slowly: an Olmec landing anywhere, a column falling three isles away,
  your slam, a bell.
- When the ledger is full it **shrugs in its sleep**. The whole plaza
  heaves 4 m up on one side and drops, and everything on it goes toward the
  low side.
- The low side is the side away from the loudest recent noise.
- You learn it by crossing the plaza quietly, step by step, while the Olmec
  smashes a colonnade somewhere you can't see, and the floor throws you
  into the void.

**Tell.**
- **Its breathing.** The breaths speed up and grow louder as the ledger
  fills, so its breathing is the meter. You hear it from anywhere near the
  plaza.
- **The held breath.** Before the shrug, it holds its breath for 3 s.
  - Every flame within 60 m leans toward the plaza: your torch, the
    cressets, the far beacons.
  - The mix ducks to near silence.
  - From the high camera, a whole field of fire bending one way is
    unmistakable.

**States / escalation.**
1. Deep sleep: slow breaths.
2. Restless: fast breaths and steam from the seams.
3. Held breath: 3 s.
4. Shrug, then back to deep sleep with the ledger empty.

Each shrug throws down one or two dorsal pillars (breakables), and they lie
as new ramps across the plaza. On the third shrug it **lifts its head**:
the buried stair at the far end rises 8 m, and stays up as a new route out
of the plaza with the floor left tilted. The layer is changed for good.

**Hooks.**
- **Sound.** The whole thing runs on sound.
- **The Olmec.** His landings fill the ledger fastest. A shrug throws him
  too (he is moving ground's passenger like anything), and near the rim it
  throws him into the void.
- **Light.** The held breath bends every flame, so your torch is your own
  warning even when you can't see the plaza.
- **Breakables.** The dorsal pillars fall, and every break anywhere feeds
  the ledger.
- **Knock-back near edges.** The shrug is one huge knock.

**Rule 0.**
- **Kill an Olmec.** Lure him onto the back, then make the layer loud:
  slam, ring something, let him pounce. He goes off the low side.
- **Ride the shrug.** Stand on the high side and jump at the top of the
  heave. The moving ground's lift adds to your jump and puts you on a ledge
  above the plaza, where the rare collectible waits. Nothing else reaches
  it.
- **The risk.** The direction comes from the noise. Misread where the
  loudest thing was and you're standing on the low side.

**Co-op story.** One friend ran across the layer slamming every landing to
"time it", while the other waited on the high side. The Olmec landed a
pounce somewhere off screen first and flipped which side was low.

**Counterplay & fairness.**
- Hold still on the spine row, which barely moves.
- Hang from a dorsal pillar's lip: hanging rides the shrug out.
- Move quietly: no slams, and roll your landings.
- The held breath is always 3 s. It never shrugs without one.

**Where it lives.** A plaza set piece, the Sleeper's own motif. One on at
most every other layer, never the first layer.

**Build cost: XL.** It needs a big animated set piece on moving ground, the
layer-wide noise ledger and bus, the mix duck and a flame-lean global, the
shrug as a knock on every body and loose piece, and the head-lift stair.

**Cliché check.** A floor that rises and falls is a moving platform, and
that part is stock. The layer-wide ledger, the held breath that bends every
fire, and the shrug's side being set by distant noise are not.

---

## a3-plumb: The Plumb Line — "The masons hung it to check their walls. It is still checking."

A serpentine plumb bob on a cord from the dark. Under it nothing can bend.

**Look & movement.**
- **The bob.** A plumb bob the height of the wanderer, in polished dark
  serpentine (a green-black cone with a drilled crown). It hangs half a
  metre off the floor on a cord of twisted agave fibre that rises out of
  sight.
- **The swing.** It swings as a very slow pendulum, about 40 s per arc,
  turning a little.
- **What moves it.** Impacts swing it wider. Each Olmec landing or
  shockwave nearby pushes it, so his rampage moves it across the court.

**The strange rule.** **Within 5 m of its line, nothing bends.**
- You can't crouch, slide, slam, roll or long jump, and a stun snaps you
  upright at once.
- The Olmec can't wind up, so he can't pounce, leap or climb; under it he
  only walks and swats.
- Anything leaning or fallen **rights itself** while the line passes over
  it: a felled column, a tipped cresset, a lintel lying as a ramp. It rises
  back to vertical over 3 s.
- You learn it by running a felled-column bridge the Olmec made for you.
  The plumb drifts over it, the column stands back up, and you're flicked
  off its top into the void. Or by dropping 7 m into the zone and finding
  you can't roll the landing.

**Tell.**
- You see the taut line against the haze, catching the torch.
- Inside the zone, dust motes hang dead still and your torch flame stops
  flickering. From above, it is a disc of perfect stillness.
- You hear the cord creak, then stone grinding as a righting begins.
- A righting is slow and eased, never a snap.

**States / escalation.**
- **Idle.** It barely swings.
- **Swinging.** After shocks its arc widens.
- **Plumbing.** Passing over something fallen, it **stops dead** above it
  and holds until the piece is upright, then swings on.
- **Pale scars.** Every righted piece shows a pale crack line where it
  mended, so you can read where the plumb has been.

**Hooks.**
- **The Olmec.** It undoes his breaks, and it is a shelter from his pounce
  and his climb. His own landings push it around.
- **Breakables.** It rights felled piers and lintels, and resets
  voussoirs.
- **Stun.** It breaks a stun instantly, which can save you on a rim.
- **Knock-back.** A rising column throws whatever is on its top.
- **Light.** Your torch burns steady inside, a tell you carry.

**Rule 0.**
- **An elevator.** Ride a felled column while the line rights it: a 10 m
  lift to a ledge you couldn't reach. Jump at the top.
- **A swing on demand.** Bait the Olmec into pouncing near the bob so the
  swing carries it over the column you need standing (or over the bridge
  you need gone, under him).
- **Shelter.** Stand under it to deny his pounce.
- **The risk.** You lose your long jump, your roll and your slam there too.
  The escape that needs a long jump isn't there.

**Co-op story.** One friend, swatted and tumbling for the rim, is snapped
bolt upright on the last metre as the plumb swings by. The other is on the
column it then stands up, and rides it into the dark ceiling yelling.

**Counterplay & fairness.**
- The line is always visible, and its arc is slow and predictable.
- A righting takes 3 s and grinds before it starts.
- It never does damage itself.

**Where it lives.** Over colonnades and felled-pier courts, near the
Olmec's breakables. One or two per layer, on any layer.

**Build cost: M.** A pendulum and a zone flag that denies moves on the
motor and the body. The righting is a reverse tween on broken pieces,
which needs the breaks to keep the pose they stood in (they almost do). It
is L if righting live rigid bodies is fussy.

**Cliché check.** The nearest are gravity and anti-gravity zones. A zone
that takes away your posture, and rebuilds by straightening, is not stock.

---

## a4-courtiers: The Bowing Court — "They bowed to the king's step. They bow to anything now."

Columns that lean one notch toward every loud noise, and never lean back.

**Look & movement.** A double row of basalt columns. Each is carved with a
courtier in low relief, hands crossed on the chest, facing the aisle. They
stand on rounded drum feet in sockets worn smooth from a long time rocking.
Each loud noise in earshot tips every column one notch (about 6°) toward
it, with a grinding click. The lean stays.

**The strange rule.** **The court remembers every sound.**
- A column takes one notch toward each noise and never takes it back.
- Past the fifth notch it falls (the existing pier break) along its lean.
- You learn it by slamming in the aisle to break a fall. Both rows bow in
  over you, and on the next landing they come down.

**Tell.**
- **Fresh stone.** A crescent of unweathered stone shows at each column's
  foot on the side it has tipped from, so the width of the crescent is the
  count.
- **The last notch.** A column on its last notch trickles grit at every
  sound and shivers.
- **A map of noise.** From the high camera, the tops of the columns make a
  pattern that points to where the noise came from.
- **Sound.** After each noise, the court answers with a chorus of clicks.

**States / escalation.**
1. Upright.
2. Leaning, one to four notches.
3. The last notch: it shivers.
4. Fallen: a felled column, a bridge or a ramp per city-breaks.

A falling column is itself a loud noise. The others lean toward it, so the
court cascades in the direction of the first fall: dominoes with intent.

**Hooks.**
- **Sound.** The court listens to the shared noise bus.
- **The Olmec.** His landings, mantles and pounces lean the court toward
  him. Lure him to stamp in the aisle and the court comes down on him (the
  destruction system's hit-stop and stagger).
- **Breakables.** It is the break system with a memory.
- **The Sleeper.** Every fall feeds a2's ledger if one is near.
- **Knock-back.** The falls and their pieces.

**Rule 0.**
- **Build your own bridge.** On the near rim, slam a few metres back from
  the edge. The far columns lean, and then fall, toward you across the gap.
- **Bury him.** Draw the Olmec into the aisle and let his own pounce
  finish the last notch.
- **The risk.** Columns fall toward the noise, so toward you. You have to
  slam and then move. If the Olmec lands somewhere else in between, the
  lean you counted on is spent the wrong way.

**Co-op story.** Two friends steered one column like a planchette, taking
turns to slam from either side of it to walk its lean round onto the gap.
Then one of them fell off a ledge and landed hard, and it came down on
both of them.

**Counterplay & fairness.**
- Move quietly: rolls, hangs, no slams.
- Read the crescents before you cross.
- A column never falls without a shiver on the notch before.

**Where it lives.** The felled colonnade motif from round 3, and any
processional aisle. One court of 6 to 12 columns per layer, on any layer.

**Build cost: M.** The breakable piers exist. It adds a notched lean, a
listener on the noise bus, and the fresh-stone crescent in the shader (a
mask on the base).

**Cliché check.** Dominoes and collapsing pillars are stock. What isn't is
the memory (the leans add up and never reset), and steering a fall with
your own noise.

---

## a5-earth-mouths: The Earth Mouths — "Eats the heavy, keeps the order, gives back the eldest first."

Carved earth-monster doorways that swallow dead weight and share one belly,
so feeding one makes another spit out the oldest thing inside.

**Look & movement.** Cave-mouth reliefs in the cliffs and plinths, after
the Chalcatzingo maw: a profile jaw of curled scrolls, big enough for the
Olmec to stoop into. The throat is smooth and black. A bar-and-dot numeral
is carved over each one, I to V. The mouths don't move until they eat or
spit. Then the lip grinds open a hand's width, and pale mist curls out
along the carved breath scrolls.

**The strange rule.** **They eat only dead weight, and all the mouths
share one belly, first in, first out.**
- **Dead weight.** That means the Olmec, fallen stone, a stunned wanderer
  and, once carrying exists, a wanderer with his hands full.
- **Awake, you're safe.** If you walk in awake, nothing happens: it's just a
  dark alcove.
- **The queue.** Feeding mouth *n* makes mouth *n+1* spit out whatever has
  been in the belly longest. With the belly empty, that is a straight
  passage.
- **You learn it** when you're swatted, stunned, into mouth II, and spat
  out of mouth III on a cliff face over the void, still tumbling. Or you
  roll a drum in and, from the mouth beside you, out comes the Olmec it ate
  three minutes ago.

**Tell.**
- **The gulp.** Something being eaten sounds as a deep layer-wide gulp, so
  you know the queue moved.
- **Mist.** It thickens on the mouth that is about to spit.
- **A full belly.** A mouth holding something breathes a slow mist all the
  time, so the mist on all the mouths shows how full the belly is.
- **Numerals.** They tell you where things come out, once you've learned
  the rule.

**States / escalation.**
1. Empty belly: a pure passage.
2. Holding: a queue of things.
3. Overfull: four or more things. Each meal now makes the next mouth spit
   two. Rubble comes out of a high mouth as a scree pile, sometimes a ramp
   that wasn't there.

The Olmec comes out laid on his back for 3 s, then hunts from wherever he
landed.

**Hooks.**
- **The Olmec.** Feed him to a mouth to be rid of him for a while. You
  know where he'll return, but not when.
- **Stun.** Any knock near a mouth is a possible trip, and a swat is a
  teleport.
- **Breakables.** Pieces broken near a mouth fall in, so the queue fills
  with rubble that lands somewhere else in the city.
- **Carrying** (later). A full pair of hands is your ticket in.

**Rule 0.**
- **A shortcut.** Get yourself stunned on purpose (a 6 m fall into the
  mouth) to ride the belly to the next mouth up, 30 m higher.
- **The risk.** You're last in line. If the Olmec is in the belly, he
  comes out first, at the mouth you're about to come out of. You land
  stunned in front of him, unless your poise saves you.

**Co-op story.** "I went in. HE came out." One friend dives in. The other,
waiting at mouth III, watches the jaw open, and the Olmec slides out onto
the ledge beside him. The diver comes out of the same mouth a breath
later.

**Counterplay & fairness.**
- Awake you are never eaten.
- Read the mist and the numerals.
- Don't fight near a mouth unless you mean to.

**Where it lives.** Cliffs and plinth faces, spread up the climb. 3 to 5
mouths per layer, numbered upward. From the first layer: simple to read,
deep to use.

**Build cost: M.** Trigger volumes with a dead-weight test (the Olmec,
rigid pieces, the motor's stun state), a FIFO, a teleport out with a toss
(`PilotMotor.toss` and the head's blast-out exist), and the mist and gulp
cues.

**Cliché check.** Linked doors are stock (warp pipes, portals). The queue
isn't: what comes out is the eldest meal, not you. That makes every trip a
trade.

---

## a6-ceiba-roots: The Thirsty Roots — "The tree drinks fire; the floor goes where it drinks."

Ceiba roots under the paving heave the slabs up toward any flame, and drop
them all the moment it goes out.

**Look & movement.** Pale, smooth, thigh-thick roots of a ceiba whose
trunk is never seen. They come down the city walls out of the dark and run
under the paving. When they move, the slabs over them lift, tilt and stack
into a rough stair, showing raw earth and white root beneath. They move
slowly, about 10 cm/s, with creaks and wet pops. They never grab, coil or
reach for you: they lift the floor, nothing more.

**The strange rule.** **The roots climb toward fire and carry the floor
with them, and when the fire goes out they let go.**
- **What draws them.** Any lit flame in reach: a cresset, a beacon, a
  runnel's end, and your own torch once you've stood still with it for 2 s.
- **How fast.** The nearest field heaves a slab stair toward the flame, in
  about 20 s to full height.
- **When it's doused.** Everything they lifted drops at once.
- **You learn it** by hiding on a root stair you built with your torch.
  You douse the torch so the Olmec won't see you, and the stair drops
  12 m out from under you.

**Tell.**
- **Flicker.** The stacked slabs shudder in time with the flame. A
  guttering fire shows as a stair sagging notch by notch.
- **The drop.** A let-go always starts with a 0.6 s full-body shudder.
- **From above.** Heaved slabs show dark earth and pale root, a scar
  pointing at its fire.

**States / escalation.**
1. Dormant: paving with root bulges.
2. Reaching: a fire in reach, the stair rising.
3. Holding.
4. Letting go.

A field that has reached the same fire three times thickens and stays: the
stair is root-bound for good. The run has left a route behind.

**Hooks.**
- **Light and the torch, the heart of it.** Standing still lit lifts you,
  but lit is how the Olmec sees you. Going dark to hide drops you.
- **Beacons.** Lighting a cresset builds a stair to it, and also calls
  every Olmec in its draw. He climbs your stair.
- **The Olmec.** Chased past a cresset, he barges it over (city-fires).
  A burning spill holds the stair. A dark bowl drops it.
- **Breakables.** His landing cracks heaved slabs.
- **Water.** Wading the hush trough douses your torch, which is a fast way
  to drop a field you're not standing on.

**Rule 0.**
- **An elevator.** Stand still lit under a high ledge and ride the slab
  up, then step off and go dark.
- **A drop on him.** Light a cresset, let the Olmec climb the stair to
  look at it, then get the fire out. The stair drops him back down the
  layer.
- **The risk.** Every lift is a lit, still wanderer: the easiest target
  in the game.

**Co-op story.** One friend is the lift operator, torch high and stock
still, while the other climbs the rising slabs to a rune ledge. The Olmec
spots the operator, who has to choose: run, and the climber's stair
falls, or stand and take the hit.

**Counterplay & fairness.**
- A drop is never instant (the 0.6 s shudder).
- Fires are visible and their reach is the same every time.
- Your torch only counts while you stand still.

**Where it lives.** Overgrown courts around cressets and the beacon
tower's foot. One or two root fields per layer, on any layer.

**Build cost: L.** A field of slabs as moving ground driven toward lit
`SightLight`s, with heave poses solved per fire and eased. It also needs
root growth visuals and the let-go timing.

**Cliché check.** Growing-plant platforms are near stock (the beanstalk,
deku sprouts). What's new is that it's the floor, that it's driven by the
same light that gives you away, and that it lets go when you hide.

---

## a7-restorer: The Restorer — "Mends what was broken. Takes its ladder home."

A kneeling mason that puts the Olmec's ruins back, building a stair of new
stone to reach each piece and taking the stair down behind it.

**Look & movement.** A kneeling basalt figure two wanderers tall, after
the San Martín Pajapan lord bent to lift his bar. Its face is worn smooth,
and it carries a greenstone mortar bowl on its back and a hammerstone in
its right fist. It goes on its knees and knuckles, a heavy patient shuffle
at about half your walk, and it never hurries. It ignores you. It knows
where every stone belongs.

**The strange rule.** **It builds a stair to anything out of place, sets
the stone back, then comes down taking the stair away behind it.**
- **The stair.** The blocks are new, pale and unweathered. It lays them
  one tap at a time from the fallen piece's resting place up toward where
  the piece stood.
- **Setting.** It lifts the drum or lintel back, through anything in the
  way.
- **Coming down.** It turns and comes down, lifting out each block as it
  goes. It does not stop for you.
- **You learn it** halfway up its scaffold to a high ledge, when it turns
  round above you and the steps start disappearing toward you.

**Tell.**
- **Tapping.** One tap per block, heard across the layer, with a rhythm
  you learn.
- **New stone.** The blocks are the brightest stone in the city, so they
  read instantly from the high camera.
- **The turn.** Before it comes down it rises, sets its hammerstone in
  the mortar and turns on its knees, a full 2 s.
- **Setting.** Before it sets a piece it raises the piece overhead and
  holds it for a beat.

**States / escalation.**
1. Kneeling: still as a statue near the most breakable place.
2. Following: trailing the Olmec's breaks at a distance.
3. Building.
4. Setting.
5. Taking down.

If the Olmec smashes it, or its scaffold, it lies in pieces for 10 s, then
gathers itself back up, block by block. It is the most uncanny thing in
the city, and from then on it builds faster.

**Hooks.**
- **Breakables, the heart of it.** Every Olmec break becomes a temporary
  route a minute later.
- **The Olmec.** It undoes his felled-column bridges and ramps. Its
  tapping is a sound he goes to, so he wrecks what it builds, and it
  rebuilds. That loop moves both of them round the layer.
- **Knock-back.** A setting piece shoves anything in its place, and a rim
  makes that deadly.
- **Runes.** Some runes sit on broken capitals that only its scaffold
  reaches, for a minute.
- **Carrying** (later). Carry a drum away and it follows you, building
  toward you, step after step up any cliff. The best and worst escort.

**Rule 0.**
- **Make it build for you.** Lure the Olmec into breaking a column on a
  high ledge. The Restorer then builds a stair from the low court up to
  it. Climb the stair while it works, and get off before it turns.
- **The risk.** Its tapping brings the Olmec back to the scaffold you're
  standing on.

**Co-op story.** Both friends race up the scaffold behind it. It turns.
One jumps off onto the colonnade. The other rides it down, step by
vanishing step, and the last block goes 4 m above the floor.

**Counterplay & fairness.**
- It never hunts and never hits on purpose.
- The turn and the hold are long, readable beats.
- Its stairs are always the pale ones.

**Where it lives.** It kneels by the layer's most breakable motif (a
colonnade, a column bridge). One per layer, from the second layer up.

**Build cost: L.** A new slow kneeling walker with a simple gait, a block
scaffold laid along a solved path and taken down in reverse, piece records
so breaks can be set back, and hand IK to lift and set.

**Cliché check.** A stair-builder is Lemmings' builder, and that part is
plainly stock. What's new is that it's fed by the Olmec's destruction, it
ignores you, and it takes its stair home.

---

## Cut during drafting

- **The turning stair** that swings its foot toward whoever stepped on it
  last: a rotating platform with a gimmick.
- **The scales**: two plazas on one beam, weighed by the Olmec. It's the
  seesaw, which exists (traps-round2-seesaw).
- **Shy doors** that close when the Olmec looks at them: a coil-head
  reskin.
- **Mason ants** carrying stones in a column: a mob pack.
- **The sinking isle** that settles under weight: a crumbling or sinking
  platform, stock.
- **The mask that latches onto the wanderer**: "latch on, shake off", which
  the user rejected.
- **Counting steps** that rise one per rune carried: thin, and it overlaps
  the Tithe-Taker.
- **Overlap note.** a3 (Plumb) and a7 (Restorer) both undo the Olmec's
  breaks. If only one goes on, keep a7 for the routes it makes, or a3 for
  its posture rule.
