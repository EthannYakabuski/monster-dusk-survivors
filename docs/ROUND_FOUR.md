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
