# Handfuls

**You release something; the world decides what becomes of it.** A handful is not a paintbrush. Where it goes and what it becomes come from the land and the air: the shape of the ground decides how water fills, and the wind and the ground decide where pollen settles and what grows. The player does not decide the outcome by where they paint. The user, on 2026-09-27, after trying a seed sprinkle: "I just don't like it as a paintbrush... the geography and the environment impacts what gets grown. In the case of the water ball, the shape of the geometry affects the water, how it fills. Similarly the seeds need to be affected by the wind, and if there's no wind, it just kind of floats down."

Agreed 2026-09-27 (branch `feature/handful-shadow`), after the user said the water ball "tends to put water in the wrong spot, not where you release it" and had not noticed its shadow at all. This is the vocabulary for tools that carry something and let it go, and the one rule they keep.

## Words

- **Handful.** The thing a tool carries in the hand and lets go: water (the water ball, `scripts/water_ball.gd`), pollen for forest (`scripts/pollen_cloud.gd`, `docs/scenic/brushes.md` "Pollen") and flower seed (below, "Flower seed"). A handful has a size that grows while it is gathered, and a place on the ground where it will land.
- **Seed.** Since 2026-09-28 forest is thrown by hand: each throw flies with real momentum and lands where the physics and the wind take it, and a soft footprint shows where the next throw will come down (`docs/scenic/brushes.md` "Thrown seed"). The veil described next is behind `--pollen-veil`.
- **Pollen (the veil, `--pollen-veil`).** Forest is a veil of pollen and seed-fluff, light enough that the air carries it. While the button is held, a sweep lays the veil in the air along the pointer's way, and nothing lands. On release the whole veil comes down together: in still air straight down in the swept shape, in wind smeared and drifted downwind. Three earlier tries were turned down on 2026-09-27: a gathered handful of winged seeds (hold, then release), a seed sprinkle that poured while the button was down (it was "a paintbrush"), and a single released cloud that a drag only moved (the user found letting it all go at the last point unintuitive). In the user's words, what they want instead: "you kind of drag around and then you release a bunch of pollen that starts in the air, and then that area that you dragged descends from the air, and then the wind kind of arranges it."
- **Shaping tools** work the ground directly under the pointer while the button is down: land and path. They stay brushes (`docs/scenic/brushes.md`).
- **Sowing tools** release a handful onto the land: water falls, pollen and flower seed drift. What they make is decided by where it lands and what the land does with it, never by a painted outline.
- **The lifecycle**, in order:
  - *gather*: the press, and the handful growing while held (the ball condensing and filling);
  - *carry*: following the pointer, a little behind it, alive (the ball's spring, bob and wobble);
  - *release*: letting go (the water ball is tossed up and popped in the air, `docs/scenic/god-hand.md`);
  - *fall* (or *drift*, for light things like pollen): straight down from where it was let go;
  - *land*: the impact, on the ground under the handful (the splash);
  - *take*: the land accepts it (the pour settles);
  - *grow*: what it becomes (a pond, a stream, a waterfall; later a meadow).

  Pollen is *laid* rather than gathered: the sweep is its carry, and the veil is the handful. At release it takes a breath (lifts and gathers in) and then *drifts* rather than falls: it sinks as one sheet, peeling down along the sweep, each mote on the air at its own pace, and the wind carries it all the way down. It *takes* where the ground suits it (moisture, water, slope, height, rock, snow, existing forest) and *grows* into a stand of the species the ground's stand holds.

## The shadow is the promise

Every handful casts a **mark** on the ground straight below it, from the moment it is gathered until it lands. The mark shows exactly where it will land, and what lands must land inside the mark.

What this guarantees:

- The mark sits straight below the handful's own x, z, not under the pointer and not along the sun. The handful may trail the pointer; the mark moves with the handful.
- Release changes nothing about where. The handful falls straight down: whatever sideways speed it carried goes into its wobble, not its path. The x, z where it lands equals the mark's centre at the moment of release.
- The landing height is the terrain under the handful, not under the pointer (`WaterBall.ground_at`), so the fall ends on the ground the mark lies on.
- The handful never swings out past the land's edge, so the mark is always on ground it can land on.
- The mark is noticeable on bright and dark ground, by day and at night, and it is the only shape under the handful that could be taken for a landing spot. No sun-cast shadow competes with it.

What it does not promise: where the land takes the handful once it has landed. Water runs downhill to the basin it drains to (`docs/scenic/water-brush.md`), and seeds will root where the ground suits them. That run should read as the handful being taken, not as it teleporting; for water it does not yet (see the water brush's known gaps).

For pollen, which drifts, the promise is a footprint: a soft pool on the ground that follows the swept shape while the veil is laid, showing where it will settle given the wind as it blows now. In still air it lies right under the sweep. In wind each part of it is shifted and stretched downwind. The wind is read every frame at several places along the veil, so a gust through the falling veil carries the part it passes, and the footprint moves with it, as the ball's mark moves with the ball. Every mote lands inside the footprint as it stands at that moment. In steady air that is the footprint shown at release. The footprint is drawn in the water ball's family, softer and lighter, with a warm rim and faint twinkling specks (`shaders/pollen_footprint.gdshader`). Since 2026-09-29 it is drawn only with `--show-promise` (`PollenCloud.show_prints`), because the user found the outlines too many and too hand-holding. The veil drifting in the air and the sprouts where it lands show where it went.

## The water ball's mark

`shaders/water_ball_ground.gdshader`, the ball's ground decal. The mark is a pooled shadow the size of the ball (`radius`), drawn as a slowly turning `MARK_SIDES`-gon (12, turning `MARK_TURN` 0.12 rad/s) so it is faceted like the ground. It is painted in two tones, a darker core inside 0.58 of the radius and a lighter band out to the edge. A pale rim of water light sits on the edge, lit by the sky as well as the sun with a small floor that rises at night, so it reads on dark ground. The rim and size breathe with the ball's bob (`breath`, ±3.5 %). Held high (`MARK_HIGH`, 2 m of gap or more) the mark is soft and lighter (0.3 + 0.08 dimming, edge 0.16 of the radius); as the ball falls it darkens (0.44 + 0.14) and its edge sharpens (0.05). Sunlight gathered by the ball plays as caustics inside it by day. The mark shows from the ball's first moment (`mark` = the hold ramp × smoothstep(0.05, 0.3, radius)) and stays through the fall until the splash takes over.

## Flower seed

Since 2026-10-02 the hand scheme sows flowers as it sows trees. The user could not put the flower kit (docs/scenic/flowers.md) into a world by hand: the hand scheme has no meadow brush, and the materials bar's wildflower and dandelion slots set down the four old forms a few at a time, a paintbrush.

**How the player does it.** Press a flower in the bar's seed group (Wildflower, Dandelion, Poppy, Cosmos, Sunflower). It rides as a pinch of seed under the pointer. Press on the land and drag: the pinch flicks a light veil of seed and fluff out along the way. Let go: the veil takes its breath and drifts down. A quick tap drops a small handful where the pointer is. The roll's pips (or `1` `2` `3`) size the veil. A few seconds later the drift comes up where the seed settled, blooming in the order it landed. Sweep again over it to fill it in; Cmd+Z takes back one sweep. Esc, the Hand or the slot again puts the seed down.

**The world decides.**

- *The air.* Flower fluff is lighter than tree seed: the veil drifts `CARRY` (1.3) times as far on the same air, and a gust or the Feather passing carries the part it passes further still (scripts/pollen_wind.gd; `pollen_cloud.gd` `_wind`, the veil's `carry`). It comes down closer to its sweep (`SPREAD` 0.55 of the tree veil's spread), so a sweep reads as a band.
- *The ground.* A flower takes only on open ground: not on water (live water 2 cm deep or more, a pond, the blend's wet ground), not on rock (steeper than the habitat's rock slope, or cells painted at least half rock, earth or sand), not within 1.2 m of the snowline, not steeper than 0.75, not under a tree's crown or where three trees stand within 2.6 m, and not on a stone or another plant. Where a seed lands on ground that takes, the veil's sprout pops up (the tree seeds' own), as a promise of what is coming.
- *The composition* is the meadow types' (scripts/meadow_types.gd): the landings' density (motes a square metre round each point, a 0.55 m kernel) stands in for a drift's presence noise, so a sweep's core is packed (heads nearly touching, as at a generated drift's heart), its edge thins and feathers, a few companions mix in, and sunflowers keep to rows (a stand, not a carpet). Under the drift the ground is only warmed toward the flowers' colour, faintly (`WASH` 0.16 at most): the faceted ground shows its painted layer per face, so a stronger wash read as a patch of bare earth under the poppies; the flowers carry the colour.
- *What grows:* Wildflower sows the wildflower meadow's mix (oxeye daisy, buttercup, poppy, cosmos, lupine in drifts of one kind), or, in a world made as a meadow type, that type's own mix and drifts. Dandelion sows dandelions and seed clocks (a few buttercups), Poppy poppies (a few daisies), Cosmos cosmos in drifts of one colour (a few daisies), Sunflower a stand in rows facing the noon sun (a very few buttercups).

**How it is built.** `scripts/flower_sowing.gd` (`SLOTS`, `suits`, `grow`). The slot is stamped on the veil (`seed_kind`); `NativeChunkEditor._write_cloud` sends a flower veil to `_write_flowers`, which grows the drift from its landings and their times in one stroke: one undo step a sweep. The flowers are object records of the kit's keys, marked hand work (`source: "hand"`, so emergence leaves them), with Emergence's `born` stamp, so they grow in with the shader's easeOutBack rise (`SHRUB_RISE`) in the order the seed came down, over 1.8 s; `born` is never saved. Old saves load and dress unchanged: nothing about generation, records already placed or the save format changed.

**Measured headless** (`tests/test_hand_flowers.gd`): a handful of 110 motes over a 1.6 m disc grows about 170 flowers on 8 m², 21 a square metre at its core (a generated poppy drift's core holds up to 25) and 10 at its edge; a 14 m sweep about 700 cosmos or 1,000 dandelions; a poppy sweep in the scene's hand path about 180 to 210 flowers. Growing a drift runs on the main thread when the veil settles: 75 to 115 ms headless for a 14 m band of 1,555 landings (a real veil lands 160 to 410 motes, so less), plus the view's usual refresh. That is a one-frame hitch on a big sweep; a worker could take it if it shows.

## Wind

The wind tool (`docs/scenic/wind-gust.md`, `scripts/wind_gust.gd`) lets go of air rather than a handful: press and drag to blow, and release to send a gust along the swipe. Its promise is a lane on the ground, adapted from the water ball's mark, that shows where the air will roll, how wide and how far. What `release` sends is exactly what the lane showed, and the air stays inside it. A still press is a burst, and its promise is a ring.
