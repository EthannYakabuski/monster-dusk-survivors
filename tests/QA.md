# Round Three source verification — 2026-10-22

Godot 4.5.1 Compatibility headless source checks passed: 263 Round Three, 125 model, 36 Round Two migration/music, 35 UI and 21 fullscreen assertions; import and service smoke also passed. Each process had fresh isolated app-data roots. Strict script/error/leak checks remained enabled.

The deliberate-fire runtime fixture passed at 30 simulated seconds/one kill/rank one. The deterministic twin-session fixture passed at 133.33 seconds/21 kills/rank three, retaining identical-seed/result and bounded-object assertions. See [Round Three scope](../docs/ROUND_THREE.md) for formulas, held-input semantics and migration. These are synthetic checks, not native gameplay or human-balance evidence.

Round Three Android/Web builds, native control/reward/save validation and refreshed screenshots are pending. Existing docs/NATIVE_QA.json and docs/LOCAL_TEST_RESULTS.json belong to the earlier D2FC Round Two APK; do not apply them to this changed source. Headless music-file and policy assertions do not establish audible playback, physical-device behavior, production services or interactive Web acceptance.

## Historical first-pass source record

The following earlier checks remain historical; their timings, counts and automatic-fire fixture do not describe Round Three.

# Recorded core verification

Godot4.5.1 Compatibility. The deterministic model suite passed125 assertions; the actual-scene UI fixture passed33 assertions with an explicit service stub. The14-simulated-second/15-elimination smoke deliberately used invulnerability and a fixed fixture. Four desktop development viewports were reviewed; they are not native/store screenshots.

The fullscreen lifecycle revision passed20 focused mocked checks without matched log errors. Historical restricted-host root-certificate-store warnings remain qualified; this does not claim all stderr was clean. Desktop callback tests establish their source scope, not actual SDK/production acceptance.

Actual current-APK native observations and limitations are summarized in docs/NATIVE_QA.json and docs/LOCAL_TEST_RESULTS.json. Physical-device behavior, audible sound, interactive Web, production configuration and human balance remain unverified.

Run the self-contained fixtures with Godot4.5.1:

```
godot --headless --path . --script res://tests/test_models.gd
godot --headless --path . --script res://tests/test_ui.gd
godot --headless --path . -- --smoke-test
```
