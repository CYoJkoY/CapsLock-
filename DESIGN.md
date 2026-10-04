# CapsLock- · Wabi-Press 侘寂刊本

## Visual thesis

CapsLock- is a keyboard instrument, not a dashboard. Its UI is treated as a
small editorial publication: warm washi or inkstone surfaces, pine-soot text,
quiet chapter rules, and cinnabar seals for actions that deserve attention.
The design language is adapted from the AzSkills `design-system` skill and is
implemented natively through `UI/Theme.ahk` and `UI/ThemeHelper.ahk`.

## Primitive tokens

- Canvas: `#F5F3EC` (light) / `#131416` (dark)
- Surface: `#FAF9F5` / `#1B1C20`
- Overlay: `#ECE8DC` / `#25272D`
- Primary / cinnabar: `#A6382A` / `#C84A3B`
- Secondary / moss: `#3B5848` / `#537B65`
- Text: pine-soot `#1C1A17` / warm paper ink `#EDEAE2`
- Geometry: 8 px rhythm, 1 px hairlines, 2 px hand-cut corners
- Elevation: hairlines and tone steps only; no heavy shadows
- Type: Segoe UI for controls, Source Han Serif SC where available for titles,
  Cascadia Mono for technical metadata

## Component rules

All windows call the shared theme helper. Buttons use cinnabar for primary
actions and moss for safe/secondary actions. Inputs and lists use a framed
paper/ink surface. Focus and active states use an ink hairline rather than a
glow, transform, or bounce. Status marks are publication glyphs rather than
emoji so they remain stable across Windows font and DPI configurations.

The persistent pin indicator is a click-through publication mark (`✦`) and is
not part of the target window's content. It is rebuilt on `WM_SIZE` restore as
well as on the timer path, covering both hotkey and mouse minimize flows.

## Verification contract

- [x] One semantic palette shared by every AHK GUI surface
- [x] Light and dark spectra avoid pure black and pure white
- [x] Titles, controls, lists, overlays, tray settings, history, switcher and
      pin/OSD surfaces consume the same tokens
- [x] Minimize/restore is tested through both CapsLock+S and native mouse flow
- [x] Motion is optional; state remains understandable without animation
