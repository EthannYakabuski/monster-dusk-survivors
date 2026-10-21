# Round Two: music, daylight and progression

The current source update adds two original 40-second looping scores (camp and patrol) and a 120-second environment cycle. Dusk starts at 0 seconds, night at 30, dawn at 60, day at 90, and dusk repeats at 120. Phase light follows simulation time, so paused play and fullscreen ads do not advance it. Stable dark control panels keep the HUD readable across bright phases. Enemy, pickup and projectile colors stay readable.

`game/main.gd` selects camp music on menus and patrol music during a run. The existing music preference controls both tracks. User pause, upgrade/result overlays, external/fullscreen pause and application backgrounding suspend playback. `tools/compose_music.py` reproducibly writes the original audio; metadata and provenance are in `assets/audio/MUSIC.json`, and notices are in `LICENSES/INDEX.txt`. No reference-game music was copied.

## Progression and save compatibility

Permanent upgrade price at current rank `r` is now `180 + 200*r + 50*r*r` coins (previously `80 + 90*r + 18*r*r`). Starting coins still afford one first upgrade. Future run account XP is now `2*kills + int(duration/7) + 5` (previously `4*kills + int(duration/3) + 10`); 42 kills over 125 seconds gives 106 XP instead of 219. A future daily claim gives 20 XP instead of 35. These changes slow future account progress; the separate in-run upgrade-card progression is unchanged.

Save schema and XP thresholds remain unchanged. Existing XP, attained levels, coins, owned weapons, purchased upgrade ranks, achievements and daily claims are preserved without repricing, refunds or replaying rewards. Isolated fixtures test legacy serialization; they are not evidence of progression on a real device.

## Verified source behavior

Godot 4.5.1 Compatibility imported cleanly and passed strict isolated tests: 36 new Round Two checks, 125 model checks, 35 UI checks, 20 fullscreen-revive checks and service smoke checks. Errors, parse errors and assertion failures remain failures. `tests/test_round_two.gd` covers legacy fields, revised future rewards/costs, cycle phases and continuity, audio resource loop metadata, and music policy under settings and suspension. CI discovers this new test automatically.

A bounded isolated Windows Compatibility GPU run rendered camp plus all four phases at 540x960, and checked the actual audio player's track selection, toggle, user pause and background/foreground state. The process master bus was muted: no auditory quality, Android audio or physical-device acceptance is claimed. Those synthetic development views are not native/store screenshots.

## Remaining acceptance

The original local QA APK/hash in `HANDOFF.txt` remains unchanged. New Android/Web exports, affected native gameplay and fullscreen-ad return checks, real save retention, Back/offline checks and final-build capture review are required for this update. New illustrated app/feature art, 27 achievement icons and five leaderboard icons are complete. Each badge was generated individually with its catalog meaning, packaged at512px and inspected at final size and64px. Originals, prompts and hashes are retained under `marketing/source-art`. Existing gameplay screenshots still belong to the original APK until final-build native captures replace them. Hosted CI is a separate result for its exact commit and does not inherit original native QA.

Use `AGENTS.md`, `README.md`, `HANDOFF.txt` and `docs/PLATFORM_SETUP.md` when starting a fresh project task. Keep test user data isolated from legitimate saves. Service IDs, consent and platform contracts are unchanged. No Pages, Library, Google Play publication or Windows distribution is part of this source change.
