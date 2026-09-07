# Codex Start Here

This folder is a complete handoff of ABAProgress v0.6.0.

## First task
Use the **Build iOS Apps** plugin / Xcode runtime if available and bring this project to a reproducibly runnable state on iPhone and iPad simulators.

### Open
`XcodeProject/ABAProgress.xcodeproj`

### Validate first — do not redesign blindly
1. Build the `ABAProgress` scheme for an iPhone simulator.
2. Resolve all compiler/runtime issues.
3. Run the app and perform the end-to-end scenarios in `AGENTS.md` and `SCENARIO_VALIDATION.md`.
4. Repeat layout checks on iPad.
5. Fix interaction/layout/data-integrity issues and retest.
6. Preserve all existing clinical behavior unless the change is explicitly documented.

## UX objective
The therapist must be able to record responses while attending to the child, not the screen. Optimize for fast, error-resistant input, immediate persistence, and easy historical correction.

## Important existing requirements
- Universal iPhone + iPad app
- `Child -> Program -> Level -> Target -> Session -> Trial`
- Trial tap cycle `NA -> + -> - -> NA`; long press -> NA
- Level is Program-owned; default mastery is every target >=80% on 2 consecutive recorded treatment dates, configurable to >=2 dates
- Intermittent treatment dates are plotted without empty date slots
- Calendar allows date -> child -> historical session edit using the same editor
- Reports use custom date ranges only
- Export architecture must remain ready for PDF/XLSX/HWPX template mapping

## Before producing a new package
Read `AGENTS.md`, `SCENARIO_VALIDATION.md`, `CHANGELOG.md`, and `BUILD_INFO.json`. Commit changes and create a new non-overwriting release with version/timestamp/SHA.
