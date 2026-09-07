# ABAProgress — Codex Project Instructions

## Product scope
ABAProgress is an offline-first Universal iOS/iPadOS application for ABA therapists who collect trial data in real time and later review, correct, graph, and report those records. Target iOS/iPadOS 17+.

## Technical baseline
- SwiftUI
- SwiftData
- Swift Charts
- Universal iPhone + iPad layout
- Xcode project: `XcodeProject/ABAProgress.xcodeproj`
- Swift Playgrounds project: `ABAProgress.swiftpm`
- Do not replace native SwiftUI patterns with web views.

## Clinical/data hierarchy — preserve
`Child -> Program -> Level -> Target -> TherapySession -> Trial`

### Trial semantics
- Default/unused state: `NA`
- Tap cycle: `NA -> + -> - -> NA`
- `+` = independent/correct response
- `-` = prompted response
- `NA` = not recorded/not attempted; exclude from accuracy denominator
- Maximum 10 trials per target/session
- Long press resets a trial to `NA`
- Bulk `+ / - / NA` actions require overwrite protection
- Trial changes must persist immediately; do not rely solely on a final Save button
- Undo must never cross to a different session/date

### Level semantics
- Levels belong to Program, not Child or Target.
- Programs start with L1 and can progress L2, L3, ... automatically.
- Default mastery criterion: all active targets in the level >= 80% on 2 consecutive *recorded treatment dates*.
- The required consecutive-date count is configurable (2 or more).
- Calendar gaps with no therapy are ignored; do not insert empty dates into mastery calculations.
- A mastery date counts only if all relevant active targets have valid data that day.
- When a level completes, mark its targets mastered as appropriate and create the next level.
- Historical edits that invalidate a previously completed level must NOT silently delete/rollback later levels. Show a review/recalculation warning and require deliberate user action.

## Daily record and calendar behavior
- Data entry is program/target-centric during therapy.
- Historical review is date-centric.
- Calendar date -> children recorded that date -> programs -> targets -> open the SAME trial editor used for live entry.
- `sessionDate` is the clinical date; `createdAt`/`updatedAt` are audit timestamps.
- Empty sessions must not make a calendar date appear as a treatment date.
- A memo-only session may be retained if explicitly meaningful.
- Future treatment dates must not be accepted by default.

## Graph rules
- User wants no blank/non-treatment dates in progress graphs.
- Plot only actual recorded sessions, using session sequence/category index for equal horizontal spacing.
- Display actual treatment dates as labels/tooltips.
- Accuracy axis is 0–100%.
- Show mastery criterion and Level transitions where useful.

## Reports
- Only custom date ranges. No weekly/monthly report modes.
- Report combines period statistics + progress graphs + therapist/supervisor narrative.
- Therapist and supervisor may be the same person; do not add unnecessary role friction in the single-user MVP.
- Historical treatment data may be corrected; reports derived from stale data should show a refresh/review warning rather than silently changing finalized narrative.
- Planned export architecture: one structured ReportData -> PDF / XLSX / HWPX mappers.
- User will supply exact XLSX/HWP(X) templates later. Keep export mapping/template layer decoupled from report calculation.

## UX priorities
1. Fast, low-attention real-time data collection during therapy.
2. Large, forgiving touch targets and clear + / - / NA state.
3. Minimal taps from child -> program -> active target -> trial entry.
4. No data loss if app backgrounds, device locks, or user navigates away.
5. iPhone compact layout and iPad split-view layout must both remain usable.
6. Use native Apple patterns (`NavigationStack`, `NavigationSplitView`, `List`, `Button`, `confirmationDialog`, SF Symbols).
7. Respect Dynamic Type and VoiceOver. Never encode state by color alone.
8. Avoid unnecessary cards, fixed widths, and fragile geometry assumptions.

## Runtime validation with Build iOS Apps / XcodeBuildMCP
When an iOS runtime tool is available, do not stop at compilation. Perform interaction-driven validation on at least:
- compact iPhone simulator (smallest available modern iPhone)
- standard iPhone simulator
- 11-inch-class iPad simulator
- large iPad simulator when available

Exercise these flows:
1. Add child -> program -> L1 target -> 10-trial session.
2. Rapidly tap trial buttons and verify `NA -> + -> -` plus Undo and long-press reset.
3. Background/foreground or navigate away/back; verify persisted state.
4. Complete with remaining NA values and verify warning behavior.
5. Create intermittent-date sessions and verify equal-spacing graph.
6. Meet 80% mastery over configured consecutive recorded dates and verify L2 creation.
7. Calendar -> date -> child -> target -> edit historical trials.
8. Modify historical data so a completed level would no longer qualify; verify warning without destructive auto-rollback.
9. Generate report over a custom range and verify only completed/eligible sessions are counted.
10. Check portrait/landscape, Dynamic Type, clipping, alignment, and scroll/tap reachability.

Capture screenshots for obvious layout issues and fix/retest them before declaring success.

## Quality gates
Before each handoff:
- Build with current available Apple SDK when possible.
- Run existing `QA/scenario_tests.swift` pure-Swift checks.
- Keep stable `ForEach` identities; never use mutable/positional identity for dynamic data.
- Keep business rules out of large SwiftUI view bodies; use services/models so logic remains independently testable.
- Do not silently change clinical semantics. If a requested change is ambiguous, preserve existing data behavior and document the assumption.

## Version/history rules
The user explicitly requires non-overlapping build history.
- Never overwrite a previous release artifact.
- Every release uses semantic version + build timestamp + short SHA.
- Update `VERSION.txt`, `CHANGELOG.md`, `BUILD_INFO.json`, and `SHA256SUMS.txt`.
- Prefer Git commits for every meaningful change; tag stable handoffs.
