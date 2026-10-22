# Round Three — deliberate firing and combat balance

This is a source update for Godot 4.5.1 Compatibility, with Android primary and Web retained. Its own exports, native control/reward/save checks and refreshed screenshots are pending. The D2FC APK and nine screenshots in the dated Round Two handoff verify the earlier automatic-fire build only. No new native, audible, physical-device or production-service acceptance is implied.

## Controls and ammunition

Drag in the arena to move. Hold the gun button to fire with assisted aim toward the nearest creature; release to stop. DASH retains the existing movement/last-direction behavior. Keyboard: WASD/arrows move, J fires, R reloads, Space dashes, Escape pauses.

The initial magazine holds 20 rounds. The new permanent `magazine` upgrade adds two rounds per rank, up to rank 10/40 rounds, using the existing `180 + 200*r + 50*r*r` cost curve. One successful volley uses one round, including scatter or spread volleys; no target means no shot and no ammo use. Empty magazines begin a 1.65-second automatic reload. RELOAD/R can begin a partial-magazine reload early. Reload completion replenishes ammo without firing; the next active held frame can shoot. The HUD shows rounds or remaining reload time.

The button is deliberately hold-to-fire. Releasing or canceling clears both held and unprocessed fire input, so a press/release entirely between gameplay frames does not fire. Holding across a frame emits a volley. Native movement and firing own separate touch IDs; unrelated finger releases and emulated mouse events cannot release another owner. Real mouse release is observed before GUI dispatch. Combat controls do not accept focus-based keyboard activation.

Pause, rank cards, results, focus loss and application lifecycle transitions clear held input. Returning from background keeps the ordinary pause until explicit Resume. Keyboard movement, firing and dash must observe neutral keys before they rearm. Fullscreen/background blocking freezes the simulation, including ammo and reload; the first uncovered frame discards elapsed cover time. Native GUI/viewport scaling, simultaneous touch and ad-return inputs still need verification on the new build.

The full-size footer follows the actual logical viewport height. A centered uniform world-only rendering transform fits the unchanged simulation arena above it; joystick, HUD and touch hit tests stay in screen coordinates. Synthetic root-Window tests explicitly expose 540x960 and 540x864 logical viewports and check full button bounds, nonoverlap, unchanged target sizes, shared world edge mapping and simultaneous control actions. Headless physical resizes retain the original canvas, so these tests configure and restore their own Window logical canvas; they do not establish native clipping or Android aspect behavior. Production project stretch settings remain unchanged.

## Exact balance

- Weapon damage is `(13 + 2.7*power_rank) * 0.75`, then existing power-card and weapon multipliers apply.
- Base firing interval is `max(0.19, 0.46 - 0.022*tempo_rank) / 0.75`; this makes the rate 25% lower. Existing tempo cards, haste and weapon cadence multipliers retain their relative effects.
- Enemy health is `old_wave_and_elite_scaled_hp + 29.25`. The additive increase is three baseline post-nerf 9.75-damage hits and is applied after elite scaling.
- Enemy movement is `old_final_speed * 1.25`, after the existing wave-speed cap.
- Incoming damage is `old_amount * 1.20` once in `take_damage`, after invulnerability/shield guards. This covers contact, hostile projectiles and hexes. There is no armor statistic in this game.
- Nova retains `(13 + 2.7*power_rank) * 5` damage, captured independently before the projectile nerf. Power cards and weapon traits do not modify Nova, matching its prior behavior.

All six enemy families, ranged retreat/projectiles, hex telegraphs, five-wave elites, three weapons, card effects, four powerups, day/night cycle, music, progression, daily claims and once-only banking remain. No new production service values are introduced.

## Save compatibility and source checks

The save schema remains 1. Loading an older profile adds only `upgrades.magazine = 0` to its upgrade dictionary. Existing coins, XP, level thresholds, purchases, selected/owned weapons, achievements, daily/login claims and pending-run banking retain their prior logic. New magazine ranks are saved and clamped to 0–10. Ammo and reload are transient run state.

Local Windows headless validation on 2026-10-22 passed import, 263 focused Round Three checks, 125 model checks, 36 Round Two migration/music checks, 35 UI checks, 21 fullscreen checks and service smoke, with no matched script/error/leak diagnostics. Runtime smoke passed at 30 simulation seconds, one kill and rank one; the separate deterministic fixture reached 133.33 seconds, 21 kills and rank three. This verifies synthetic source behavior only. No hosted CI result or new binary acceptance is claimed here.

Run tests with fresh, per-process APPDATA and LOCALAPPDATA roots (and isolated XDG roots on Linux). Never use genuine app save directories for synthetic fixtures:

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_round_three.gd
godot --headless --path . --script tests/test_models.gd
godot --headless --path . --script tests/test_round_two.gd
godot --headless --path . --script tests/test_ui.gd
godot --headless --path . --script tests/test_fullscreen_revive.gd
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . -- --smoke-test
```

The focused suite checks every family at waves 1/5/20/100 with normal and elite HP/speed; damage/cadence at power/tempo ranks 0/5/10 across all weapons and card/haste effects; unchanged Nova; all damage paths and protection; ammunition/reload boundaries; migration/rank maximum; independent touches, release/cancel/synthetic mouse, held-input behavior and lifecycle freeze/rearm. The existing full-profile legacy comparison now expects its original dictionary plus only the new zero magazine rank. Existing UI/banking/revive/music tests remain strict.

The deterministic session fixture now runs 4,000 purposeful-fire frames (133.33 simulation seconds), retaining its kill/rank/bounded-object checks and strengthening duration/wave expectations for the tougher balance. Runtime smoke now requests fire explicitly for 900 frames instead of assuming automatic shots in 420 frames. These are synthetic fixtures, not human balance or native evidence. Strict error/leak checks remain required. Hosted CI must be verified on the actual published commit separately.

`assets/weapon.png` reuses the existing Kenney Desert Shooter Pack 1.0 gun sprite under CC0, with its pack notice retained in `assets/licenses` and the accompanying license bundle. The original code remains Apache-2.0; Creature Mixer keeps its separate custom terms. No new illustration or audio asset is part of this change.
