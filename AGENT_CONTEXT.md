# Foundry World Switcher Context

## Purpose

Swift Discord bot for one Discord guild. Dungeon Masters book Foundry VTT worlds for D&D sessions or preparation. On a booking date, the bot selects the booked Foundry world in Pterodactyl, restarts Foundry, locks manual world switching for the booking interval, and sends configured session reminders.

## Architecture

- Swift Package executable target: `FoundryWorldSwitcher`.
- Discord integration: DiscordBM gateway, slash-command registration, `DiscordCache` for guild/member data.
- Foundry integration: Pterodactyl Client API. Worlds come from `/data/Data/worlds/<id>/world.json`; current world comes from the `WORLD_NAME` startup variable.
- External dependencies: DiscordBM and HTML2Markdown. No database or web server.
- `main.swift` initializes persistent services, Discord gateway/cache, command registration, Pterodactyl world cache, then dispatches gateway events. Scheduler updates run after each gateway event; Discord heartbeats normally provide the polling cadence.

## Commands And Authorization

- Command registry: `DiscordCommands.commands`. Registration bulk-replaces application commands on bot startup.
- Permission levels: `user`, `dungeonMaster`, `admin`. User and role mappings persist in `permissions.json`; highest assigned level wins.
- Bot application owner receives admin on startup when Discord returns an owner.
- User commands: help, health check, permission lookup, world info, bookings, session log.
- Dungeon Master commands: list/restart/switch worlds; create, cancel, or reschedule bookings; read lock state.
- Admin commands: permission management, config, cache refresh, lock management, booking deletion, pin management, scheduler queue inspection. Forced world switch requires admin.
- Bot is designed for at most one guild. Startup disconnects and fatally exits if it belongs to more than one guild.

## Booking Lifecycle

- `Booking` has `EventBooking` and `ReservationBooking` variants. Only one booking may exist per local calendar date, including cancelled bookings.
- `/book event` parses dates as `dd.MM.yyyy` and times as `HH:mm`; it stores campaign role, voice channel, topic, and world ID. `/book reservation` stores a date and world ID for preparation.
- Each booking creates persisted scheduler events: switch and lock at booking interval start, then unlock at interval end. Event bookings also queue configured reminders.
- Booking interval start is seconds from local midnight. Interval end is a duration from interval start, not seconds from midnight. Defaults: 06:00 start, 23 hours duration, therefore 05:00 next day.
- `sessionLength` controls displayed session metadata; it does not control world-lock interval.
- `BookingsService` persists changes and asynchronously refreshes registered booking messages. Completed and cancelled bookings remain for session history.

## Scheduling And Locking

- `Scheduler` persists `events.json`. Due events execute ordered by due date; successful events are removed after execution.
- Scheduler events perform world switching, lock/unlock, and Discord reminders. The scheduler has no independent timer: disconnected/inactive gateway activity delays due work.
- Lock state is only `data/.worldlock`. It records no world, booking, owner, or expiry. Timed unlocks can therefore release a manually created or newer lock.
- `lockWorldSwitching` first changes `WORLD_NAME` and restarts Foundry, then creates lock marker.
- Manual `/switchworld` rejects locked state unless `force:true` is used by admin. Current implementation does not clear lock after forced switch despite README claim.
- Rescheduling changes booking date but currently retains its original `associatedEvents`; recreate or update queue when fixing this behavior.

## Persistent Runtime State

Runtime data directory: executable sibling `data/`; Docker mounts it at `/home/container/data`.

- `botConfig.json`: Pterodactyl connection, booking/reminder settings, pinned-message references.
- `permissions.json`: user and role permission levels.
- `bookings.json`: booking history and associated scheduler event IDs. Legacy `reservation_bookings.json` and `event_bookings.json` migrate when both exist.
- `events.json`: scheduler queue.
- `.worldlock`: manual-switch block marker.
- `BOT_TOKEN` and `PTERODACTYL_API_KEY`: optional file-based secrets in runtime data dir.

All state uses direct JSON writes. No atomic-write, corruption recovery, schema migration framework, or multi-process coordination exists. Do not commit runtime state or secrets.

## Configuration And Secrets

- Required config: `pterodactylHost` and `pterodactylServerID`. Startup logs errors when absent but continues until API use.
- Reminder config: `sessionReminderTime`, `shouldNotifyAtSessionStart`, `sessionStartReminderTime`, and `reminderChannel`.
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

- README names `/reschedulebooking`; registered command is `/rescheduleevent`.
- README says forced switch unlocks world switching; implementation does not.
- README says Discord scheduled event creation is planned; `createServerEvent` exists but no command uses it.
- Pterodactyl egg token variables may be user-viewable. Treat panel configuration and generated secret files as sensitive.
- A failed earliest due scheduler event throws before later due events execute, potentially blocking them until retry succeeds.

Update this document when these contracts or hazards change.
