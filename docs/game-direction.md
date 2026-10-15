# Game direction (draft)

> **Status: draft, not final.** This is the best direction so far, worked out
> in conversation on 2026-10-11 after the fresh start. Treat it as the current
> lean, not a spec. Anything here can change, and the open questions at the
> end are open.

## What it is

Freeform parkour with polish, in a sky of distinct, dangerous,
beautiful regions, plus a plane. A playground you get lost in: it is fun to
do nothing but move, slide, hop, fly and look. Objectives and set pieces point
you at more to see; they are never the point.

**Tone:** a joyful, nimble pilot in a melancholy, ancient world. Not cozy.
There is real danger, and the comedy comes from that danger and the physics
(getting flung, the plane rolling off an isle, a dragon ruining your
afternoon). It is never written as jokes. Each region gets its own look.

**Why you push on:** to see more. More isles, regions, themes, spectacle,
what's past the horizon. The reward for playing is more places to play:
every reward is a place, a theme or a set piece, never a stat.

**What it isn't:** base building, farming, skill trees, crafting, survival,
fuel, stats, upgrade loops.

## Structure

- **Regions:** clusters of isles, each with its own pack (kit, sky palette,
  one twist on traversal, maybe one local enemy). Packs share a universe and
  a shape grammar; the materials change. Region one is the ruins: the
  aqueduct isle and the eight motif isles around it.
- **Isles:** playgrounds built from features (slopes, gaps, paired walls,
  updraft spots, ledges with a view), not A-to-B levels. One idea per isle
  that changes how you move there. Handcraft the terrain, not the route.
- **Pseudo open world.** Regions are separate places (their own scenes,
  rules, threat, sky and scale; the dragon belongs to the ruins and never
  follows you out), but they share one sky and can see each other. From the
  ruins you look out and up and see the next region far off, a cheap far
  version of it with a crazy silhouette and a little life (lights at night,
  weather on it): the "I have to go there" pull. Finishing a region opens the
  way, a flown passage (a cloud deck, a storm wall, a slipstream) that hides
  the scene switch, locked until then by something physical you can see (a
  current you can't fly against, a wall of weather). You can always fly back
  and 100% a region; from the new one you look back down at the old. Arrive
  in the air, never at a loading screen. Chosen over a fully seamless world
  (huge engineering, regions bleed into each other, no arrival) and over a
  level select (kills the horizon and the plane's fantasy).
- **Horizontal and vertical:** both. Regions stacked through the cloud decks,
  each beat taking you up (or out) to the next.

## The loop

Spot an isle (or someone waving from it) → get there your way → clear its
objectives in any order → the region's count opens its beat → a sky set
piece → a new region.

### The ledger

Lock onto an isle from the plane (or arrive on foot the first time) and its
card shows its title, epithet and progress. Objective names double as
evocative, slightly cryptic hints ("Beneath the Keel's Shadow", "What the
Bells Remember"), so the card reads as a list of questions about the isle.
Round 1 (feature/ledger) persists progress and makes the cards live; see
docs/design/ledger/round1.md on that branch.

### Objective types

Distant spots reached with any tech · sets (red coins) · races (the serpent,
an airship) · recorded flight challenges (plane only) · deliveries (on foot,
or slung under the plane) · knock enemies off · a boss.

Recorded flight challenges are the content pipeline: the user flies a route,
records it (feature/challenge-recorder), and it becomes a challenge in that
isle's ledger, maybe raced as a ghost.

### Collectibles

A shared language in three tiers:

| Tier | Role | Counts on the card |
|---|---|---|
| Trail | breadcrumbs showing a line through the air or along the ground | no |
| Sets | red coins: a handful scattered on an isle that complete something | one entry per set |
| The big one | the moon: the named ledger entry | yes |

Every objective type pays out the big one. Foot or plane is a property, not
a type: foot finds sit on the stone, small and heavy; plane finds hang in the
air, bigger, at plane scale. Readable at a glance.

The theme is what the world lost, so collecting tells the mystery without
text. A lead: tesserae, each set restoring part of a mosaic in a hall, the
mosaics showing what happened here. New regions keep the grammar and change
the material.

### The beat: seating and delivering

Finding a big one stamps the ledger at once (freeform play never stops) and
it seats in the plane, as the lodestone does today, glowing. With enough
seated, the plane can thread the Sundered line and deliver them to the slot
at its end, which opens the next region. Plane repair, the lodestone, the
beat and region progress become one system.

The delivery's best form is a **physics tether**: the load hangs under the
plane on a rope (the swing rope and rope bridge already simulate rope). The
pendulum is the skill: bank hard and it swings wide, pull up and it whips,
so smooth lines matter. Scrapes chip and crack it, the cracks glowing toward
breaking; broken, it drops and you go back for it, cheaply. The slot is a
lodestone socket that magnetizes: nearing it the rope pulls taut toward the
slot, and you release on the pass without stopping, the load seating behind
you with a thunk while the halls react.

Level design follows: gaps need room for the plane plus the hanging load
(thread high so the load clears); rope length tunes the difficulty. Size the
arches with this in mind during the scale work.

Carried deliveries on foot (tech muffled while carrying) stay special: a
handful per region, the dragon heist among them.

## The plane

- **Starts broken.** Region one's first goal is finding its parts on foot
  and on the serpent route; the first flight is a payoff.
- **A physical thing the world can take.** Badly parked, it rolls off when
  the dragon tips an isle; a swipe knocks you out of it. Getting it back is a
  short quest, never a timer. No fuel.
- **Earned travel: the 80/20 rule.** About 80% of a region is reachable on
  foot, slower and more perilous. The plane is required for the rest: a
  higher isle, the dragon, plane-only collectibles, and the physical
  progression pieces for the beat. The flow: explore on foot and find the
  plane's parts, the plane flies, the last 20% opens.
- **Getting between isles on foot.** The isles are hundreds of metres apart,
  too far to platform. Foot links: the serpent (reaches the cloister tarn,
  the drowned nave and the Sundered gorge today), the sky folk's airships as
  boardable ferries (slower and riskier than the plane, dropping you at a
  ledge you jump to), and floating stone chains or rope lines for short
  hops. Each objective records whether it needs the plane, so the 80/20
  split can be checked.
- **Physical vs stamped.** Progression pieces (plane parts, beat pieces) are
  physical: picked up, seated in the plane, delivered. Ordinary finds are
  stamped in the ledger at once.

### The plane's parts

Six, each a real piece of the plane (look/plane-parts, look/broken-plane-2:
found parts hover as the actual piece; the parked plane shows damage where
each is missing, and its paint goes from dusty to pristine as they seat),
each found a different way. One rule: you usually see a part before you can
get it.

| Part | How | Where |
|---|---|---|
| Wheel | out in the open, a platforming climb near spawn | aqueduct isle |
| Cowl | summit climb; jammed under the bell, a downdraft on the bell swings it loose | top of the bell spires (via an airship ferry) |
| Tail fin | caught in the serpent's back ridges like a dorsal fin; ride it and get carried off | the serpent loop |
| Wingtip | swimming; the serpent strands you here, so the fin leads to it | the cloister tarn |
| Propeller | dangling on a rope under a salvager's plane (the snag) | his loop dips through the Sundered gorge; grab it from the rope bridge |
| Windscreen | watch it fall: at dusk the glass glints as it streaks down, then glints in the water | the drowned nave |

**The crash opening: the landing is the tutorial.** The game opens flying,
the plane already limping: the engine sputters, and something has hit you or
hits you now. You never see what: a shadow in the cloud, a roar under the
engine, a wingbeat. It's the dragon, and hours later, spotting the roost
through the telescope, you realise it. The hit tears parts off in the air and
you watch them scatter: the fin catches on the serpent passing below, the prop
tumbles toward the gorge, the windscreen sails off into the clouds. The rest
of the region is hidden (storm cloud, heavy weather), so the aqueduct isle is
all there is.

Then you land, and it's played, not a cutscene: the game teaches the landing
(touch down softly, drift, slide), the skill you use all game, under pressure
that makes sense. You pick your own landing spot on the isle, reading it and
choosing your line, the whole game in miniature. The limping handling (see
"Damage and losing the plane") shows itself here first. No fail state: a bad
landing still lands, just rougher; a hard touchdown might cost the wheel,
bouncing up onto the stone circle where it waits near spawn. A good landing is
a win, because the parts were lost to the hit, not to you.

You climb out, the cloud clears, and the region opens round you: the first
look at the sky. The telescope comes out of the wreck and the first thing you
do is look for where things went. It is the tutorial (landing, then moving on
foot) and "see it before you get it" for the whole arc. The salvager with the
prop (Gaspard Wren, "who prowls the wrecks and says the hulls are still warm")
becomes a recurring sky-folk character. Needs: the landing to read well at
the new scale, a scripted hit, the parts' scatter.

**The snag in the region** follows "never wait-and-grab" (below).

**Rounds:** 1 wheel and wingtip · 2 the downdraft · 3 fin and prop · 4
windscreen · 5 ferries, then the cowl.

### Damage and losing the plane

Later, once the dragon can hit you: big moments (a dragon swipe, a hard crash
into stone) knock one or two parts off, right there and visibly; you watch
where they fall, go grab them, and they snap back on. Thirty seconds of "oh
no", never re-collecting from the original hiding spots, never routine
attrition, and the ledger is untouched (only the plane's state changes). The
plane limps rather than dies, and each loss changes the handling: no prop,
you're a glider picking a landing; no wingtip, it pulls to one side; no
wheel, a one-wheel skid landing; no windscreen, wind and a shaky camera; no
cowl, a coughing engine; no fin, a wobbly yaw. The far end of the same scale
is losing the plane: lose the prop over the cloud sea, glide too far, and it
comes down on some lower isle to recover.

### The downdraft

The updraft's opposite, in the pilot's own wind tech rather than a borrowed
ground pound or a shovel (both stop you; this keeps you moving). Mid-air
with crouch held, spending the flow charge drives a burst of wind down
beneath him: it blows turf and dust off a glowing patch to reveal what's
buried (the dig, done with wind), knocks nearby enemies outward and off
edges, shakes loose cracked slabs, hanging bells and crates, and flattens
the grass in a ring. It shares the charge with the updraft: go up or slam
down. The motor's slot is free (crouch does nothing in the air today).

### Ways to discover things

A menu for parts and objectives, mostly on what exists: out in the open but
high (platforming) · ride the serpent and get carried off · blow away the
glow (downdraft) · watch it fall (a streak at dusk; you saw roughly where) ·
knock it loose (an airship crate, a hanging bell, a sagging lintel) · a thief
has it (chase it, knock it off) · someone waves you down and wants something
first · behind or under (the spill, the tarn, the keel) · the lodestone hums
louder near it (hot and cold) · only at night (a lantern shrine lit after
dark shows the way) · snag it from a passing plane · the blimp brings the
isle to you (wait, time the jump as it swings past).

**Never wait-and-grab.** Not ridiculously hard, but never "watch it, stand
still, take it". Every find asks for a little
creativity: a ramp to slide down for momentum, a wall to kick off, a ledge
to launch from. If you want to wait for something to come to you, the
waiting spot itself takes platforming to reach. For the snag: no easy spot
under the dip; the load passes only near places that are hard to reach; the
route there takes about a lap, so you plan where to start; an obvious-but-hard
way and a clever way (watch a pass, plan, go).

## The pilot's kit

No inventory: no grid, equipping or swapping (that is management, and it
leads to the crafting and survival game this isn't). The pilot has a small
built-in kit, each tool its own button or used in context, acquired over the
game but never managed, hard-capped (if a tool needs a menu to pick it,
it's one too many): the binoculars, the sail, the flow charge (updraft and
downdraft), maybe one or two more. Physical things (parts, the lodestone,
the dragon's egg) are carried in hand or seated in the plane, seen in the
world. The only menu is the ledger.

**Binoculars** (feature/binoculars): hold to raise, on foot. Spot glints
of unfound things far off, see an isle's card from the ground (the plane's
lock-on, on foot), watch a loop to plan a route, check whether the dragon is
home. Brass, raised to his eyes, a soft round vignette, not a scope. Maybe
later: a pin to mark a spot seen.

## Falling

Cheap for the body: back on solid ground almost at once, no real penalty.
The plane is the stake, not the pilot.

## Carrying and the tech

The tech stays powerful. Limit it with space, not nerfs: height is the
currency (moving sideways is free), and isles get taller or spread out where
the tech makes them small. Carrying something muffles the tech (no updraft,
no twirl, heavier jumps, a sluggish plane) until you deliver it, and getting
it back is the relief.

## The dragon

- **A home.** A colossal Sundered hall half-swallowed by a crag on its own
  isle, roof broken open. He sleeps curled in the nave on his hoard, a wing or
  tail spilling out over the rim so the nest reads from far off. Inside but
  open to the sky: drop in through the roof or walk in through the nave doors.
- **Alive, not a clock.** Asleep at home; roaming (grips isles, mostly
  ignores you unless you buzz him); hunting (at night, or provoked); chasing
  (the heist). A rough rhythm with the day, plus waking when you're noisy
  nearby: learnable, not exact.
- **The dread.** You look over, he's asleep, you go play. You come back,
  the nest is empty. Then a far wingbeat, a shadow, the rumble before he grips
  your isle, or he comes out of a cloud beside the plane. Sound finds him
  before your eyes do.
- **Air attacks.** The gust (his breath already buffets the plane); the
  swipe (the plane tumbles; the big one knocks you out of it, and the plane
  goes spiralling off to be recovered); later, the grab (he snatches the
  plane and drops it on some isle).
- **Tells and counters.** Trees lean as he inhales; in the air his shadow, a
  roar, the wind going still, a wing beat. Barrel roll to dodge, knife edge
  through a gap, dive under a keel or into an undercroft where he can't
  follow. The ruins are cover; flying skill is safety.
- **The heist.** Steal something from him (the gem on his tongue, or
  something in the nest) and deliver it while he shakes the world around you.

## Enemies

Physics, not damage: slide into them to knock them off the isle; they can
knock you off. Enemies are also traversal props (bounce off them, slide
through for speed). The motor already has knock, seize and toss. The henge
guardian (unmerged park/henge-guardian) is a first boss candidate. An isle
arena (a timed wave to clear off the edges, no upgrades) could be one ledger
slot.

Enemies are expected in a game like this, and they are what makes the foot
route perilous; the plane is the way around them. Foot tokens are taken only
on foot (the plane passes through them), so the plane skips the gauntlet but
not the last stretch: you land or bail out with the sail and drop in, which
makes landing spots part of the design. The dragon keeps the air from being
safe.

**When:** decide the rule now (they knock you off, they don't hurt you).
Right after the plane's arc, a small feel prototype in a study yard (one
enemy type: slide into them, downdraft on them, get knocked off). Place them
in the region once progression exists, where they make the foot route
perilous (an aqueduct gauntlet).

## Life and NPCs

A small cast of sky folk, sparse and a little strange, not chatty. A lone figure waving the plane down from a far isle
marks something to do there and gives quests and deliveries. The airship
crews already wave.

## Set pieces

The dragon heist · the Sundered line (the beat, or just a flight challenge)
· a sky-folk blimp lifting an isle and moving it (an isle hauled up could be
how a region opens upward) · halls rising out of the cloud sea.

## Systems

- **Wind as the world's chemistry:** gusts off cliffs, vents, dragon
  breath, storms, all pushing the pilot, sail, plane and load. Today it is
  mostly visual and the plane flies in still air.
- **Knockback physics.**
- **Carrying limits the tech.**
- **Height is what costs.**

## Parked

- **Spawn pools (later, once region one's finds are designed):** each
  small find (rune tokens) has 3–5 curated spots; a seed rolled per new
  game picks one each, saved with progress. Ledger ids stay per find; each
  spot carries its own hint name. Plane parts and set pieces stay authored
  (at most 2–3 variants). `--new-seed` for playtesting.

- **Co-op:** it suits the game (watching a friend get yeeted), but it is a
  huge cost to retrofit. Decide within a few months whether it is real.
- **Interiors:** out of scope, except spaces that are inside but open to the
  sky (the dragon's hall, the keel's cavern, a blimp deck).
- **A survivors-style fork:** fun pitch, different game.

## Open questions

1. Region one's beat: the Sundered line delivery, the dragon heist, or the
   blimp lift?
2. What does a dragon hit cost?
3. What do you steal from the dragon, and where is his isle?

Settled since the first draft: progression pieces are physical, ordinary
finds are stamped; about 80% of a region is reachable before the plane;
pseudo open world, regions stacked both ways (2026-10-12).

## Where things stand

- **Waiting on:** the scale and spacing work (plane at the pilot's size,
  arches and spacing growing to match). It changes every gap and route.
- **Built:** feature/ledger (round 1): saved progress, an objective registry
  (57 tokens in region "ruins"), live isle cards, a region query.
- **Built:** rune tokens (a glowing diamond with an orbiting ring) in place
  of the flower glyphs, a stopgap; maybe yellower later.
- **Next, roughly:** the plane's arc (brief: docs/briefs/plane-arc.md) and
  cheap falls (last safe ground); an enemy feel prototype; then, after the
  scale work, airship ferries, challenges into the ledger (merge the
  recorder), the dragon's home and heist, one waving NPC, the tether
  prototype, and gating the beat on the region count.
- **Names:** brainstorm in docs/names/ruins-brainstorm.md.
