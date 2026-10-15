# Runes and the ledger in a run (ideas, 2026-10-12)

> **Status: brainstorm, nothing decided.** Hard rules:
> no builds, no stat boosts, no skill trees, no crafting. Items are tools or
> verbs, lost on death. Numbers are at default sizes (walker 1.0, plane 2.0;
> jump 0.8/1.5 pumped, twirled gap 3 m, glide 3.7:1) and are guesses.

## 0. The one idea that holds it together

**Runes buy time, safety and information; the ledger pays out the same three
things in kind; nothing ever makes the pilot stronger.** A rune is a favour
you can cash at a sky-folk trader, so a speedrunner who skips every card
simply arrives poorer and *less informed*, never weaker. Everything a rune
buys is something a good player can also do without (carry a spring boot vs.
nail the twirl), so skipping is a risk choice, not a handicap.

Runes are per-run and die with you (a few "banked" exceptions in section 6).

## 1. What runes buy

### 1a. The trader model

- **Sky-folk traders** sit on roughly 1 isle in 4, as a tender mercy: a
  lantern on a ledge, a hanging stall, a trader on a drifting slab, a
  trader in a stuck gondola.
- **Stock: 3 slots, rolled per trader**, never more than one of each item,
  one slot always cheap (a "hello" item), one always a "tempting" pricey
  one. Stock is shown from a distance by the trader's wares hanging on the
  stall (readable on scouting: you can see a spring boot swinging).
- **Prices in 3 tiers**: S (3-5 runes), M (8-12), L (18-25). A normal isle
  with a full rune set pays 4-8; a risky one 10-16. One trader visit
  affords about one M item per layer if you stop for most things.
- **One-trader-per-layer guarantee** so the economy isn't luck-starved,
  and the trader's position is on the ledger *map* (not the card) so
  routes can plan around it.
- **No selling and no haggling**, but **bribes work**: carrying a "rare
  find" (buried thing, caged-folk token) trades 1:1 for an L item. Finds
  are runes with a story, so the economy has two coins that don't convert
  by default.
- **Theft is a verb**: grab an item off the stall and run; the trader
  sends bell-hawks (a danger spawn) at you. Kept in for speedrunners.

### 1b. Items (all tools, all lost on death)

| # | Item | Verb / what it does | Effect on movement or danger | Tier |
|---|---|---|---|---|
| 1 | Spring boots | next landing from height bounces you, jump held = 2.5 m launch | one big vertical, no fall-reset; bounce chains off flat ground; fall damage gone while worn | M |
| 2 | Cape | open a second glide (a cloth, not the pocket sail): wider, slower, lift in updrafts | rescues a missed jump; the sail's "once per airtime" kick stays | M |
| 3 | Grappling gloves | hold a grab on any ledge at 2x reach, no slip on wet stone | GRAB_TOP 1.9 -> ~2.6 on plain jumps; wall-kick climbs bare walls | M |
| 4 | Compass (rune-sense) | a needle pointing to the nearest unfound rune/find on this isle | information; speeds up full-ledger, no help on any% | S |
| 5 | Spyglass lens | binoculars show prices and stock on far traders and the ledger card rows at 2x range | scouting without flying | S |
| 6 | Rope coil | place one anchor point (a stake) once; swing from it | makes a 17 m gap crossable by hand, a fixed-length rope | M |
| 7 | Smoke pot | thrown, blocks dragon line of sight 10 s; birds ignore you | dragon avoidance for one crossing | M |
| 8 | Wax boots | stuck to walls: slide is slow, rails are slow | brakes; helps tight tech at the cost of speed | S |
| 9 | Lantern | lights dark interiors (halls, cisterns) and lets you see through fog | enables the dark sections as a shortcut | S |
| 10 | Bell charm | ring it: nearby enemies look at you for 2 s | a lure for knock-offs and for stealing past a patrol | S |
| 11 | Glue pot | stick a platform you are standing on to a rail so it stops bobbing | removes drift/bob timing from one section | S |
| 12 | Blast seed | thrown, shoves everything 4 m, including you | double jump (self-launch), knocks enemies off, breaks fragile walls | M |
| 13 | Plane patch | restore one knocked-off plane part | cure for a bad landing | M |
| 14 | Fuel can | +1 tank, refilled in the plane | one more sky leg | M |
| 15 | Ferry token | one paid ride on a sky-folk airship/serpent between layers | skip a section of climbing, ending on a landing isle | L |
| 16 | Dragon toll | a pearl the dragon takes; it won't land on this isle for one visit | removes the pressure clock on one isle | L |
| 17 | Skeleton key | opens one cage or locked door anywhere | skips the "find the key" half of a caged-folk module | S |
| 18 | Parachute leaf | once-only: if you fall past the isles' base, a leaf catches you, you land on the layer's lowest isle | a single "undo a fatal fall" | L |
| 19 | Bait fish | tossed to a serpent: it follows you and rides alongside a layer | the serpent as an ally for one race or a crossing | M |
| 20 | Lodestone shard | places a map ping on the next layer's ceiling gap | information only | M |

**Cheap rule of thumb**: an item either unlocks a *different route* (boots,
gloves, rope coil, ferry) or *buys back one mistake* (patch, parachute,
dragon toll). Never "+10% anything".

### 1c. Other rune sinks (not on a stall)

| Sink | What | Notes |
|---|---|---|
| Serpent ride | pay a serpent-folk shrine; ride the serpent to a visible isle | a fast skip with an unskippable cutscene-free ride; the serpent has its own path of hazards (updraft, flock) |
| Plane repair | a wreck-smith isle: runes for fitting a found part or fixing damage | the plane is earned each run; runes shorten the hunt |
| Fuel | fuel cans on isles, sometimes locked behind rune doors | |
| Scouting | a tower or beacon: pay to show every card on the layer | the thing speedrunners buy first |
| Bribing | pay a guard-spirit to look away from a gate or a patrol | enemies ignore you for the section |
| Shortcuts | pay to extend a ferry line, drop a rope bridge, lower a drawbridge | the shortcut stays for the *rest of this run*; see section 6 for persistent ones |
| Shrine wish | drop 12 runes in a shrine: the next hard jump has a safety net (a ghost-platform) once | tender mercy converted to a purchase |
| Toll gates | a gate wanting N runes to pass | the "you skipped cards, now you pay" gate; skipping stays viable because of other routes |

## 2. Isle activities (generator modules)

Each module is a small config: a *spawn rule*, a *cost to the generator's
danger budget*, a *validator*. Every module is declared with a card row (a
cryptic name) and a reward. The validator runs on the pilot's real reach
(`PilotMotor`, `RuinKit.GRAB_TOP`/`CHAIN_TOP`) without items, so a module is
always doable bare-handed.

| # | Module | What the player does | Generation | Validation |
|---|---|---|---|---|
| 1 | Rune set | collect 5 runes in a ring/chain/terrace | pick a cluster layout (scatter, ring, chain, terrace, stack) and place with relation near/bridge/stones | each rune reachable from the previous by a route within the pilot's reach; none dead-ends below the isle's floor |
| 2 | Rune cache (buried) | dig at a marker; a find (not a rune) | a decal-less mound at a "heel stone" spot; the card hints "where the shadow ends at noon" | the spot is on walkable ground, not on a sloped rubble face |
| 3 | Race (serpent) | race a serpent to a gate | a start rune and a goal gate; the serpent's spline follows the sections chain | the pilot's best-case time beats the serpent by 15-25% on the intended route |
| 4 | Race (ghost / ring run) | pass N rings in order within T | rings along the section chain, T = bare-hands speed x 1.3 | route exists; no ring in a hidden pocket |
| 5 | Caged sky-folk | find a key, open a cage, escort or just free | key in another module on the same isle (carried key slows tech) | key is on a different section from the cage; cage not behind one-way drop |
| 6 | Knock-offs | send 3-5 enemies off the edges | enemy slots on narrow pieces (bridges, ledges) | each slot has an open edge <4 m away; none stands on a knockback-proof tile |
| 7 | Delivery | carry an object to a slot (tech is muffled) | pick a start at spine end, goal at crown | the route is walkable *with carry penalties* (reduced jump, no sail) |
| 8 | Plane-only find | something on the sky side, needs the plane | placed at a position the walker can't reach but a plane (width + wingtip SNUG) can | an opening through `WorldScale.opening` |
| 9 | Dark hall | cross a dark interior to a find | the hall family with a hidden shortcut | route without a lantern is possible but long |
| 10 | Weather window | reach the top before the storm (timer) | a storm clock with a route and a shelter | safe-by-time route validated |
| 11 | Guardian / mini-boss | defeat or evade a boss on the crown | one boss per tier; rewards the same | arena has edge hazards |
| 12 | Stolen trader | the trader is gone, find them | a trader token placed on the isle; once found, a shop opens here | a path exists and is flagged |
| 13 | Dragon heist | swipe an egg from the dragon's perch | needs the dragon's pressure; the perch is on a ruined spire | the heist leaves a way out |
| 14 | Echo (puzzle) | strike N chimes in the card's remembered order | the card gives the order as a cryptic epithet | all chimes reachable |
| 15 | Wreck salvage | pull a plane part from a hanging wreck | the wreck dangles under a ledge | only reachable with a rope/glide |

**Generation order** (per isle): ground -> spine -> crown -> routes ->
modules (budgeted) -> dressing. Total module count is 2-5 per isle; a module's
danger cost counts against the isle's cap, so a rich card is also a dangerous
isle. A seed fully determines modules, so a daily seed is fair.

## 3. The card in a run

- **Scouting shows the card**: plane lock-on, binoculars, or a spyglass lens.
  A far glance shows the title, epithet, and the *row icons*; a close look
  adds the objective names.
- **Cryptic names stay**, but each type has a constant *sigil* so veterans can
  read the row at a glance: a diamond (runes), a loop (a race), a spade
  (buried), a bell (caged), a boot (knock-off), a satchel (delivery). The
  name hides the specifics ("What the Bells Remember" shows a bell sigil but
  not that it's a cage).
- **What the card *never* shows**: positions, the reward, the exact price.
  The reward shows only as a *shape* on the card's edge (a feather = a
  safety, an eye = an information, a hand = a favour).
- **Risk shown honestly**: a small skull rating (1-3) = the isle's danger
  cost. So the choice is "3 sigils, 2 skulls, a feather reward" vs "1 sigil,
  1 skull, an eye".
- **Layer map**: scouting a layer gives the compass of cards that isle by isle;
  a tower can reveal all of them (see sinks).

## 4. Reward for clearing an isle's card

Each card is *all rows done* (not each row). Options, weighed:

| Reward | What it is | Pro | Con |
|---|---|---|---|
| A. Dragon won't land here | safe haven for this run; a campfire appears | strong tender mercy; no stats | only useful if you'd stay |
| B. Next layer's cards revealed | the next layer's cards unveiled | pure info; great for planning a route | wasted for speedrunners who already scout |
| C. Free plane repair | one part restored | helps a fragile plane | feels like a stat if the plane is broken |
| D. A sky-folk favour | one-shot: ferry token, trader discount, a shortcut built | flexible; story-rich | needs authored favours |
| E. A permanent shortcut in the ledger | the ferry route is saved for future runs | persistent without stats | lopsided if too strong |
| F. A free item from a stock | a tool from the trader's stock for free | simple | feels like a shop |
| G. A "clear sky" | the weather and dragon pause for the layer | pacing relief | doesn't feel special |

**Recommended**: pick one *per card, rolled by the generator* and shown as
the shape on the card: A (dragon), B (reveal), or D (favour). C and F are
rare; E only for a full region (a "region clear" beat). Rolling means the
route-planner decides whether the reward is worth the card.

## 5. Speedrun balance

### Why skipping stays viable

- **Nothing on a card is required** to reach the cloud deck's gap; the
  generator guarantees a *skip route* on every layer (a fast line that needs
  only base tech) and validates it bare-handed.
- **Rewards don't scale the player**: a ledger clear gives safety, info or
  time, which a good run doesn't need.
- **Tolls are optional**: a toll gate always has a bypass requiring tech.
- **The dragon is the pressure**: stopping costs wall-clock, and the dragon
  turns up over time, so "do the card" always costs dragon time.
- **Seeds are shareable**: a speedrunner posts a seed + a route; the
  community's meta is route knowledge.

### What the routes look like

| Route | Plan | Reads as |
|---|---|---|
| Any% | skip every card; use skip routes, glide, wall-kick; buy 1-2 S items only; no plane | hard tech, low runes, high death risk |
| Scout-and-snipe | buy scouting, hit only cards with a feather/eye reward and 1 skull | route planning |
| Trader-line | collect runes on the way, spend on ferry tokens to skip layers | economy optimisation |
| Full-ledger | clear every card for the dragon-free havens, bank every favour | slow, safe, long; the journal fills |
| Plane any% | find the wreck first, fly the sky layer | different risk: fuel and tail damage |
| Naked | no purchases, no tokens | challenge category |

### Risk vs reward reading

- A **skull** is how fast you might die; a **sigil** is how many things to
  do; the **reward shape** is why. Players can see all three from outside.
- Rule: **average reward value ~ the isle's cost to a competent player in
  runes-equivalent time**; rewards beat the shop only for players who like
  the module itself.

## 6. Persistence across runs

- **The ledger as a journal**: every seen card, found object and trader is
  noted. A card remembers *what you did*, not a bonus.
- **Unlock what is *in the pool*, not what you can do**: items appear in
  traders' stock when the journal shows you found them (a discovery gates
  appearance). New isle types (modules) enter the pool by finding their
  first instance in a run.
- **Shortcuts (persistent, from section 4E)**: sky-folk build ferries, bridges
  and signal fires that start the next run a layer up, if you cleared the
  region's card before. Persistent shortcuts mean *start higher*, never
  *start stronger*. Capped at 1 per region; a daily seed ignores them.
- **Banked runes**: none, with one exception: a "cairn" where you can leave
  up to 5 runes to be there next run (a sack the dragon might eat).
- **Journal pages**: completing a region page reveals lore and a cosmetic;
  no mechanical value.
- **Named finds**: the big collectibles (the moon) unlock new regions' entry
  tiles.
- **Fair daily seeds**: persistent unlocks apply to normal seeds only.

## 7. Combos and abuses worth leaving in

| Combo | Why it's fun |
|---|---|
| Spring boots + blast seed | launch yourself 15 m and glide; faster than the intended route; risk of dropping off the layer |
| Cape + updraft + flow charge | the long glide; skipping a whole layer (the intended "great skip") |
| Bell charm + knock-off | lure three enemies together, one slide hits all |
| Dragon toll + theft | steal from the stall, then the dragon can't land on the trader's isle |
| Rope coil + carry delivery | swing a heavy delivery over a gap, losing it halfway (comedy) |
| Smoke pot + heist | blind the dragon, take its egg |
| Glue pot on a ferry | glue yourself to a moving slab and ride it off the layer |
| Ferry token + plane | ride the ferry with the plane in tow |
| Grappling gloves + wet stone | chain-hang up a bare wall |
| Bribe + trader | pay the guard to kill the trader's rivals |
| Throw a rune | runes can be thrown onto a far spot to bring along (the cheap "carry" trick) |
| Stack carry | carry two deliveries with a combo (hard, slow, funny) |
| Reset the dragon | a rune offering at a shrine pushes the dragon's arrival 60 s (stackable, a speedrunner's timer-buying) |

**Leave in**: sequence breaks that skip a module (no "required" flags), item
combos that break the intended route, and theft. **Block**: nothing that
breaks seed determinism or dupes runes.

## 8. Recommended minimal economy for a first prototype

- **Runes**: 4-8 per isle in one rune set module; nothing else pays runes.
- **One trader per layer**, 3 slots, prices S=4 / M=10.
- **6 items**: spring boots (M), cape (M), compass (S), rope coil (M), smoke
  pot (S), plane patch (M). Skip fuel, ferry and dragon toll at first.
- **Modules**: rune set, knock-offs, buried find (3 only); each with a card
  row and sigil.
- **Card reward**: the dragon-free haven (A) only, shown by a feather.
- **One sink outside the shop**: a scouting beacon (costs 6).
- **No persistence at first** beyond the existing ledger file; unlock nothing.
- **Validator**: every layer has a bare-handed route to the deck's gap; every
  module is reachable without items. Test that in headless seeds.
- **Success test**: can a tester finish a layer with zero runes? With 20? Is
  any item bought by >80% or <10% of players?

## 9. Wildcards

1. **Runes as ammo**: a thrown rune is a lure, a signal, a weight for a
   switch and a toll; the same currency has verbs, so "spend or use" is the
   tension, not the shop.
2. **The sky-folk ledger**: traders keep their *own* ledger of you; if you
   steal, free caged folk or skip, their prices and stock shift across
   the run (a reputation of this run only). No stats, but a world that
   remembers.
3. **Debt**: a trader will lend a tool for free *now* and the dragon
   collects later (a debt token follows you; repay at any trader or lose the
   tool and meet a collector). A speedrunner's gamble: carry the debt to
   the end.
