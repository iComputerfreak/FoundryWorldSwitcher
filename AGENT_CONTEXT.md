# Foundry World Switcher Context

## Purpose

Swift Discord bot with one global Foundry/Pterodactyl target. Dungeon Masters book Foundry VTT worlds for D&D sessions or preparation. On a booking date, the bot selects the booked Foundry world in Pterodactyl, restarts Foundry, locks manual world switching for the booking interval, and sends configured session reminders.

## Architecture

- Swift Package executable target: `FoundryWorldSwitcher`.
- Discord integration: DiscordBM gateway, slash-command registration, `DiscordCache` for guild/member data.
- DiscordBM currently uses `nreilly/DiscordBM` branch `components-v2-payloads` for date-poll checkbox modals. Keep this fork until upstream PR #111 merges; use DiscordBM APIs only.
- Foundry integration: Pterodactyl Client API. Worlds come from `/data/Data/worlds/<id>/world.json`; current world comes from the `WORLD_NAME` startup variable.
- External dependencies: DiscordBM and HTML2Markdown. No database or web server.
- `main.swift` initializes persistent services, Discord gateway/cache, command registration, Pterodactyl world cache, then dispatches gateway events. Scheduler updates run after each gateway event; Discord heartbeats normally provide the polling cadence.

## Commands And Authorization

- Command registry: `DiscordCommands.commands`. Registration bulk-replaces application commands on bot startup.
- Permission levels: `user`, `dungeonMaster`, `admin`. User and role mappings persist in `permissions.json`; highest assigned level wins.
- Application owners receive runtime-only admin from `Permissions`; their IDs never enter guild `permissions.json` mappings.
- Date-poll role snapshots require Guild Members intent enabled in code and Discord Developer Portal.
- User commands: help, health check, permission lookup, world info, bookings, session log.
- Dungeon Master commands: list/restart/switch worlds; create, cancel, or reschedule bookings; read lock state.
- Admin commands: permission management, config, cache refresh, lock management, booking deletion, pin management, scheduler queue inspection. Forced world switch requires admin.
- Guild-scoped routing is still being integrated. Do not retain the single-guild startup guard when wiring `GuildRegistry`.

## Booking Lifecycle

- `Booking` has `EventBooking` and `ReservationBooking` variants. Only one booking may exist per local calendar date, including cancelled bookings.
- `/book event` parses dates as `dd.MM.yyyy` and times as `HH:mm`; it stores campaign role, voice channel, topic, and world ID. `/book reservation` stores a date and world ID for preparation.
- Each booking creates persisted scheduler events: switch and lock at booking interval start, then unlock at interval end. Event bookings also queue configured reminders.
- Booking interval start is seconds from local midnight. Interval end is a duration from interval start, not seconds from midnight. Defaults: 06:00 start, 23 hours duration, therefore 05:00 next day.
- `sessionLength` controls displayed session metadata; it does not control world-lock interval.
- `BookingsService` persists changes and asynchronously refreshes registered booking messages. Completed and cancelled bookings remain for session history. World-lock interval dates snapshot at creation; legacy records initialize from their queued lock/unlock events or config once at load.

## Scheduling And Locking

- `Scheduler` persists `events.json`. Due events execute ordered by due date; successful events are removed after execution.
- Scheduler events perform world switching, lock/unlock, Discord reminders, and poll deadlines. A 30-second background task runs updates while gateway idle; gateway events also trigger updates.
- Global lock state is `data/world-lock.json`, containing optional guild and booking ownership plus acquisition time. Scheduled booking unlocks only release their own lock; manual locks have no booking owner. Manual switches acquire a process-global operation slot before lookup or Pterodactyl changes; scheduled locks cannot enter until it releases.
- Scheduled locks persist their booking ownership before changing `WORLD_NAME`; Pterodactyl failure releases that same lock.
- Manual `/switchworld` rejects locked state unless `force:true` is used by the bot application owner. Forced switches preserve existing booking-owned locks. Full `/unlockworld` is application-owner-only.
- Rescheduling reserves the replacement interval before replacing the booking, preserves its ID, and regenerates its queued events.

## Persistent Runtime State

Runtime data directory: executable sibling `data/`; Docker mounts it at `/home/container/data`.

- Version 3.0 performs a one-time root-to-guild migration before `BotConfig.shared` can read or create `botConfig.json`. It runs only when `data/guilds/` does not exist, root `botConfig.json` already exists, and Discord reports exactly one bot guild. Migration builds and verifies state in `data/.v3-migration-staging/`, verifies backups in `data/migration-backups/v3/`, safely writes global output, then atomically moves staged guild state to `data/guilds/`. Incomplete staging restores root global output and is removed for retry. `data/guilds/` is the completion indicator; no marker exists.
- Root `botConfig.json` and root secrets retain global Pterodactyl target configuration. Runtime services have no legacy root-state fallback.
- Guild state belongs in `data/guilds/<guild-id>/`: `config.json`, `permissions.json`, `bookings.json`, `events.json`, and `date_polls.json`.
- Root `booking_conflicts.json` indexes active booking intervals across guilds because the Foundry target and world lock are global. Startup prunes records for guilds the bot no longer belongs to before loading current guild contexts.
- `GuildContext` owns per-guild config, permissions, scheduler, bookings, and polls. Obtain contexts through `GuildRegistry`; do not add guild-local singletons.
- `GuildRegistry` supplies the process-scoped application owner ID to each context's `Permissions`. `Permissions.isApplicationOwner(_:)` authorizes forced world switching and owner admin access is never persisted.
- `world-lock.json`: global manual-switch block record. V3 migration converts legacy `.worldlock` to a manual record before archiving it.
- `BOT_TOKEN` and `PTERODACTYL_API_KEY`: optional file-based secrets in runtime data dir.

All state uses direct JSON writes. No atomic-write, corruption recovery, schema migration framework, or multi-process coordination exists. Do not commit runtime state or secrets.

Guild state types live one-per-file under `Sources/Services/Guild State/`. Document state types and their persisted properties with `///`; retain source headers and meaningful comments during refactors.

## Configuration And Secrets

- Required config: `pterodactylHost` and `pterodactylServerID`. Startup logs errors when absent but continues until API use.
- Reminder config: `sessionReminderTime`, `shouldNotifyAtSessionStart`, `sessionStartReminderTime`, and `reminderChannel`. `/config set reminderChannel` fetches the channel and accepts only one owned by the invoking guild.
- Secrets prefer runtime data files, then environment variables: `FOUNDRY_BOT_TOKEN` and `FOUNDRY_PTERODACTYL_TOKEN`.
- Runtime timezone controls parsed dates, booking intervals, and scheduled messages. Set `TZ` explicitly in Docker/Pterodactyl.

## Pterodactyl And Foundry Contract

- Bot needs Pterodactyl Client API permissions: power start/stop/restart, file read/read-content, startup read/update.
- Foundry Pterodactyl egg must expose `WORLD_NAME` and apply it to Foundry's startup world setting. Egg variants live in `pterodactyl_eggs/foundry_vtt`.
- Pterodactyl client cache lasts 24 hours. Use admin `/updatecache` after adding, removing, or editing Foundry worlds.
- `changeWorld(to:restart:)` updates `WORLD_NAME`, then restarts when requested. Manual switching currently calls stop, `changeWorld(..., restart: true)`, then start; verify desired panel power semantics before changing this sequence.

## Deployment And Development

- Build locally: `swift build`; run with `swift run` after supplying runtime secrets/config.
- Dockerfile uses Swift 6 Jammy multi-stage build, runs non-root `container`, and expects `/home/container/data` to persist.
- GitHub workflow builds and pushes Docker Hub image for every tag. It does not run tests, linting, or security scans.
- Pterodactyl bot egg installs/releases bot separately. Validate egg install commands after changing package/build behavior.
- No `Tests` target exists. For behavior changes, at minimum build, test command registration in a non-production guild, test Pterodactyl API against a safe server, and verify persisted data across restart.

## Documentation Drift And Open Work

- Date polls use checkbox modals for voting/finalization, a Components V2 shared message, JSON-backed role voter rosters refreshed on vote, scheduler-backed per-user reminders, and short IDs. Components V2 is permanent per Discord message and forbids embeds/content. Poll owners/admins can manage any owned/all polls; other Dungeon Masters must hold campaign role. See `docs/DATE_POLL_SPEC.md` for runtime behavior and command contract.
- README names `/reschedulebooking`; registered command is `/rescheduleevent`.
- README says Discord scheduled event creation is planned; `createServerEvent` exists but no command uses it.
- Pterodactyl egg token variables may be user-viewable. Treat panel configuration and generated secret files as sensitive.
- Failed scheduler events remain queued for retry; other due events continue executing.

Update this document when these contracts or hazards change.
