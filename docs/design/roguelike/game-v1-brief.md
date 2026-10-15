# The game, v1: the brief (2026-10-14)

> Status: draft for the user to mark up. Every round toward the first
> playable game reads this first. Where it and an older design doc disagree,
> this wins.

## What this is for

Spelunky is the inspiration, not the target. The goal is not Spelunky in 3D.
It's to take the genius of that genre (short brutal runs, generated levels,
systems that collide, deaths that are your own fault) and build on top of
it into something fresh and new. Take risks with how enemies behave and how
the platforming works. A round that only recreates a Spelunky feature in 3D
has missed the point. Ask what this game can do that Spelunky can't.

What we take from Spelunky (for agents who don't know it well):

- **Short, brutal, generated runs.** Levels come from hand-made chunks
  stitched by rules, so each run is new but every piece is designed. Death
  ends the run. You get better, not stronger.
- **Systems that collide.** Enemies, traps, items and terrain all obey the
  same physics and hurt each other, so unplanned moments happen: a boulder
  crushes a shopkeeper, an arrow trap kills the monster chasing you.
- **Carrying.** You can pick up and carry almost anything: pots, rocks,
  bodies, the golden idol, a key to a locked chest, the damsel. You throw
  them, and you can take some through the exit to the next level. Carried
  things make the famous long-haul quests: take an item from one world to a
  later one to unlock something hidden. Carrying makes you vulnerable,
  because your hands are full and a hit makes you drop it.
- **Branching paths.** After the first world you choose where to go:
  jungle or volcano, desert or ocean. Each branch has its own look, enemies
  and secrets. Runs differ, and you come back to see the other branch.
- **Secrets and shortcuts.** Hidden areas, secret levels behind odd
  conditions, and shortcuts that, once earned, let later runs start further
  in.
- **The shop.** A shopkeeper sells items. You can rob him at great risk.

Three things set it apart:

- **Made for a friend.** It's single player, but designed with co-op in
  mind. This is the game you want to play with a buddy: terrified together,
  barely making it out of a layer, then buzzing about what's next (the
  next realm, the next theme world, the next enemy, the next nasty climb).
  Build every moment to be that kind of shared story. v1 is single player,
  but don't assume one wanderer forever: the camera, input, hearts, run
  state and enemy targeting shouldn't hard-wire a lone player where it's
  cheap not to.
- **Beauty and spectacle.** Spelunky isn't a looker. This game takes beauty
  to the next level, which is why the shaders, materials and art detail
  matter. Seeing things far off, silhouettes of what's coming up ahead, how
  the enemies look and move: part of the joy is simply being engrossed in
  the atmosphere. Atmosphere is never what gets cut to ship a mechanic.
- **Discovery.** Each new realm, theme world and enemy should be something
  you want to reach just to see it.

## The game in one breath

A Spelunky-like, pushed somewhere new, in an abandoned Olmec city
underground. Get from the start to the exit of a big, sprawling, vertical
layer, then the next, as far as you can. Each gate leads **higher**: the
run climbs out of the dark, and "going further" means climbing. The record
is the height reached.

It feels dangerous and a bit scary. It takes precise platforming, wit and
sometimes nerve. Enemies are relentless and don't care about you. They will
kill you or knock you off if they can. But there are always ways around them.

**Pacing, unlike Spelunky's short levels:** a layer is bigger in scale and
takes about **10 minutes** to reach the exit. A **world** (a realm with its
own theme, kit and enemies) is 3 or 4 layers, so about 30 to 40 minutes.
Then the next world. The Olmec city is the first world.

The user wants to boot it up, play, struggle to reach the exit, and keep
going.

## Design rules (every round is held to these)

0. **Creativity is rewarded, and it is risky.** This is the most important
   rule. The clever line (using an enemy, breaking the kit, taking the
   secret way) pays more than the safe one: a shortcut, a chest, a secret,
   height. It also exposes you: near the Olmec, in his sight, over the
   void, on a hit that knocks you off. The safe route exists, but it's slow
   and poor. Never make the clever play free, and never make it a trap the
   player couldn't read.
1. **Enemies are tools as well as threats.** Each enemy has at least one way
   a clever player uses it: a ride, a lure, a breaker or a launcher. Each
   layer offers at least one such chance, but not every route needs one.
   Examples the user named:
   - Lure the Olmec into a pillar so it falls and becomes a platform.
   - Ride his shoulders up a wall he's climbing, before he reaches his
     head. With the right item later, this gets easier or safer.
2. **Brutal, but fair.** Danger reads before it hits. Every death should
   feel like the player's mistake.
3. **Physics first.** Things knock you over; you can knock things over.
   Knock-back near an edge is what makes a hit deadly.
4. **Breakable kit.** Pieces the Olmec (or a slam) can break. What's left
   is something to stand on or climb, and sometimes a secret is revealed.
5. **Collectibles are a big part of the game**, the way they are in Mario
   Odyssey. Skilful, clever players collect more, and collecting is
   rewarded. There are two tiers:
   - **Runes**, the coin. Many of them, scattered along routes and just off
     them, in chests, and in risky spots that tempt a detour.
   - **A rare collectible** (name and look still to come). Few per layer,
     placed in hidden and hard-to-reach spots: behind breakable kit, at
     the top of a ride on the Olmec, across a jump only a good player
     makes. Finding one should feel like a small triumph.

   Both follow rule 0: the best haul is on the risky line. Both count on
   the death card and in the record. What they buy (the merchant, unlocks,
   secret levels) comes later, but the reward has to be felt from v1, even
   if only as a tally and a best.
6. **Existing pieces over new ones** in the stitch round. New mechanics
   wait for their own round.
7. **Don't box out what comes later** (see the last section): carrying,
   more than one gate per layer, checkpoints that persist. Keep runes as
   the currency, and keep gates and doors general.

## v1 scope

**In:**

- **The run loop**, already built as the stakes experiment
  (`scripts/roguelike/run_loop.gd`, `run_state.gd`): a start spot, a gate
  to the next layer, death in the void, a death card, retry on the same or
  a new seed, and a saved record.
  - Change: the gate leads **up**, not deeper.
  - Change: the card and the record read height.
- **Underground only.** Use the `--underground` look (torch, haze, abyss
  sky). It can lighten as the run climbs: deep dark at first, then hazier.
- **The Olmec body** hunting by light and sound, with beacons. The rune
  serpent, hazards and traps where they fit.
- **One world**: the Olmec city, 3 or 4 layers of about 10 minutes each,
  then the run simply carries on (the next world comes later). Today's
  layers may be a different length, so the tuning subagent times real runs
  and sizes the layers to match.
- **Hearts**, which are new:
  - 4 hearts, and gates don't refill them.
  - Fall damage scales with drop height (thresholds from the wanderer's
    size, `scripts/world_scale.gd`): a short drop is free, a long one costs
    1, a very long one costs 2.
  - An Olmec hit, a shockwave or a trap costs 1 and knocks you back.
  - Brief invulnerability after a hit.
  - The void still kills outright.
  - Hearts shown in the corner.
  - Death by hearts gives the same card as the void, naming the cause.
- **Collectibles** (rule 5). Runes are scattered on every layer, and
  chests (merged) pay runes. A first rare collectible is placed in hidden
  and hard spots. `GlyphPickup` already has a second glyph (`sun`) that
  could stand in until it gets its own look. Both are tallied in the
  corner, on the death card and in the record.
- **One launcher**, `run-game.command`, and a simple title screen. Boot it
  and you're in the run.
- **The Olmec city sets.** Picked from
  `brainstorm/round3-olmec-city/`, greyboxed and turfed through the motif
  pipeline **before** the stitch round. Prefer cards with breakable pieces
  and enemy-as-tool moments.

**Out of v1:** the plane, the dragon, items and upgrades, the merchant,
keys, secret rooms and secret levels.

## Order of rounds

1. **Olmec city sets.** The user picks cards. Then `motif-greybox`, and the
   user plays them. Then `motif-turf` on the keepers. Opus for new kit and
   places.
2. **The stitch round.** Done 2026-10-14 for hearts, the launcher and title,
   and the climb up; collectibles and danger tuning are still to come. One coordinator with four subagents in parallel,
   each in its own worktree:
   - **Hearts and damage** (Opus). Proved through the real play loop and
     input.
   - **Launcher, title and hearts in the corner** (Sonnet).
   - **Climb direction and danger tuning** (Opus): the gate leads up, there
     are more enemies higher up, the ledges get meaner, and the Olmec sets
     go into the generator's mix.
   - **Collectibles** (Opus): rune scatter and rare-collectible spots in the
     generator, putting the best haul on the risky lines, plus the tallies.

   The coordinator merges, runs the smoke checks (AGENTS.md), and writes
   one handoff with a **seams list**: everything faked, rough, or where two
   pieces didn't fit. Then the user plays the whole game.
3. **The city into the generator.** This is the round that makes real,
   legible Olmec city levels. As of 2026-10-14 the city kit (climb pieces,
   breaks, fire, landmarks, refuges, serpent) lives only in its yards
   (`studies/city_*_yard.tscn`, `city_kit_gallery.tscn`); nothing in
   `scripts/roguelike/` places it.
   - Build city motifs from the kit through the motif pipeline (greybox,
     then turf). Each motif is a place: a stair climb, a breakable
     colonnade, a serpent crossing, a refuge. Each has its routes, its
     threat and at least one enemy-as-tool moment (rules 0 and 1).
   - Teach the generator to lay layers mostly from city motifs, the old
     motifs mixed out or kept rare. Layers are sized for about 10 minutes,
     and the next layer stands higher.
   - Collectibles and danger tuning land on these city layers, not the old
     ones.
4. **Follow-ups**, picked from the seams list and the user's play.

## Later (v1 leaves room for these)

- **Merchant**, found at spots through the map, selling items that help
  you, for runes. It needs items, so the
  merchant and items are one round. `ideas-runes-ledger.md` sketches
  traders: about one per few layers, three wares shown on the stall.
- **One item at a time.** You carry a single item, so taking a new one means
  giving up the one you have. Every pick is a choice (rule 0).
- **Items and upgrades**, for example a grip that lets you hold on to the
  Olmec while he climbs.
- **Secrets.** Breakable kit reveals hidden spots. Keys open sealed rooms;
  the locked chest's slam-to-open is the seed of this.
- **Checkpoints that hold forever.** The game is brutal by default: a death
  costs the run. Beat a world once and its shortcut unlocks for good. Every
  later run chooses: take the shortcut to a later world, or play from the
  start again (to find secrets you missed, to fetch something a later world
  needs, or for a particular kind of run). There may be a hub world later
  to choose from; not yet.
- **Carrying.** Pick things up, carry them, throw them, take them through
  the gate. Your hands are full, so you climb worse, and a hit makes you
  drop it (rule 0). Uses:
  - **Heists.** For example the dragon heist: steal his egg and get it out
    of the layer while he hunts you, moving from cover to cover.
  - **Long hauls across worlds.** Take something from world 1 to world 3 to
    open X. Take something from world 2 to world 4 for Y. Checkpoints let a
    player go back for the thing.
  - Keys, the rare collectible's caches, and throwing things at enemies or
    traps.

  Nothing like this exists yet; it's a mechanic round of its own (Opus:
  input, physics and animation).
- **Branching worlds.** A layer can end at more than one gate, and the
  player chooses the next world: two or more realms with their own theme,
  kit and enemies. Runs differ, and there's a reason to come back. The
  dragon's sky could be one branch.
- **Secret levels.** A hidden second gate leads to a special layer and back
  into the climb.
  - **The aqueduct isle** (The Aqueduct of Veyl,
    `run-aqueduct-isle.command`, `aqueduct-map.md`) becomes a secret level
    behind some crazy conditions. Open: which conditions, and whether it
    keeps its daylight (a glimpse of the sky from underground) or goes
    dark. It is also the ring shape's middle isle today, and that would
    need to change.
  - The dragon may become a bonus or side area.
- **The sky.** Eventually the climb may open into sky layers: the same
  game with a different feel.

## Open questions for the user

- The aqueduct's conditions. Some candidates: reach a height in a time
  limit; carry a key found on a deep layer up unhurt; get the Olmec to
  break a particular sealed gate; take no damage on a layer.
- 4 hearts, or another number?
- Which Olmec city cards go to greybox first?
- The rare collectible: what is it, and what's it called?
