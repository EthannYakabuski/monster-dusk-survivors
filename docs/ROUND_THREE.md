# Round Three - deliberate firing and combat balance

This update uses Godot 4.5.1 Compatibility, Android primary and Web retained. Accepted Android/Web exports and qualified current native/capture scope are recorded below. Limited sequential controls, genuine manual refill and 18 current screenshots are complete; native empty reload, simultaneous input, other lifecycle/offline and device gates remain explicit. The dated D2FC APK and nine Round Two screenshots verify the earlier automatic-fire build only.

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

Local Windows headless validation on 2026-10-22 passed import, 263 focused Round Three checks, 125 model checks, 36 Round Two migration/music checks, 35 UI checks, 21 fullscreen checks and service smoke, with no matched script/error/leak diagnostics. Runtime smoke passed at 30 simulation seconds, one kill and rank one; the separate deterministic fixture reached 133.33 seconds, 21 kills and rank three. This verifies synthetic source behavior only. These are local source checks; exact-runtime hosted CI and local export verification are recorded below, separately from qualified native acceptance.

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

## Verified exports and exact-source CI, 2026-10-22

Runtime/source commit: `3f519732a70553ca65dcd708f5e1323f0040fe61`.

- Android: `build/round-three-3f519732-a1/android/monster-dusk-survivors-debug.apk`; 188503271 bytes.
  SHA256 `7998FB97F42976D0F9FFB0A7B28C38C86C009514AA609097C2AABC211D8961C1`.
- Web: `build/round-three-3f519732-a1/web/index.html` plus every sidecar and notice.
- [Exact-runtime hosted build/test CI](https://github.com/EthannYakabuski/monster-dusk-survivors/actions/runs/39795003210): **SUCCESS**, with the same runtime commit.

Both exports passed source/input binding, strict error checks and complete-notice verification. They were compiled from frozen committed export settings; unrelated owner working-tree files/settings remain preserved and were not build inputs. These local test exports are distinct from hosted artifacts and historical native-tested binaries. Current qualified native scope is below; later documentation/capture commits require their own exact CI result.

## Qualified native scope and screenshots, 2026-10-22

Limited current-APK sequential input and banking checks plus 18 fresh raw screenshots are complete. Held FIRE consumed ammunition; release then movement did not spend more. Partial reload initially showed a countdown and disabled FIRE; DASH and Android Back pause were observed. A later single targeted genuine run spent one round (19/20 at 0:03), then manual RELOAD plus 1900ms sequential evasive movement refilled 20/20 at 0:06 with FIRE enabled and full-magazine RELOAD disabled. Back paused safely alive. This establishes manual refill, not empty automatic reload or two-finger input.

Two earlier short genuine failed runs banked once each. The targeted 7-second partial run then banked 21 coins / 6 XP once through ordinary Bank & return. The earlier same-APK cold check retained banked bytes without restoration; opening Daily later added only three false claim flags without payout. After the targeted run, its new banked main survived background/stop byte-identically and was verified with the actual backup and pending store in the latest genuine full private archive. Historical restoration after host-session loss is not cross-session retention.

An automatic test interstitial closed with banked main unchanged. A planned menu tap may have activated an emerging test ad and opened the browser first-run screen; attribution was not established and no terms were accepted. No combat was active then. Existing guards were inspected; that event alone did not justify a code change or an earned-revive claim.

The [current manifest](../marketing/screenshots-round-three/capture-manifest.json) records six actual raw screenshots per phone/logical 7-inch/logical 10-inch profile. All 18 were independently reviewed. Tablet frames show menus only; tablet combat/control layout remains unverified. Outer scrolling exposes Back above the banner; nested scrolling discoverability remains qualified. Old captures retain their original APK identity.

Native empty-magazine automatic reload, true simultaneous touch, mid-combat background-held-input clearing and earned-revive/endcard remain unverified. Actual offline networking was not established. Short sequential-input attempts do not establish human balance. Audible output, physical devices, interactive Web and production services remain unverified. A bounded recent-log scan had no targeted matches, without a broad SDK-clean claim. See `../HANDOFF.txt` and `NATIVE_QA.json` for exact current and historical scope.

## Source fixtures and remaining native owner checks

The synthetic ammo fixture in `tests/test_round_three.gd`, lines 119-169, checks the final round starting 1.65-second automatic reload, empty state before the boundary, exact refill without an automatic shot after release, a fresh held shot afterward, one accepted manual reload, freeze on cards/death and one round per volley. Lines 253-267 exercise synthetic fullscreen/background freeze and neutral rearm; lines 338-346 use synthetic pointer owners and viewport hit tests. These are source evidence under the linked exact-runtime CI, not native proof.

The genuine native manual refill is now observed. Native empty-magazine automatic reload remains unverified: draining 20 baseline rounds needs roughly 12 seconds of continuous target fire, beyond the earlier 8/9-second bounded sequential-input runs. No grinding, fake state or false two-finger input was used. Owner follow-up should exercise empty reload in ordinary play, actual simultaneous movement/FIRE, mid-combat background rearm and tablet combat, then earned-revive/offline/audio/device/production flows as applicable. Do not treat those follow-ups as passed by source fixtures.
