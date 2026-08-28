#!/usr/bin/env python3
import pathlib
import plistlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: validate_watch_bundle.py /path/to/MeteoblueWatch.app")

app = pathlib.Path(sys.argv[1])
if not app.is_dir():
    raise SystemExit(f"Watch app bundle not found: {app}")

app_plist = app / "Info.plist"
widget_plist = app / "PlugIns/MeteoblueWatchWidgetExtension.appex/Info.plist"
if not widget_plist.is_file():
    raise SystemExit("Watch widget/complication extension is missing from the Watch app bundle")

with app_plist.open("rb") as handle:
    app_info = plistlib.load(handle)
with widget_plist.open("rb") as handle:
    widget_info = plistlib.load(handle)

checks = [
    (app_info.get("CFBundleIdentifier"), "com.arthurtrovato.MeteoblueWidget.watchkitapp", "Watch app bundle id"),
    (widget_info.get("CFBundleIdentifier"), "com.arthurtrovato.MeteoblueWidget.watchkitapp.Widget", "Watch widget bundle id"),
    (app_info.get("WKApplication"), True, "WKApplication"),
    (app_info.get("WKRunsIndependentlyOfCompanionApp"), True, "WKRunsIndependentlyOfCompanionApp"),
    (app_info.get("WKCompanionAppBundleIdentifier"), "com.arthurtrovato.MeteoblueWidget", "WKCompanionAppBundleIdentifier"),
    (widget_info.get("NSExtension", {}).get("NSExtensionPointIdentifier"), "com.apple.widgetkit-extension", "Watch widget extension point"),
    (widget_info.get("NSWidgetWantsLocation"), True, "NSWidgetWantsLocation"),
]

for actual, expected, label in checks:
    if actual != expected:
        raise SystemExit(f"{label} mismatch: {actual!r} != {expected!r}")

for key in ("CFBundleShortVersionString", "CFBundleVersion"):
    if not app_info.get(key) or app_info.get(key) != widget_info.get(key):
        raise SystemExit(
            f"Watch app/widget {key} mismatch: app={app_info.get(key)!r}, widget={widget_info.get(key)!r}"
        )

nested_apps = list(app.rglob("*.app"))
if nested_apps:
    raise SystemExit(f"Unexpected nested app bundle inside independent Watch app: {nested_apps}")

print(
    "Validated independent Watch bundle: "
    f"{app_info['CFBundleIdentifier']} {app_info['CFBundleShortVersionString']} "
    f"({app_info['CFBundleVersion']}) + rectangular WidgetKit extension"
)
