# Meteoblue Widget — ChatGPT Handoff

> **MANDATORY SESSION RULE**
>
> Any ChatGPT session working on branch `meteoblue-widget` must read this file before making project changes and must update this file **before ending every substantive project turn**. The update must record the new branch head, CI state, decisions, physical-device results, known blockers, and the exact next action. This file exists so a new conversation can resume without relying on ChatGPT conversation history.

## Repository and branch guardrails

- Repository: `arthurtrovato/oc-install-ide-cours`
- Working branch: **`meteoblue-widget` only**.
- Do **not** modify `master`.
- Do **not** modify `ProjetLedor`.
- Functional checkpoint immediately before this handoff file was created: `29f7c2550575c9cddfd1ca51920502a091847cf6` (`ci: remove canonical-link dispatch bootstrap`).
- Commits that only update `HANDOFF.md` are bookkeeping commits; the most recent functional checkpoint should always be stated explicitly in this document.

## Persistent product goal

Build, test and push as far as technically possible a native SwiftUI iPhone app plus WidgetKit widget using meteoblue weather data, with automatic location, robust cache/offline behavior, movement handling, and useful tap behavior. The project also contains an Apple Watch app and rectangular WidgetKit complication.

The large iPhone widget should remain dense: current conditions + upcoming hours + upcoming days simultaneously.

## Current iPhone state

### What is physically validated

On a real iPhone, the SideStore path has successfully demonstrated:

- SideStore can install the **iPhone app + iPhone widget** package.
- Meteoblue Weather launches correctly.
- The custom app icon displays correctly.
- The large WidgetKit widget appears in the widget gallery.
- The widget displays real meteoblue weather data.
- In SideStore's `App Contains Extensions` dialog, **Keep App Extensions (Use Main Profile)** preserves the widget correctly.
- Build `1.0.3 (88.1)` physically validated the pre-iOS-27 widget tap relay through the web fallback: tapping the widget reached the host app and opened the corresponding meteoblue forecast in the browser.

### Latest iPhone-link change awaiting physical installation

The latest functional code uses meteoblue's location search endpoint to resolve the exact GPS position to a canonical meteoblue place slug only for the **tap URL**. The weather forecast itself remains requested for the exact GPS coordinates.

Relevant implementation:

- `Sources/MeteoblueCore/MeteoblueLink.swift`
  - `MeteoblueLocationSearchResolver`
  - canonical URL form such as `https://www.meteoblue.com/fr/meteo/semaine/aumetz_france_3036107`
  - best-effort fallback to the older coordinate/elevation/time-zone URL if location search fails.
- `Sources/MeteoblueCore/WeatherService.swift` injects and uses the resolver without making weather loading depend on it.
- `Tests/MeteoblueCoreTests/MeteoblueLinkAndEndpointTests.swift` covers canonical URL generation and resolver behavior.

For coordinates around `49.41, 5.95`, meteoblue's location search returned canonical nearby places including Aumetz (`aumetz_france_3036107`) and Tressange (`tressange_france_2971777`).

The canonical-link code passed the full CI and was packaged into SideStore build **`1.0.3 (95.1)`**.

### Latest SideStore build / CI

- Functional code checkpoint: `29f7c2550575c9cddfd1ca51920502a091847cf6`.
- Full push CI run: `33192852966` — **success**.
- Manual `workflow_dispatch` SideStore run used to package canonical-link build: `33192536496` — **success**.
- Produced build: **1.0.3 (95.1)**.
- The manual bootstrap workflow was removed afterward; `.github/workflows/` should contain only `ios-ci.yml` in the clean state.

### Current installation blocker

Attempting to install build 95.1 produced SideStore:

`Minimuxer.MinimuxerError 27`

`AFC was unable to manage files on the device.`

At the time, the iPhone was on **4G with no Wi-Fi available**. This is a SideStore/device communication failure before the app itself installs, not an app-runtime error.

Do not change Meteoblue Weather code in response to this AFC error. Retry when Wi-Fi is available with Wi-Fi + LocalDevVPN active. If it persists, investigate SideStore nightly / pairing refresh with iLoader.

### User distribution preference

**Do not upload future IPA files to Google Drive.**

When a new IPA must be tested, provide it directly in the ChatGPT conversation / sandbox attachment only.

## iPhone widget tap behavior

### Pre-iOS-27

The widget sends its stored meteoblue HTTPS URL through `widgetURL`. The host app validates the URL and attempts `UIApplication.open(..., universalLinksOnly: true)`, then falls back to opening the same URL normally if the official meteoblue app does not accept the Universal Link.

Physical build 88.1 opened the browser rather than the meteoblue app.

Investigation already completed:

- `meteoblue.com` and `www.meteoblue.com` publish valid Apple App Site Association data.
- Apple's CDN also exposes the association.
- The current meteoblue bundle is `com.meteoblue.meteoblue-weather`.
- Forecast paths including French `/meteo/semaine/` are in the association.
- In Apple Notes, long-pressing the generated old coordinate URL did **not** offer `Open in meteoblue`.
- Safari did **not** display an Open-in-meteoblue Smart App Banner on the tested page.
- No documented/public `meteoblue://` custom URL scheme was found.

Because of this, the latest approach is the canonical location-slug URL in build 95.1. That build has **not yet been installed**, because of MinimuxerError 27 above.

## Apple Watch status

### Implemented

The project contains:

- watchOS app target `MeteoblueWatch`
- watchOS WidgetKit extension `MeteoblueWatchWidgetExtension`
- supported family: `.accessoryRectangular`
- complication displays meteoblue data including current temperature, min/max, precipitation information, and five upcoming hours.
- Watch location authorization flow exists.
- Watch timeline/cache logic uses `WidgetWeatherCoordinator(namespace: "watch-widget")`.
- The Watch app and complication continue to compile successfully in CI.

Important files:

- `WatchWidget/MeteoblueWatchWidget.swift`
- `WatchApp/WatchContentView.swift`
- `WatchApp/MeteoblueWatchApp.swift`
- `project.yml`

### IMPORTANT USER DECISION — do not change this

**Tapping the Apple Watch complication is intentionally supposed to open Apple's Weather app on the Apple Watch.**

This is not a bug and must not be "fixed" to open the meteoblue Watch app.

Current intended chain:

`complication -> meteobluewatch://apple-weather -> Watch app relay -> weather:// -> Apple Weather`

The user explicitly wants this because the official meteoblue Apple Watch app is considered too poor for the tap destination, while meteoblue data is still desired on the complication itself.

### Watch blocker

The Watch code is not yet physically installed/validated on the user's Apple Watch.

A SideStore IPA containing:

- iPhone app
- iPhone widget
- Watch app
- Watch complication

made SideStore crash around 1–2 seconds after import.

The same iPhone app + iPhone widget IPA **without Watch bundles** installs successfully. Therefore the production SideStore IPA deliberately removes the nested Watch app before packaging, while CI still builds/tests all Watch targets.

Next Watch objective: establish a **separate Watch installation route**, likely Xcode + free Personal Team on a Mac or another confirmed watchOS-capable signing/deployment method. Do not re-add Watch bundles to the SideStore transport IPA unless SideStore gains proven watchOS support.

## Current project configuration

`project.yml` currently declares:

- marketing version `1.0.3`
- source `CURRENT_PROJECT_VERSION: 7`; the manual SideStore workflow overrides the packaged build number dynamically from the GitHub run number/attempt (examples: `88.1`, `95.1`).
- iOS deployment target 17.0.
- watchOS deployment target 10.0.
- Bundle IDs:
  - `com.arthurtrovato.MeteoblueWidget`
  - `com.arthurtrovato.MeteoblueWidget.Widget`
  - `com.arthurtrovato.MeteoblueWidget.watchkitapp`
  - `com.arthurtrovato.MeteoblueWidget.watchkitapp.Widget`

The SideStore package contains only the first two bundle IDs.

## Weather architecture / decisions that should not be accidentally reverted

- Weather values come only from meteoblue.
- Production packages: `basic-1h_basic-day`.
- `current` package is intentionally not required because a real probe returned HTTP 403 for the current account.
- Current conditions are derived from the nearest `basic-1h` row.
- Cache fresh duration: approximately 75 minutes.
- Up to 8 geographic zones cached.
- Location movement threshold: 20 km.
- Maximum accepted location age: 6 hours.
- Maximum accepted horizontal uncertainty: 5 km.
- Stale matching data and old-zone fallback are intentionally supported offline.
- No WeatherKit dependency.
- No App Group dependency.

## SideStore packaging rules

`.github/workflows/ios-ci.yml` should:

- run tests/builds on ordinary pushes;
- compile iPhone app, iPhone widget, Watch app and Watch complication;
- use `METEOBLUE_API_KEY` only for allowed live/manual contexts;
- generate the runner-only XOR-obfuscated embedded key only for manual SideStore packaging;
- package **iPhone app + iPhone widget only**;
- remove the nested Watch app from the SideStore transport copy;
- verify bundle IDs, build metadata, icon/Assets.car, no provisioning profile, no plaintext API key, ZIP integrity;
- upload the keyed IPA only on `workflow_dispatch`;
- give each manual package a unique build number from run number + attempt;
- retain IPA artifact only briefly (currently 1 day).

## Manual workflow dispatch procedure

There is no permanent bootstrap workflow in the clean branch.

When a direct workflow-dispatch connector action is unavailable, a temporary `.github/workflows/manual-dispatch-bootstrap.yml` has been used to POST the `ios-ci.yml` dispatch endpoint on push. Procedure:

1. Create the temporary bootstrap.
2. Confirm the actual `workflow_dispatch` run exists.
3. **Do not push anything while that manual run is active**, because CI concurrency may cancel it.
4. Wait until manual packaging and artifact upload complete.
5. Remove the bootstrap immediately.
6. Confirm the final cleanup push CI is green and the bootstrap file is 404/absent.

## GitHub connector pitfall — critical

The high-level GitHub `delete_file` action has repeatedly hung/stalled ChatGPT turns even though GitHub permissions are valid. This was isolated experimentally: blobs, trees, commits and ref writes work; `delete_file` was the problematic wrapper.

For deletions on this project, prefer low-level Git Data operations:

1. Fetch current commit/tree.
2. `create_tree` using the base tree and an entry for the path with `sha: null`.
3. `create_commit` with the current branch head as parent.
4. `update_ref` for `meteoblue-widget`.
5. Verify the deleted file returns 404.

Do not repeatedly retry `delete_file` if it produces no result.

Normal `create_file` / `update_file` have generally worked.

## Previous ChatGPT-stall diagnosis

The earlier "stopped thinking" incidents were not caused by repository permissions or conversation length. GitHub auth was confirmed as admin/push-capable and low-level writes succeeded. The strongest observed cause was a connector/approval path that failed to return a result for certain high-level destructive operations, especially `delete_file`.

If a tool call returns no result, explicitly record that in this handoff and switch strategy rather than silently waiting/retrying indefinitely.

## Immediate next actions

There are currently two independent tracks:

### Track A — iPhone canonical meteoblue tap

Blocked until the user has Wi-Fi available.

When Wi-Fi is available:

1. Enable Wi-Fi and LocalDevVPN together.
2. Retry installing SideStore build **1.0.3 (95.1)**.
3. Open Meteoblue Weather and force a fresh weather refresh so the snapshot obtains a canonical meteoblue URL.
4. Reload/re-add the widget if necessary to eliminate an old cached timeline.
5. Tap the widget.
6. Record whether it opens the meteoblue app or browser.

If installation still fails with MinimuxerError 27, debug SideStore/pairing before touching app code.

### Track B — Apple Watch complication deployment

Can proceed independently of the iPhone canonical-link test.

1. Keep the existing intentional tap behavior to Apple Weather.
2. Investigate a separate watchOS installation/signing path, preferably Xcode Personal Team if technically viable.
3. Do not put Watch bundles back into SideStore IPA unless proven safe.
4. Once installed on a real Watch, validate:
   - app launch;
   - location permission;
   - complication availability in the rectangular slot;
   - real meteoblue data;
   - refresh behavior;
   - tap opens Apple Weather on the Watch.

## Per-turn handoff update format

Before ending every substantive project turn, update this file with at least:

- `Last handoff update` date/time if known;
- current branch HEAD;
- latest **functional** commit (separate from handoff-only commits);
- latest relevant CI run(s) and result;
- files changed during the turn;
- physical-device test result, if any;
- new decisions/constraints from the user;
- blockers/errors and exact messages;
- next action that can be executed;
- exact suggested prompt for a new ChatGPT conversation.

Do not erase useful historical discoveries unless they are clearly obsolete; update them or mark them superseded.

## Suggested new-conversation prompt

Use this when moving to a fresh ChatGPT conversation:

> Continue the Meteoblue widget project in `arthurtrovato/oc-install-ide-cours`, branch `meteoblue-widget`. Read `HANDOFF.md` first and treat it as the authoritative project state. Execute the next useful actions yourself, do not touch `master` or `ProjetLedor`, and update `HANDOFF.md` before ending the turn.

## Last handoff update

- Date: 2026-08-28
- Reason: initial creation requested explicitly by the user so project state survives ChatGPT conversation/tool stalls.
- Branch head before this handoff bookkeeping commit: `29f7c2550575c9cddfd1ca51920502a091847cf6`.
- Latest functional CI: run `33192852966`, success.
- Latest manual SideStore packaging run: `33192536496`, success, build `1.0.3 (95.1)`.
- Latest physical blocker: build 95.1 could not be installed because SideStore returned `Minimuxer.MinimuxerError 27` / `AFC was unable to manage files on the device`; user currently has no Wi-Fi available.
- Latest user decision: do not upload IPA files to Google Drive; Apple Watch complication tap must intentionally open Apple Weather on the Watch.
- Next executable technical track without waiting for Wi-Fi: investigate/develop a separate Apple Watch installation path while preserving the current complication tap behavior.
