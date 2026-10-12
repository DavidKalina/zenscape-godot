# The dragon as the run's pressure system (ideas, 2026-10-12)

> Brainstorm, not decided. Companion to concept.md. Spelunky's ghost, made
> alive: he is never a countdown on screen, but every layer he gets closer.

## What exists vs not

| Built | Not built |
|---|---|
| Flying body, procedural rig, wingbeats, roar, tail rope (`sky_dragon.gd`) | Any way to hurt the player or plane |
| Asleep on the roost, wake, one scripted circuit, settle (`dragon_roost.gd`, `dragon_wake.gd`) - spectacle only, explicitly "never grips, blows, grabs or knocks" | Hunting, chasing, noise-waking, state machine |
| Grip on a far isle's rim, isle tips/sags, breath ribbons, plane gust cone with buffet and shove (`dragon_gale.gd`, `dragon_breath.gd`) | Gale on the player's isle; foot gust; the plane rolling off |
| Roost mountain, carrion birds, wrecked sky-folk plane warning (`motif_dragon_roost.gd`, `roost_air.gd`) | Swipe, grab-and-drop, parts knocked off, flung-off-isle |
| Isle shape sampling for chin/breath (`dragon_isle_shape.gd`) | Any link to the generator, cover tags, sound-first tells |

The art and the "he is a big weather event" layer are done. The missing half is
all consequence and all awareness (what he knows about you).

## 1. Role per layer

He is Spelunky's ghost with a body: leaving a layer is what makes him lose
interest, staying is what makes him arrive. No timer; a rising **Attention**
number he owns (hidden, but every rise is audible/visible).

| Layer | He is | What he does to the run |
|---|---|---|
| Low strata (wreck, first isles) | Far, asleep or a silhouette | Teaches the dread: a wingbeat, a shadow across the turf, he ignores you. Zero damage. |
| Mid | Roaming, grips isles | Roams *toward* noise and loiter. First real hits (gust, swipe at the plane). |
| High | Hunting | Picks your isle. Scheduled-feeling, not scheduled. |
| Cloud deck gap | Between you and the exit | Last-isle gauntlet: he loiters at the gap if Attention is high. |

**Greed raises Attention.** Everything the ledger asks you to stop for has a
sound footprint:

| Greed action | Attention | Why it reads as fair |
|---|---|---|
| Walking/gliding quietly through | ~0 | Stealth is real |
| Collecting runes (chime, per rune) | small, per chime | Chime is audible to him too: the player hears the cost |
| Clearing a ledger card (fight, dig, race) | medium | Noise, dust, breaking stone |
| Ringing a bell / opening a chest / trader haggle | big spike | Opt-in loud things |
| Plane engine running near him | continuous | The engine is a beacon; glide-landings are quiet |
| Camping at a campfire | decays Attention, but only in cover | Tender mercy, but not free |
| Leaving by the gap | resets to the layer's baseline | Moving on is the relief valve |

Rule of thumb: **Attention rises with time-on-layer x noise made, falls with
distance and cover.** There is never a number on screen; the proxy is how many
birds are up, how the wind sounds, how close his shadow lane is.

## 2. States and escalation

States (per game-direction.md, wired to Attention):

| State | Trigger | Behaviour | Player-facing signal |
|---|---|---|---|
| Asleep | Low Attention, day start | At roost, curled | Slow breath audible near, snore rumble |
| Stirring | Attention crosses T1 or a very loud event | Raises head, roars once, circuit begins | Far roar, birds scatter, **sound first** |
| Roaming | T1..T2 | Big circuits, grips isles that are far from you, mostly ignores | Wingbeats pan across the stereo field, shadow lanes |
| Hunting | T2 or provoked (hit him, steal, buzz) | Picks the *loudest/closest* isle, circles, strafes | Trees lean, wind goes still, the sky folk stop singing |
| Gripping | Hunting + isle chosen | Clings to the rim, tips the isle, breathes across it | Rumble in the floor, isle tilt ramp |
| Chasing | Heist only (or rage after a theft) | Pursues the plane on a line, swipes | Constant roar, no safe air |
| Sated / leaving | Grabbed the plane, or you left the layer | Departs | Silence, then relief and dread |

Escalation across a run (not a stat sheet; behaviour breadth):

| Run stage | New behaviour |
|---|---|
| Region 1, layers 1-2 | Flyby only. Gust at distance. No contact. |
| Region 1, layer 3+ | Grips far isles. Swipe at the plane if you buzz him. |
| Region 2 | Grips *your* isle. The grab (plane taken and dropped on another isle). Hunts on foot: breath sweeps the turf. |
| Region 3+ | Two tells overlap (storm + dragon). A second, smaller dragon / hatchlings? (wildcard). He anticipates: waits at the gap. |

Across regions the same dragon is the *recurring* one: older, scarred from the
last time, with a name the sky folk use (see section 8).

## 3. Attacks

Every attack: **sound, then sight, then a counter, then a cost.**

| Attack | Tell (sound first) | Tell (sight) | Counter (tech) | Cost |
|---|---|---|---|---|
| **Gust** (breath from afar) | Inhale hiss, leaf rattle | Trees lean toward him, grass flattens, ribbons start | Plane: knife-edge through a gap or dive under a keel; foot: crouch behind a wall/arch, wall-kick off the lee side | Plane shoved off course; on foot, slid toward the rim; parked plane starts rolling |
| **Swipe** (plane) | Wingbeat gets *closer* (louder, then stops), wind goes still | His shadow crosses the plane, a wing silhouette over the sun | **Barrel roll** at the shadow's edge; or dive into an undercroft/arch narrower than his wing | Roll lost: 1-2 parts knocked off (visibly, where they fall), tumble. Big swipe: knocked out of the plane at height, plane spirals away |
| **Swipe** (foot) | Footfall boom through the turf, dust falls from arches | Claw rake across the isle | Slide under, ledge-hang under the rim lip (he overshoots), wall-kick out | Flung off the isle; save with pocket sail glide if you have the height |
| **Rim tip** (grip) | Stone groan, floor tremble, long creak | Isle tilts over ~3 s; things slide | Run uphill, rope-swing off, glide to a neighbour | Loose things (runes, parked plane) slide off; you glide or fall |
| **Grab** (later) | Roar, rapid wingbeats at your plane | Talons open, a big shadow *above* | Barrel roll at the last beat; eject (pocket sail) if you can't | Plane taken and **dropped on another isle** - a recovery side-quest, never a death |
| **Sweep breath** (foot, hunting) | Inhale, trees lean, ribbons across the turf | Ground ribbons skim the isle | Behind ruin, under arch, in a trough | Pushed 5-15 m toward the rim; item drop from your hands |
| **Perch ambush** | Absence: the birds are gone, the quiet | He is just *there* on the next isle | Back off, hide, wait | Soft: forces a detour (he is parked on your route) |

Tell budget: the first cue must fire >= 1.2 s before contact (swipe) and >= 3 s
for a grip. If a tell is purely visual, it is not a tell.

## 4. Interaction with the generator

Every generated isle gets tags that the dragon system reads; the generator is
the thing that makes him a *different* problem each run.

| Isle tag (generator) | Dragon uses it for |
|---|---|
| `cover:undercroft` / `cover:arch` | Hide: he cannot enter, can only breathe at the mouth. Needs width >= wing clearance (WorldScale.opening). |
| `grippable` (rim >= N m of solid) | He may perch here to watch. Thin isles he can't grip, so he rakes them in passing. |
| `tippable` (mass below threshold) | Grip tilts it; heavy anchored isles don't tip. |
| `loud` (bell, chest, trader) | Raises Attention when used; visible on the ledger card as a bell icon. |
| `dry` (no cover at all) | Danger card: "open ground" shown on the ledger so the greed choice is informed. |
| `flat-park` (a level landing) | Safe park for the plane; the rest are slopes and rims - parked planes roll. |
| `lee` (leeward side of a ruin) | Breath-shadow: free cover from gusts, not from swipes. |

Parked-plane danger: a plane on a tippable isle, left while he grips, rolls
off. Chocks (sky folk wedges, a found item) and the plane's brake are the
counter. This makes "where do I land" a layer-level decision.

Generator rule: every layer must have at least one cover of each class within
glide reach of the exit gap, and never more than N exposed seconds between
covers on the main route. Danger cost per section includes "exposed to the
sky" the way it already includes drops.

## 5. Manipulating him (Spelunky combos)

| Move | Setup | Result |
|---|---|---|
| **Rune lure** | Drop a rune stack on a far isle | He investigates the chime, goes there, you pass quiet |
| **Bell decoy** | Ring a bell on a thin isle, run | He rakes it to rubble while you are elsewhere |
| **Bait into hazards** | Lead him past a wind-eddy/updraft or a crumbling arch | Arch collapses on him (stun 2 s); he rides the updraft away |
| **Enemy fodder** | Knock a turret/serpent into his path | He eats it, loses interest 20 s |
| **Hide** | Undercroft + stay still | His Attention decays; he circles twice and leaves |
| **Distract with loot** | Drop the carried relic on an open rim | He picks it up (hoarding) - give up the loot, keep the run |
| **Shadow riding** | Fly in his shadow lane | He loses the plane (no line of sight) but you can't see either |
| **Updraft steal** | Use the wake of his gust as a thermal | Free altitude; a high-skill trick |
| **Smoke / flare** | Light a campfire in a cave mouth | Heat and light hold him off a ring; he circles |
| **Feed the chain** | Lure him to a gripped isle that holds a hoard-cache | He tips it; the cache falls to a lower layer you can reach |

## 6. Killable? Boss? Nemesis? Heist?

My lean, in order:

1. **Not killable on foot.** A dragon you kill is a boss fight with health;
   a dragon you outplay is a world. Spelunky's ghost is never killed.
2. **Recurring across runs as a persona, not a stat.** He remembers the ledger,
   not the character: the sky folk tell stories about "the one who took the
   plane at the second gap". His scars, his ledger card, a kill count of
   runs-he-ended. No power growth, just a *story* (melancholy).
3. **Regional boss = survive him, not damage him.** The region's boss beat is
   a set-piece where he grips the final isle and you must climb it while it
   tips (the Colossus feel): win by reaching the gap, not by dealing damage.
4. **The heist as optional greed.** Take the gem/relic from the nest:
   chasing starts, the whole region becomes the escape. Big reward (a run-long
   tool, a shortcut that persists in the ledger). Never required to ascend.
   If it fails, you *lose the item, not the run*, unless he drops you.
5. **A rare, late "tame/befriend" outcome** is a wildcard, not a plan.

## 7. Fairness: what must be readable

- **Sound is the spatial map.** Stereo wingbeats, distance reverb, a distinct
  low "inhale" 3 s before any breath. Mute the music when he is near.
- **His position is always findable.** A shadow on the turf, birds up on a
  thermal, or the sky folk's distress call in the direction he is - at least
  one of three at all times.
- **State is legible:** the sleeping dragon looks asleep; hunting has a
  different silhouette, wings held out, head low.
- **One hit, one consequence, one recovery.** Never a stack of losses from a
  single mistake (a swipe knocks 1-2 parts, not all of them; the part falls on
  a visible isle).
- **Cover is honest.** If it looks like it hides you, it hides you: a ledger
  mark for cover, same footprint, no invisible wing-spans.
- **No damage you cannot see coming from outside the frame.** Camera pulls
  slightly to keep his tell in view during a hunt (a cinematic look-at, not a
  lock).
- **Deaths replay clearly:** the death screen shows where he was, where the
  shadow fell, and the tell timing, once, in the ledger journal.
- **Comedy from physics:** hit by the gust and flung ten metres, landing on
  your own parked plane. The cost is a laugh and a recovery quest, not a
  restart (unless you fell off the world).

## 8. Minimum viable dragon

Smallest version worth prototyping, in order (each is playable alone):

1. **Attention + Stirring.** One hidden Attention value fed by rune pickups
   and time on the isle. At the threshold: the existing wake circuit runs,
   but now **aimed at the player's isle** (the circuit already exists). Cue
   only: roar, shadow, wingbeat sound. No damage yet. Tests tell readability.
2. **Gust on the isle** (the gale already exists): breath on the player's
   isle. On foot: slid 5-10 m, items dropped. Cover (one arch) = safe. Tests
   cover.
3. **Plane swipe with the barrel roll counter.** One part (prop) falls on the
   nearest isle. Tests the plane-cost loop.
4. **Rim tip + parked-plane roll.** Gale already tips isles; add the roll.
5. **Grab-and-drop** (later). Not MVP.

Scope guard: one dragon, one circuit, one cover type, two attacks (gust,
swipe), one Attention source (runes), and a debug HUD showing Attention while
tuning. If step 1 does not make the player *feel hunted*, nothing after it
will fix that.

## Wildcards

1. **The hoard fights back.** The nest's chest is a mimic of the *last run's*
   dead player: every item you lost on a prior run is in his hoard (a
   persistent, comical "he's wearing my spring shoes"). The heist recovers
   your own lost tools - a built-in comeback and a joke.
2. **He is cold.** The roost's negative light is real: he hunts toward *warmth*
   (campfires, the engine, a lit lantern). Campfires become both relief and
   bait; engine-off glides become a stealth verb; snow regions flip it.
3. **The dragon is a ride.** Late in the run, after a heist and a long chase,
   if you drop the stolen thing on a cliff he doesn't want, he carries you up
   through the cloud deck in his talons - a once-per-run shortcut with the
   biggest swing: he drops you wherever he gets bored, anywhere in the next
   layer, with whatever you were holding. Dread and a free lift in one.
