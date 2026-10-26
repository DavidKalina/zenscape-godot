# Spec: shared routes (parked)

**Status: parked, 2026-10-25.** The user wants this and thinks it fits the game, but later. Nothing is built. Settle the open questions with the user before a round starts.

A player flies a route of their own, records it and publishes it. Other players find it and fly it, scored on how closely they hold the author's line and/or how fast they finish.

## What the user said

- You can create your own route and publish it online for other people to discover.
- A good player makes a route by flying it. The closer people stay to the route, the better their score. Beating the time could be the other score.
- Discovery is open. Ideas so far: a shared daily world, a shared monthly world, or a menu for browsing other people's routes.

## Sketch

- **Recording.** Press record and fly. The path is sampled at about 10 Hz (position and rotation), roughly 30 KB for two minutes. Playback is of the recording, so the flight physics doesn't need to be deterministic.
- **Flying a route.** It's the rival race with a recorded line: the author's ghost flies the recording, and the existing race marker, pass rule and HUD carry over (`rival-race-handoff.md`).
- **Scores.** Two together:
  - **Time:** gates generated along the path every so often, passed in order.
  - **Line:** how closely you hold the author's path along its length. This one makes the author's tight threads the challenge.

  Medals could combine the two.
- **Finding routes.**
  - In the world: a faint ghost contrail or glint marks where a route starts, and flying into it starts the route. This works the same way the rival is offered now.
  - In a menu: browse routes with ratings and most-played.

## The land has to match

A route only works if every player sees the same land under it.

- **A shared seed.** Routes are recorded on a world everyone shares: one standing world, or a daily or monthly one (open question).
- **A land version.** A route stores the land generator's version. Any change to terrain generation can move land under old routes. Before routes launch, either freeze a world-1.0 generator and keep it alongside newer ones, or retire routes when the land changes.
- **Repeatable features.** Not everything is repeatable yet. `LandArches.standing()` depends on which arches the worker threads have built around the eye, and a slot hall's height is read from its built pieces (`rival-race-handoff.md`, "What isn't repeatable"). Routes and ghosts need these read from the seeded plan (`arch_plan.gd plan()`) instead. Co-op needs the same fix.

## Hosting

Steam can do all of it, with no backend of our own:

- Workshop / UGC files hold the routes, with ratings and discovery.
- A leaderboard per route (Steam can create one at runtime).
- Ghost files attached to leaderboard entries, so you can race the top run.

Godot reaches all of this through GodotSteam.

## Order, when it's picked up

1. **Local.** Record your own line and race your own ghost. The same recording feeds the replay idea (a cinematic replay of your last 20 to 30 s).
2. **Repeatable land.** The shared seed, the land version, and arches and halls read from the plan.
3. **Steam.** Publish, browse, leaderboards, ghosts, and the in-world start markers.
4. **Later.** A curated route of the day or week.

## Open questions

- A daily world, a monthly world, one standing world, or several?
- Browsing in a menu, finding routes in the world, or both?
- The line score's tolerance: how far off the line still scores, and does it tighten with the medal tier?
- Does a scrape or touch during a route cost anything?
