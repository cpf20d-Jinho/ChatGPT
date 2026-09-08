# ABA — Rose Progress

Status: original vector source and flat fallback only. Icon Composer has NOT been run; no verified .icon document is supplied. Do not rename this folder to .icon.

## Composition

1024 × 1024 square canvas, no baked system corner mask. Pink gradient (#F6ACC9 → #E66CA2 → #C62D76), warm-white ABA wordmark, three small ascending marks suggesting progress. Letterforms are original vector paths, not embedded font files or copied SF Symbols. No puzzle-piece or clinical outcome claim.

## Finish in Icon Composer on a Mac

1. Create an iOS/iPadOS document, set the canvas gradient above directly in Composer.
2. Import 01-ABA.svg, then 02-Progress.svg. Both retain the same 1024 canvas and alignment. Use one foreground group initially.
3. Start with subtle glass depth and high opacity for ABA readability. Add effects in Composer, not baked shadows in the source assets.
4. Inspect Default, Dark, Mono and their clear/tinted previews. For Dark, try a deep berry canvas (#39152A → #79224D) and pale pink letters. For Mono, preserve strong foreground/background separation. These are starting suggestions, NOT tested Composer settings.
5. Check at 40, 60, 120 and 1024 pixels and on the device home screen. Keep the three progress marks subordinate to ABA.
6. Save as AppIcon.icon and add to the Xcode app target; select it as App Icon. Retest deployment to the minimum supported OS. Keep the PNG fallback until compatibility is confirmed.

Preview.svg and the asset-catalog PNG are flat vector renders, NOT native Liquid Glass previews. The SVG sources intentionally contain no baked glass reflections, blur, or outer corner mask.

## Apple references

- https://developer.apple.com/icon-composer/
- https://developer.apple.com/videos/play/wwdc2025/361/
- https://developer.apple.com/design/resources/
- https://developer.apple.com/design/human-interface-guidelines/app-icons
