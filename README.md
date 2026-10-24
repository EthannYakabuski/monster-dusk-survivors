# Monster Dusk: Apocalypse

## Round Four source update

The prior 25% firing-rate nerf is removed. All monster movement speeds are reduced by 10% from Round Three; existing wave-four ranged Spitters are verified by source tests. See [current gameplay rules](docs/ROUND_FOUR.md). New exports/native checks and exact-commit CI are separate gates; dated Round Three artifacts below retain their original scope.

Keep the lantern burning. The creatures keep coming.

A portrait endless monster shooter with six enemy behavior families, escalating waves, a large creature bestiary, weapon builds and permanent progression.

## Play

Drag to move, hold the gun button to fire toward the nearest creature, and use DASH to escape. A magazine starts with 20 rounds; empty magazines reload in 1.65 seconds, or tap RELOAD early. Keyboard controls are WASD/arrows to move, J to fire, R to reload, Space to dash and Escape to pause. Shape your weapon build with upgrades, survive escalating creatures and spend your rewards between attempts. Daily goals and the bestiary track your discoveries. A repeating dusk/night/dawn/day cycle changes the arena light, while separate original camp and patrol scores follow music and pause settings. Future account XP and permanent upgrades progress more slowly; existing saved XP, levels, purchases and claims are retained.

Touch/mouse portrait play and offline local saves are supported. Android is the primary target; Web retains gameplay and saves when Android services are unavailable. Browser play never grants pretend ad rewards.

## Continue this project

This game folder is the canonical Git working copy for [Monster Dusk: Apocalypse](https://github.com/EthannYakabuski/monster-dusk-survivors). Open this folder as its own Codex project and use one focused task per update. Read `AGENTS.md`, `HANDOFF.txt` and `docs/PLATFORM_SETUP.md` first; a new task must recover context from these files rather than assume access to an earlier chat. Check existing user changes before editing.

Verified pre-consolidation public baseline: `8938102c7afb8c5f4d22b8c8ca01a9aefb0856ab`.
[Hosted build/test run](https://github.com/EthannYakabuski/monster-dusk-survivors/actions/runs/39526798397): **PASS** on that exact commit.
Later documentation commits require their own CI result; this dated result does not verify later binaries.

`game/catalog.json` defines 27 achievements and 5 leaderboards. `platform/config.json` maps their symbolic keys to owner-supplied console IDs; the numeric Play Games game ID must also match `export_presets.cfg`. See native setup for the separate AdMob manifest setting and the development test-ID rules.

## Development

Original code: Apache-2.0. Developer: [EthannYakabuski](https://github.com/EthannYakabuski). Included assets/plugins retain their own licenses and notices.

Use Godot **4.5.1**, **Compatibility**, matching export templates, Java 17 and the Android SDK. The test preset uses minimum API 24 and target API 35. This is a test-configured build; final release signing, current Play requirements and production backend verification remain with the owner. See [native setup](docs/PLATFORM_SETUP.md).

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_round_three.gd
godot --headless --path . --script tests/test_round_two.gd
godot --headless --path . --script tests/test_models.gd
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . --export-release Web build/next-reviewed-update/web/index.html
godot --headless --path . --install-android-build-template --export-debug Android build/next-reviewed-update/android/game-debug.apk
```

Create a new unused build/next-reviewed-update/web and build/next-reviewed-update/android first; choose another unused name for each later build. Preserve all accepted and original artifacts. Android package: `com.ethannyakabuski.monsterdusk`. Tests are documented under game/ and tests/. No Windows build is supplied.

See [preserved Round Two implementation and verification](docs/ROUND_TWO.md) for its source changes, balance formulas and qualified acceptance. Historical Android/Web outputs remain under `build/round-two-97c75e32-a1/`, APK `D2FC0ADA386F51BD3ADEC057FC4B2EA4FEC41BED5F529198DDD44C0364BCDC96`. The current Round Three exports are described below; `HANDOFF.txt` selects their new ZIPs. Original APKs and dated hosted CI retain their separate scopes.

## Round Three qualified local handoff

Manual firing, the persistent magazine upgrade and enemy/weapon rebalance have accepted Android/Web exports from runtime `3f519732a70553ca65dcd708f5e1323f0040fe61` under `build/round-three-3f519732-a1/`, with [exact-source CI SUCCESS](https://github.com/EthannYakabuski/monster-dusk-survivors/actions/runs/39795003210). Limited sequential native controls including a genuine manual 19-to-20-round refill, once-only banking, cold banked retention and [18 genuine screenshots](marketing/screenshots-round-three/capture-manifest.json) are complete. Empty-magazine automatic reload, simultaneous touch, tablet combat layout, mid-combat background-held-input clearing, earned revive, actual offline mode and human/device/audio/Web/production acceptance remain unverified. An automatic interstitial returned with banked data unchanged; a possible accidental test-ad/browser transition is qualified in [native scope](docs/NATIVE_QA.json). Full artifacts and limits are in `HANDOFF.txt`. The preserved D2FC APK and captures below retain their Round Two scope.

## Integration and handoff

AdMob uses Google's official test IDs. Menus support a banner, every two completed rounds create an interstitial opportunity, and rewarded benefits require the earned-reward callback. Unavailable ads or consent leave normal play usable. Google Play Games uses symbolic achievement/leaderboard maps with empty production IDs and is disabled until the owner configures them. See platform/config.json and docs/PLATFORM_SETUP.md.

Round Two replaces app/feature art, all 27 achievement icons and all five leaderboard
icons with distinct generated illustrations. Original hashes, exact per-badge prompts and
provenance are recorded under `marketing/source-art`; full generated originals remain privately retained where recorded. Committed packaged 512px badges
were reviewed at final size and at 64px. These illustrations are not screenshots.
Marketing text, the preserved nine Round Two raw screenshots under `marketing/screenshots-round-two/`, current 18-image Round Three manifest and original-APK provenance are in marketing/. The current evidence, limitations and exact next owner actions are in HANDOFF.txt. Production backend testing, human playtesting and Google Play publication are human-owned.

## CI and Web

Hosted GitHub Actions imports resources, runs game/service tests, exports Web and an Android debug APK, and retains export artifacts. Pages deployment remains explicitly disabled. Build outputs, caches and signing keys are excluded from source. Confirm actual run results in HANDOFF.txt; workflow presence alone is not a passing CI claim.

## Future extension

Moonfall: a second arena, alternate weapon traits and new elite combinations.

## Licenses

See [the complete accompanying notices](LICENSES/INDEX.txt) for the engine,
fonts, plugins and assets. Keep the `LICENSES` directory with every redistributed
Android or Web build; original-code Apache licensing does not replace third-party
terms. CI copies these notices beside both exports and includes them with the
Android artifact.

## Public source and deployment status

The public repository contains source, assets, notices and sanitized verification summaries. Original local QA APKs, raw SDK logs, real saves, signing material and private evidence stay outside tracked public content. Local restored build outputs remain ignored. Hosted export artifacts are separate binaries from the APK named in HANDOFF.txt and have not received that original native QA.

Pages remains disabled; no live deployment, Library action or Google Play publication is part of this handoff. Keep the complete third-party notices with redistributed source and builds.

## Previously accepted Round Two local verification

Both Round Two exports passed exact committed runtime binding and matching notices. Ordinary native play observed all four light phases through Day at92seconds, the revised purchase/reward values, music-preference persistence, normal controls/Back, a96.225second earned endcard with alive unchanged-HUD return and once-only banking, actual offline/cold25-group retention and restored-network cold retention. A genuine historical save was restored after an absent package before the update; this does not establish retention across earlier AVD loss.

The retained captured Godot error scan was empty; no exhaustive full-lifetime SDK-clean claim is made. Native120second repeat, separate unearned/failure callback/current interstitial, same-run fresh post-ad inputs, simultaneous multitouch, audible/physical/interactive-Web/production/human balance remain unverified. See the [archived Round Two native summary](docs/history/round-two-d2fc0ada/NATIVE_QA.json) and the preserved Round Two section of HANDOFF for that historical scope.

## Screenshot verification by build

`marketing/screenshots-round-three/capture-manifest.json` records 18 current Round Three raw PNGs, six per logical profile. All were reviewed by the operator and coordinator. Tablet frames show menus only; they do not verify tablet combat.

The preserved `marketing/screenshots-round-two/capture-manifest.json` records nine exact dated D2FC APK raw PNGs, relative names, SHA256 digests and logical profile sizes. Operator and coordinator independently reviewed all nine. They were not resized, cropped, overlaid or generated as fixtures. Logical tablet profiles do not prove physical-device acceptance. Original `marketing/screenshots/` files and their manifest remain unchanged and belong to the original APK.
