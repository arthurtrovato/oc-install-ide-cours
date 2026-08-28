# Meteoblue Widget — ChatGPT / Codex Handoff

> **MANDATORY CONTINUITY RULE**
>
> Any ChatGPT or Codex session working on branch `meteoblue-widget` must read this file before changing the project and must update it before ending every substantive turn. Record the current branch state, latest functional commit, CI, physical-device results, exact blockers and the next executable action.

## Repository guardrails

- Repository: `arthurtrovato/oc-install-ide-cours`
- Work only on branch **`meteoblue-widget`**.
- Never modify `master`.
- Never modify `ProjetLedor`.
- Never discard unknown local user changes; use a clean clone/worktree if necessary.
- Do not put Watch bundles back into the SideStore IPA.
- Do not upload future IPA files to Google Drive.
- Never commit `Config/Secrets.xcconfig`, credentials, DerivedData, provisioning profiles or private signing material.
- Codex on the Mac may push handoff-only commits concurrently; refetch branch HEAD/file SHA before every write.

## Product goal

Native SwiftUI iPhone app + dense WidgetKit widget using meteoblue data, plus an independent Apple Watch app and rectangular complication.

Preserve:

- meteoblue-only weather values;
- automatic location;
- cache/offline behavior and movement handling;
- SideStore transport for iPhone app + iPhone widget only;
- separate Xcode/Personal Team installation for Watch;
- intentional Watch tap destination: **Apple Weather on Apple Watch**.

## User decisions that must not be reverted

1. Apple Watch complication data comes from **meteoblue**.
2. Tapping the complication must intentionally open **Apple Weather on the Apple Watch**. This is desired behavior, not a bug.
3. The implementation may use the Meteoblue Watch app as a relay, but the final destination must remain Apple Weather.
4. The unresolved iPhone widget tap that opens Safari is a separate issue and must not block Watch work.
5. Keep **five upcoming hours** in the rectangular complication unless the user explicitly agrees to trade density for larger typography.

## Current functional checkpoints

### Visual baseline — `74a649e`

Commit: **`74a649e4ab9861bfb4f5faffd0d242c5dc1f770c`** — `watch: polish complication readability at density limit`.

This is the current density-max visual design while preserving all five hours and all core weather information. It changes only `WatchWidget/WatchWeatherRectangularView.swift`.

Physical photos confirmed the preceding color/contrast build is attractive and readable on the user's Series 9. `74a649e` further optimizes:

- darker full-color veil for contrast;
- very high-opacity secondary text;
- compact two-digit hourly labels (`23 00 01 02 03`);
- slightly larger/bolder hourly labels, symbols and temperatures;
- readable daily precipitation spacing (`3,3 mm`);
- redundant all-day timing hidden;
- useful timings such as `soir`, `mat.` and exact ranges retained;
- five hourly columns retained.

Further material readability gains now require a product tradeoff (for example 5 → 4 hours or removing another field). Do not make that tradeoff without explicit user approval.

Watch CI for `74a649e`: **`33207420190` — SUCCESS**, including `generic/platform=watchOS` physical-device SDK and simulator.

### Apple Weather launch fix — latest runtime candidate `f5ad451`

Commit: **`f5ad451414fe8a81ed7a05021d5d3ecd5d1be9ad`** — `watch: simplify Apple Weather universal-link launch`.

Changed file: `WatchApp/WatchContentView.swift` only.

Reason:

- User physically tested the Watch app button `Ouvrir Météo`.
- The button animation executes, proving the button receives the tap.
- The app stays on the same screen and Apple Weather does not open.
- The old second-hop implementation used `weather://` through SwiftUI `openURL`.
- Therefore the physical failure is isolated to the `weather://` launch path, not the button itself.
- The complication first hop remains `meteobluewatch://apple-weather` and should continue opening the Meteoblue Watch relay; the relay's second hop is what changed.

New candidate path in `f5ad451`:

`button or complication -> Meteoblue Watch relay -> https://weather.apple.com/?lat=<watch latitude>&long=<watch longitude> -> system Universal Link handling -> Apple Weather`

The Watch app asks `AppleLocationClient` for current position without prompting again, builds the Apple Weather HTTPS URL with latitude/longitude, and calls SwiftUI `openURL` on the MainActor.

An intermediate commit **`f6e9b38`** attempted the same Universal Link with an `openURL(...completion:)` callback and visible failure state. It failed Swift/watchOS compilation. GitHub exposed the failed checks but the connector did not expose the compiler annotation body. Rather than guessing at the callback/concurrency issue, the implementation was simplified to the documented `openURL(url)` form and Foundation was imported explicitly.

Validation for `f5ad451`:

- Watch CI run **`33208401695` — SUCCESS**.
- `generic/platform=watchOS` physical-device build: **SUCCESS**.
- Watch simulator build: **SUCCESS**.
- iOS CI run `33208401616` had Swift tests, live meteoblue test, project generation and iPhone app/widget build progressing successfully when the handoff was written; Watch CI above is the decisive validation for this Watch-only change.
- **Physical launch behavior of the new Universal Link is not yet validated.**

If the HTTPS Universal Link still fails physically, do not revert blindly to `weather://`. Capture the actual runtime behavior/logs and investigate a watchOS-supported Apple Weather launch mechanism.

## Physical Apple Watch environment

Observed during Codex deployment:

- local clone: `/Users/Arthur/Documents/Codex/2026-08-25/fai/work/oc-install-ide-cours`
- macOS `26.5.2`
- Xcode `26.6 (17F113)`
- iPhone 16e, iOS `26.6.1`
- Apple Watch Series 9, watchOS `26.6`, `arm64e`
- Developer Mode enabled
- Xcode DDI services available
- free Personal Team, automatic provisioning

Physically validated:

- `MeteoblueWatch` builds, signs, installs and launches on the Series 9;
- `MeteoblueWatchWidgetExtension` embeds/signs correctly;
- Watch location permission is granted;
- ignored local meteoblue key works;
- runtime cache contained 169 hourly entries and 7 daily entries, confirming real meteoblue data;
- rectangular complication `Meteoblue 5 h` is installed and displays real data;
- selected watch face permits the full-color gradient;
- visual layout is functional and readable.

Current physical defect:

- old `Ouvrir Météo` button using `weather://` animates but does nothing;
- old complication tap is expected to suffer the same second-hop failure;
- `f5ad451` is compiled and ready for physical reinstall/test.

## Watch deployment architecture

Never use SideStore for the Watch app/complication. A combined iPhone + widget + Watch IPA made SideStore crash.

Use:

- SideStore: iPhone app + iPhone widget only;
- Xcode + free Personal Team: Watch app + complication.

Important files:

- `WatchWidget/MeteoblueWatchWidget.swift`
- `WatchWidget/WatchWeatherRectangularView.swift`
- `WatchApp/WatchContentView.swift`
- `WatchApp/MeteoblueWatchApp.swift`
- `WatchApp/Info.plist`
- `AppleSupport/AppleLocationClient.swift`
- `project.yml`
- `WATCH_INSTALL.md`
- `Scripts/validate_watch_bundle.py`
- `Scripts/prepare_watch_install.sh`
- `CODEX_WATCH_MISSION.md`

## Local secret rules

`Scripts/prepare_watch_install.sh` is the normal local preparation path.

- `Config/Secrets.xcconfig` exists only locally on the Mac.
- It is ignored by Git.
- Never print or commit its meteoblue API key.
- Watch physical builds use it locally.

## iPhone state

Physically validated:

- SideStore installs iPhone app + iPhone widget;
- app launches;
- custom icon appears;
- large widget displays real meteoblue weather;
- SideStore option `Keep App Extensions (Use Main Profile)` preserves the widget;
- build `1.0.3 (95.1)` is installed.

Unresolved separate issue:

- tapping the iPhone widget opens the canonical meteoblue forecast in Safari rather than the official meteoblue app;
- coordinate URL and canonical place-slug URL both fell back to Safari;
- do not mix this issue into current Watch launch work.

## GitHub connector pitfalls

- High-level `delete_file` previously stalled; use low-level Git Data deletion if deletion is needed.
- A high-level `create_file` was previously blocked by risk classification; low-level blob/tree/commit/ref operations worked.
- If a wrapper stalls/blocks, switch strategy rather than repeatedly retrying it.
- `fetch_workflow_job_logs` was not yielding usable log text in the Watch-launch debugging turn; GitHub check metadata confirmed failures, but annotation-body URLs were rejected by the connector. Do not endlessly retry the same log path.

## Immediate next action

Use the existing local Codex thread if convenient:

`codex://threads/01a04993-07ed-7170-847c-6597c9f9a8d5`

Codex should:

1. pull latest `meteoblue-widget` and confirm `f5ad451` is present;
2. rebuild/sign/reinstall `MeteoblueWatch` on the paired Series 9 with the existing Personal Team/local ignored secret;
3. launch the Watch app while the watch is unlocked;
4. press **`Ouvrir Météo` first** and report whether Apple Weather actually opens;
5. if the button succeeds, return to the face and tap the Meteoblue complication and confirm the same Apple Weather destination;
6. if either fails, capture Xcode runtime/device logs around the tap before changing code;
7. update this handoff with the physical result.

## Last handoff update — 2026-08-28 around 22:30 CEST

- User reported the physical Watch app button `Ouvrir Météo` animates but leaves the app on the same screen.
- Root cause isolated to the old second-hop `weather://` launch behavior.
- Intermediate `f6e9b38` moved to Apple Weather HTTPS Universal Link but failed compile with the callback-based implementation.
- Final compile-safe candidate: **`f5ad451414fe8a81ed7a05021d5d3ecd5d1be9ad`**.
- Watch CI **`33208401695` — SUCCESS**, physical-device SDK + simulator.
- Desired final destination remains Apple Weather on the Watch.
- Physical validation of `f5ad451` is the only remaining step for this bug.
- Resume prompt: `Continue le projet Meteoblue sur arthurtrovato/oc-install-ide-cours, branche meteoblue-widget. Lis HANDOFF.md. Le bouton Watch weather:// était physiquement no-op. f5ad451 remplace le second hop par le Universal Link https://weather.apple.com/ avec les coordonnées Watch et passe le Watch CI appareil physique. Rebuild/reinstall sur la Series 9, teste d'abord Ouvrir Météo puis le tap de complication, capture les logs si échec, puis mets HANDOFF.md à jour.`
