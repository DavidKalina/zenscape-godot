# Round 4, lens 4: traps in the Olmec idiom

Six fresh traps. None is a dart wall, spike pit, boulder or crusher. Each one
runs on a rule the player learns once, and each one can be pointed at the
Olmec. They avoid everything in `ideas-traps.md` (voussoirs, seesaw, censer,
drum run, sluice, vents, bell, gargoyle, jaw slot, windmill, mossy slope, ivy
fuse, keystone, catapult flag, orbit stones, rotten bridge, pennants, lintel
drop, mist shelf, plughole, cistern floor, courteous statue, hungry door) and
the round 1 and 2 calendar machines (timed rings, Tithe Wheel, Calendar Drum).

Three of the six are about **what the player's own light, sound or step does
to the place**. That is the thread: the trap is a mirror of your behaviour,
not a clock.

---

## t1-day-count: The Day-Count — "Time is kept here by feet. Stand still and it keeps nothing."
One line: a calendar floor of nested stone rings that advances one notch per
footfall by anyone, and not at all while everyone stands still.

Look & mechanism: a sunk calendar court, three or four concentric basalt
rings set in a pit rim, each ring cut with day-glyphs and a few gaps open to
the void (or to a sump a layer down). A bronze-free stone pawl-and-ratchet
under each ring. Rings turn on a rubbed stone race, with a grinding burr.
Worn grooves at the ring edges show where feet land. Dust sits in the glyphs.

The strange rule: **the rings turn on footfalls, not on a clock.** Each step
by any body on the floor (you, a friend, the Olmec) clicks the outer ring one
notch; every 2nd step clicks the next ring, every 4th the next. Jumping,
wall-running and hanging don't click. Standing still freezes the whole
machine, so it is a puzzle you can plan, played in your own steps. Players die
once by running across it and watching the gap they aimed at slide away.

Tell: a ratchet CLACK on each footfall, loud and rhythmic, and the ring
visibly jumps one notch. The glyph under the active ring is cleaned by
scrape marks. A deep thrum when the centre ring is about to align.

States / escalation:
- Idle: any ring still.
- Counting: rings advance with steps. Big strides (run) click once per 2 m,
  so a run covers the court in fewer clicks than a walk, which is the quiet
  trick that makes running the sane way across.
- Aligned (the calendar round: all gaps close up in one line): the centre
  hatch opens on the cache, and a roof-hole shaft above lets a long jump
  chain climb. It stays aligned for ten clicks and then re-skews.
- Skewed to the worst: all gaps line up as one straight chute down into the
  sump. The chute is the same moment the cache is open.

Hooks: the Olmec's stride (each huge step is a click, so a chasing Olmec
winds the machine fast and mangles your route); sound (every click is loud,
it carries to nearby hunters); greed (centre cache, rune ring); breakables
(a ring can be slam-cracked to jam it at the current notch); co-op (two
people stepping double-time it).

Rule 0 (as a tool): lure the Olmec into the court and he turns it to the
chute alignment with his own steps, then falls through or gets stuck below
(a cleared lane for you, or a sump to climb out of with his head nearby). Or
jam a ring by slamming a cracked rim while one friend holds a good alignment.
Real risk: the Olmec's footfalls change what you planned mid-jump. Landing on
a ring that just moved one notch is how you die.

Co-op story: one friend freezes, rigid, calling "don't move, DON'T MOVE"
while the other creeps to the cache; then the first cannot resist a tiny step.

Counterplay & fairness: nothing moves without steps, and every click is
loud. A freeze is always safe. The first gap is slow (a 1 s notch). A
jump-only route is visible at the rim (a 3 m ledge skirting it). The
alignment is shown by a glow in the glyphs, not by guessing.

Where it lives: a plaza floor, the sunk court of a mid-layer. One per
layer, tier 2 to 3. It reads as an echo of the calendar machinery, but it is
the first calendar that is moved by feet.

Build cost: M. Rings are rotating kinematic bodies; the clock is a step
counter fed by `PilotMotor` footfalls and the Olmec's gait callbacks.

Cliché check: the nearest stock trap is a timed rotating platform puzzle. This
isn't one: the time base is the player's own movement, so standing still is a
move, and the same machine is a Rule 0 gadget on the Olmec's footfalls.

---

## t2-copal-floor: The Copal Floor — "Each slab stands on a candle's worth of gum. Take the light away and it remembers it is soft."
One line: a floor of slabs held up on resin props that stay rigid only while
they are warm and lit, so a shadow across a slab drops it.

Look & mechanism: a long gallery floor of pale limestone slabs, each set on a
lattice of amber copal-resin blocks (the gallery's old incense gum). Resin
glints when lit, goes dull and sags under shadow. Open cressets and the
wanderer's torch keep it firm. Slabs have a hair gap between them and amber
beads sweating at the corners. No red glow; the light is the ordinary firelight.

The strange rule: **a slab is solid only while it is lit.** Cast a shadow on
it (for 1.2 s) and its props slump and it drops to the pit below. Your own
torch is held forward so you don't shadow yourself, but anything standing
between the torch and a slab does: a friend, a pillar, the Olmec, a block you
carry. Walk behind a friend and the slab you are about to step on goes.

Tell: an amber glint on the props; the moment a shadow lands the glint dies,
a dry creak starts (1.2 s warning), the slab's edge sags a few centimetres.
From the high camera the shadow shape is readable on the floor.

States / escalation: lit (firm); shadowed (creaking, 1.2 s); dropped (slab
falls). A fallen slab stays gone; the floor can be re-lit but never re-set.
Deeper galleries have only candle-lit pools between dark stretches.

Hooks: torch (the key: it is the only source that travels with you); light
(beacons and cressets firm up an area; dousing one is a trap setter);
the Olmec (his body casts a huge shadow); breakables (a cresset knocked over
lights a spill that firms the floor); co-op (two torches, or one torch and a
friend walking in front is a death); carrying (a big carried piece shadows).

Rule 0 (as a tool): douse the cresset when the Olmec crosses and the whole
span under him goes. Or stand him between you and a beacon and his shadow
drops the floor under him. Real risk: the dark of the floor is also the
Olmec's blind side, and you are halfway across holding nothing but your torch.

Co-op story: one friend runs ahead, the other's feet fall through the floor
that the first friend's body shadowed. They learn to cross side by side, then
one is hurt when the first steps wide.

Counterplay & fairness: the creak is a clear 1.2 s window; slabs under a
lit brazier never drop; the player can put their torch out (T) and the
slab firmness is lost only where the shadow already fell. A shadow only
drops one slab at a time.

Where it lives: an incense gallery or processional hall, a mid-length floor
crossing. One per layer, tier 2 to 3.

Build cost: M-L. Needs a light-occlusion test from the torch and each
`SightLight` to each slab (a few rays per slab per tick).

Cliché check: a collapsing floor is stock. The rule is not the collapse: it
is that the collapse comes from light, shadow and who walks in front of
whom, so it is a torch and co-op puzzle.

---

## t3-whisper-wall: The Whisper Wall — "Speak at the near end. It is the far end that answers."
One line: a curved stone wall that throws every sound from one focus to the
other, where a rest bench sits under a slab that shakes loose when it hears.

Look & mechanism: a long parabolic wall of fitted basalt with a smooth inner
face, two worn spots in the floor at its foci, a stone bench at the far focus
(a refuge, "sit and listen"), and a hanging resonant slab over it, hung on
cords. A hush of dust trails on the floor between the foci.

The strange rule: **sound made at the near focus is delivered at the far
one, ten times louder.** Land hard, break a pot, slam, run: the far bench
hears it, and its ceiling slab shakes down. Anything that makes noise at the
near focus drops the far slab. It also pushes that sound to the Olmec if he
is near the far one.

Tell: two floor discs worn by pacing feet, a faint hiss of dust that flows
toward the bench when a sound lands, and a creak of cords above the bench. A
dropped slab leaves a clear mark on the bench top.

States / escalation: armed; shaken (the cords snap after a second sound, so
the first one is a warning); dropped (slab lies on the bench, now a step
up); dead. Larger variants have two benches and two foci.

Hooks: sound (the key); the Olmec (he goes toward loud sounds, and so he
goes to the far bench); breakables (the slab becomes rubble, a stair);
knock-back (the slab's crash throws things at the bench's edge); greed (a
rune cache sits on the bench "for the one who listens"); co-op (the person
on the bench is the victim of the person pacing at the other end).

Rule 0 (as a tool): stand at the near focus and stamp to lure the Olmec to
the bench (away from your route), and as he sits under the slab, stamp again
to flatten him. Or you rest on the bench, safe from sound because you
cannot be heard when the wall is whispered into by someone else. Real risk:
the near focus is an open spot in his sightline, and the stamps are heard
by him everywhere, not only at the bench.

Co-op story: the friend resting on the bench gets flattened because the
other one landed a jump at the wrong spot. "You cleared the room."

Counterplay & fairness: the bench is the only trap spot; the slab visibly
trembles on the first sound. Quiet (crouch) movement is silent at the focus.
The bench cache is optional.

Where it lives: a public plaza or a processional wall, a mid-layer rest
spot. One per layer, tier 1 to 2.

Build cost: M. The rest is a sound relay in `EnemyField.sound` plus a slab
using the lintel drop's drop code.

Cliché check: a sound-trigger slab drop is stock. The distinct part is the
geometry: the trigger is far from the victim, so it is a lure and a murder
at once, and you have to read where the foci are.

---

## t4-burning-dish: The Hematite Dish — "The old priests lit their altars from across the court. The court kept the habit."
One line: a polished concave dish that throws the light of a lit cresset to
a point across the way and burns whatever is there.

Look & mechanism: a dark, metallic-grey hematite dish a few metres wide on a
stone yoke, its face pitted and finger-polished at the centre, set to look at
a great cresset. A faint bright dot (the focus) rests on one plank, rope or
resin-bound span across the chasm. Smoke curls from old scorch rings on
nearby planks.

The strange rule: **lighting a cresset can burn your bridge.** The dish
focuses any lit fire in front of it onto a point 12 to 20 m away, and the
point scorches whatever is wooden or oily there in about five seconds. So
the beacon you light to lure or to light your way is also the match for the
span. Players learn it once by lighting the cresset and then hearing the
span crackle behind them.

Tell: a hard white dot appears on the target a second after the cresset
catches, then a smoke thread, then the dull crackle of char. A burned span
is blackened and snaps at the middle. The dot hunts along the plank edge
(readable).

States / escalation: dormant (no fire), aimed (cresset lit), burning (dot on
the span), burned out (span falls). Larger dishes have several spans; some
point to an oil runnel and light it as a fuse.

Hooks: light and the torch (a torch near the dish is a weak dish source, so
the effect is slower); beacons (the cause: lighting a beacon draws the Olmec
and sets the fire); the Olmec (he may stand in the beam, which shadows the
focus and saves the span); breakables (the dish itself can be slammed to
turn it); greed (the burnt span reveals what was under it).

Rule 0 (as a tool): light the cresset after the Olmec steps onto the span,
so the span falls with him on it; or turn the dish with a slam so it burns a
rope that holds a rare cache; or line it up with the oil runnel to light the
fuse wall from across the court. Real risk: the cresset is a loud beacon
that calls him straight at the dish.

Co-op story: one friend lights the cresset from the stair, the other is on
the span. "I only lit it because you said it was dark!"

Counterplay & fairness: five seconds of dot before the fire spreads; the dot
and its smoke are visible; standing in the beam shadows the focus; dousing
the cresset stops it; the safe route (a stone span a long way round) is
slow.

Where it lives: across a chasm from a great cresset or a tower. One per
layer, tier 2 to 3.

Build cost: M. The dish is a fixed focus; the burn is a heat value on a
span that already uses `CityFire` heat.

Cliché check: the nearest stock trap is a fire trap. This isn't one: the
fire is the player's own beacon bouncing into the level, so the same action
calls the Olmec and burns the way.

---

## t5-usurer-cradle: The Usurer's Cradle — "It pays a rune an hour to whoever can bear to wait."
One line: a hoard on a stone cradle that grows with time and sags into the
void as it grows.

Look & mechanism: a shallow stone cradle on a long pier over a drop, with a
bowl of runes in it, the pier slung from a counterweight beam in the rock.
Runes accumulate on their own, visibly ("a tithe is paid in"). The pier
sags as the pile grows and the counterweight lifts. A worn mark on the
lip shows the lowest it has ever gone.

The strange rule: **the prize grows over time, and the floor falls as it
grows.** A new cache holds three runes, and gets one more every thirty
seconds. When the pile is big enough the cradle tips and spills all of it
into the void. Greed is the clock.

Tell: a running tally of runes in the bowl; the pier's deflection is
visible against a fixed stone line; a groan from the beam; the lip scrapes
the rock.

States / escalation: filling (safe to approach); heavy (the pier is
bowed, standing on it speeds the sag); spilling (it tips in two seconds);
spent (the empty cradle, a ledge you can use).

Hooks: greed (the whole card); the Olmec (his weight on the pier speeds the spill, so he can be
lured on); knock-back (the tip throws the greedy off the lip); breakables
(slam the counterweight to freeze the sag); carrying (a heavy piece on the
pier speeds it).

Rule 0 (as a tool): load the pier with something heavy so it spills early
onto a ledge below you, a controlled rain of runes. Or time the dive to
catch the spill mid-fall. Real risk: standing on the pier while it tips.

Co-op story: one friend waits at the pier for the pile to grow while the
other fights the layer and returns with the dare: "wait one more."

Counterplay & fairness: the tally and the bow are readable; the tip warns
for two seconds; the cradle's full value is the same every run so the
greedy choice is known.

Where it lives: a high pier on a mid-layer, off a main route. One per
layer, tier 1 to 3.

Build cost: S-M. A timer, a rune pile and a lever beam; no new physics.

Cliché check: the nearest stock trap is a bait pile over a drop. The
twist is the interest: waiting is the choice, and the reward is being
eaten by its own growth.

---

## t6-smoking-mirror: The Smoking Mirror — "It does not show you your face. It shows him."
One line: a polished obsidian mirror that carries the Olmec's sight round
corners, but only when it is lit.

Look & mechanism: a black obsidian disc, a metre across, set on a tilting
stone yoke at a corner, on a wall, or on a ledge, polished to a wet glass
shine. A faint smoke-grey sheen across its surface. A nearby lamp or cresset
lights it; unlit it is just a dull black plate.

The strange rule: **an Olmec sees through a lit mirror.** His sight follows
the reflection, so a hiding spot behind a wall is not hidden if the mirror
faces it. A mirror in the dark does nothing. Players die once by crouching
behind a corner that a mirror showed.

Tell: the disc reflects a recognizable lit patch of the room it faces; the
yoke's lines point to the hiding spot; an Olmec that sees in the mirror
stops and tilts his head toward it.

States / escalation: dark (blind); lit (relays his sight); cracked (it
shows a broken view with reflection blind spots after a slam); shattered
(shards on the floor are sharp underfoot and reflect motes, a faint tell).

Hooks: light and sight (the key); the torch (dousing it blanks your own
reflection); the Olmec (he looks into mirrors and is held by them);
breakables (slam it to crack); co-op (one friend stands in the mirror's
view as bait while the other slips by).

Rule 0 (as a tool): tilt the yoke with a slam so it shows a decoy, a lit
lantern, to the Olmec, which sends him the wrong way. Or douse the nearby
lamp to blind the mirror and slip past. Real risk: tilting the yoke makes
the loud slam in his hearing.

Co-op story: a friend stands in the mirror with a torch as a decoy, the
other crawls past in the dark: "wave at him!"

Counterplay & fairness: the mirror is lit by a visible lamp; the relay line
is visible as a sheen; dark corners still hide you.

Where it lives: corners of a hall or a stair. One to two per layer, tier
2 to 3.

Build cost: L. The Olmec's sight needs a reflected ray step and a mirror
node in `SightLight`'s world.

Cliché check: the nearest stock trap is a security camera. The twist is the
light dependence and that the mirror can be turned to lie.

---

## Cut during drafting
- Rubber bounce pad: a trampoline, stock, and Mario-ish.
- Glyph threshold that reads your runes: the Tithe-Taker's trigger, so it
  would duplicate lens 1.
- Offering tithe tile (pay a rune to pass): a toll booth, stock.
- Cenote that returns what falls in: too close to the rubber pad and a
  launcher with no strange rule.
- Hands-Empty Arch (stone refuses what you carry): carrying isn't built, so
  the card couldn't be proved yet.
- Obsidian scree (a floor loud as glass): creaky-floor stealth, stock.
- Sweat bath steam room: the Mist Shelf and steam vents already exist.
- Counterweight offering lift: a Seesaw cousin.
- Rune-pinned slab bridge: a Keystone Collapse cousin.
- Lodestone idol that drags the torch: contrived, and it needs metal rules.
