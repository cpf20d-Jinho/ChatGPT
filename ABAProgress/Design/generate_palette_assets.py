"""Write matching Xcode and Swift Playgrounds sRGB color assets."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = (
    ROOT / "XcodeProject/ABAProgress/Assets.xcassets",
    ROOT / "ABAProgress.swiftpm/Sources/AppModule/Assets.xcassets",
)

# Each tuple: default light, default dark, increased-contrast light/dark.
# The three original colors are the default-light Palette* source colors.
TOKENS = {
    # Dark ochre keeps native tinted text and controls legible on ivory.
    "AccentColor": ("#795900", "#FDDE6A", "#624600", "#FFEC91"),
    "PaletteIvory": ("#F9F1DC", "#1D241D", "#FFF9EC", "#111811"),
    "PaletteButterYellow": ("#FDDE6A", "#E8C85A", "#E5BA32", "#FFEC91"),
    "PaletteLeafGreen": ("#758756", "#AFC38D", "#52643B", "#D2E6AA"),
    "PaletteSurface": ("#FFFCF4", "#273026", "#FFFDF7", "#1A2418"),
    "PaletteRaised": ("#F3E7BE", "#35412F", "#FDE8A5", "#495D3D"),
}


def entry(hex_color: str, appearances: list[dict[str, str]]) -> dict:
    rgb = [int(hex_color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    result = {
        "color": {
            "color-space": "srgb",
            "components": dict(zip(("red", "green", "blue", "alpha"),
                                   (f"{rgb[0]:.6f}", f"{rgb[1]:.6f}", f"{rgb[2]:.6f}", "1.000000"))),
        },
        "idiom": "universal",
    }
    if appearances:
        result["appearances"] = appearances
    return result


for catalog in CATALOGS:
    for name, (light, dark, contrast_light, contrast_dark) in TOKENS.items():
        colors = [
            entry(light, []),
            entry(dark, [{"appearance": "luminosity", "value": "dark"}]),
            entry(contrast_light, [{"appearance": "contrast", "value": "high"}]),
            entry(contrast_dark, [{"appearance": "luminosity", "value": "dark"},
                                  {"appearance": "contrast", "value": "high"}]),
        ]
        destination = catalog / f"{name}.colorset"
        destination.mkdir(parents=True, exist_ok=True)
        (destination / "Contents.json").write_text(
            json.dumps({"colors": colors, "info": {"author": "xcode", "version": 1}},
                       ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
