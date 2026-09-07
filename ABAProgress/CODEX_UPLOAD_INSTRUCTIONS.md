# Moving this project into Codex

ChatGPT cannot directly place files into a separate Codex workspace from this conversation. This bundle is prepared so the transfer is one upload/repository import rather than a manual reconstruction.

## Option A — fastest: upload the ZIP to Codex
1. Download the Codex handoff ZIP from this ChatGPT conversation.
2. In Codex, create/open a coding workspace that supports uploaded project files.
3. Upload the ZIP and extract/open the project root.
4. Enable the **Build iOS Apps** plugin if your Codex environment has macOS/Xcode access.
5. Tell Codex: `Read AGENTS.md and CODEX_START_HERE.md first, then continue from the existing project. Do not recreate it from scratch.`
6. Use `XcodeProject/ABAProgress.xcodeproj` as the primary runtime project.

## Option B — best for ongoing development: Git repository
This handoff already contains a `.git` repository and a tagged baseline. Put the entire folder into a private Git remote, then open that repository from Codex. This preserves diffs, commit history, tags, and SHA-based release management.

## First Codex instruction
`Read AGENTS.md, CODEX_START_HERE.md, SCENARIO_VALIDATION.md, CHANGELOG.md, and BUILD_INFO.json. Build XcodeProject/ABAProgress.xcodeproj with Build iOS Apps, run the prescribed iPhone/iPad runtime scenarios, fix issues, retest, then create the next non-overwriting versioned release with timestamp and Git SHA.`
