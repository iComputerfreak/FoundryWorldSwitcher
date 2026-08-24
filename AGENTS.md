## Agent Memory

Keep this file up to date. If you learn a new repo convention, workflow detail, safety rule, architecture decision, or recurring preference that would help future agents, update `AGENTS.md` directly without waiting for an explicit user request or asking for approval.

Mention the update briefly in a plan when already writing one. Otherwise, make the update as part of the current work and note it in the final summary.

## Project Context

Read `AGENT_CONTEXT.md` before non-trivial work for architecture, runtime contracts, deployment details, and known hazards. Keep it current when behavior, persistence, external integrations, deployment, or verification guidance changes.

## Implementation Principles

Respect the existing architecture, code quality, documentation standard, and established patterns. Keep code maintainable and human-readable. Prefer the lightest implementation that correctly meets the requirement.
Use DiscordBM for Discord API communication. Do not make manual Discord REST requests.

## Guild State

Guild-local state uses `GuildContext` from `GuildRegistry` and persists below `data/guilds/<guild-id>/`. Pterodactyl target, world lock, and booking conflicts are global. Guild state initialization must fail on corrupt state or inaccessible storage; never replace persisted state with in-memory defaults. Keep guild-local services instance-scoped; never add a singleton for them.
V3 root-state migration stays entirely in `V3StateMigration`. It runs only before `BotConfig.shared` reads root config, only when `data/guilds/` is absent, root `data/botConfig.json` exists, and Discord reports exactly one guild. Build and verify migration state under `data/.v3-migration-staging/`; migrate legacy split `event_bookings.json` and `reservation_bookings.json` when consolidated `bookings.json` is absent; write verified backups and global output before atomically moving staged guild state to `data/guilds/`. Incomplete staging restores source global output for retry; failed restoration retains staging and backup artifacts. The guild directory indicates migration completion; no marker exists. Do not add legacy root-state runtime fallbacks.
Keep `Sources/Services/Guild State/` one-type-per-file. Document moved state types and persisted properties with `///`; retain source headers and meaningful existing comments when refactoring.

## Verification

Do not add tests. This project does not use them. Verify changes with appropriate builds and manual checks.
After code modifications, use Xcode MCP to build the project instead of `swift build`. Fix build failures and rebuild until successful so the latest executable is ready for manual testing.
