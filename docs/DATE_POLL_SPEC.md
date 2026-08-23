# Date Poll Specification

## Goal

Let a Dungeon Master collect availability from a campaign role for proposed D&D session dates, identify a date with the highest attendance, finalize a date, and remind undecided members after 24 hours.

## Interaction Model

Use Discord message components instead of emoji reactions.

- A multi-select menu lists candidate dates and permits selecting every date a user can attend.
- A distinct `None of these dates` option records no availability.
- A `Remind me` button schedules a 24-hour DM reminder for the clicking user.
- Reminder DM includes `Remind me tomorrow` for one further 24-hour delay.

Components give the bot one authoritative, editable vote per user. They avoid emoji-to-date mapping, reaction gateway handling, and stale reactions. Reactions remain possible but are not recommended.

## Create Poll

Proposed command: `/datepoll create`.

- Required: campaign role and one or more comma-separated candidate dates.
- Optional: description and voting deadline.
- Command creator becomes poll owner.
- Candidate and finalized dates accept `dd.MM.yyyy`, `dd.MM`, or `dd.MM.`. Yearless dates resolve to this year when still upcoming, otherwise next year. Future-only dates.
- Deadline accepts same date formats and expires at 23:59:59 local time. Default deadline is end of local day seven calendar days after creation.
- Preserve command date order in poll display.
- Reject duplicate dates.
- Initial version limit: 20 dates. This stays below Discord select-menu option limit after reserving one option for `None of these dates`.
- Each poll receives a unique, eight-character ID for `/datepoll finalize` and `/datepoll cancel`.
- Poll posts in command channel. Creator receives success/error through normal interaction flow.
- Capture the campaign-role member IDs at creation. This snapshot defines required voters, even if the role changes later.

No selected world, target channel, or automatic booking integration in first version.

## Poll Message

Message contains:

- Title: `Session date poll`.
- Campaign role mention, creator, optional description, and voting deadline.
- Candidate dates with availability count.
- Current best date or tied best dates.
- For every best date: list role members unavailable on that date.
- `Everyone can attend` only when every required voter selected that date.
- Visible voting status: voted member count, outstanding member count, and members who selected no date.
- Multi-select availability control and `Remind me` button while open.
- Do not show `Remind me` when its 24-hour delivery time would be after poll deadline.
- Final state: chosen date, finalizer, and finalization timestamp. Components become disabled.

Votes are visible. The message displays each candidate's availability and unavailable members; detailed availability lists may be shown in a follow-up message if embed limits require it.

## Voting Rules

- Required voter: a user in the campaign-role member snapshot.
- Only required voters may vote or request reminders.
- One persisted vote per required voter per poll.
- A vote is a set of candidate date IDs, not additive reaction history.
- Selecting dates replaces prior vote.
- Selecting `None of these dates` replaces all selected dates with no availability.
- Selecting one or more dates clears no-availability state.
- Users may revise votes at any time while poll is open. Voting ends only at deadline, finalization, or cancellation.
- Every valid vote updates poll message immediately.
- Members who have not voted are outstanding, not unavailable. They prevent `Everyone can attend` from appearing.
- When deadline arrives, poll closes for voting and awaits Dungeon Master finalization. Pending reminders are removed.

## Attendance Calculation

- Availability count for date: required voters whose selected date set includes date.
- Best date: candidate date with maximal availability count.
- Ties: show every date with maximal count.
- Unavailable list for date: required voters with a submitted vote that does not include date. This includes `None of these dates` voters.
- Outstanding list: required voters with no submitted vote.
- No votes: show no best date and prompt campaign role to vote.

## Finalization

- Poll owner or `admin` may finalize any candidate date after or before deadline.
- Finalization closes voting, cancels pending reminders, updates poll message to show chosen date, and disables controls.
- Bot posts a channel message that mentions the campaign role and states the finalized date.
- Finalization does not create an event or world booking. Booking integration is a later feature.
- Closed polls that reach deadline but have no chosen date remain available for owner/admin finalization.

## Reminder Flow

- Clicking `Remind me` creates one pending reminder for `(poll ID, user ID)` due 24 hours later.
- Re-clicking before delivery does not create duplicates; acknowledge existing reminder.
- At delivery, DM the user with a link to the poll.
- If Discord rejects the DM, mention the user in poll channel with poll link.
- Reminder message includes `Remind me tomorrow`.
- One delay replaces delivered reminder with one final reminder due 24 hours later. Do not show it when delivery would be after deadline. Further delays are not offered.
- Poll closure, deadline, cancellation, or finalization removes pending reminders.
- Reminder delivery must not occur for a non-open poll.

## Persistence

Persist polls in dedicated JSON runtime data, separate from bookings.

Each poll needs:

- Stable poll UUID.
- Discord guild, channel, and message IDs.
- Owner user ID.
- Campaign role ID and snapshot of required voter IDs.
- Creation, deadline, close, and finalization timestamps.
- Optional description.
- Ordered candidate date IDs and date values.
- Poll status: open, awaiting finalization, finalized, or cancelled.
- Finalized candidate date ID and finalizer ID when applicable.
- Per-user vote: selected candidate date IDs or no-availability state.
- Per-user pending reminder due timestamp, delay count, and delivery state.

Persist after creation, vote changes, status changes, reminder changes, and finalization. On restart, restore open polls and pending reminders.

## Scheduler Integration

Extend scheduler event types for poll deadline and reminders. Events reference poll and user IDs, never mutable poll payload.

- Deadline event loads current state, transitions open poll to awaiting-finalization, updates message, disables vote controls, and removes reminders.
- Reminder event loads current poll state. Missing, expired, or non-open polls make event no-ops.
- Removing/replacing reminder unqueues prior event.
- Scheduler currently runs only after Discord gateway events. Reminder and deadline timing can slip while disconnected or inactive. Add independent scheduler wakeup before promising precise timing.

## Discord Integration

- Existing interaction handler supports application commands only. Add message-component routing for select menus and buttons.
- Use DiscordBM APIs for every Discord request. Do not add manual REST requests.
- Component custom IDs include version, action, and poll UUID. Validate IDs, poll state, guild/channel, and voter authorization server-side.
- Update existing poll message after each state mutation.
- A component interaction must receive acknowledgement within Discord's short response deadline.
- Discord permits at most 25 select-menu options. Initial 20-date limit leaves one no-availability option and capacity for future actions.
- Disable controls when poll reaches deadline, finalizes, or cancels.
- Bot needs access to campaign-role membership at poll creation. Cache/intents must support reliable role-member lookup.

## Permissions

- Create poll: `dungeonMaster`, matching session-booking authority.
- Vote and request reminder: required campaign-role members only.
- Finalize/cancel: poll owner or `admin`.
- Restrict all interactions to poll guild/channel. Reject cross-guild and stale component IDs.

## First-Version Scope

- Create, display, vote/revote until deadline/finalization/cancellation, no-availability selection, visible results, best-date availability summary, DM reminders with one delay, deadline, close, cancel, finalization, JSON persistence, restart recovery.
- No booking integration, automatic winner selection, poll editing, DMs for poll creation, recurring polls, date-time availability, weighted votes, or non-voter reminders.

## Implementation Risks

- Poll creation requires the Guild Members intent in bot code and Discord Developer Portal so role membership can be fetched reliably.
- Discord embed and message limits may require a compact summary plus follow-up detail message for large roles or many dates.
- Current scheduler's event-driven cadence is unsuitable for precise deadlines/reminders without an independent timer.

## Future Work

- Explicit booking creation from finalized date.
- Deadline reminders for outstanding voters.
- Availability matrix across role members and dates.
- Poll editing before votes begin.
- Configurable reminder delivery and repeated delays.
