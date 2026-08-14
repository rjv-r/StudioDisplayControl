# StudioDisplayControl

A macOS menu bar app for controlling an Apple Studio Display XDR — brightness and sleep — from a Mac.

## Why this exists

The Studio Display has no public power API and doesn't speak DDC/CI, so there's no documented way for third-party software to turn it fully off or on. This app uses the same approach as tools like [BetterDisplay](https://github.com/waydabber/BetterDisplay) and [MonitorControl](https://github.com/MonitorControl/MonitorControl):

- **Brightness** is controlled via Apple's private, undocumented `DisplayServices.framework` (`DisplayServicesGetBrightness` / `DisplayServicesSetBrightness`), loaded at runtime with `dlopen`/`dlsym` so the app degrades gracefully if Apple changes or removes these symbols in a future macOS release.
- **"Off"** triggers macOS display sleep (equivalent to `pmset displaysleepnow`), which blanks the panel — the closest real equivalent to powering it off, and reversible with any key press or mouse movement.

The display is detected specifically (not just "any external display") by matching `NSScreen.localizedName` against "Studio Display". (The classic approach — vendor ID via `CGDisplayVendorNumber` plus IOKit's `IODisplayConnect` registry — is broken on Apple Silicon: the vendor API returns non-unique values and the IOKit service class is unpopulated.)

## Features

- Lives in the menu bar only — no Dock icon
- Shows connection status for the Studio Display
- Brightness slider (debounced, updates the physical display in real time)
- "Sleep Display" button
- Automatically re-detects the display on connect/disconnect

## Requirements

- macOS 13 or later
- Xcode 16 or later (to build)
- An Apple Studio Display or Studio Display XDR connected

## Building

Open `StudioDisplayControl.xcodeproj` in Xcode and run, or build from the command line:

```bash
xcodebuild -project StudioDisplayControl.xcodeproj -scheme StudioDisplayControl -configuration Debug build
```

## Caveat

Brightness control and display sleep both rely on private/undocumented APIs, same as other display-control utilities in this space. Behavior may change with future macOS updates.
