# Round Four: restored firing rate and slower enemy movement

The requested small balance update retains deliberate held firing, magazines,
reload, damage/health values, progression, native callbacks and save semantics.
No real save or production service setting is changed.

- `FIRE_RATE_SCALE` is restored from 0.75 to 1.0. Base interval is again
  `max(0.19, 0.46 - 0.022 * tempo_rank)`. This removes the earlier 25% rate nerf,
  rather than shortening the already-nerfed interval by only 25%. Existing tempo
  cards, haste and individual weapon cadence still apply afterward.
- All six enemy movement families, including elite variants, now use
  `old_wave_capped_speed * 1.25 * 0.90`. This is a 10% reduction from the actual
  Round Three final speed, retaining the prior buff otherwise. Ranged projectile
  velocity is unchanged: the request changes monster movement, not projectile
  speed, attack timing, health or damage.
- Ranged Spitters already enter ordinary spawn selection at wave four. They
  approach from afar, hold their ranged band, retreat when close and fire aimed
  hostile bullets that can damage the player. Existing Hexlings also retain
  telegraphed ground attacks. No duplicate ranged enemy system was added.

`tests/test_round_four.gd` passes 111 deterministic checks for restored cadence,
every family/wave/elite final speed and actual movement, ordinary ranged spawn
eligibility, hostile projectile travel/damage and close-range retreat. The
existing Round Three expectations are updated to the requested balance while
retaining damage, ammunition, lifecycle, upgrade/migration and protection checks.

Local Godot4.5.1 headless validation on 2026-10-24 passed 591 isolated assertions:
Round Four111, Round Three263, model125, Round Two36, UI35 and fullscreen21.
No script/parse/assertion, resource-in-use or ObjectDB leak errors were found.
These are synthetic source checks, not native gameplay, audible output or
production-service verification. New Android/Web builds and exact-commit CI are
separate coordinator gates. The preserved Round Three native APK/screenshots and
remaining reload/multitouch/device/offline/ad qualifications retain their dated
scope; see HANDOFF.txt and NATIVE_QA.json. No screenshots are relabelled.

## Focused music pause-state follow-up / qualified verification

Music remains enabled. The focused follow-up avoids redundant pause-state assignments while leaving the gameplay and service rules above intact. Its source is `4a278ba54737e9d7d08e6c6b3026a0c05f3ccfcb`; its [exact hosted CI](https://github.com/EthannYakabuski/monster-dusk-survivors/actions/runs/40146779414) passed. The actual accepted AAB/Web003 components and qualified test package are recorded in `../HANDOFF.txt`. Earlier named-source tests and frozen exports do not establish this follow-up's runtime acceptance.

Corrected Web runtime findings: Bounded isolated Chrome Web003 observations: Home opened a genuine fresh Wave 1. The live interface showed 20/20 rounds and manual Fire, Reload, Dash and movement controls. A stationary run ended naturally after 10 seconds with zero kills and zero dashes before the Fire input took effect. Return to camp awarded 21 coins and 6 XP, leaving 201 coins at level 1. No createBuffer recurrence was recorded during the 272-second check. Full original audio and project playback configuration were retained.
Remaining browser and platform limits: The zero-kill run is not a win or a combat-controls pass. Firing/cadence, manual or empty-magazine reload, movement/dash effectiveness and actual ranged-enemy behavior remain unverified. Fire arrived after the run ended; this latency-limited observation does not establish a control defect or human usability acceptance. Headless tab changes kept both pages visible and focused; actual hidden/focus-loss and music pause/resume transitions remain unverified. These are bounded Chrome Web003 observations, not Android screenshots or native/device, audible-output, SDK/ad, production-service or release acceptance. No cold browser restart was tested.

Affected Android/native checks, real SDK callbacks and current-build Android screenshots remain unverified. Physical-device play, audible-output and production services are separate acceptance work. Preserve all old APK/capture provenance and full third-party notices.
