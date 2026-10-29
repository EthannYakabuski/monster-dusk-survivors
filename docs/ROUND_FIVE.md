# Round Five: reachable combat controls

Requested criterion: move DASH directly left of FIRE and make the buttons roughly the same size. Both are now 160×64 logical units, aligned on the same row with a 12-unit gap. RELOAD stays below, and the fire hint moves below FIRE rather than overlapping DASH. The existing independent pointer ownership and keyboard controls are unchanged.

Acceptance: `tests/test_round_three.gd` checks real Godot Window logical viewports for phone, 7-inch and 10-inch profiles; equal sizes, relative ordering, visible bounds, non-overlap and routed movement/fire/reload/dash inputs are source/engine evidence. The other model, UI and fullscreen lifecycle suites remain applicable. Fresh native touch ergonomics, audible output, signed-in services and physical-device acceptance remain separate pending checks. No claim is made that a headless viewport test is an Android test or a gameplay screenshot.

Owner configuration, untracked feature artwork, existing saves, accepted binaries and historical provenance are retained. This update changes no gameplay balance or service-ID mapping. Source test results and the exact public commit/CI will be recorded in the local Round Five receipt.
