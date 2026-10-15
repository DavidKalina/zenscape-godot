# Round 4, lens 1: things that hunt you

Seven hunters for the underground Olmec city, each with one strange rule.
They're built to sit beside one or two Olmecs per layer, not to replace him.
They cover what he can't do: he can't enter your walker-only lanes, he
forgives standing still in the dark, and he ignores your runes. Each card
says how it meets him.

Real verbs used below are the motor's (`scripts/pilot_motor.gd`): run (4.8
m/s), walk (2.4), jump and pump (0.8 / 1.5 m), long jump, slide, crouch,
wall kick, wall run, twirl, ledge grab, hang and shimmy, swim, the pocket
sail, the slam, the roll and tech, `knock`, `seize`, `downed()`, `harm`.
The torch is the underground look's `torch` node, read by `LightLevel`.
Falls stun from 6 m.

---

## h1-sunkeepers: The Sun-Keepers — "Set here to hold the sun up. Nobody came to say it had gone."

They can only stand where light falls, and the torch in your hand is light.

**Look & movement**
- Tall, thin figures of lime plaster over clay, about 1.5 times your height.
- The white is flaking away in maps to show ochre clay. Each wears a disc of
  hammered mica for a face, so it has no features, only your torch
  reflected back at you, pale and small.
- They walk like people crossing a river on stepping stones. Each step is
  planted, the weight is shifted, and the back foot is lifted in a stork
  hold that's kept a beat too long.
- At the rim of a lit patch they stop with one foot raised over the dark and
  wait like that, swaying.
- Where no light reaches them, they freeze mid-step as statues.

**The strange rule.** They can't stand in the dark. Any foot that lands on
unlit floor doesn't hold. Your torch throws a pool about 8 m across, and they
can walk right into it. Put the torch out while one is inside your pool and
it has nothing to stand on: it topples where it is, stiff as a plank.
- On a floor, that's a plaster crash and a heap that wakes again when lit.
- Over a gap, it falls and is gone.
- You learn the rule when one walks up your torchlight across a causeway and
  shoulders you off it.

**Tell**
- Sight: the mica discs flash with your own torch from 20 m or more, a
  cluster of small pale coins in the dark, and they all turn toward it.
- Sound: a dry plaster creak on every planted step, and a fine hiss of
  sifting lime when they wake.
- From the high camera you see a row of white figures waiting along the edge
  of a lamp's circle, one foot up.

**States / escalation**
1. Asleep in the dark.
2. Woken by light, they walk toward the brightest pool they can reach.
3. They reach for the torch. A shove costs 1 heart and knocks you back.
4. The second time one touches you, it takes the torch and holds it high. It
   now carries its own sun.
   - It walks up through the layer toward the highest point it can reach.
   - It's a moving lit beacon, so every Olmec in draw turns to it.
   - You're dark until you get the torch back, either by knocking it off a
     ledge, which drops the torch, or by dousing a cresset under it.

**Hooks**
- *Light*: the torch, cressets, way lanterns, the runnel and the sun-mirror's
  beam all make floor for them.
  - Lighting a cresset across a gap builds them a road.
  - The sun-mirror's beam is a narrow bridge of light, and they walk its
    footprint exactly.
- *The Olmec*: he hunts by light, so the torch-thief is a decoy you didn't
  choose, or one you did. Chased past a cresset, he barges it, the light
  goes, and every Keeper on that floor topples.
- *Breakables*: a toppled Keeper is a heap that becomes a step.
- *Edges*: the knock is a plain shove, deadly only near a rim.

**Rule 0 (as a tool)**
- Let one walk into your pool on a bridge, then hide the torch, and it drops
  into the void.
- Let one steal the torch so the Olmec chases a white figure up the
  pyramid while you climb the dark side.
- The real risk: with the torch hidden you're blind. Mid-crossing you can
  see only what other fires light, and the bridge is narrow.

**Co-op story.** "Keep your torch lit. Walk." The other one waits at the
far end, and when the Keeper is halfway across the light, she says "now."
Your torch goes out and you're standing blind on a 2 m causeway while it
falls past you.

**Counterplay & fairness.** Their speed is a walk. The flashing discs
read from far off. Dark costs nothing but sight, and cresset light shows
where they can go. You die because you kept your torch lit as they came on,
or put it out where you couldn't see your feet.

**Where it lives.** Dark galleries and lantern-lit causeways over the
void, in households of 3 to 5 beside an unlit cresset. One household a
layer, from layer 2.

**Build cost: M.** A thin new model with a short clip set (step, stork
hold, topple, reach). The rule is `LightLevel.exposure` sampled at each
foot target, which already exists. The torch steal is **L**: it needs the
torch as a separate object, which leans on carrying.

**Cliché check.** The nearest stock pattern is "monsters that move only in
the light or dark" (Boo, the coil-head inverted), and that's partly stock.
The twist is that light is their *ground*, not their go signal: it's
spatial and over the void, so you build or take away the floor they walk.

---

## h2-second-walker: The Second Walker — "Came in by the same door you did. Has no road of his own."

A clay figure your size walks your exact path, every foothold in order,
eight seconds behind you.

**Look & movement**
- A hollow white-slipped clay figure in the Olmec "baby" style (the
  Las Bocas ceramics): puffy limbs, a heavy head, a serene, slightly
  open mouth.
- It does your moves (your run, pump, wall kick, ledge hang, shimmy and
  mantle), but in fired clay. It's a touch stiffer, and lands with a hollow
  *tok* and a squash that doesn't quite spring back.
- When it waits, it sits in your last pose. At rest it sits cross-legged
  in a niche with its hands on its knees, facing the way you came in.

**The strange rule.** It walks your footprints. It isn't a ghost on your
positions, though: it's a body that puts its feet where yours touched, in
order, with your timing.
- Stand still for eight seconds and it arrives where you are and steps into
  your place: a heart and a knock.
- If the floor under one of your footprints has gone since you stood there
  (a slab dropped, a column broke, a lintel fell), it takes the step anyway
  and falls.
- You learn the rule by hiding in a refuge niche from the Olmec. You're safe
  from him, and then the clay hand comes over the lip of your niche.

**Tell**
- Sound: your own footsteps come back to you eight seconds late in clay.
  Each landing is a hollow knock and each grab a dry scrape.
- Sight: a pale figure re-doing your last climb. From the high camera you
  can watch it hang where you hung.
- When the gap is closing it walks faster on your trail, and its knocks come
  closer together.

**States / escalation**
1. Seated in its niche. It wakes when you walk past it.
2. Walking your trail eight seconds behind.
3. Catching you. Then it sits down on the spot for 4 s, which is your head
   start, and gets up again.
4. Each catch shortens its delay: 8 s, then 6, then 4.

**Hooks**
- *The Olmec*: this is his counterweight. He's beaten by refuges, stillness
  and waiting him out, and the Walker forbids all three.
  - It makes your sounds late, so a headless body listening goes to where
    you *were*. That's half a decoy.
  - In his sight it reads as a walker, so he swats it, and it breaks into
    clay sherds.
- *Breakables*: anything you cross and then break kills it: the loose
  voussoirs, the drum floor, a column you lure him to fell after you.
- *Walker-only lanes*: it follows you into all of them.
- *Edges*: if you were knocked across a gap, those were your footprints too,
  and it can't be knocked. It walks off the rim where you flew and falls.
- *Runes*: it ignores them.

**Rule 0 (as a tool)**
- Run the slab row, slam the cracked slab behind you, and it does your jump
  onto nothing.
- Lead your trail past the Olmec's swat, so he breaks it.
- The real risk: you have to keep moving, and the clever kill means slowing
  near something deadly, eight seconds ahead of it.

**Co-op story.** It follows whoever woke it. "Wait for me at the gate" is
the worst thing you can say. He waited, and his own clay self came up the
stair behind him, while you watched from the ledge, unable to tell him in
time.

**Counterplay & fairness.** Eight seconds is a long, loud, readable leash.
You hear yourself coming. Every catch is you standing still while hearing
your own footsteps getting closer.

**Where it lives.** A seated niche on a long climbing route, one a layer
from layer 2, never more than one awake at a time.

**Build cost: M.** It reuses the wanderer's rig and move clips in a clay
skin, plus a footprint and pose ring buffer, and drops at each step only if
the step's floor ray misses. There's no AI. The h5 and h7 cards share this
footprint buffer.

**Cliché check.** Plainly, the nearest is Mario Galaxy's Cosmic Mario (a
copy on your path), and following your path is stock. What isn't stock: it
falls through a world you changed behind you, and it's the hard counter to
hiding from the Olmec.

---

## h3-echo: The Echo — "Never once spoke for itself. Said everything twice."

It repeats every sound it hears four seconds late, from where it stands,
with the weight of the original.

**Look & movement**
- A tall clay urn in the Zapotec effigy-jar way, chest-high on you. A
  seated figure is moulded onto its front, and the mouth is a round hole
  rimmed like a conch's lip.
- It's unpainted and soot-dark inside the mouth.
- It moves by rocking on its round base, tipping side to side like a full
  jar being walked across a floor.
  - Each rock is a key pose with a hold.
  - It's heavier on the downswing, and its lid jiggles as follow-through.
- It makes no sound of its own: not a scrape, not a footfall.

**The strange rule.** Four seconds after it hears something, it says it
again from where it stands, with the original's force. It then walks
toward where it first heard it.
- Your footsteps come back harmless.
- A slab you slammed comes back as a slam ring.
- An Olmec landing comes back as a real shockwave, thrown out from the jar.
- You learn the rule when the Olmec lands 30 m away, you relax, and four
  seconds later the same thump hits you from the urn beside your ledge.

**Tell**
- Its silence. On a noisy layer, a thing that rocks toward you without a
  sound is wrong.
- Before a repeat, the urn swells: the clay creaks, the lid lifts, the body
  leans back. A heavy repeat holds that pose longer (0.4 to 1.0 s, by
  weight).
- Dust puffs from the mouth as it speaks.
- You hear your own sounds return, displaced.

**States / escalation**
1. Silent and still.
2. Listening (it turns its mouth toward sound), then repeating, then walking
   to the source.
3. Each repeat cracks it a little. Two Echoes in earshot of each other
   repeat each other, each time a little louder.
   - The feedback runs until one shatters in a burst that breaks nearby kit.
   - Every repeat in that loop also calls the Olmec.

**Hooks**
- *Sound and the Olmec*: the headless body and the whole Olmec hear its
  repeats as they would hear you.
  - It's a herald that walks toward you, bringing him along.
  - It's also a decoy, if you make your noise somewhere you aren't.
- *Breakables*: it can record an Olmec shockwave beside a cracked column
  and break it.
- *Edges*: its repeated shock near a rim is a full Olmec shove, without
  the Olmec.

**Rule 0 (as a tool)**
- Slam the drum floor on the far side, then climb away quietly. The urn
  rocks there, repeats the slam, and the Olmec goes to it.
- Let it hear him land beside the column you want felled, and stand clear.
- The real risk: everything loud you do is coming back near you, louder.

**Co-op story.** Two urns at either end of the court. You slam once by
accident. For the next half minute the plaza is a ringing match between
them, the Olmec turning back and forth like a man at a ball game, and your
friend crosses under him while you hold your breath on the stair.

**Counterplay & fairness.** Be quiet near it. Walk, don't slam. Watch for
the swell. A jump clears the shock ring, as it does the Olmec's. It moves
at a slow walk.

**Where it lives.** Courts, ball courts and colonnades, where sound
carries. One or two a layer from layer 1; a pair is a layer 3+ set piece.

**Build cost: M-L.** A simple model and rocking rig. It needs a general
sound-event bus, with your noises and his landings as events with a
weight. The Olmec's hearing is the head's call channel today, so that needs
widening. The repeated shock reuses the body's shockwave.

**Cliché check.** The nearest is the stealth game's thrown-bottle decoy,
and decoys are stock. What isn't: it's alive, it closes on the source, and
the repeat carries the force of what it heard.

---

## h4-jade-mask: The Jade Mask — "Whatever wore it, got up. Whatever it left, lay down."

A greenstone mask that leaps to the largest face it can see and makes
whatever wears it move.

**Look & movement**
- A real Olmec mask: mottled blue-green jadeite, a serene down-turned mouth,
  and drilled eyes with nothing behind them. It's sized for a giant, about
  1 m.
- It moves like a dropped plate. It rolls on its rim with a wobbling ring
  of stone on stone, and slows into a tighter and tighter spin, like a coin
  settling.
- Then it springs up face-first with a click onto its new host.
- Hosts move in their own idiom:
  - A stele figure takes stiff steps.
  - A relief lord leans out of his wall.
  - A carved pillar sways and then leans all the way toward you.

**The strange rule.** It always goes to the largest face in its sight.
- That means the stele's, then the relief's, then, once he's whole and in
  view, the Olmec's own head.
- The headless body has no face, so it ignores the body, until the head
  is back on.
- You learn the rule when you knock the mask off a statue, sure you've
  won, and it rolls across the court to the bigger face of the relief over
  your climb. The wall starts to lean.

**Tell**
- Sound: the rim's ring rolling. Before a leap it stands on its rim,
  wobbling, aimed at its pick for 0.8 s.
- Sight: the jade catches torchlight with no glow of its own. On a host
  there's dust shed from the stone, and the carving's eyes go dark behind
  the holes.

**States / escalation**
1. Lying face down.
2. Rolling and seeking.
3. Worn. The host hunts you at its own pace and shoves (1 heart).
4. Shaken loose. It aims, then leaps.
   - Worn things wear out: after about 30 s the host cracks and crumbles and
     the mask moves on.
   - The masked whole Olmec forgets beacons and his head's calls. He
     hunts you silently and never stops to look at a fire, until a hard
     landing shakes the mask loose.

**Hooks**
- *The Olmec*: you choose whether he wears it.
  - A masked Olmec is worse in a chase, but his own leaps shake it off.
  - If a stele's face is in view when it comes loose, the mask lands
    there, not on you.
- *Breakables*: a masked pillar leans toward you. Make it lean across a gap
  and it falls as a bridge.
- *The relief*: a masked relief lord leans out, and his arm becomes a ledge
  for one crossing.
- *Edges*: host shoves near rims.

**Rule 0 (as a tool)**
- Stand so the pillar beside the gap is the biggest face the mask can see,
  then knock it off its stele. The pillar leans to you, over the gap, and
  falls: a bridge.
- The real risk: you're standing where something heavy is falling, and any
  bigger face that turns up (him, coming whole over the rim) takes the mask
  first.

**Co-op story.** "Get it off the statue!" She twirls into the stele's face,
the mask rolls, wobbles, and aims, and you both watch it choose. It goes
past you, past the relief, up to the Olmec's head as he comes over the
brim. He doesn't look at the bonfire you lit for him. He turns around.

**Counterplay & fairness.** The aim hold is long and points at its pick.
Hosts move slowly. A jump-twirl into the host's face or a slam beside it
knocks the mask off. You die because you knocked it loose with a bigger
face in view.

**Where it lives.** Stele courts, relief cliffs and colonnades of carved
pillars. One mask a layer, from layer 2, and only where there are at least
three faces to choose from.

**Build cost: L.** The mask prop and its roll and leap are small. The cost
is the hosts: every carved thing needs a masked behaviour.
- v1 slice: pillars, which lean and fall using the destruction system, and
  the whole Olmec, whose mask mode is his chase with beacons and calls off.
- Statues that walk come later, at XL.

**Cliché check.** The nearest is the body-hopping parasite (a possession
ghost, the headcrab), and possession is stock. What isn't: its choice is
the largest face, its hosts are the architecture, and its best use is
building a bridge.

---

## h5-tithe-taker: The Tithe-Taker — "Asked for nothing. Took the difference."

A stone porter that follows the richest of you at a distance your runes
set: every rune you carry brings it a stride closer.

**Look & movement**
- A tameme, the Mesoamerican porter, carved in basalt and bent nearly double
  under a tumpline strap across its forehead.
- Two netted baskets of old runes ride its back. They're the tithe of
  wanderers before you, dull and dusty.
- It moves at a steady porter's trot that never hurries. The load sways a
  beat behind every step, and when it stops, the baskets settle with a
  rattle.

**The strange rule.** It follows at a leash whose length is what you
don't carry.
- Start of layer: 40 m. Each 5 runes on the richest player costs 1.5 m (to
  be tuned to the layer's scatter).
- When the leash runs out, it's beside you and takes its tithe. It
  swings the baskets on the strap: 1 heart and a knock, and a third of your
  runes spill across the floor, rolling.
- Then it walks back to its new, longer leash.
- You learn the rule when you open a chest on a ledge and it's suddenly
  there.

**Tell**
- Its distance is your greed, shown in the world. Glance back and you know
  how rich you are.
- Sound: the baskets' rattle grows as its own haul grows.
- Before a tithe it stops, plants, and dips its head to let the strap
  swing back (0.7 s), with the anticipation pose held.

**States / escalation**
1. Seated by the layer's start under its load.
2. Following at the leash.
3. Tithe swing.
4. Heavier. Each tithe adds to its baskets: it's noisier and slower, and
   its stride on a drum floor or loose voussoirs is closer to breaking it.
   - Pay it on purpose by walking into the baskets and it takes half without
     a blow, then sits for 60 s.

**Hooks**
- *Greed and runes*: it's the price of the risky line, paid in the world.
- *Sound and the Olmec*: its baskets rattle louder the more it's taken. A
  rich porter is a noise the headless body hears, walking always just
  behind the richest player.
- *Breakables*: heavy with tithe, it breaks a cracked floor it walks onto.
- *Edges*: spilled runes roll toward rims, the clearest greed test the game
  can set.
- *Shared tech*: it walks your footprints at the leash, h2's buffer.

**Rule 0 (as a tool)**
- Load up on purpose so it follows you close over the drum floor, cross,
  and let its weight break the floor.
- If it drops onto a terrace below, rather than into the void, the baskets
  burst: every wanderer's tithe across the floor, the biggest haul on the
  layer.
- The real risk: to bring it that close you have to be rich, and one
  mistimed step is a swing and a spill at the rim.

**Co-op story.** It follows the richest, per player. "Don't pick anything
up, let it come to me." One friend hoards and leads it on a dance. The other
picks the layer clean behind them, until he grabs one rune too many and it
turns, mid-step, and walks to her.

**Counterplay & fairness.** Its distance is always on screen. The trot
is slower than your run. The swing has a long, low wind-up you can jump
over. Poor players are never touched. Every hit is a rune you chose to pick
up.

**Where it lives.** Rune-rich layers: one porter a layer from layer 2. It
starts at the layer's start, so it's the first thing that tells you greed
costs.

**Build cost: M.** A new model (body, strap and baskets with
follow-through) and a trot rig. The logic is the footprint buffer at a
distance, plus spilling runes as pickups and a weight on breakables.

**Cliché check.** Spilling your coins on a hit is stock (Sonic's rings), and
that part is. What's new is that the hunter's *distance* is your greed, and
its weight is a tool against the floor.

---

## h6-bearers: The Bearers — "Four to carry and one to be carried. They are still one short."

Four little stone bearers and an empty litter. They carry off whatever
lies down, up the city to a brink, and tip it off.

**Look & movement**
- Four squat basalt men, chest-high on you, with a stone litter on poles
  across their shoulders. The seat is worn smooth, with a carved cushion,
  and it's empty.
- They move in lockstep, four heads turning as one.
  - They shuffle-trot with the poles bouncing (squash on each step) and the
    litter swaying a beat late.
  - They kneel all together, with a 1.0 s anticipation hold.
  - They rise with a grunt in four parts.

**The strange rule.** They carry off whatever lies down.
- That covers a fall stun, a swat that puts you down, a tumble, and a shock
  that throws you.
- The moment you're `downed()` and they're within their dash, they run in,
  kneel, and slide the litter under you. You're lying in state, and they
  run.
- You can jump off at any time, but they run fast and take you over the
  narrowest bridges, so it's a choice to make.
- Their destination is a brink: an altar lip high up on the layer. There
  they kneel forward together and tip the seat out.
- You learn the rule when the Olmec's swat lays you down at 1 heart, you
  think "I'm alive", and four men carry you away.

**Tell**
- They trail the Olmec at about 15 m, waiting like gulls behind a plough.
  When anything falls, all four heads turn to it.
- Sound: a four-beat stone clack, and pole creak.
- The tip at the brink: they stop, plant, and kneel (1.0 s), and the seat
  tilts. Jump in that window.

**States / escalation**
1. Idle near the Olmec or a fall.
2. Dash to the downed.
3. Carrying, along their own lane.
4. Tip at the brink.
5. After a tip they walk back down, empty.
- If they carry a lit thing, they become a walking beacon.

**Hooks**
- *The Olmec*: they make his swats and shockwaves deadlier, but they work
  his lanes, and he barges what's in his way. A litter he barges spills.
- *Stun and falls*: they're the price of a sloppy landing. A roll or a tech
  denies them.
- *Light*: a toppled cresset bowl lies down, so they carry it lit, moving
  his attention along their route.
- *Other hunters*: a toppled Sun-Keeper or a fallen Jade Mask lies down
  too, so they carry the mask away.
- *Carrying*: they're the first thing in the game that carries, and a test
  bed for the carrying round.

**Rule 0 (as a tool)**
- Lie down on purpose: take a 6 m fall without rolling in front of them and
  ride the litter up their lane. It's a free lift up the epic stair.
- Jump off one ledge short of the brink. That's height and time saved.
- The real risk: a fall-stun is a stun, they cross the void bridges, and
  the jump-off window is one kneel long.

**Co-op story.** He got swatted at the top of the drum stair, and before he
was up they had him. You chased the litter along the causeway shouting
"Not yet, not yet. NOW!" and he jumped at the kneel, onto the gate ledge,
first through.

**Counterplay & fairness.** Don't lie down near them: roll the landing
or tech. The kneel is long and plain. They can't hurt you. Only the brink
and the drop do, and both take your own choice to stay on.

**Where it lives.** With the Olmec. One crew a layer from layer 2, paired
with an Olmec and with a brink on the layer.

**Build cost: M-L.** A five-part model with a lockstep rig, and the
litter is a moving floor, which the serpent round built. The scoop is
`seize` on a downed motor. The tip is a tilting platform, as in the seesaw
round. Pathing to the brink uses body routes at walker size.

**Cliché check.** The nearest is Zelda's Wallmaster, which carries you back
to the start, and that's partly stock. The difference is that only the
fallen are taken, it's a lift *up* as well as a threat, and when to get off
is your call.

---

## h7-mirror-twin: The Mirror-Twin — "Stands behind the line just as far as you stand before it."

A basalt figure your size moves as your reflection across a line of
mirror stelae. Break the line and it steps through.

**Look & movement**
- A row of stelae, each set with a polished concave mirror of magnetite.
  These are real Olmec mirrors, dark iron-grey with a soft bronze sheen,
  never black glass.
- The twin is a kneeling-ruler figure your size in the same weathered
  basalt, a smaller mirror on its chest.
- It moves as you do, mirrored, a hair late, with stone weight: your run,
  your jump, your pump. It lands heavier, with a grinding slide where your
  boots skid.

**The strange rule.** While the line stands, it can only be where your
reflection would be.
- Walk at the line and it walks at you. You meet at the line, and it hits
  first (1 heart, knocked straight back).
- Where its side has no floor under your reflection, it falls.
- When a stele breaks, the line opens. It steps through and is free: a
  hunter your size, with your moves, that climbs your walker-only lanes.
- You learn the rule when the Olmec smashes the mirror row chasing you,
  and the thing that was your reflection walks round the rubble toward you.

**Tell**
- Sight: you see yourself, mirrored, from the high camera. The pectoral
  mirror throws your torch back as a warm spot.
- Sound: its steps are your steps' rhythm in stone.
- Freed, it stops copying. It pauses, looks at its own hands for a beat
  (the key pose), and then runs.

**States / escalation**
1. Mirrored, while the line is whole.
2. Freed. It walks your footprints at your pace with no delay, and it's
   always closing.
3. Freed for 40 s, it slows and kneels, a statue again until a stele is
   rebuilt (never, so it's done).

**Hooks**
- *Light and the Olmec*: its chest mirror throws your torch back, so in the
  dark he sees a lit figure: it. He hunts the twin, which you steer with
  mirrored moves. It's a decoy on a joystick, but he's heavy and he breaks
  stelae.
- *Breakables*: the line is breakable kit, by him, by a slam, by a felled
  column.
- *Edges*: the twin's side of the court is cut to fall away where yours
  doesn't.

**Rule 0 (as a tool)**
- Drive it in the dark to lead the Olmec round the far side of the court
  while you climb. Or walk to the one spot where your reflection is over
  the void, and it steps off.
- The real risk: the closer he chases it, the closer he is to the stelae,
  and one barge frees it.

**Co-op story.** It only mirrors the first through the line. You make it
dance for him at the far rim. Your friend says "he's getting close to the
stones." You say "I know." He barges a stele, and you both watch your
reflection look at its hands.

**Counterplay & fairness.** Mirrored, it can't touch you unless you go
to the line. Freed, it pauses before it runs, and the mirror row's
condition is visible from the start. Every freeing is a stele you or
he broke.

**Where it lives.** A mirror court: a strip plaza with a line of five to
seven stelae down its middle, one side with a broken rim. One a layer,
from layer 3. It's a set piece, not a scatter.

**Build cost: M.** It reuses h2's clay walker in a basalt skin, with a
reflection transform. Freed, it uses h2's footprint buffer at zero delay.
The stelae are breakables and the mirror line is a plane.

**Cliché check.** Mirror-controlled twins are a puzzle-game staple, and
that part is stock. The new part is the twin as an Olmec lure that you
steer, kept on a leash that's breakable kit, which he breaks.

---

## Cut during drafting

- **The Weeper, again**: a statue that moves only when unwatched. That's
  the coil-head itself, and it's already `ideas-enemies.md` #6.
- **The heartbeat hunter**: it homes on the player with fewest hearts. That's
  a stock "hunts the wounded" pattern, and heart sacrifice is a tired
  Mesoamerican trope.
- **The shade-walker**: it walks only in shadow. Stock stealth inversion, and
  h1 does light better.
- **The jaguar pack**: a generic mob pack with a reskin. The brief rules it
  out.
- **The rune mimic**: a pickup that bites. A stock mimic.
- **The stash keeper**: fine until you touch its hoard. A straight copy of
  the hoarding bug, and h5 turns greed inside out instead.
- **The cord-stretchers**: two surveyors with a taut knotted cord that sweeps
  you off. It's a trap, not a hunter, so it goes to lens 4.
- **The mover-when-you-move statue**: Superhot. Stock.
- **The waking guardian**: a statue that wakes when you come near. The most
  stock enemy there is. h4 keeps the statues and drops the proximity.
