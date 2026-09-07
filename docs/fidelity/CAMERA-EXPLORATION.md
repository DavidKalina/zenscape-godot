# Landscape framing and close exploration

Startup and R now fit the landscape to the current viewport. The fit uses real
mesh vertices and individual instanced-mesh bounds, avoiding the large empty
upper corners of a single enclosing box. It leaves a small margin around the
scene and includes the exposed base. Birds are excluded because their flight
bounds should not control framing. Explicit capture camera arguments still work;
Tab retains the original source camera for its reference overlay.

Wheel zoom now reaches .5 units, matching the explicit camera's lower limit.
This fixes scrolling inward from the 6.5-unit Bigfoot view jumping outward to
the former eight-unit minimum. Scroll event strength is honored, making fractional
trackpad input gentler. Manual exploration can still enter geometry; collision
navigation is not implemented by this change.

`test_camera_exploration.gd` passes for wide and portrait framing, all exposed
base vertices inside the frame, close zoom direction/limit, fractional scrolling,
and original reference framing. `landscape-framing.jpg` was visually inspected
at the normal 1440x900 view. Reframe after resizing with R; resizing does not
interrupt the user's chosen orbit automatically.
