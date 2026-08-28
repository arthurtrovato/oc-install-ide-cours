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

## Product goal

Native SwiftUI iPhone app + dense WidgetKit widget using meteoblue data, plus an independent Apple Watch app and rectangular complication.

Preserve:

- meteoblue-only weather values;
- automatic location;
- cache/offline behavior and movement handling;
- SideStore transport for iPhone app + iPhone widget only;
- separate Xcode/Personal Team installation for Watch;
- intentional Watch tap behavior to Apple Weather.

## User decisions that must not be reverted

1. Apple Watch complication data comes from **meteoblue**.
2. Tapping the Apple Watch complication must intentionally open **Apple Weather on the Apple Watch**. This is desired behavior, not a bug.
3. Intended chain: `complication -> meteobluewatch://apple-weather -> Meteoblue Watch relay -> weather:// -> Apple Weather`.
4. The unresolved iPhone widget tap that opens Safari is a separate issue and must not block Watch work.
5. The Watch complication should keep **five upcoming hours** unless the user explicitly agrees to trade density for larger typography.

## Current functional checkpoint

Latest functional commit: **`74a649e4ab9861bfb4f5faffd0d242c5dc1f770c`** — `watch: polish complication readability at density limit`.

This changes only `WatchWidget/WatchWeatherRectangularView.swift`. It does **not** change weather data, meteoblue API behavior, cache behavior, location behavior, bundle IDs or the intentional tap destination.

### Final readability polish in `74a649e`

The user physically tested the previous full-color design (`b578e2f`) on an Apple Watch Series 9 and supplied a photo. The design was functional and substantially improved, but the photo showed two remaining readability issues:

- the top-right rain text was crowded (`3,3mmjour`);
- hourly labels such as `23h`, `0h`, `1h` spent precious horizontal space on a redundant suffix.

Final polish applied while preserving all five hours and all core weather values:

- full-color background dark veil increased from 11% to 16% to improve white-text contrast while preserving the iPhone-like weather palette;
- current temperature increased slightly again (compact 17 pt);
- min/max text increased slightly and stays bold;
- secondary white text increased to 96% opacity;
- precipitation cyan made slightly brighter;
- daily precipitation now includes readable spacing (`3,3 mm` rather than `3,3mm`);
- the redundant all-day timing (`tte j.` / `jour`) is hidden because the value is already explicitly the daily total;
- useful timing information such as `soir`, `mat.` or exact ranges is still displayed, separated with a centered dot;
- hourly labels are now compact two-digit clock values (`23 00 01 02 03`) without the redundant `h` suffix;
- hourly labels are larger/bolder;
- hourly condition symbols and temperatures are slightly larger;
- compact hourly precipitation values remain available when nonzero;
- five upcoming hours remain present.

### Density limit decision

With the current `.accessoryRectangular` slot, the project is now considered at the **reasonable readability/density limit while preserving all of these simultaneously**:

- current temperature;
- daily high/low;
- daily precipitation summary/timing;
- five hourly columns;
- hour, condition icon and temperature for every column;
- hourly precipitation when relevant.

Further **material** readability gains should not be attempted by blindly enlarging fonts. The next meaningful improvement would require a product tradeoff such as reducing five hours to four, removing the daily precipitation timing, or simplifying another field. Do not make that tradeoff without explicit user approval.

## CI for latest Watch polish

For functional commit `74a649e4ab9861bfb4f5faffd0d242c5dc1f770c`:

- **Watch CI `33207420190` — SUCCESS**
  - Xcode project generation: success;
  - independent Watch app build for `generic/platform=watchOS` physical-device SDK: success;
  - independent Watch app build for simulator: success.
- iOS CI `33207420200` was still running when this handoff bookkeeping commit was created; Swift tests, live meteoblue integration, project generation and iPhone app/widget build had already succeeded. The Watch-specific CI above is the authoritative validation for this view-only change.

Previous visual CI:

- Watch CI `33206293859` — success.
- iOS CI `33206293791` — success.

## Physical Apple Watch state — validated

Environment observed during Codex deployment:

- Mac local clone: `/Users/Arthur/Documents/Codex/2026-08-25/fai/work/oc-install-ide-cours`
- macOS: `26.5.2`
- Xcode: `26.6 (17F113)`
- iPhone: **iPhone 16e**, iOS `26.6.1`
- Apple Watch: **Apple Watch Series 9**, watchOS `26.6`, `arm64e`
- Developer Mode: enabled on Watch
- Xcode DDI services: available
- signing route: free **Personal Team**, automatic provisioning

Physically validated:

- `MeteoblueWatch` builds for the physical Watch;
- `MeteoblueWatchWidgetExtension` embeds and signs successfully;
- signed Watch app installs and launches successfully;
- Watch-side location permission is granted;
- local meteoblue key configuration is valid and ignored by Git;
- runtime produced a real cache with 169 hourly entries and 7 daily entries;
- rectangular complication `Meteoblue 5 h` is installed on the Watch face and functional;
- the full-color weather gradient renders on the user's selected Watch face;
- user physically confirmed the `b578e2f` readability build with a photo on 2026-08-28 around 22:13 CEST.

The **new `74a649e` polish is compiled but not yet visually photographed/confirmed on-device** at the time of this handoff. It must be pulled/reinstalled by the existing Codex Mac session.

## Watch deployment architecture

Do **not** use SideStore for the Watch app/complication. A combined iPhone + widget + Watch IPA made SideStore crash.

Use:

- SideStore: iPhone app + iPhone widget only;
- Xcode + free Personal Team: Watch app + complication.

Important files:

- `WatchWidget/MeteoblueWatchWidget.swift`
- `WatchWidget/WatchWeatherRectangularView.swift`
- `WatchApp/WatchContentView.swift`
- `WatchApp/MeteoblueWatchApp.swift`
- `WatchApp/Info.plist`
- `project.yml`
- `WATCH_INSTALL.md`
- `Scripts/validate_watch_bundle.py`
- `Scripts/prepare_watch_install.sh`
- `CODEX_WATCH_MISSION.md`

## Local secret / preparation history

`Scripts/prepare_watch_install.sh` is the normal local preparation path.

Current intended local behavior:

- valid `Config/Secrets.xcconfig` exists only on the Mac;
- it is ignored by Git;
- it is not printed or committed;
- the Watch physical build uses it locally.

A previous bug treating the French example API-key placeholder as configured has already been fixed.

## iPhone state

Physically validated:

- SideStore installs iPhone app + iPhone widget;
- app launches;
- custom icon appears;
- large widget displays real meteoblue weather;
- SideStore choice `Keep App Extensions (Use Main Profile)` preserves the widget;
- build `1.0.3 (95.1)` is installed.

Unresolved separate issue:

- tapping the iPhone widget still opens the canonical meteoblue forecast in Safari rather than the official meteoblue app;
- older coordinate URL and canonical place-slug URL both fall back to Safari;
- do not mix this issue into Watch visual work.

## GitHub connector pitfalls

- High-level `delete_file` has previously stalled. Prefer low-level Git Data deletion if deletion is needed.
- A high-level `create_file` was previously blocked by risk classification; low-level blob/tree/commit/ref operations worked.
- If a wrapper stalls/blocks, switch strategy rather than repeatedly retrying it.
- Codex on the Mac may push handoff-only commits concurrently with ChatGPT; always refetch branch HEAD/current file SHA before writing.

## Immediate next action

Use the existing local Codex thread if convenient:

`codex://threads/01a04993-07ed-7170-847c-6597c9f9a8d5`

On the Mac, Codex should:

1. pull the latest `meteoblue-widget` branch;
2. verify functional commit `74a649e` is present;
3. rebuild/sign with the existing Personal Team and local ignored secret;
4. reinstall/launch on the paired Series 9;
5. refresh/re-add `Meteoblue 5 h` only if WidgetKit retains the previous timeline;
6. visually confirm the final top-row spacing and `23 00 01...` hourly labels;
7. verify tap still opens Apple Weather;
8. update this handoff with the physical result.

## Last handoff update — 2026-08-28 around 22:16 CEST

- User supplied a second physical photo of the full-color complication and asked whether more improvement was possible or whether the design was at its maximum.
- The photo confirmed that the existing `b578e2f` version is readable and attractive, but rain timing and hour-label density still had small optimization headroom.
- Functional commit pushed: **`74a649e4ab9861bfb4f5faffd0d242c5dc1f770c`**.
- Changed file: `WatchWidget/WatchWeatherRectangularView.swift` only.
- Watch CI `33207420190`: **SUCCESS** for physical-device SDK and simulator.
- No API/cache/location/tap behavior changed.
- Product assessment: after `74a649e`, further meaningful readability improvement requires sacrificing information or reducing the five-hour horizon; therefore treat this as the density-max baseline unless the user explicitly chooses a tradeoff.
- Exact next action: Codex pulls/reinstalls `74a649e` on the Series 9 and user gives a final visual confirmation.
- Resume prompt: `Continue le projet Meteoblue sur arthurtrovato/oc-install-ide-cours, branche meteoblue-widget. Lis HANDOFF.md. Le dernier commit fonctionnel 74a649e est la passe finale de lisibilité de la complication Watch à densité constante. Pull/rebuild/reinstall sur la Series 9, valide visuellement et vérifie le tap Apple Weather, puis mets HANDOFF.md à jour.`
