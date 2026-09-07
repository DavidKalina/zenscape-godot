# Integrated weather cycle

`tools/film_weather_cycle.gd` runs 18 seconds of rain, 24 seconds of snow/cold,
then 30 seconds of warm clearing. The 24-second review film runs the entire
simulation at 3x speed, using three normal 1/30-second steps per captured image.
This is an accelerated review, not the normal sandbox speed.

The capture showed ice reaching 0.93 and snow cover 0.89 before clearing, then
ice falling to 0.03 and snow cover to 0.08. Water flow resumes through the thaw.
The natural rainbow initially remained active through full snowfall because
the suspended-moisture state outlived the warm rain. Automatic rainbow strength
now includes the liquid precipitation fraction, fading out smoothly as rain
turns to snow. Warm humid air can reveal it again while surface ice is melting.
The explicit **Hold rainbow** control remains a creative override.

**Face rainbow · look opposite the sun** points the camera toward the antisolar
direction, raises its view within the existing orbit range, and steps back to
show the landscape. It stops automatic orbit. The arc may still be obscured by
terrain or out of frame at unusually low sun angles; it does not change the
hour or weather or force a rainbow to exist.

`tests/test_rainbow_weather.gd` checks warm/snowy/warm conditions, manual hold,
antisolar orientation and arc framing at the default reference hour.
`weather-cycle.mp4` shows the integrated sequence from this viewing angle.
