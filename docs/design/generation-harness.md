# Generation harness (idea, not started)

Status: idea captured 2026-10-08 for a future session. Nothing is built. Ask the user before starting.

## What the user wants

"If I was to build a harness I'd want it to be for level generation variety. So, being able to build all the kits, pieces, and then have a harness actually play them, and get some numbers. Like 'is it playable', 'is it long enough', 'how much does the player have to move'. Being able to quickly spin up new generations, combinations, motifs, and then iterate and natural select what's best."

The user keeps their taste for themselves: they are still finding what they want and don't want taste encoded as rules. The harness measures what can be measured; the user picks.

## Shape

1. **Generate.** Run any motif or set piece over N seeds and parameter mixes, e.g. hall length, gap sizes, act order, hole count.
2. **Play.** Bots run each result headless.
   - **Plane bot:** follows the piece's flight line at cruise speed (`scripts/sky_plane.gd`, 14 m/s, boost 22), threads holes, and bumps and recovers.
   - **Foot bot (later):** routes the walkable tops and checks each jump against the pilot's ~2.5–3 m jump.
3. **Measure.**
   - **Playable:** it completes without getting stuck, every hole admits the plane's wingspan with a margin, every gap is jumpable.
   - **Long enough:** seconds of flight from entry to exit, and the inside vs open-sky share.
   - **How much the player moves:** stick input over time, bank and pitch changes per second, tight moments per minute. Too low is boring; too high is exhausting.
   - **Freedom:** exits per minute and entry points.
   - **Cost:** triangles near and far, build time, frame hitches when it streams.
   - **Variety:** how far apart two seeds' results are, so a batch isn't ten near-copies.
4. **Select.** Drop the broken ones and keep the ones inside the target ranges. The user gets a review packet: a stats table, a contact sheet of captures, and one command to fly each. The user flies the top few and picks, and the picks move the target ranges for the next batch.

## Rule: filters, not maximisers

Use the metrics as filters and target ranges. Never maximise one: maximising "player movement" breeds a nauseating corkscrew. Metrics rule out the broken and the boring; only the user judges fun among what's left.

## Missing piece: a common set-piece interface

Every set piece should answer the same query:
- its flight line (sampled world-space path with heading and height)
- its sections, with type and extent
- its exits and entries (roof gaps, breaches, holes) and the gaps between pieces
- its clear corridor (lane width and height per section, slit and hole sizes)
- its walkable tops and gap anchor points

One bot and one report then work for all set pieces. Collectible token lines and skydive landing spots need the same data.

## What already half-exists

- `tools/probe_clusters.gd`: cluster plans over many seeds (30 for everyday checks, 300 at milestones). `tools/capture_clusters.gd` takes rendered captures.
- The ruin kit gallery's fly mode autopilot follows a hall's path (`docs/scenic/ruin-kit.md`).
- The pierced isle verifies every hole is flyable (`docs/scenic/pierced-isle.md`, `tools/probe_pierced*.gd`, on feature/pierced-isle).
- The Sundered hall (feature/sundered-hall) has its own plan checks.

## Suggested first round

1. Add the common interface to the Sundered hall and the pierced isle.
2. Build the plane bot, the metrics and the review packet.
3. Run a first batch of hall seeds for the user to fly and pick from.

The foot bot comes in a later round.

Constraints: tests and bots run headless (`AGENTS.md`). Rendered captures for the packet are allowed and always pass `--no-title`. GPU-only checks are reported as unverified.
