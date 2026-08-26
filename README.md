# Meteoblue Weather for iOS

A native SwiftUI iPhone application with a large WidgetKit Home Screen widget. The project is intentionally focused on one job: show a dense, glanceable weather summary using **meteoblue data only** for weather values while following the device's current area as iOS permits.

The widget presents current conditions, roughly six hourly forecasts, and five daily forecasts at the same time. It is functionally inspired by dense first-party weather widgets, but the layout, range bars and code are original. It uses SF Symbols rather than copying meteoblue or Apple Weather artwork.

## Recommended free installation: SideStore

For a zero-cost setup without owning a Mac, the recommended path is now **GitHub Actions -> SideStore -> iPhone**. GitHub's macOS runner compiles an unsigned device IPA, SideStore re-signs it with the user's free Apple Account, and SideStore can refresh the normal seven-day development signature directly from the iPhone.

The only computer-dependent step is SideStore's initial device installation/pairing; Windows, macOS or Linux can be used. After that, normal installation and refreshes happen on the iPhone with LocalDevVPN enabled. The exact procedure is in [`SIDESTORE.md`](SIDESTORE.md).

The `iOS CI` workflow creates the `MeteoblueWeather-SideStore` artifact only on a **manual workflow run** on `meteoblue-widget`. It contains the app plus the WidgetKit extension and is intentionally unsigned so SideStore can apply the user's personal development certificate. The artifact expires after one day.

## Current API design

The network layer uses the meteoblue Forecast/Packages API at `my.meteoblue.com` and combines these two Free Weather API packages in one JSON request:

- `basic-1h` for hourly temperature, detailed pictocode and precipitation fields;
- `basic-day` for daily min/max, daily pictocode and probability fields.

The production request path is therefore `basic-1h_basic-day`. This exact combination was exercised successfully against the real Free Weather API key in GitHub Actions. An earlier live probe that also appended `current` returned HTTP 403 for this account, so `current` is deliberately not a production dependency. This also minimizes package accounting and keeps the app portable across Free Weather API keys.

meteoblue documents that one Forecast API call can combine multiple packages. JSON is used because the hourly and daily packages have different time resolutions. Forecast length is limited to seven days by the service. Present conditions are derived entirely from meteoblue by selecting the closest valid `basic-1h` row to the display time. The decoder still accepts an optional `data_current` block in fixtures or future compatible responses, but the app does not require it. Decoding also tolerates numeric strings, nulls, partial arrays and selected field aliases.

Weather source rule: temperature, precipitation, forecast and weather condition values come only from meteoblue. Core Location / CLGeocoder may provide coordinates, locality text and time zone; those are location metadata, not weather data. WeatherKit is not used.

## Architecture

```text
App/                         SwiftUI host app and Diagnostics UI
AppleSupport/                iOS adapters: Core Location, geocoder, files, configuration
Widget/                      WidgetKit provider, large widget UI, previews
Sources/MeteoblueCore/       Platform-light domain/network/cache/timeline/link logic
Tests/MeteoblueCoreTests/    Fast unit tests + one opt-in live API integration test
Config/                      xcconfig template (real secret ignored)
.github/workflows/           macOS GitHub Actions build/test/package pipeline
project.yml                  Reproducible XcodeGen project definition
Package.swift                Swift package for MeteoblueCore and tests
SIDESTORE.md                 Zero-cost no-Mac installation guide
```

Key separations:

- `WeatherService` is the public weather-source boundary.
- `MeteoblueWeatherService` implements the real API.
- `MockWeatherService` supports deterministic previews/tests.
- `MeteoblueEndpointBuilding` allows direct API access today and a proxy later without rewriting UI code.
- `WeatherRepository` owns refresh-vs-cache decisions and offline fallback.
- `LocationPolicy` decides whether a new position is usable and meteorologically meaningful.
- `WeatherTimelineBuilder` turns one meteoblue response into multiple future WidgetKit entries.
- `MeteoblueForecastLinkBuilder` builds the exact-place meteoblue Universal Link and validates the host-app relay target.

No third-party runtime dependencies are used. XcodeGen is a development/CI generator only.

## Location strategy and iOS limitations

The containing app asks for **When In Use** Core Location permission. The widget extension has `NSWidgetWantsLocation = true` and checks `CLLocationManager.isAuthorizedForWidgetUpdates` before asking for a location.

Apple's documented behavior matters here:

1. The containing app must obtain location permission first.
2. When a location-using widget is added, iOS can ask the user whether the app's When In Use permission should extend to widgets.
3. `isAuthorizedForWidgetUpdates` becomes true after that approval (or with Always authorization).
4. A widget is considered "in use" only for a limited period after it is visible. Even when authorized, a location update is not guaranteed every time WidgetKit runs the extension.
5. Widget refreshes have a system-controlled budget and requested timeline dates are not hard real-time deadlines.

For that reason the implementation never promises instant GPS changes. It keeps the last valid position and the last valid weather data.

### Movement policy

Default policy:

- maximum location age: **6 hours**;
- maximum accepted horizontal uncertainty: **5 km**;
- weather-zone movement threshold: **20 km**.

The 20 km threshold avoids burning API credits for street-level movement that is normally insignificant to this forecast while still reacting to meaningful travel. It is also close to the 20-30 km regional scale meteoblue describes for its pictogram analysis. A move below the threshold retains the previous weather coordinate; a move at or above it selects the new coordinate. Tests cover both sides, stale/imprecise/unavailable fixes and returning to a previously cached zone.

The host app and widget each maintain their own last-location file. This is deliberate: the main product does **not** depend on App Groups.

## Cache and offline behavior

Each process has a JSON cache in its own Application Support container. A record contains the full `WeatherSnapshot`, including:

- retrieval time;
- exact forecast coordinates and locality;
- time zone/elevation metadata;
- current, hourly and daily conditions;
- the meteoblue URL for the displayed place.

Policy:

- data is considered fresh for **75 minutes**;
- up to **8 geographic zones** are retained;
- positions within 20 km share a weather-zone cache entry;
- stale data is refreshed when possible;
- network/API failure returns stale matching data;
- if the device is in a new zone and the API is unavailable, the latest valid old-zone data is still shown and marked as fallback rather than showing an empty widget;
- data older than 6 hours is visually marked very stale but remains available offline.

This keeps normal same-location use inside the requested 60-90 minute full-fetch interval.

## Widget timeline

A single fetched forecast is projected into several future `TimelineEntry` values. If a response is obtained around 09:00, later entries shift the six-hour window without another network request solely to move the UI from `09 10 11...` to `10 11 12...`.

The default builder creates the current entry plus hourly future entries and requests a refresh no earlier than the cache policy allows. Tests cover hourly progression, midnight, day changes and different time zones.

## Widget UI

The supported family is `.systemLarge`. It shows, at once:

- locality;
- current temperature and condition;
- today's high/low;
- six hourly cells with time, SF Symbol, temperature and precipitation probability when useful;
- five daily rows with weekday, symbol, minimum, maximum and a compact relative temperature-range bar;
- a subtle stale/fallback indicator.

Semantic SwiftUI foreground/background styles and SF Symbols are used for light/dark mode and modern widget rendering modes. Previews include rain, clear/hot with an unusually long locality, snow with negative temperature, storm, fog, an explicit clear-night case and dark-mode cases.

## meteoblue pictocode mapping

`MeteoblueConditionMapper` has two explicit code sets:

- daily pictocodes 1...17;
- detailed hourly pictocodes 1...35.

Every documented code in both sets is covered by automated mapping tests. The app maps those codes to original semantic categories (`clear`, `rain`, `fog`, `sleet`, and so on), then chooses an SF Symbol. Unknown future codes degrade to `unknown` rather than crashing.

## Opening meteoblue from the widget

On iOS 27 and later, the large widget is interactive. After adding it, edit the widget and set **Action au toucher** to **Open App**, then select the official **meteoblue** app. The widget uses Apple's `RunSystemShortcutIntent`, so iOS launches the selected installed app directly from the widget button without opening the Meteoblue Weather host app or the Shortcuts app.

On older iOS versions, the widget keeps the shortcut relay fallback described below. The URL is tied to the **coordinates stored in the displayed snapshot**, not the phone's later location.

The flow is:

```text
widget button
 -> RunSystemShortcutIntent
 -> official meteoblue app selected in the widget configuration

Legacy fallback:
widget tap
 -> shortcuts://run-shortcut
 -> custom shortcut
 -> official meteoblue app
```

meteoblue's live `apple-app-site-association` currently associates its app with forecast paths including French `/*/meteo/semaine/*` and English `/*/weather/week/*`. The builder therefore generates a coordinate/elevation/time-zone forecast path in that family. The host app rejects non-HTTPS and non-meteoblue targets to avoid an open-redirect style relay.

A widget cannot be relied on to directly launch an arbitrary third-party application URL as its own target, so the host-app relay is the minimal reliable WidgetKit-compatible design.

## Diagnostics

The host app exposes a Diagnostics screen with:

- app location authorization;
- widget-location authorization as seen by Core Location;
- last latitude/longitude;
- horizontal accuracy and position age;
- displayed locality;
- last meteoblue retrieval timestamp;
- cache age and source;
- next requested refresh;
- last error;
- app version;
- deep-link state.

`Copy diagnostic` emits plain text. Explicit configured secret values and API-key-looking query parameters are redacted. Unit tests verify the redaction.

## API key security

meteoblue documents API-key signing for frontend/mobile scenarios and recommends protecting credentials. Their signing flow requires a shared signing secret associated with the key. This repository has only the existing API key, not such a shared secret, so no fake HMAC scheme is implemented.

For normal local/Xcode builds, the ignored `Config/Secrets.xcconfig` path remains available. For a manually requested SideStore package, GitHub Actions reads the existing `METEOBLUE_API_KEY` repository secret and overwrites `AppleSupport/EmbeddedMeteoblueSecret.swift` **only inside the ephemeral runner**. The generated source stores the key as two random XOR byte arrays rather than as a plaintext Info.plist value. CI verifies that the plaintext key is absent from the packaged app before it creates the unsigned IPA. The checked-in source contains empty arrays.

This is obfuscation, not secret storage. **An API key shipped in a native client can ultimately be extracted.** Because this repository is public, a SideStore artifact must also be treated as potentially accessible to other readers while it exists. For that reason keyed IPA packaging is manual-only and the artifact expires after one day. A backend proxy or meteoblue signing secret is the correct architecture if cryptographic credential protection becomes necessary.

A Vercel proxy was intentionally not made mandatory: deploying a useful secret-hiding proxy requires securely provisioning the meteoblue credential into that deployment. Copying a GitHub Actions secret into another provider without an authorized secret-transfer mechanism would either require user intervention or risk exposure, which is worse than the simple personal-client design.

## Local key configuration

Never commit the real key.

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Then edit only `Config/Secrets.xcconfig`:

```text
METEOBLUE_API_KEY = your_real_key_here
```

`Config/Secrets.xcconfig` is ignored by Git. `Base.xcconfig` includes it optionally, so the project still builds without a local key and the app reports that configuration is missing.

## Alternative: Xcode Personal Team

A Mac remains an optional fallback, not the recommended free path. Install XcodeGen, run `xcodegen generate`, open the project, choose a free Personal Team for the app and widget extension, and run on the iPhone. Apple's free development profile still expires after seven days, so direct Xcode installation requires periodic re-sign/reinstall.

The project deliberately has no App Group, WeatherKit, Associated Domains or push-notification dependency. A paid Apple Developer Program membership is not required for the core personal-device design.

## Tests

Run fast deterministic tests with:

```sh
swift test
```

The suite covers at least:

- meteoblue decoding and partial responses;
- current/hourly/daily transformation;
- date/time-zone parsing;
- all used daily and detailed pictocodes;
- six-hour/five-day selection;
- midnight and future timeline progression;
- fresh/stale/very-old cache behavior and offline fallback;
- API/HTTP/transport failures;
- missing API key;
- missing/stale/imprecise location and below/above threshold travel;
- returning to a cached zone;
- exact-place meteoblue link generation and relay validation;
- diagnostics secret redaction.

### Real integration test

The live test is opt-in locally. In CI it has been run successfully against the `basic-1h_basic-day` response and verifies that the current response can be transformed into non-empty hourly and daily forecasts:

```sh
RUN_METEOBLUE_LIVE_TEST=1 METEOBLUE_API_KEY='...' swift test --filter MeteoblueLiveIntegrationTests
```

Do not place a real key in shell history on a shared machine. GitHub Actions obtains the already-configured `METEOBLUE_API_KEY` repository secret from the Actions environment and runs only this single controlled network test. The key is never printed by the test.

## GitHub Actions

`.github/workflows/ios-ci.yml` runs on a macOS runner and:

1. reports/selects Xcode;
2. installs XcodeGen;
3. runs all package tests;
4. runs the single real meteoblue integration test when the Actions secret is available;
5. regenerates the Xcode project;
6. builds the host iOS app for a generic iOS Simulator with signing disabled;
7. explicitly builds the WidgetKit extension;
8. verifies that no local secret file is tracked;
9. on a manual `workflow_dispatch` from `meteoblue-widget`, generates the runner-only obfuscated key source;
10. builds an unsigned Release app for a physical iPhone target, verifies the widget extension is embedded and the plaintext key is absent, packages `MeteoblueWeather-SideStore.ipa`, and uploads it for one day.

Pull-request contexts never receive the SideStore packaging secret. Normal push runs validate the project but do not publish a keyed IPA.

## What iOS and SideStore still control

No implementation can force these behaviors:

- instant GPS delivery to a widget whenever the phone crosses the 20 km threshold;
- an exact WidgetKit refresh time;
- unlimited widget refreshes;
- the user's location-permission choice;
- whether the meteoblue Universal Link opens the app or web when the official app is absent or iOS/user link preferences choose the browser;
- SideStore's own signing/extension compatibility on every future iOS release.

SideStore currently documents that apps should normally not need modification. The project also deliberately avoids App Groups; this matters because a current SideStore issue concerns App Group entitlements for extensions/widgets. Physical-device installation remains the final validation of the free signing path.

## Authoritative references checked during implementation

- meteoblue Forecast API Configurator and Free Weather API package list: https://docs.meteoblue.com/en/weather-apis/forecast-api/forecast-api-configurator
- meteoblue pictograms: https://docs.meteoblue.com/en/meteo/variables/pictograms
- meteoblue API overview/security: https://docs.meteoblue.com/en/weather-apis/forecast-api/overview
- Apple: Accessing location information in widgets: https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets
- Apple: `isAuthorizedForWidgetUpdates`: https://developer.apple.com/documentation/corelocation/cllocationmanager/isauthorizedforwidgetupdates
- Apple: Personal Team account limits: https://developer.apple.com/help/account/basics/about-your-developer-account
- Apple: iOS capability availability by membership: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- meteoblue Universal Links association: https://www.meteoblue.com/.well-known/apple-app-site-association
- SideStore prerequisites/install/FAQ: https://docs.sidestore.io/docs/installation/prerequisites
