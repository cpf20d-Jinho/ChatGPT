# Vendored Claude Code skills

These skill folders are copied from locally-installed Claude Code plugins
(`mattpocock-skills`, `superpowers`, `figma`, `i-have-adhd`) so they are
available in any Claude Code session that clones this repo — including
Claude Code web/cloud sessions (claude.ai/code), which do not install
plugins/marketplaces from `~/.claude/settings.json` or the repo's
`enabledPlugins`.

Source plugin versions at time of copy:
- mattpocock-skills 1.2.3
- superpowers 6.4.1
- figma 2.2.120
- i-have-adhd 0.3.0

Note: the `figma-*` skills describe workflows that call the `use_figma`
MCP tool (from the `FigmaEdit`/Figma MCP server). That MCP server itself
is not vendored here and isn't available in cloud sessions, so those
skills' instructions won't be actionable there — they're included for
completeness/reference only.

To refresh after updating a plugin locally, re-copy its `skills/*`
subfolders here and commit.
