# Cryptids: the game pitch

Written 2026-09-10 after a long design conversation. This is a direction document,
not a plan. Nothing here is committed to code yet; it exists so the idea survives
the next round of doubt and so branches can be judged against it.

## One sentence

A cozy, top-down cryptids game where you run a camera-trap crew trying to get
undisputable proof that a creature exists, in a world where the creature is
really living its own life just out of sight.

## Where this came from

ZenScape started as "build a beautiful landscape and look at it." That worked
and then asked "now what?" Bigfoot answered it, then a utility-scored mind, a
world clock, weather, seasons, dead wood, hibernation, a second island with
campers and a rope bridge. Each was a good system and none of them made it a
game, because the player had no hand in the world and the world had no stakes.

The reference that explains what we are after is Breath of the Wild's chemistry
engine (fire, wind, rain, wet, wood, metal; a small table of elements that all
interact), with one change: the player is not Link. The entities are the ones
subject to the systems. Link's problem is that he accumulates permanent answers
(stamina, Revali's Gale) until rain is a nuisance. Nobody in this game ever
gets a permanent answer.

## The player

You are on the campers' side. You never drive anyone. You place trail cameras,
bait and blinds, shape the land, and nudge the weather. The campers have their
own minds (same scorer class as Bigfoot, different drive weights); they walk
out, set the cameras, retrieve the cards, and get scared. Bigfoot has his life:
fishing at dawn, clearing branches after wind, fixing his bed after a storm,
stashing things in his cave, sleeping through winter.

The world is the interface. Every player act is an object or condition in the
world with a lifecycle, read by the minds through the same context keys as
everything else (`bigfoot_living_world.gd` `_context()`, the chunk manifest in
`docs/world-progression/MANIFEST.md`). You move things; you do not make them.
Fish for the crew's bait come from his pool.

## The loop

- **Morning:** review last night's clips. Most are deer and wind. One has a shape.
- **Day:** move cameras, move bait, sculpt a bank, keep the crew out of trouble.
- **Night:** watch, or don't. Time runs whether you watch or not.

Progression is evidence quality: a footprint cast, a blur, an infrared night
shot, daylight, a behaviour, a sequence. The year is the clock. The crew leaves
at first snow and the documentary is cut from whatever you kept.

Challenges are predicates over world state, not scripts: "film him fishing,"
"film him at the bed," "film him in snow." A challenge that cannot be reached
means a missing drive, not a missing script.

## Stakes without death

Nobody dies. He is the antagonist in the Tom and Jerry sense: he finds the
camera and carries it off, knocks the tripod into the pool, eats the bait,
stashes the SD card in his cave. The existing mischief, water mischief,
throwing and cave cutaway systems become the stakes.

Rules that follow:

- Evidence is a physical object he can take and the player can recover.
- Losing footage sets the ladder back. Knowledge (where he fishes, where the
  cave is, what he does in rain) is never lost. Footage is fragile, knowing him
  is permanent. A second year is the same world with a smarter player.
- The systems already in play write the losses: the bridge snaps under the
  camper carrying the card home; the storm kills the flashlight, they get lost,
  he knocks them over in the dark; the rain washes the print before the camera
  catches it.

## The reveal

A new player should not see him in the first hour. There is a fogged island
next door and there are traces: a print in the mud the rain half took, a fish
stash where none should be, a branch cleared from a path overnight, a grey
shape on a night clip that could be a bear. Then a first contact.

The thing no other game can say: the traces are true. He is over there living
his actual life and the print is where he really stepped. This is the payoff
for the mind.

Each cryptid repeats the reveal. This cannot be self-playtested. It needs
strangers who have never seen him.

## The map

Chunks are islands, never stitched terrain. The gap does design work:

- A crossing is a chokepoint, and chokepoints are where the drama is.
- Each island adds exactly one new element to the chemistry table
  (multiplicative, not additive): Bigfoot is the forest; a lake creature is
  water, hydrophones and surface shots; Mothman is night and lights; a swamp
  thing is wet and heat. A new biome that adds no element is a second game.
- Each crossing is a different physical thing the season opens or closes: a
  rope bridge the campers build and a storm can drop, a fallen log fire can
  burn, a ford that exists only in the dry season, ice that exists only in
  winter and may not hold him.
- The campers build the bridge slowly, over days, out of dead wood, when
  scarcity or a sighting drives them. The rope coming out of the fog is the
  chapter-two image. He can tear it down at stage two. Escalation comes from
  the scorer, not a level designer.

Two islands first. Add a third when the campers have a real reason to choose.

## Each cryptid

A cryptid is a chunk, one new element, a drive profile on the shared mind
class, and its own kinds of evidence. The proof ladder is the same shape every
time; the pictures all look different. Time runs on every island; attention is
what the player spends, and off-screen time must leave a record (the clips).

## Sandbox

The diorama already built (Build and Enjoy modes, the tool rail, presets,
lighting) ships as the mode unlocked at the end. The strange game is the
pitch. The pretty one is the reward.

## Legibility

Every drive needs a visible tell. The only added UI is a hover thought bubble
showing the top two or three ranked actions as icons, no numbers. The clip
review screen is where his behaviour becomes legible without it.

## Things this replaces

- "Terrarium, not survival" as the identity. It survives as the sandbox.
- Four chunks at launch, or stitched terrain.
- An RTS where you control and upgrade him (reintroduces the permanent-answer
  problem and deletes the mind). Fallback only if the day-seven test fails.
- Carrying and calling him inside the campaign; those stay in sandbox.

## Ideas parked, not rejected

- The intervention budget: a fixed number of nudges over a week, placed on a
  scrubbable timeline. Most novel, needs snapshots; version two.
- Trust: point at a thing and he weighs "the god wants me there" like any
  drive; ordering him spends trust. A hedge if players want more agency.
- The Photograph as a mode: magazine briefs the player shoots with the diorama
  camera.
- Standalone games from the same stack: Lead the Beast (Lemmings with one
  thinker), The Forest Fights Back (loggers, really chunk three), Raise One.

## Playing it: the day, the crew, the kit

You are on the campers' side and you never walk as one of them. That would
turn the diorama into a third-person game, triple the scope, and lose the best
joke in the design: watching someone you cannot steer walk toward a noise. The
shape is prepare, then let it run (Darkest Dungeon, Majesty, FTL).

### The day

The world clock sets the rhythm and the interface follows it.

1. **Dawn, review.** A full-screen clip screen. Last night's cameras, scrubbable,
   mostly deer and wind. Tagging a clip is how objectives get ticked.
2. **Midday, plan.** Time slow or paused. Each camper gets one job and a place:
   set a camera here, swap that card, bait the rock, cast the print by the
   pool. Where is a click on the terrain; the route is theirs.
3. **Dusk, deploy.** Time runs. They walk out with their own minds and nerves.
4. **Night, home.** Night is where it goes wrong in most games, and here too.
   The whole day was exploration; the night is about getting everyone back
   with the evidence. One of them is still in his cave, and he is walking
   home. That scene is the game.

### Where you can send them

Click the terrain, as the editor already allows. The map opens as fog of war:
places become clickable as the crew and the cameras see them. Cameras are the
crew's eyes when nobody is out. A camper is a destination, never a route.

### Three levels of influence

- **Before they go, everything.** Who goes, where, and what they carry.
- **While they're out, a little.** A short radio budget per night: come home,
  hold, go on. Plus hands on the world: bait to pull him elsewhere, fog, rain
  to cover a retreat. These cost the world nothing, so the radio budget is
  their cost.
- **Never, movement.** If she drops the card and runs, that was your plan
  meeting her nerves.

### Crew and kit

A small crew, each a drive profile on the shared mind class with a trait that
matters in the field: brave and careless, careful and jumpy, the fish person.
The wrong camper for a job is a choice you made.

Kit is the answer to Phasmophobia's loadout screen. Each camper has a few
slots, and what fills them is the plan: one carries three cameras, one carries
the casting kit and bait, one carries the deterrent. Gear is finite in the
field. Lost gear stays in the world where he left it and can be recovered.

Open question, recorded below: whether any of that kit can hurt him.

### The economy

No shop. A producer funds the crew: footage you send earns the next supply
run, and the supply run is where new gear arrives (better cameras, more
batteries, later a hydrophone). The producer's requests are the objectives
in the top right, three or four at a time, and the producer's messages are
the tutorial and the game's voice.

Objective types that show the sim is the content:

- **Traces:** a footprint cast, a claw mark on a tree, the torn bed.
- **Data:** "prove the fish are declining," a count from the pool camera over
  a week drawn as a small graph. Evidence that is not a picture, straight from
  the context keys.
- **Sightings:** blur, night shot, daylight, a behaviour, a sequence.
- **Whims:** him in snow, him at the cairn. The charming ones.

### Screen

- **Top right:** objectives.
- **Bottom:** crew cards: name, kit, one mood icon from the mind, destination.
  Click to follow.
- **Center:** the diorama, cameras as icons with view cones, click to sit in
  one.
- **Dawn:** the review screen replaces everything.

## First two spikes

Both are small, both are yes-or-no, both gate everything above.

1. **Trail cam.** An object with a transform that renders one low-res frame
   from its own view when something moves in front of it, with an infrared,
   timestamp and grain shader for night. Dump frames to disk at a few times of
   day and weather presets. Question: do fog, night and rain make a convincing
   bad photo on their own?
2. **Day seven.** One chunk, three seeded weeks: left alone, fed a fish at the
   rock every day, stormed every night. Question: on day seven, can a stranger
   tell the three Bigfoots apart by watching? Needs a placed fish as a sourced
   context key and familiarity per source. If they diverge, the indirect game
   is real. If not, the drives need to be longer-horizon before any faction
   work matters.

## First hour, as a scene list

To be written before the spikes are judged: print, stash, cleared branch,
night blur, first contact. It is the spec for the trail cam and the thing to
hand a stranger.
