# Fences

Branch `feature/fences`, from `main`. Fences are drawn as a line on the land with the **fence** specimen in the tray. On release, a rustic split-rail fence follows the line.

## Using it

- Take the **fence** from the case (the slot after the river stone) or from the command palette.
- Press on the land and drag a line. Faint stakes show where the posts will go. A stake that will not stand shows pale red.
- Let go and the fence is laid. A tap lays nothing.
- If the line ends within 1 m of where it began, and is at least 4 m long, it closes into a **pen**.
- Press or let go near a fence and the line joins it (see [Joining](#joining)). A bright ring in the preview marks each post the line will join.
- Each drawn fence is one Cmd+Z, even when the land splits it into several runs. A join is part of the same Cmd+Z.

## Joining

Branch `feature/fence-joins`. Joining should take no aim. Both ends of a drawn line snap onto any fence within reach, so the line starts or ends on that fence's post.

- **Reach.** The reach is 1 m, or 28 pixels on screen when that is more. Zoomed out, a press does not have to land within a metre.
- **On an open fence's end post.** An end post within reach always wins. Pressing there continues that fence: the new posts are added to its record, which keeps its id. The end post is not doubled, and the rails run on from it. Letting go on an end post does the same from the other side. A line that starts on one fence's end and ends on another's joins all three into one record.
- **Closing a pen.** A line from one end of a fence round to its other end closes that fence into a pen, still one record. The old rule still holds too: a line that ends on its own start is a pen.
- **Anywhere else on a fence** (on its middle, or anywhere on a pen) the join is a **T**. The line snaps to the nearest point on the fence. If that point is within 0.4 m of a post, the line shares that post. Otherwise a post is put into the span there. The new line is a record of its own, and its end post sits on exactly the same spot as the fence's post.
- **What does not snap.** While the line is still leaving the fence it started from, the end does not snap back onto that same fence within 2 m of the start. Also, ending on the line's own start only snaps when the line is long enough to make a pen.
- **Undo.** A put-in post and a merge are part of the drawn line's stroke, so one Cmd+Z takes back the new piece and the join together.

### The data model: extended records, posts shared by position

Two models were considered. A shared-post graph would keep a table of posts and a list of rails between them. The other model keeps the existing records (`{"id", "posts", "closed"}`) and does joins by extending records and sharing positions. The second was chosen because it changes no saved format and keeps the trash can's per-span cut, undo and re-seating as they were.

- **Continuing and closing** are done in the record itself. The new posts are spliced onto the old fence's list, and the shared post appears once. A fence continued from its end is the same single fence it would have been if it had been drawn in one go.
- **A T** is two records whose posts stand at the same plate point. The point is copied exactly from the host's post, or from the post put into its span. Nothing stores the link. Matching to within 2 cm (`Fences.JOIN_EPS`) counts as the same post.
- **Drawing.** The view draws each post position once (`rebuild`). The first record to reach a shared post draws it. The others draw only their rails up to it.
- **The trash can** cuts each record span by span, as before. A shared post flies into the can only when no remaining fence still stands on it (`cut`). A T whose foot is cut away simply ends one post short of the fence.
- **Re-seating.** Heights are still read from the ground at each rebuild. Both records seat a shared post at the same spot, so it rides the land as one post.
- **Save and load.** The save holds plain records, so joins survive a save with no new keys. The same position means the same post after loading too.
- **The look.** Each piece's lean and shade is seeded by where it stands, not by the fence id. A fence that is extended, joined or cut keeps its look. When merges reverse a list, the rails' seed does not depend on direction either.

## How the land decides

The fence is not forced onto the land. It works like tree painting (`scripts/tree_paint.gd` `suits`):

- **Posts.** A post stands only on dry ground on the plate, and only where the slope is no steeper than the land's rock slope. Dry means no live water 2 cm deep and no pond, lake or stream that emergence knows about. Without a rock slope the limit is 1.0, which is 45°.
- **Rails.** A span of rails is laid only between two standing posts. The ground between them must also be dry, and the posts must be no more than 0.75 m apart in height. A fence never steps down a cliff.
- **Gaps.** Where the land refuses, the fence is cut into runs. Each run of two or more posts becomes its own record. A post left standing alone is dropped. A line drawn across a lake stands on both shores with a gap over the water. A pen broken by water opens into a line.

The land decides once, when the fence is drawn. After that, re-shaping the land never removes a fence; the posts ride the ground (see below). Water poured later can flood a fence's feet. Its posts then stand on the bed under the water, which is wet but not floating. If the ground under a post is blown away (a void), that post and its spans are not drawn until the ground comes back.

## Data

`NativeTerrainData.fences`: `[{"id", "posts": [x0, z0, x1, z1, ...], "closed"}]`, in plate metres.

- Only x and z are stored. Heights are read from the ground each time the fence is drawn.
- Ids come from the data's `next_id`, the same counter the objects use.
- The fences are part of `_snapshot` and `_restore`, so undo, redo and favourites carry them. `reset_flat` clears them with a new world.
- The fences are part of `to_document` and `load_document`, under a `"fences"` key. A save from before fences loads with none. A malformed record refuses the whole document, as a malformed object does.
- Limits: 256 fences, 160 posts each.

## Following the land

The fence view (`scripts/fences.gd`, a child of the terrain) seats each post on the ground at every rebuild:

- **Full refresh.** The editor rebuilds the view in `refresh`, beside `landmarks.rebuild`. This covers undo, load and the settle at the end of a stroke.
- **Light refresh.** The editor also rebuilds it in `_refresh_light`, beside `landmarks.lift`. This is the refresh a held brush makes every frame.

So the Hills, Mountain, Modeller and the rest carry the posts up and down as they shape the ground, mid-stroke as well as after. Posts stay vertical, and the rails between them follow the slope. This is how the authored landmarks follow land edits. Unlike the trees (`LandClay.shake_trees`), posts never slide off a slope.

## The trash can: per span

The trash can takes a fence **span by span**, not the whole fence:

- Every span of rails that its reach (1.4 m at the middle pip) touches goes. So does any post left with no span on either side. Those posts fly into the can's mouth.
- A run cut through the middle becomes two fences. The second one gets a new id.
- A pen that is cut opens into a line.
- Shift (spare the big things) does not spare fences.
- The cut is part of the press's undo step.

Per span was chosen because a fence can run across the whole plate. The can is the eraser, so a sweep across a fence should cut a gate in it, not remove all of it. To clear a whole fence, sweep along it, or Cmd+Z it straight after drawing.

## The look

The look is split-rail, built in code like the tools' props:

- **Posts.** Six-sided posts 0.62 m tall and 5.5 cm in radius, sunk 12 cm into the ground. Each leans a hair and has a slanted cut top.
- **Rails.** Two rails, at 0.24 m and 0.48 m. Each sags a touch in the middle, is twisted a little, and its ends sit into the posts.
- **Spacing.** Posts are about 1.3 m apart, spread evenly along the line so that both ends get a post.
- **Wood.** Every face is flat-shaded, in four weathered browns and greys with a little jitter per piece. The jitter is seeded by where each piece stands, so a fence looks the same after a load, an extension, a join or a cut.

Each fence is one `MeshInstance3D` with a vertex-coloured `StandardMaterial3D`. Wattle was considered and left for later.

## Code

- `scripts/fences.gd`: layout (`plan`, `posts_along`, `runs`), joining (`snap`, `lay`), the trash cut (`cut`), record validation, and the view (`rebuild`, `preview` with its join rings, `post_part`).
- `scripts/native_chunk_editor.gd`: `lay_fence` (which finds the joins at the line's ends), `fence_join`, `fence_opens`, `fence_preview`, `fence_stands`, `fence_dry`, and the view's rebuilds in both refreshes.
- `scripts/native_terrain_data.gd`: the `fences` list in the snapshot, the save and the load.
- `scripts/hand_materials.gd`: the `fence` specimen. The press holds `fence_line`. The line is drawn with `scripts/clay_tools/drawn_line.gd`, the Ravine's drawn line, which gained `add(point)` so a hand outside the clay can feed it. `_fence_snap` sets the snap reach from the screen, and `_fence_end_snap` decides where the pointer would end the line.
- `scripts/clay_tools/trash.gd`: `_cut_fences`.
- The tray slot, icon and palette entry are in `scripts/materials_tray.gd`, `scripts/hud_icons.gd` and `scripts/command_palette.gd`.

## Probe

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_fences.gd -- --modeless --no-title
```

The probe checks:

- The slot exists.
- A drawn line lays one fence in one undo step.
- Post spacing is right, and each post is sunk exactly `POST_SINK`.
- A tap lays nothing.
- Undo and redo work.
- Posts re-seat while the Hills are held and after the stroke settles.
- The trash can's gap, and its undo.
- A pen closes.
- A save survives a JSON round trip. A corrupt record is refused, and an older save loads with no fences.
- A line across a lake skips the water.
- Joins: a start snapped to an end post continues the fence (one record, no doubled post, rails carrying on, the preview ringing the post). An end snapped to an end post merges the fences. Ending on the fence's other end closes a pen. A press on a span makes a T with a post put in. An end on a pen's side makes a T sharing its post. Each is one undo step and is drawn once at its junction. The trash can across a join opens the pen and cuts the T, and undo mends both. A cut of the pen's spans either side of a T keeps the shared post (it does not fly). The Hills carry a shared post. The joins come back from the save.

It checks geometry from the mesh's vertices. It does not check the look: the wood colours, the shading, the faint preview stakes, the join rings (the probe only checks where they are placed) and the trash flight need a rendered run.
