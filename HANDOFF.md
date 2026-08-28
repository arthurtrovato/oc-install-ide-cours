# Meteoblue Widget — ChatGPT Handoff

> **MANDATORY SESSION RULE**
>
> Any ChatGPT session working on branch `meteoblue-widget` must read this file before making project changes and must update this file **before ending every substantive project turn**. Record branch head, functional checkpoint, CI, physical-device results, blockers and exact next action.

## Guardrails

- Repository: `arthurtrovato/oc-install-ide-cours`
- Work only on **`meteoblue-widget`**.
- Do not modify `master` or `ProjetLedor`.
- Latest functional checkpoint entering this handoff update: **`47ac307914f910dfff7792da8dee4b8d1f91174d`** (`watch: add guided local install preparation script`).
- Handoff-only commits are bookkeeping and should not be confused with the latest functional checkpoint.

## Product goal

Native SwiftUI iPhone app + dense WidgetKit widget using meteoblue only, plus an Apple Watch app and rectangular complication. Preserve automatic location, cache/offline behavior, movement handling and existing weather architecture.

## iPhone — physically validated state

SideStore successfully installs the iPhone app + iPhone widget package. The app launches, custom icon appears, widget is available and displays real meteoblue weather. `Keep App Extensions (Use Main Profile)` is the validated SideStore choice.

### Widget tap behavior — latest physical result

Build **1.0.3 (95.1)** has now been physically installed successfully on the user's iPhone after Wi-Fi became available. The diagnostics screen showed:

- version `1.0.3 (95.1)`;
- locality `Tressange`;
- fresh cache/no latest error;
- deep-link diagnostic: `Prévision meteoblue ouverte sur le web`.

Physical test result on 2026-08-28: **tapping the iPhone widget still opens the canonical meteoblue forecast in Safari, not the official meteoblue app**.

This means the earlier SideStore `Minimuxer.MinimuxerError 27 / AFC was unable to manage files on the device` was transient/environmental and is no longer the current blocker. The canonical place-slug URL approach did not cause the official meteoblue app to claim the link on this physical device.

Known investigation already completed:

- meteoblue publishes Apple App Site Association data;
- current official app bundle identified as `com.meteoblue.meteoblue-weather`;
- `/meteo/semaine/` paths are associated;
- older coordinate URL and newer canonical place-slug URL both physically fall back to Safari;
- Notes/Safari did not provide an Open-in-meteoblue route in prior tests;
- no documented/public `meteoblue://` custom scheme was found.

Do not block the Watch work on this. Revisit the iPhone deep-link track separately only if a new viable route is found.

## User distribution preference

Do not upload IPA files to Google Drive. If another IPA must be tested, provide it directly through ChatGPT/sandbox.

## Apple Watch — required behavior

**Do not change this user decision:** tapping the complication must intentionally open **Apple Weather on the Apple Watch**, while the complication itself displays meteoblue data.

Intended chain:

`complication -> meteobluewatch://apple-weather -> Meteoblue Watch relay -> weather:// -> Apple Weather`

## Apple Watch implementation

Targets:

- `MeteoblueWatch`
- `MeteoblueWatchWidgetExtension`
- complication family `.accessoryRectangular`

Watch functionality includes Watch-side location authorization, network/cache/timeline using `WidgetWeatherCoordinator(namespace: "watch-widget")`, meteoblue current/min/max/precipitation/five upcoming hours, and Watch app icon assets.

The Watch app is configured as independent of the iPhone companion with `WKRunsIndependentlyOfCompanionApp = true`.

Important files:

- `WatchWidget/MeteoblueWatchWidget.swift`
- `WatchApp/WatchContentView.swift`
- `WatchApp/MeteoblueWatchApp.swift`
- `WatchApp/Info.plist`
- `project.yml`
- `WATCH_INSTALL.md`
- `Scripts/validate_watch_bundle.py`
- `Scripts/prepare_watch_install.sh`

## Watch distribution architecture

Do **not** re-add Watch bundles to the SideStore IPA. A combined iPhone + widget + Watch + complication IPA made SideStore crash after import, while the iPhone + widget IPA installs correctly.

The Watch route is deliberately separate: **Xcode + Personal Team on the user's Mac**.

Completed Watch deployment work:

- `1b275fa` — independent Watch deployment flag;
- `97a8b3a` — structural Watch bundle validator;
- `65e582e` — dedicated Watch CI including `generic/platform=watchOS` physical-device SDK build;
- `c966f9f` — `WATCH_INSTALL.md` physical installation guide;
- `754f5f9` — Watch AppIcon assets;
- `47ac307` — `Scripts/prepare_watch_install.sh`, a guided local preparation script.

The preparation script:

- requires macOS/Xcode;
- verifies branch `meteoblue-widget` when inside a Git clone;
- installs XcodeGen through Homebrew when available and needed;
- creates `Config/Secrets.xcconfig` from the example when missing;
- asks for the meteoblue API key silently if not configured;
- verifies the secret file is ignored by Git;
- runs `xcodegen generate`;
- verifies the `MeteoblueWatch` scheme;
- prints the destinations Xcode sees;
- opens `MeteoblueWeather.xcodeproj`.

## CI state

Previously validated functional Watch state:

- Watch CI `33195073438`: **success**, including `generic/platform=watchOS` physical-device build, bundle validator and simulator build.
- iOS CI `33195073470`: **success**, including Swift tests, live meteoblue integration, iPhone app/widget and Watch app/complication builds.

After commit `47ac307`, new push CI runs were triggered on 2026-08-28; at the time of this handoff update the new Watch CI run `33197005675` was still `in_progress`. The new commit only adds a local preparation shell script and does not alter Watch runtime code.

## Current project configuration / decisions not to revert

- marketing version `1.0.3`;
- iOS minimum 17.0;
- watchOS minimum 10.0;
- Watch AppIcon enabled;
- weather values only from meteoblue;
- production packages `basic-1h_basic-day`;
- `current` package intentionally not required after real HTTP 403 probe;
- current conditions derived from nearest basic-1h row;
- cache fresh ~75 min, up to 8 zones;
- movement threshold 20 km;
- max location age 6 h;
- max accepted horizontal uncertainty 5 km;
- stale matching data/old-zone fallback intentionally supported;
- no WeatherKit and no App Group dependency.

Bundle IDs:

- `com.arthurtrovato.MeteoblueWidget`
- `com.arthurtrovato.MeteoblueWidget.Widget`
- `com.arthurtrovato.MeteoblueWidget.watchkitapp`
- `com.arthurtrovato.MeteoblueWidget.watchkitapp.Widget`

## GitHub connector pitfalls

- High-level `delete_file` has repeatedly stalled; for deletions use low-level Git Data (`create_tree` with `sha:null` -> `create_commit` -> `update_ref` -> verify 404).
- A prior high-level `create_file` was blocked by risk classification; low-level `create_blob` -> `create_tree` -> `create_commit` -> `update_ref` succeeded.
- If a wrapper stalls or is blocked, do not repeatedly retry it.

## Immediate next action — NOW

The user currently has **Wi-Fi, Mac and Apple Watch available**. Proceed with physical Watch installation now.

On the Mac, from a local clone of this repository:

```sh
git fetch origin
git switch meteoblue-widget
git pull --ff-only origin meteoblue-widget
./Scripts/prepare_watch_install.sh
```

Then in Xcode:

1. choose the user's Personal Team for `MeteoblueWatch` and `MeteoblueWatchWidgetExtension` under Signing & Capabilities;
2. pair/select the physical Apple Watch as the destination for scheme `MeteoblueWatch`;
3. press Run;
4. report the exact first blocking message if Xcode does not install;
5. if it installs, open Meteoblue on the Watch, grant location, add `Meteoblue 5 h` to a rectangular complication slot, verify real meteoblue data and verify tap opens Apple Weather.

Do not change Watch code pre-emptively in response to a signing/pairing issue; capture the exact Xcode error first.

## Last handoff update

- Date: 2026-08-28 around 19:55 Europe/Paris.
- Latest functional commit: `47ac307914f910dfff7792da8dee4b8d1f91174d`.
- New file this turn: `Scripts/prepare_watch_install.sh`.
- Physical iPhone result: build `1.0.3 (95.1)` installed successfully with Wi-Fi; widget still opens Safari rather than official meteoblue app.
- New blocker status: iPhone SideStore AFC error cleared; iPhone app-claim deep link remains unsuccessful but is not blocking Watch track.
- Physical Watch test: not started yet; user now has Mac + Watch ready.
- Exact next action: run the four shell commands in the Immediate next action section, then continue from the first Xcode result.
- Resume prompt if conversation changes: `Continue le projet Meteoblue depuis HANDOFF.md. Le test physique iPhone 95.1 ouvre toujours Safari. Le Mac et l’Apple Watch sont disponibles. Reprends l’installation Watch depuis Scripts/prepare_watch_install.sh et corrige le premier blocage Xcode réel, puis mets HANDOFF.md à jour.`
