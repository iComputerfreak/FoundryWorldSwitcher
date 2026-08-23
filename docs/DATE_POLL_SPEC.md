# Date Poll Specification

## Goal

Let a Dungeon Master collect availability from a campaign role for proposed D&D session dates, identify a date with the highest attendance, finalize a date, and remind undecided members after 24 hours.

## Interaction Model

Use Discord message components instead of emoji reactions.

- `Set availability` opens a personal modal with checkbox groups for candidate dates.
- Checkbox groups show current selections and save all changes when modal is submitted.
- A distinct `No dates work` checkbox records no availability. Submitting no selected dates also records no availability.
- A `Remind me` button schedules a 24-hour DM reminder for the clicking user.
- Reminder DM includes `Remind me tomorrow` for one further 24-hour delay.

Components give the bot one authoritative, editable vote per user. The modal shows current vote state without changing the shared poll message. Reactions remain possible but are not recommended.

## Create Poll

Proposed command: `/datepoll create`.

- Required: campaign role and one or more comma-separated candidate dates.
- Optional: description and voting deadline.
- Command creator becomes poll owner.
- Candidate and finalized dates accept `dd.MM.yyyy`, `dd.MM`, or `dd.MM.`. Yearless dates resolve to this year when still upcoming, otherwise next year. Future-only dates. Poll cards, modal options, and finalization display localized weekday with date.
- Deadline accepts same date formats and expires at 23:59:59 local time. Default deadline is end of local day seven calendar days after creation.
- Preserve command date order in persistence; render dates chronologically in poll and availability modal.
- Reject duplicate dates.
- Initial version limit: 20 dates. Checkbox groups allow 10 options each, so 20 dates use two groups plus one no-availability checkbox within Discord's five-modal-component limit.
- Each poll receives a unique, eight-character ID shown in its footer.
- Poll posts in command channel. Creator receives success/error through normal interaction flow.
- Capture campaign-role member IDs at creation for initial status. Refresh the role roster when a vote is submitted; added members can vote, departed members stop counting, and their pending reminders are removed.

No selected world, target channel, or automatic booking integration in first version.

## Poll Message

Message contains:

- Title: `<campaign role> · Session date poll`.
- Optional description and current participation summary, including outstanding voters.
- When votes exist, one leading-date container uses the first chronological best match. Its accent is green when everyone can attend, yellow for partial attendance, or red when no one can attend.
- One chronological date-card container shows leading state and dynamic attendance text: no votes, no attendees, everyone, or attendee mentions.
- `Everyone can attend` when every submitted voter selected that date.
- Visible voting status: voted member count, outstanding member count, and members who selected no date.
- `Set availability` and `Remind me` buttons while open.
- Do not show `Remind me` when its 24-hour delivery time would be after poll deadline.
- Show green `Finalize` when at least one vote exists and poll is not finalized/cancelled. It opens a chronological checkbox modal with current availability fractions and currently requires exactly one selected date.
- Show red `Cancel` until poll is finalized/cancelled.
- Small footer line: creator username, poll ID, and relative voting deadline while poll is not finalized/cancelled.
- Final state: chosen date. Components become disabled. Cancelled polls hide leading and date availability containers.

Votes are visible. The shared message uses Components V2 containers and text displays rather than embeds.

## Voting Rules

- Required voter: a user in the campaign role when roster was last refreshed.
- Current role members may open the availability modal. Vote submission refreshes roster and rejects users no longer in role.
- One persisted vote per required voter per poll.
- A vote is a set of candidate date IDs, not additive reaction history.
- Modal submission replaces the user's prior vote.
- Selecting `No dates work` without dates records no availability.
- Selecting one or more dates records those dates as available, even when no-availability checkbox remains selected.
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

- Poll owner, `admin`, or Dungeon Master currently in campaign role may finalize any candidate date after or before deadline.
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

- Stable eight-character poll ID.
- Discord guild, channel, and message IDs.
- Owner user ID.
- Campaign role ID and required voter IDs from most recent vote refresh.
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
- A 30-second background task runs the scheduler while gateway idle. Gateway events also trigger updates.

## Discord Integration

- Existing interaction handler supports application commands only. Add message-component routing to present modals and modal-submit routing to persist votes.
- Use DiscordBM APIs for every Discord request. Do not add manual REST requests.
- Component custom IDs include action, poll ID, and checkbox-group index where needed. Validate IDs, poll state, guild/channel, and voter authorization server-side.
- Shared poll uses Components V2 containers, text displays, separators, and action rows. Components V2 forbids embeds/content and cannot be removed once set on a message.
- Discord controls message width. No minimum-width setting exists; Components V2 containers use normal message width.
- Update existing poll message after each state mutation.
- A component interaction must receive acknowledgement within Discord's short response deadline.
- Discord checkbox groups allow 10 options and modals allow five top-level components. Initial 20-date limit remains valid.
- Disable controls when poll reaches deadline, finalizes, or cancels.
- Bot needs access to campaign-role membership at poll creation and vote submission. Cache/intents must support reliable role-member lookup.

## Permissions

- Create poll: `dungeonMaster`, matching session-booking authority.
- Vote and request reminder: required campaign-role members only.
- Finalize/cancel: poll owner, `admin`, or Dungeon Master currently in campaign role.
- Restrict all interactions to poll guild/channel. Reject cross-guild and stale component IDs.

## First-Version Scope

- Create, display, vote/revote until deadline/finalization/cancellation, no-availability selection, visible results, best-date availability summary, DM reminders with one delay, deadline, close, cancel, finalization, JSON persistence, restart recovery.
- No booking integration, automatic winner selection, poll editing, DMs for poll creation, recurring polls, date-time availability, weighted votes, or non-voter reminders.

## Implementation Risks

- Poll creation requires the Guild Members intent in bot code and Discord Developer Portal so role membership can be fetched reliably.
- Components V2 permits 40 total nested components. Twenty date cards plus one leading card use 32 components with optional description.

## Future Work

- Explicit booking creation from finalized date.
- Deadline reminders for outstanding voters.
- Availability matrix across role members and dates.
- Poll editing before votes begin.
- Configurable reminder delivery and repeated delays.
