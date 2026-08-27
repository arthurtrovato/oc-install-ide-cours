# Apple Watch rectangular complication

The watch target implements WidgetKit's full-width rectangular family (`accessoryRectangular`). This is the modern WidgetKit complication intended for the large rectangular/central slot on compatible Apple Watch faces. The exact rendered dimensions are controlled by watchOS and the selected face, so the view uses `GeometryReader`, scalable type and five equal-width forecast columns rather than assuming one fixed pixel size.

Apple documents accessory widgets as the mechanism for watchOS complications, and confirms that watch complications can perform network requests and access location when the containing app/widget has the required permission.

## Layout and abbreviations

The complication shows, in one glance:

- current temperature;
- today's maximum and minimum using `↑` and `↓`;
- total precipitation for today plus a compact timing label;
- five hourly columns with hour, weather symbol, temperature, and precipitation millimeters when non-zero.

The top line is kept intentionally short. A typical result is `17° ↑22° ↓11°  💧2,4mm 8–10h`. Each hourly column then uses four compact rows such as `17h / ☔ / 16° / 0,6mm`. The view scales its font down automatically on the smaller rectangular region and keeps all five hours visible.

Precipitation timing is shared with the iPhone widget. One or two forecast hours use exact ranges such as `8–10h` or `8–9/17–18h`. Longer periods collapse to these French labels:

- `d.mat.` = début de matinée;
- `mat.` = matinée;
- `f.mat.` = fin de matinée;
- `d.ap.` = début d’après-midi;
- `ap.m.` = après-midi;
- `f.ap.` = fin d’après-midi;
- `soir` = soirée;
- `nuit` = nuit;
- `tte j.` = toute la journée.

The same timing label is now displayed under the daily precipitation amount in each iPhone five-day row, and beside today's precipitation total in the iPhone current summary.

## Data source and refresh

Weather values still come only from Meteoblue. The watch complication directly uses the same `basic-1h_basic-day` API combination, the same 75-minute cache policy and the same 20 km weather-zone movement threshold as the iPhone widget. This avoids requiring the iPhone to be awake merely for the complication to refresh.

The Watch app asks for location permission once. The complication declares `NSWidgetWantsLocation`; WidgetKit decides when the complication is considered in use and when timeline refreshes occur, so exact GPS/refresh timing remains system-controlled.

## Free installation

The existing SideStore path remains the easiest zero-cost route for the iPhone app. SideStore's official documentation targets iOS/iPadOS devices and does not document installation of custom watchOS companion apps or complications, so the watch target is deliberately a separate **watch-only** app and is not embedded into the SideStore IPA.

The zero-cost watch installation path is therefore Xcode Personal Team on the Mac:

1. Create `Config/Secrets.xcconfig` from `Config/Secrets.example.xcconfig` and put the Meteoblue API key in it.
2. Run `xcodegen generate` and open `MeteoblueWeather.xcodeproj`.
3. Select the `MeteoblueWatch` target and your free Personal Team under Signing & Capabilities.
4. Select the paired Apple Watch as the run destination and run the `MeteoblueWatch` scheme.
5. Open Meteoblue once on the Watch and authorize location.
6. Edit the watch face and choose **Meteoblue 5 h** for the rectangular central complication.

A free Personal Team profile normally expires after seven days, so the watch app has to be rebuilt/reinstalled periodically. This limitation comes from Apple's free provisioning rather than the complication code.

## References

- Apple WidgetKit: https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications
- Apple WidgetKit strategy (network/location support table): https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy
- Apple location-enabled widgets: https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets
- SideStore installation scope: https://docs.sidestore.io/docs/installation/install
