# Foundry World Switcher Context

## Purpose

Swift Discord bot with one global Foundry/Pterodactyl target. Dungeon Masters book Foundry VTT worlds for D&D sessions or preparation. On a booking date, the bot selects the booked Foundry world in Pterodactyl, restarts Foundry, locks manual world switching for the booking interval, and sends configured session reminders.

## Architecture

- Swift Package executable target: `FoundryWorldSwitcher`.
- Discord integration: DiscordBM gateway, slash-command registration, `DiscordCache` for guild/member data.
- DiscordBM currently uses `nreilly/DiscordBM` branch `components-v2-payloads` for date-poll checkbox modals. Keep this fork until upstream PR #111 merges; use DiscordBM APIs only.
- DiscordBM validates entity-select modal `default_values` against `min_values` even when no defaults exist. Discord rejects required entity selects with `min_values: 0`; unprefilled role/channel selects must use `min_values: 0` and `required: false`, then submission parsing enforces one selection.
- Foundry integration: Pterodactyl Client API. Worlds come from `/data/Data/worlds/<id>/world.json`; current world comes from the `WORLD_NAME` startup variable.
- External dependencies: DiscordBM and HTML2Markdown. No database or web server.
- `main.swift` initializes persistent services, Discord gateway/cache, command registration, Pterodactyl world cache, then dispatches gateway events. Scheduler updates run after each gateway event; Discord heartbeats normally provide the polling cadence.

## Commands And Authorization

- Command registry: `DiscordCommands.commands`. Registration bulk-replaces application commands on bot startup.
- Command/subcommand/option descriptions are user-facing runtime contracts. Keep them accurate for current form flow, date formats, permission restrictions, and Foundry-disabled behavior; Discord caps each description at 100 characters.
- Permission levels: `user`, `dungeonMaster`, `admin`. User and role mappings persist in `permissions.json`; highest assigned level wins.
- Application owners receive runtime-only admin from `Permissions`; their IDs never enter guild `permissions.json` mappings.
- Date-poll role snapshots require Guild Members intent enabled in code and Discord Developer Portal.
- `foundryFeaturesEnabled` is a guild admin config flag, defaulting to true for legacy config. Each Foundry command must explicitly set `requiresFoundryFeatures = true`; protocol default is false. When false, those commands are blocked for every user, including application owner; date polls, config, and worldless external-event booking management remain available. Global command registration means blocked commands remain visible but reject at runtime. Help renders the registered command metadata, filtering disabled Foundry commands. Date-poll message payloads require this flag explicitly; booking controls remain available for external sessions.
- Date-poll component actions use `DatePollAction` raw values. Add actions to the enum and pass enum cases to the renderer; never compare date-poll action strings. Raw values are persisted in existing Discord custom IDs, so preserve them when refactoring.
- User commands: help, health check, permission lookup, world info, bookings, session log.
- Dungeon Master commands: list/restart/switch worlds; create, cancel, or reschedule bookings; read lock state.
- Admin commands: permission management, config, cache refresh, lock management, booking deletion, pin management, scheduler queue inspection. Forced world switch requires admin.
- Guild-scoped routing is still being integrated. Do not retain the single-guild startup guard when wiring `GuildRegistry`.

## Booking Lifecycle

- `Booking` has `EventBooking` and `ReservationBooking` variants. Only one booking may exist per local calendar date, including cancelled bookings.
- `/book event` accepts `dd.MM.yyyy` with optional `HH:mm`; missing time uses guild `defaultEventBookingTime`, defaulting to 19:00. It stores campaign role, optional voice channel, topic, and optional world ID. `/book reservation` stores a date and required world ID for preparation.
- `/book event` and `/book reservation` open Components V2 modals. Event forms always put selected `No Foundry world` first, then up to 25 cached worlds; they use date/time text, optional voice-channel select, topic text, and role select. Worldless events work in Foundry-disabled guilds; Foundry-linked events and reservations do not.
- Worldless events create only session-reminder scheduler events. They never reserve global booking conflicts or create lock/switch/unlock events, and render as external sessions without Pterodactyl lookups.
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
- Disabling Foundry features cancels only active Foundry-linked bookings, unqueues their events, removes global conflicts, and releases matching booking-owned world locks. Worldless event reminders continue. Scheduler also ignores stale booking lock and reminder events from disabled guilds; cleanup unlock events still run.

## Persistent Runtime State

Runtime data directory: executable sibling `data/`; Docker mounts it at `/home/container/data`.

- Version 3.0 performs a one-time root-to-guild migration before `BotConfig.shared` can read or create `botConfig.json`. It runs only when `data/guilds/` does not exist, root `botConfig.json` already exists, and Discord reports exactly one bot guild. Migration builds and verifies state in `data/.v3-migration-staging/`, imports split legacy `event_bookings.json` and `reservation_bookings.json` when `bookings.json` is absent, verifies backups in `data/migration-backups/v3/`, safely writes global output, then atomically moves staged guild state to `data/guilds/`. Incomplete staging restores root global output and is removed for retry; failed restoration retains recovery artifacts. `data/guilds/` is the completion indicator; no marker exists.
- Root `botConfig.json` and root secrets retain global Pterodactyl target configuration. Runtime services have no legacy root-state fallback.
- Guild state belongs in `data/guilds/<guild-id>/`: `config.json`, `permissions.json`, `bookings.json`, `events.json`, `date_polls.json`, and `date_poll_reminder_preferences.json`.
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

- After code changes, build with Xcode MCP. Manual runtime checks require configured runtime secrets/config.
- Dockerfile uses Swift 6 Jammy multi-stage build, runs non-root `container`, and expects `/home/container/data` to persist.
- GitHub workflow builds and pushes Docker Hub image for every tag. It does not run tests, linting, or security scans.
- Pterodactyl bot egg installs/releases bot separately. Validate egg install commands after changing package/build behavior.
- No `Tests` target exists. For behavior changes, at minimum build, test command registration in a non-production guild, test Pterodactyl API against a safe server, and verify persisted data across restart.

## Documentation Drift And Open Work

- Date polls use modals for creation/voting/finalization/editing, a Components V2 shared message, JSON-backed role voter rosters refreshed on vote, scheduler-backed per-user reminders and repeating polls, and short IDs. Bare `/datepoll` opens a guild-local creation modal: role, newline-separated dates, optional description, 1...60 deadline days, and no repeat/every 1...4 weeks. Each published poll queues one automatic non-voter reminder at the earlier of 48 hours after creation or half its initial voting duration. The event refreshes role membership, DMs outstanding voters, falls back to a channel mention, and retries individual failures without duplicating successes. Users can permanently opt out per guild from automatic reminders only via the red DM button; explicit `Remind me` stays enabled. Reopened polls do not get another automatic reminder cycle. An owner/admin/campaign DM can edit open or awaiting-finalization polls. Edits preserve votes for unchanged dates, prune removed-date/departed-member selections, refresh role membership, reopen voting, and replace reminders/scheduling invalidated by a new deadline. Recurring edits apply to every live occurrence in the series; repeat timing remains anchored to each occurrence's creation. A recurring poll creates its successor from its source poll's creation time, shifts every candidate by calendar weeks, carries forward deadline duration/metadata, refreshes role voters, and starts without votes. `Cancel repeat` is red and stops its whole series. Finalization accepts one or more candidates; legacy single-candidate records remain readable. Open polls group all tied leading candidates in one top container and repeat every candidate in the lower chronological container. Finalized polls show selected-date results only, plus `View votes`, which opens a read-only Components V2 modal with up to five date-result displays. Components V2 is permanent per Discord message and forbids embeds/content. Poll owners/admins can manage any owned/all polls; other Dungeon Masters must hold campaign role. See `docs/DATE_POLL_SPEC.md` for runtime behavior and command contract.
- Date polls use modals for creation/voting/finalization/editing, a Components V2 shared message, JSON-backed role voter rosters refreshed on vote, scheduler-backed per-user reminders and repeating polls, and short IDs. Bare `/datepoll` opens a guild-local creation modal: role, newline-separated dates, optional description, 1...60 deadline days, and no repeat/every 1...4 weeks. Each published poll queues one automatic non-voter reminder at the earlier of 48 hours after creation or half its initial voting duration. The event refreshes role membership, DMs outstanding voters, falls back to a channel mention, and retries individual failures without duplicating successes. Users can permanently opt out per guild from automatic reminders only via the red DM button; explicit `Remind me` stays enabled. Reopened polls do not get another automatic reminder cycle. An owner/admin/campaign DM can edit open or awaiting-finalization polls. Edits preserve votes for unchanged dates, prune removed-date/departed-member selections, refresh role membership, reopen voting, and replace reminders/scheduling invalidated by a new deadline. Recurring edits apply to every live occurrence in the series; repeat timing remains anchored to each occurrence's creation. A recurring poll creates its successor from its source poll's creation time, shifts every candidate by calendar weeks, carries forward deadline duration/metadata, refreshes role voters, and starts without votes. `Cancel repeat` is red and stops its whole series. Finalization accepts one or more candidates; legacy single-candidate records remain readable. Finalized polls show selected-date results, `View votes`, and blue booking buttons for every unbooked final date. Booking controls require DM permission; they prefill the selected date at the guild default event time and the poll campaign role. Successful bookings persist the candidate link and remove its button. Components V2 is permanent per Discord message and forbids embeds/content. Poll owners/admins can manage any owned/all polls; other Dungeon Masters must hold campaign role. See `docs/DATE_POLL_SPEC.md` for runtime behavior and command contract.
- README names `/reschedulebooking`; registered command is `/rescheduleevent`.
- README says Discord scheduled event creation is planned; `createServerEvent` exists but no command uses it.
- Pterodactyl egg token variables may be user-viewable. Treat panel configuration and generated secret files as sensitive.
- Failed scheduler events remain queued for retry; other due events continue executing.

Update this document when these contracts or hazards change.
