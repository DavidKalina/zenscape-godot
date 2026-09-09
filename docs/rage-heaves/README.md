# Enraged tree pull and log heave

At the start of an interaction, Bigfoot captures whether he is enraged. This
keeps the held pose continuous if the rage timer expires during the action.
The tree pull uses the existing 5 m input limit rather than the calm 2.8 m
pull: essentially 100% tension instead of 56%. The ordinary spring simulation
supplies the stronger recoil; its physical bend limit is unchanged.

Enraged log tosses use a separate LogSlam Blender clip with a deeper loading
dip and larger torso drive. The held log draws back 22 cm before a faster
forward shove. Its heading stays aligned with the shoulder carry. Enraged
launch speed is approximately 18.6 m/s in the focused test. Calm LogToss
and the existing lift/carry clips retain their previous behavior.

Source: tools/animate_bigfoot_log.py and the dedicated log Blender file.
Validation: test_bigfoot_rage.gd measures near-maximum tree tension and
both strong throws; test_bigfoot_mischief.gd covers calm interactions and
interruptions. Full-suite baseline remains in docs/log-animation.
