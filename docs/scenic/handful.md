# Handfuls

Agreed 2026-09-27 (branch `feature/handful-shadow`), after the user said the water ball "tends to put water in the wrong spot, not where you release it" and had not noticed its shadow at all. This is the vocabulary for tools that carry something and let it go, and the one rule they keep.

## Words

- **Handful.** The thing a tool carries in the hand and lets go: water now (the water ball, `scripts/water_ball.gd`), later seeds for forest and pollen for meadow. A handful has a size that grows while it is gathered, and a place on the ground where it will land.
- **Shaping tools** work the ground directly under the pointer while the button is down: land and path. They stay brushes (`docs/scenic/brushes.md`).
- **Sowing tools** gather a handful and release it: water, forest, meadow. What they make is decided by where the handful lands and what the land does with it.
- **The lifecycle**, in order:
  - *gather*: the press, and the handful growing while held (the ball condensing and filling);
  - *carry*: following the pointer, a little behind it, alive (the ball's spring, bob and wobble);
  - *release*: letting go (the anticipation hop);
  - *fall* (or *drift*, for light things like pollen): straight down from where it was let go;
  - *land*: the impact, on the ground under the handful (the splash);
  - *take*: the land accepts it (the pour settles);
  - *grow*: what it becomes (a pond, a stream, a waterfall; later a stand of trees, a meadow).

## The shadow is the promise

Every handful casts a **mark** on the ground straight below it, from the moment it is gathered until it lands. The mark shows exactly where it will land, and what lands must land inside the mark.

What this guarantees:

- The mark sits straight below the handful's own x, z, not under the pointer and not along the sun. The handful may trail the pointer; the mark moves with the handful.
- Release changes nothing about where. The handful falls straight down: whatever sideways speed it carried goes into its wobble, not its path. The x, z where it lands equals the mark's centre at the moment of release.
- The landing height is the terrain under the handful, not under the pointer (`WaterBall.ground_at`), so the fall ends on the ground the mark lies on.
- The handful never swings out past the land's edge, so the mark is always on ground it can land on.
- The mark is noticeable on bright and dark ground, by day and at night, and it is the only shape under the handful that could be taken for a landing spot. No sun-cast shadow competes with it.

What it does not promise: where the land takes the handful once it has landed. Water runs downhill to the basin it drains to (`docs/scenic/water-brush.md`), and seeds will root where the ground suits them. That run should read as the handful being taken, not as it teleporting; for water it does not yet (see the water brush's known gaps).

## The water ball's mark

`shaders/water_ball_ground.gdshader`, the ball's ground decal. The mark is a pooled shadow the size of the ball (`radius`), drawn as a slowly turning `MARK_SIDES`-gon (12, turning `MARK_TURN` 0.12 rad/s) so it is faceted like the ground. It is painted in two tones, a darker core inside 0.58 of the radius and a lighter band out to the edge. A pale rim of water light sits on the edge, lit by the sky as well as the sun with a small floor that rises at night, so it reads on dark ground. The rim and size breathe with the ball's bob (`breath`, ±3.5 %). Held high (`MARK_HIGH`, 2 m of gap or more) the mark is soft and lighter (0.3 + 0.08 dimming, edge 0.16 of the radius); as the ball falls it darkens (0.44 + 0.14) and its edge sharpens (0.05). Sunlight gathered by the ball plays as caustics inside it by day. The mark shows from the ball's first moment (`mark` = the hold ramp × smoothstep(0.05, 0.3, radius)) and stays through the fall until the splash takes over.
