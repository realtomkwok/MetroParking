# iPhone Duo

iPhone Duo is a foldable iPhone.
- The **outer display** behaves like a regular iPhone: compact width.
- The **open inner display** is regular width and regular height.

References:
- Apple Tech Talk: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
- The updated Human Interface Guidelines

## What changes by SDK

| Built with | Behaviour on the inner display |
|---|---|
| iOS 26 SDK | Compatibility mode: the app runs in a phone-sized area on black |
| iOS 27.0 SDK | Uses most of the display; content extends left of the status bar |
| iOS 27.1 SDK | Full edge-to-edge; standard toolbars can lay out vertically; `ReservedRegion` available |

The project builds on both Xcode 27.0 and 27.1. Code that needs the 27.1 SDK is gated two ways:

```swift
#if canImport(SwiftUICore, _version: 8.0.85)   // iOS 27.1 SDK
if #available(iOS 27.1, *) { … }               // iOS 27.1 at runtime
#endif
```

## Layout rules

- **Size class only.** The inner display ignores supported interface orientations. `ContentView` switches between the bottom sheet (compact width) and the floating panel (regular width or compact height) using size classes, never the device model or orientation.
- **Asymmetric safe areas.** Insets differ between left and right depending on pose and Split View position.
  - Pad each edge on its own.
  - The floating panel and the map's camera padding both follow this rule.
  - Never compute a width as `bounds.width - inset * 2`.
- **No `UIScreen.main`.** A device with two displays has no single main screen. Use trait collections, the window scene, or SwiftUI geometry. The codebase has no uses; keep it that way in review.
- **Respect the fold.**
  - `FloatingPanel.activeFold(in:)` reads the active `.division` reserved region.
  - When a vertical fold is active, the panel fills the leading pane up to the hinge.
  - The map gets the other pane, and no content sits on the fold.
- **State survives pose changes.** Selection, navigation and camera live in `MapSheetModel`, outside the sheet or panel. Folding or unfolding keeps the user where they were.
- **System bars can be vertical.** On iOS 27.1 the sheet's toolbar may lay out down the side. Keep toolbar items as symbols with accessibility labels, and don't assume a horizontal bar.

## Testing checklist

Use the iPhone Duo simulator with Xcode 27.1 and the DeviceHub controls.

- [ ] **Closed (outer display):** bottom sheet at each detent, pin → detail, back → zoom to all
- [ ] **Open (inner display):** floating panel fills the leading pane up to the fold; map framed on the other pane
- [ ] **Unfold with a detail open:** the same facility is still shown, now in the panel
- [ ] **Fold with a detail open:** the same facility is still shown, now in the sheet
- [ ] **Rotated inner display:** layout follows size class; nothing is hidden under the fold or camera
- [ ] **Partially folded (tabletop):** the map and panel stay usable
- [ ] **Split View with another app,** at both narrow and wide widths
- [ ] **Accessibility:** Dynamic Type accessibility sizes in the panel and sheet
- [ ] **Look & motion:** Reduce Motion, dark mode, zh-Hans/zh-HK
- [ ] **App Resizability:** run Xcode 27.1's App Resizability check

The simulator's fold poses can only be changed from DeviceHub, not from `simctl`, so these checks are manual.

## Not yet adopted

- **`.occlusion` reserved regions (camera).** The floating panel sits on the leading side, away from the camera, and the map's system controls follow the safe area. Revisit if custom controls move to the trailing edge.
