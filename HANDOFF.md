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
- intentional Watch tap destination: **Apple Weather on Apple Watch**;
- five upcoming hours in the rectangular complication unless the user explicitly approves a density tradeoff.

## Current branch state — 2026-08-29 13:25 CEST

### Tested functional HEAD

**`02db6a8ce69d9f2a9e7f0cf80979103ef14b157f`** — `weather: harden cross-device forecast consistency`

This is the latest runtime/code commit and the last commit fully validated by both Watch CI and iOS CI.

The commit that updates this `HANDOFF.md` is documentation-only and uses `[skip ci]`; therefore the branch HEAD after this handoff update is one documentation commit after `02db6a8`, with **no runtime/code change after `02db6a8`**. Always run `git rev-parse HEAD` after pulling to obtain the exact current documentation HEAD.

### Files modified by the functional fix

- `Sources/MeteoblueCore/WeatherCache.swift`
- `Sources/MeteoblueCore/WeatherModels.swift`
- `Sources/MeteoblueCore/WeatherLoadDiagnostic.swift` — new
- `AppleSupport/WidgetWeatherCoordinator.swift`
- `Tests/MeteoblueCoreTests/WeatherConsistencyTests.swift` — new

No changes were made to `master`, `ProjetLedor`, SideStore Watch packaging, Google Drive upload behavior, or any secret file.

## Priority issue — iPhone / Apple Watch precipitation divergence

Physical observation on 2026-08-29 around 12:19 CEST:

- iPhone: Aumetz, 20 °C, daily rain **1.2 mm**, timing **`tte j.`**, first visible hour **13 h**;
- Apple Watch: 20 °C, daily rain **1.0 mm**, timing **`ap.m.+soir`**, first visible hours **12, 13, 14, 15, 16**.

This was diagnosed as a **snapshot/timeline divergence**, not an arithmetic or rounding problem. Both surfaces use the shared precipitation logic (`WeatherDisplayModel.todayPrecipitationSummary` / `precipitationSummary(for:)`), so the same snapshot must produce the same daily rain total and timing.

The iPhone widget and Watch complication fetch meteoblue independently and have physically separate caches/devices. A shared local cache file is impossible and must not be proposed as the solution.

## Weather consistency architecture now in place

### 1. Hyperlocal location threshold

`LocationPolicy` and weather cache selection use a default geographic tolerance of **2 km**, not the old 20 km. GPS accuracy is still taken into account by the location policy.

Purpose: a move large enough to matter for local precipitation should trigger a geographically relevant fetch instead of retaining weather for a distant zone.

### 2. Shared aligned network cadence

`WeatherRefreshCadence` defines a common default network cadence:

- interval: **90 minutes**;
- phase: **5 minutes**;
- cache freshness and repository selection are aligned to the same cadence windows;
- `WeatherSnapshot.freshness(at:)` now uses the same 90-minute default rather than the previous 75-minute default.

Do **not** blindly reduce this to a few minutes or 45/60 minutes. The current design intentionally improves convergence without multiplying meteoblue API calls.

The devices still call meteoblue independently. Alignment does not mathematically guarantee the same meteoblue model run if WidgetKit/watchOS delays one surface or meteoblue changes runs inside a window, but it removes the arbitrary rolling-cache phase drift that was a major source of divergence.

### 3. Presentation cadence separated from network cadence

`WeatherTimelineBuilder` can advance the displayed hourly columns around **HH:05** using the same already-fetched snapshot. This lets the 12 h column disappear in favor of 13 h without forcing another network request.

Do not conflate presentation timeline updates with meteoblue network refreshes.

### 4. Fresh snapshot preferred over stale exact-coordinate snapshot

`WeatherCachePolicy.match` now evaluates all records inside the 2 km hyperlocal radius and prefers a record that is both:

- inside the current shared refresh window; and
- within the 2 km geographic tolerance.

Only if no such record exists does it fall back to the closest stale record. This avoids an unnecessary API call when a valid fresh snapshot already exists nearby, while still rejecting materially different weather zones.

### 5. Exact widget/Watch snapshot diagnostics

The host iPhone app's old diagnostics are not enough because the host uses namespace `host` while the actual iPhone widget uses namespace `widget`.

`WidgetWeatherCoordinator` now emits a sanitized OSLog line for every actual widget/complication load with prefix:

`METEOBLUE_SNAPSHOT`

It records:

- `surface=widget` or `surface=watch-widget`;
- `source=network|freshCache|staleCache`;
- `observed_at`;
- `fetched_at`;
- `age_s`;
- meteoblue `run` when exposed by the response;
- `locality`;
- `coordinate`;
- displayed `rain_mm`;
- displayed `rain_timing`;
- `first_hour`;
- `next_refresh`.

No API key or secret is logged.

These two lines are the preferred physical evidence for proving whether iPhone and Watch actually used the same run/snapshot.

## Automated tests added / preserved

`WeatherConsistencyTests.swift` adds explicit regression coverage for:

1. a fresh snapshot within 2 km winning over a closer but stale record without a network call;
2. the same snapshot producing the same daily precipitation total/timing across iPhone-like and Watch-like presentation windows;
3. the default snapshot freshness matching the shared 90-minute cadence;
4. diagnostic output identifying source, fetchedAt, displayed rain and first visible hour.

Existing tests continue to cover:

- 2 km location threshold and GPS accuracy behavior;
- current-window cache reuse;
- expired/previous-window network refresh;
- offline stale-cache fallback;
- return to a previous zone;
- very old cache behavior;
- timeline hourly cutovers including HH:05;
- precipitation timing categories;
- meteoblue model-run metadata.

## CI for `02db6a8`

### Watch CI

Run **`33249970633` — SUCCESS**.

Validated:

- XcodeGen project generation;
- `generic/platform=watchOS` physical-device SDK build — SUCCESS;
- independent Watch simulator build — SUCCESS.

### iOS CI

The ordinary push run **`33249970659`** was cancelled by workflow concurrency because the bootstrap workflow intentionally dispatched the full manual run for the same HEAD. This cancellation is not a compile/test failure.

Bootstrap run **`33249970638` — SUCCESS** dispatched the full manual iOS CI.

Manual iOS CI run **`33249973310` — SUCCESS** on exact HEAD `02db6a8` validated:

- `swift test` — SUCCESS;
- live meteoblue integration test — SUCCESS;
- XcodeGen project generation — SUCCESS;
- iPhone app + embedded widget build — SUCCESS;
- explicit iPhone widget extension build — SUCCESS;
- Apple Watch app + rectangular complication build — SUCCESS;
- repository check that no local secret file is tracked — SUCCESS;
- SideStore credential generation on the ephemeral runner — SUCCESS;
- unsigned SideStore IPA build/validation — SUCCESS;
- SideStore artifact upload to GitHub Actions — SUCCESS.

The SideStore packaging rules remain unchanged: the distributed IPA is iPhone app + iPhone widget only. Watch bundles are compiled for validation but removed from the SideStore copy and must never be restored there.

## Physical Apple Watch environment

Known validated environment from the configured Codex Mac:

- local clone previously used: `/Users/Arthur/Documents/Codex/2026-08-25/fai/work/oc-install-ide-cours`
- macOS `26.5.2`
- Xcode `26.6 (17F113)`
- iPhone 16e, iOS `26.6.1`
- Apple Watch Series 9, watchOS `26.6`, `arm64e`
- Developer Mode enabled
- free Personal Team, automatic provisioning

Physically validated before this precipitation fix:

- `MeteoblueWatch` builds, signs, installs and launches on the Series 9;
- Watch location permission is granted;
- ignored local meteoblue key works;
- real meteoblue data is loaded;
- rectangular complication `Meteoblue 5 h` is installed and displays real data;
- final full-color five-hour design is functional/readable;
- iPhone app + widget are installed via the validated SideStore route and show real meteoblue data.

The new `02db6a8` precipitation-consistency change is **not yet physically installed/validated** on both devices. CI proves compilation/tests, not cross-device runtime convergence.

## Apple Weather tap status — still needs final physical retest

Do not confuse this with the precipitation issue.

Historical sequence:

1. `weather://` through SwiftUI `openURL` physically no-op'd.
2. `f5ad451` changed the second hop to an Apple Weather HTTPS Universal Link with Watch GPS coordinates.
3. Physical test of that SwiftUI `openURL` path displayed: **`URL failed to load. This URL can't be viewed on your iPhone.`**
4. Diagnosis: SwiftUI `openURL` was the wrong watchOS system-launch mechanism for this Universal Link.
5. `WatchApp/WatchContentView.swift` was then changed to use `WKExtension.shared().openSystemURL(...)`.
6. The corrected Watch app + complication built, installed and relaunched successfully on the Series 9.
7. **The final button retest and direct complication tap after the `WKExtension.openSystemURL` correction have not yet been physically performed.**

Desired behavior remains intentional:

`Meteoblue complication -> Meteoblue Watch relay -> Apple Weather Universal Link with coordinates -> Apple Weather on the Watch`

Do not revert this to opening the meteoblue Watch app as the final destination.

## iPhone separate tap issue

Physically validated iPhone baseline:

- SideStore installs iPhone app + iPhone widget;
- app launches;
- custom icon appears;
- large widget displays real meteoblue weather;
- `Keep App Extensions (Use Main Profile)` preserves the widget.

Separate unresolved issue:

- tapping the iPhone widget can open the canonical meteoblue forecast in Safari rather than the official meteoblue app;
- this is not the current precipitation task and must not be mixed into the Watch/weather consistency diagnosis.

## Watch deployment / secret rules

Never use SideStore for the Watch app/complication. The combined iPhone + widget + Watch IPA previously made SideStore crash.

Use:

- SideStore: iPhone app + iPhone widget only;
- Xcode + free Personal Team: Watch app + complication.

`Scripts/prepare_watch_install.sh` is the normal local Watch preparation path.

`Config/Secrets.xcconfig` exists only locally on the Mac, is ignored by Git, and must never be printed or committed.

Important files:

- `Sources/MeteoblueCore/WeatherCache.swift`
- `Sources/MeteoblueCore/WeatherRepository.swift`
- `Sources/MeteoblueCore/WeatherTimeline.swift`
- `Sources/MeteoblueCore/WeatherLoadDiagnostic.swift`
- `Sources/MeteoblueCore/LocationPolicy.swift`
- `Sources/MeteoblueCore/PrecipitationTiming.swift`
- `Sources/MeteoblueCore/WeatherModels.swift`
- `AppleSupport/AppleEnvironment.swift`
- `AppleSupport/WidgetWeatherCoordinator.swift`
- `Widget/MeteoblueWidget.swift`
- `WatchWidget/MeteoblueWatchWidget.swift`
- `WatchWidget/WatchWeatherRectangularView.swift`
- `WatchApp/WatchContentView.swift`
- `project.yml`
- `WATCH_INSTALL.md`
- `Scripts/prepare_watch_install.sh`
- `CODEX_WATCH_MISSION.md`

## GitHub connector pitfalls

- High-level file operations have occasionally been blocked/stalled; low-level blob/tree/commit/ref operations have worked reliably.
- If a wrapper blocks, change strategy rather than repeatedly retrying it.
- Refetch branch HEAD and the current file SHA immediately before writes because the Mac Codex thread can push concurrently.

## Exact next action

Use the already configured Codex Mac thread for one controlled physical convergence test.

1. Pull the latest `meteoblue-widget`; verify `02db6a8` is an ancestor of HEAD and read this file plus `WATCH_INSTALL.md`.
2. Preserve any unknown local changes; use a clean worktree/clone if needed.
3. Rebuild/sign/reinstall the Watch app + complication separately through Xcode/Personal Team; never add Watch bundles to SideStore.
4. Install/rebuild the iPhone app + widget from the same source revision using the existing validated iPhone route appropriate for the diagnostic session.
5. Start macOS/Xcode Console capture filtered to `METEOBLUE_SNAPSHOT` before forcing widget/complication reloads.
6. Trigger **one controlled refresh cycle** on each device. Do not loop force-refreshes and burn meteoblue quota.
7. Capture the latest complete `surface=widget` and `surface=watch-widget` lines.
8. Compare `source`, `fetched_at`, `age_s`, `run`, coordinates, `rain_mm`, `rain_timing`, `first_hour` and `next_refresh`.
9. Confirm whether the displayed iPhone and Watch rain total/timing converge. If they differ, determine first whether the model run/fetchedAt differs before changing precipitation arithmetic.
10. Also retest `Ouvrir Météo` and then the direct complication tap on the Series 9 to close the pending Apple Weather `WKExtension.openSystemURL` validation.
11. If either launch fails, capture the exact runtime/device log around the tap before changing code.
12. Update this `HANDOFF.md` with the physical results, HEAD, files changed, CI and next exact action, then push only `meteoblue-widget`.

### Expected success criteria for the physical precipitation test

Best case:

- iPhone and Watch report the same meteoblue run and close/same `fetched_at` values;
- coordinates are in the same hyperlocal zone (within the 2 km policy, ideally much closer);
- daily `rain_mm` and `rain_timing` are identical;
- first visible hour is consistent with the HH:05 presentation cutover;
- no repeated unnecessary network calls occur inside the same current 90-minute refresh window.

If WidgetKit/watchOS scheduling causes different runs, record that explicitly. The current architecture is designed to minimize this without excessive API calls; perfect atomic cross-device equality would require a separate synchronization transport rather than a nonexistent shared local cache.

### Codex execution status — 2026-08-29 13:39 CEST

- The clean `meteoblue-widget` branch was fetched and fast-forwarded to `4e672c451b8b976b349feab3d7e44fd7beebc5d4`; `02db6a8` is its direct functional ancestor.
- The local ignored Meteoblue configuration and Personal Team were accepted. The Watch app and complication from this HEAD built, signed, installed and launched successfully on the physical Apple Watch Series 9.
- The validated iOS CI artifact from run `33249973310` was downloaded. Its SHA-256 was checked locally and its IPA contents contain the iPhone app plus iPhone widget only; no Watch bundle is present.
- The iPhone is currently unavailable to CoreDevice, so the IPA has not yet been handed through the validated SideStore route and no `surface=widget` snapshot has been captured. The Watch has not yet been forced into a new diagnostic cycle.
- No source code, SideStore package or secret file was changed. The current physical blocker is making the paired iPhone available to the Mac while unlocked.
- Exact next action: unlock and connect the iPhone to the Mac, then install the prepared IPA through SideStore and start the filtered iPhone/Watch snapshot capture before one controlled refresh cycle.
