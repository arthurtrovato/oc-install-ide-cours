# Meteoblue Weather for iOS

A native SwiftUI iPhone application with a large WidgetKit Home Screen widget. The project is intentionally focused on one job: show a dense, glanceable weather summary using **meteoblue data only** for weather values while following the device's current area as iOS permits.

The widget presents current conditions, roughly six hourly forecasts, and five daily forecasts at the same time. It is functionally inspired by dense first-party weather widgets, but the layout, range bars and code are original. It uses SF Symbols rather than copying meteoblue or Apple Weather artwork.

## Current API design

The network layer uses the meteoblue Forecast/Packages API at `my.meteoblue.com` and combines these Free Weather API packages in one JSON request:

- `basic-1h` for hourly temperature, detailed pictocode and precipitation fields;
- `basic-day` for daily min/max, daily pictocode and probability fields;
- `current` for present conditions when the package returns them.

meteoblue currently documents that a Forecast API request can combine multiple packages and that Basic and Current are available to the Free Weather API. JSON is used because packages with different time resolutions can be returned together. Forecast length is limited to seven days by the service.

If the `current` block is absent or partly missing, `MeteoblueTransformer` derives present conditions from the closest valid hourly row instead of making the UI fail. Decoding also tolerates numeric strings, nulls, partial arrays and selected field aliases.

Weather source rule: temperature, precipitation, forecast and weather condition values come only from meteoblue. Core Location / CLGeocoder may provide coordinates, locality text and time zone; those are location metadata, not weather data. WeatherKit is not used.

## Architecture

```text
App/                         SwiftUI host app and Diagnostics UI
AppleSupport/                iOS adapters: Core Location, geocoder, files, configuration
Widget/                      WidgetKit provider, large widget UI, previews
Sources/MeteoblueCore/       Platform-light domain/network/cache/timeline/link logic
Tests/MeteoblueCoreTests/    Fast unit tests + one opt-in live API integration test
Config/                      xcconfig template (real secret ignored)
.github/workflows/           macOS GitHub Actions build/test pipeline
project.yml                  Reproducible XcodeGen project definition
Package.swift                Swift package for MeteoblueCore and tests
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

Semantic SwiftUI foreground/background styles and SF Symbols are used for light/dark mode and modern widget rendering modes. Previews include rain, clear/hot with an unusually long locality, snow with negative temperature, storm and dark-mode cases.

## meteoblue pictocode mapping

`MeteoblueConditionMapper` has two explicit code sets:

- daily pictocodes 1...17;
- detailed hourly pictocodes 1...35.

Every documented code in both sets is covered by automated mapping tests. The app maps those codes to original semantic categories (`clear`, `rain`, `fog`, `sleet`, and so on), then chooses an SF Symbol. Unknown future codes degrade to `unknown` rather than crashing.

## Opening meteoblue from the widget

The URL is tied to the **coordinates stored in the displayed snapshot**, not the phone's later location.

The flow is:

```text
widget tap
 -> meteoblueweather:// relay URL
 -> host app validates the HTTPS target
 -> UIApplication opens the meteoblue Universal Link
 -> official meteoblue app when iOS resolves the Universal Link
 -> otherwise meteoblue website in the browser
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

For this personal app, direct API access is therefore used. **An API key embedded in a native client can ultimately be extracted.** The architecture isolates endpoint creation so a future HTTPS proxy or meteoblue signed-URL service can replace direct access without changing the cache, timeline or UI layers.

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

## Generate and open the Xcode project

Install XcodeGen, then from the repository root:

```sh
xcodegen generate
open MeteoblueWeather.xcodeproj
```

The generated `.xcodeproj` is intentionally ignored; `project.yml` is the source of truth.

## Signing and installation on an iPhone

The project keeps automatic signing enabled and adds no App Group dependency.

For a free Xcode **Personal Team**:

1. Open the generated project in Xcode.
2. Sign into your Apple Account in Xcode if needed.
3. Select the `MeteoblueWeather` app target and your Personal Team under Signing & Capabilities. Do the same for `MeteoblueWidgetExtension` if Xcode does not inherit the choice automatically.
4. Connect/select the iPhone, enable Developer Mode when iOS asks, and Run.
5. Accept the system's trust/developer prompts if shown.
6. In the app, tap the location authorization button and choose While Using the App.
7. Add the large Meteoblue Weather widget to the Home Screen and approve extending location access to the widget when iOS asks.

Apple currently documents Personal Team limits including development profiles that expire after seven days, up to 10 App IDs, up to 3 registered devices and up to 3 installed Personal Team apps per device. Rebuilding/reinstalling is therefore periodically required with a free account. This project does not require WeatherKit, Associated Domains, App Groups, push notifications or another advanced entitlement.

A paid Apple Developer Program membership is not required for the core personal-device design. It would be required for App Store distribution and may be useful later for additional entitlement-backed services.

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

The live test is opt-in locally:

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
8. fails if `Config/Secrets.xcconfig` is tracked.

CI intentionally validates compilation without needing a personal Apple ID or signing certificate.

## What iOS still controls

No implementation can force these behaviors:

- instant GPS delivery to a widget whenever the phone crosses the 20 km threshold;
- an exact WidgetKit refresh time;
- unlimited widget refreshes;
- the user's location-permission choice;
- whether the meteoblue Universal Link opens the app or web when the official app is absent or iOS/user link preferences choose the browser.

The project handles those constraints through cached positions, multi-zone weather cache, future timeline entries, stale indicators and a web-safe Universal Link fallback.

## Authoritative references checked during implementation

- meteoblue Forecast API Configurator and Free Weather API package list: https://docs.meteoblue.com/en/weather-apis/forecast-api/forecast-api-configurator
- meteoblue pictograms: https://docs.meteoblue.com/en/meteo/variables/pictograms
- meteoblue API overview/security: https://docs.meteoblue.com/en/weather-apis/forecast-api/overview
- Apple: Accessing location information in widgets: https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets
- Apple: `isAuthorizedForWidgetUpdates`: https://developer.apple.com/documentation/corelocation/cllocationmanager/isauthorizedforwidgetupdates
- Apple: Personal Team account limits: https://developer.apple.com/help/account/basics/about-your-developer-account
- Apple: iOS capability availability by membership: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- meteoblue Universal Links association: https://www.meteoblue.com/.well-known/apple-app-site-association
