# Round Two: music, daylight and progression

The current source update adds two original 40-second looping scores (camp and patrol) and a 120-second environment cycle. Dusk starts at 0 seconds, night at 30, dawn at 60, day at 90, and dusk repeats at 120. Phase light follows simulation time, so paused play and fullscreen ads do not advance it. Stable dark control panels keep the HUD readable across bright phases. Enemy, pickup and projectile colors stay readable.

`game/main.gd` selects camp music on menus and patrol music during a run. The existing music preference controls both tracks. User pause, upgrade/result overlays, external/fullscreen pause and application backgrounding suspend playback. `tools/compose_music.py` reproducibly writes the original audio; metadata and provenance are in `assets/audio/MUSIC.json`, and notices are in `LICENSES/INDEX.txt`. No reference-game music was copied.

## Progression and save compatibility

Permanent upgrade price at current rank `r` is now `180 + 200*r + 50*r*r` coins (previously `80 + 90*r + 18*r*r`). Starting coins still afford one first upgrade. Future run account XP is now `2*kills + int(duration/7) + 5` (previously `4*kills + int(duration/3) + 10`); 42 kills over 125 seconds gives 106 XP instead of 219. A future daily claim gives 20 XP instead of 35. These changes slow future account progress; the separate in-run upgrade-card progression is unchanged.

Save schema and XP thresholds remain unchanged. Existing XP, attained levels, coins, owned weapons, purchased upgrade ranks, achievements and daily claims are preserved without repricing, refunds or replaying rewards. Isolated fixtures test legacy serialization; they are not evidence of progression on a real device.

## Verified source behavior

Godot 4.5.1 Compatibility imported cleanly and passed strict isolated tests: 36 new Round Two checks, 125 model checks, 35 UI checks, 20 fullscreen-revive checks and service smoke checks. Errors, parse errors and assertion failures remain failures. `tests/test_round_two.gd` covers legacy fields, revised future rewards/costs, cycle phases and continuity, audio resource loop metadata, and music policy under settings and suspension. CI discovers this new test automatically.

A bounded isolated Windows Compatibility GPU run rendered camp plus all four phases at 540x960, and checked the actual audio player's track selection, toggle, user pause and background/foreground state. The process master bus was muted: no auditory quality, Android audio or physical-device acceptance is claimed. Those synthetic development views are not native/store screenshots.

## Qualified current local acceptance

Android and Web exports for runtime `97c75e32f423772a5fb13dca26a78468b60f99fd` passed exact before/after input binding, strict errors and complete matching notices. Current Android SHA256 is `D2FC0ADA386F51BD3ADEC057FC4B2EA4FEC41BED5F529198DDD44C0364BCDC96`; versioned artifacts/packages are selected by HANDOFF.

Ordinary native play observed Dusk/Night/Dawn/Day through92seconds, Power1to2 at430coins/next780, formula-consistent future run XP, music preference persistence, normal controls/Back, once-only banking and actual offline/cold25-group retention. A real earned continue held its earned endcard96.225seconds and returned alive at unchanged75second/70killHUD. Subsequent natural defeat preceded fresh same-run input observation; do not claim post-ad fresh controls. The genuine prior-save restore after an absent package is qualified restoration, not cross-AVD-session retention.

Nine new raw current-APK images were reviewed at phone and two logical tablet profiles. Existing original images/reports remain preserved. The captured Godot error scan was empty within retained logs, not an exhaustive full-lifetime SDK-clean claim. Native120second cycle repeat, unearned/failure/current interstitial, simultaneous native multitouch, audible output, physical devices, interactive Web, production services and human balance remain unverified. See NATIVE_QA and HANDOFF for complete qualifications.

Illustrated app/feature and27achievement/fiveleaderboard badges are complete. Each badge was individually generated, packaged512px and inspected512/64. Provenance records prompts/original hashes; privately retained full originals are not promised in committed source archives. Illustrations are not gameplay proof. Legacy generate_assets.py cannot reproduce the new set.

Use AGENTS, README, HANDOFF and PLATFORM_SETUP when continuing. Isolate test data and preserve real saves/artifacts/notices. Services/IDs remain owner-configured. Public updates are held after denial; no new hosted CI/Pages/Library/Play publication or Windows distribution is claimed.
