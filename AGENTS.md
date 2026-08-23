## Agent Memory

Keep this file up to date. If you learn a new repo convention, workflow detail, safety rule, architecture decision, or recurring preference that would help future agents, update `AGENTS.md` directly without waiting for an explicit user request or asking for approval.

Mention the update briefly in a plan when already writing one. Otherwise, make the update as part of the current work and note it in the final summary.

## Project Context

Read `AGENT_CONTEXT.md` before non-trivial work for architecture, runtime contracts, deployment details, and known hazards. Keep it current when behavior, persistence, external integrations, deployment, or verification guidance changes.

## Implementation Principles

Respect the existing architecture, code quality, documentation standard, and established patterns. Keep code maintainable and human-readable. Prefer the lightest implementation that correctly meets the requirement.
Use DiscordBM for Discord API communication. Do not make manual Discord REST requests.

## Verification

Do not add tests. This project does not use them. Verify changes with appropriate builds and manual checks.
After code modifications, use Xcode MCP to build the project instead of `swift build`. Fix build failures and rebuild until successful so the latest executable is ready for manual testing.
