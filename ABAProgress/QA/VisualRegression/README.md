# UI visual regression baseline

The `before-v0.10.0` directory preserves the unmodified screenshots from GitHub Actions run `34471212046` before the v0.11 UX correction patch.

Each device has the same five scenarios:

- `controls`: report date and program controls
- `help`: the program-selection help presentation
- `narratives`: long-form report fields
- `landscape`: the same report after rotation
- `consent`: web-edit consent before opt-in

Device prefixes are `iphone-se-ax` (Accessibility Large), `iphone-17`, `ipad-11`, and `ipad-13`. Files in a later `after-*` directory must come from the matching UI test names and device configuration; do not manually recreate or retouch them.

The SwiftUI layout uses shared, invisible form tracks through `ABAAlignedField`: a label axis and a content axis on regular layouts, folded onto one leading axis on compact or accessibility layouts. No guide line is rendered to users.
