# A home made from the surroundings

Arrange a mature tree with clear, dry ground beneath its canopy. Nearby shrubs,
rocks or a log make it more appealing. On an ordinary rest decision, Bigfoot can
choose that patch, approach it along a safe path, inspect it for two seconds,
rake a first leaf bed together and settle down. Return visits improve the same
bed through the existing three stages. No dedicated shelter prop is required.

The editor's **His spot** button focuses the chosen location. A brief question
mark marks inspection; **Home** appears on first making a sheltered bed.

## Rules

- A canopy must cover at least 30% of the resting footprint and clear his standing
  height. The headroom accounts for the visual model size used in the woodland
  trial. Canopy bounds approximate cover; this is not a physical rain simulation.
- He considers spots within the existing eight-unit rest search and must be able
  to reach and sit on them safely. Nearby screens improve a covered spot; shrubs
  alone do not count as a roof.
- Once sheltered, he returns instead of chasing slightly better scores. An old
  outdoor resting spot can be superseded by reachable player-created shelter.
- With no suitable tree, the original outdoor leaf-bed routine still works.
- Removing cover relinquishes the home but leaves the bed as an ordinary editable
  prop. The area remains eligible if you repair it. Moving/deleting his bed still
  relinquishes his ownership and respects the existing avoidance memory.
- Terrain and water safety checks remain authoritative. Autonomous bed edits
  cannot merge into a player's active stroke.
- Version-two habit memory persists the sheltered status. Version-one saves
  remain valid and retain their outdoor resting memory.

## Validation

`test_bigfoot_home.gd` covers low foliage, sheltered ranking, upgrading an outdoor
spot, inspection, first-visit bed creation, His spot, JSON save/reload, legacy
memory and canopy removal without deleting the bed. It passes.

`test_bigfoot_habits.gd` covers normal three-stage development, pause, selectable
bed ownership, undo/delete/move, terrain invalidation and legacy documents.
The existing habit regression passed after preserving outdoor fallback behavior.

`tools/render_bigfoot_home.gd` requests one sleep in an isolated arranged scene,
then runs the real routine to capture inspection and sleep on the bed. It does
not directly claim a home or place the leaf bed. Images were inspected for
readability and canopy clearance. This is a visual sequence fixture, not proof
that a sleep request originated autonomously; the long habit test covers that.

![Inspection](inspection.png)
![First bed under shelter](home.png)

Final verification: home, existing habits, routine pause and diorama-flow tests
all completed with zero failures. `git diff --check` is clean. The user's running
woodland was not restarted, so it will pick up this behavior on its next launch.
