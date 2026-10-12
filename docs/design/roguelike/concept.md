# Roguelike concept (brainstorm, 2026-10-12)

> **Status: spitball, not decided.** Worked out in conversation. It would
> replace much of docs/game-direction.md's handcrafted plan; the pillars,
> tone and many systems carry over.

## The pitch

A 3D Spelunky with Mario Odyssey's movement. A weird, wacky, dangerous,
beautiful sky world of ruined floating isles. Climb as high as you can.
Randomly generated levels built from authored pieces: "hellish, never shit".

## What it is

- **Runs.** Start low, climb through layers (strata) of isles toward the
  cloud deck above; the way up is a gap in the deck you reach on foot. After
  a region's boss, a branch: two regions seen from the sky, pick one.
- **No builds, no stats.** The player gets better. Items found in a run are
  tools you use (Spelunky's spring shoes, cape, gloves), lost on death.
- **Isles are Odyssey/Galaxy playgrounds.** Each generated isle has things
  to do (rune sets, races, a trader, something buried, enemies to knock
  off, a caged sky-folk) and the isle's ledger card shows them when you
  scout it (plane lock-on or binoculars). The heart is Spelunky's "do I stop
  for that?" against a pressure (the dragon, a storm).
- **Runes are run currency:** spend on items, plane repair, fuel, a paid
  serpent ride, scouting.
- **The plane is earned each run.** You start on foot; the wreck and its
  parts are on the first layer or two. Assembled, it's precious and
  breakable: limited fuel, six parts that knock off (each loss changes the
  handling), it rolls off isles if badly parked, the dragon swipes it. It
  can't fly through a layer's ceiling.
- **Deaths are physics:** a dragon swipe mid-air with no isle below, an
  enemy knocking you off, a badly timed jump, the plane rolling away.
- **Tender mercies** pace the run: campfire alcoves, traders, view ledges,
  shrines, fuel cans. Tension, spike, relief.
- **Persistent:** the ledger as a journal of everything ever found;
  shortcuts (sky folk build ferries that start you higher); no stats.
- **Speedrun-friendly:** set seeds, daily seed, timer.

## Generation

- **Ruins hide generation:** collapse and decay read as authored.
- **Layers** of the aqueduct isle (the template): ground, spine (a big
  landmark: aqueduct, colonnade, hall), crown (henge, belfry), routes
  (sections), activities (ledger modules), dressing (already procedural).
- **Sections:** 10-40 m stretches with a way in and a way out (position,
  height, facing, speed needed), the verbs they need, and a danger cost.
  The generator chains them, checked against the pilot's real reach.
  Knobs (gap as share of max reach, steps, still vs moving, what's below)
  make one section easy or hellish. Each tier has a min and max total cost.
- **Existing grammar:** scripts/cluster_motifs.gd (layouts scatter, ring,
  chain, terrace, stack; relations near, bridge, stones, stack, fall).
- **Existing pieces:** the ruin kit (scripts/ruin_kit.gd: gothic, aqueduct,
  hall families), foot pieces (balustrade slide, swing ropes, bob and drift
  slabs, rope bridges), nine motif isles (scripts/kit_isle/motif_*.gd).

## Tone

A joyful, nimble pilot in a melancholy, ancient world. Not cozy. Comedy from
danger and physics, never written jokes. Region one, the ruins, feels like
Elden Ring's Limgrave. Physics, not damage: slide into enemies to knock them
off; they knock you off.

## The pilot's tech

Fast, momentum platforming where a skilled player is OP: run, jump, twirl,
slide, rail slide, wall kick, ledge grab and chain, rope swing, the pocket
sail (glide), the flow charge (updraft up, downdraft slam). Binoculars.
