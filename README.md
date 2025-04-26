#  Foundry World Switcher

This is a Discord bot written purely in Swift that allows one to change the currently active world on their [Foundry VTT](https://foundryvtt.com) server.

## Installation
You can install this bot as a standalone docker container or as a Pterodactyl server.

### Standalone Docker Container
This bot is available as a Docker Hub image at [icomputerfreak/foundry-world-switcher](https://hub.docker.com/r/icomputerfreak/foundry-world-switcher).
Make sure to set the environment variable `TZ` inside the docker container to your timezone (e.g., `TZ=Europe/Berlin`), to avoid the scheduled bot messages being delivered at UTC time.

### Pterodactyl Server
To install this bot as a Pterodactyl server, import the egg located at `pterodactyl_eggs/foundry_world_switcher` into Pterodactyl and create a server for it. Everything you need to configure should be available under "Startup".

To update the bot, simply re-install the server. This should not remove any configurations or data, but better make a backup before to be sure.

## Configuration

The bot requires Foundry to be run in a [Pterodactyl](https://pterodactyl.io) server instance.

The modified Pterodactyl egg for running Foundry VTT can be found in `pterodactyl_eggs/foundry_vtt` and is taken directly from [parkervcp/eggs](https://github.com/parkervcp/eggs/tree/master/game_eggs/FoundryVTT) and I modified it by adding a new startup variable called `WORLD_NAME`. An egg configuration for the Pelican Panel fork of Pterodactyl is available as well in the same directory.  
This startup variable is used to restart the Foundry server, immediately starting a given world when its online.

The Discord bot itself manages the Foundry server via the Pterodactyl API by reading files, changing the startup variable and restarting the server.
For the bot to work, you need to create a new Pterodactyl user in the Pterodactyl server instance with the following permissions:

* Control: `START`, `STOP`, `RESTART`
* File: `READ`, `READ-CONTENT`
* Startup: `READ`, `UPDATE`


Then, log in as this new user and under your profile, create a new API key for this bot.
You can supply this API key either via a `PTERODACTYL_API_KEY` file located in this bot's executable directory or via an environment variable called `FOUNDRY_PTERODACTYL_TOKEN`.

Analogously, you supply your Discord bot token via a file `BOT_TOKEN` or the environment variable `FOUNDRY_BOT_TOKEN`.

## Commands
Once all tokens have been supplied to the bot and the bot is started, you can use the following commands in Discord to use the bot.

### User Commands
`/hello`  
Returns a message to verify that the bot is running

`/help`  
Returns a help message instructing the user how to use the bot

`/mypermissions`  
Returns the user's current permission level

`/worldinfo`  
Shows information about the currently active world

`/worldinfo world_id:<foundry_world_id>`  
Shows information about a specific world

`/bookings`  
Shows a list of all future reservations

### Dungeon Master Commands
These commands require the permission level `Dungeon Master`.

`/listworlds`  
Shows a list of all Foundry worlds together with their world IDs

`/restartworld`  
Restarts the Foundry server without switching the world

`/switchworld world_id:<foundry_world_id> force:[true|false]`  
Restarts the Foundry VTT server, switching to the given world. Unless `force` is set to `true`, this command fails if the world is currently locked.

`/book event world_id:<foundry_world_id> date:<date> time:<time> location:<voice_channel> topic:<title> role:<server_role>`  
Creates a new reservation for a session in the given world and notifies the players about the new session date and time.
This command also creates a new server event for the given date and time (not yet implemented).
The server is locked to the given world on the provided date (from 6 AM to 5 AM the following day).

`/book reservation world_id:<foundry_world_id> date:<date>`  
Create a new reservation for a given world on a given date. Use this, if you need to prepare for a session on a given day. This command will **not** notify the players about a new session and just lock the server on that day.

`/cancelbooking date:<date>`  
Cancel a reservation for a given date.  
**Note**: Only users with `Admin` permissions can cancel reservations made by other users.

`/reschedulebooking date:<date> new_date:<date> new_time:<time>`  
Reschedule a reservation for a given date to a new date and time.
**Note**: Only users with `Admin` permissions can reschedule reservations made by other users.

`/lockstate`  
Returns the current state of the world switching lock

### Admin Commands
These commands require the permission level `Admin`.

`/setpermissionlevel user user:<user> level:<permission_level>`  
Changes the permission level of an individual user

`/setpermissionlevel role role:<user> level:<permission_level>`  
Changes the permission level of a server role

`/showpermissions`  
Lists all non-User permissions

`/switchworld world_id:<foundry_world_id> force:true`  
Restarts the Foundry VTT server, switching to the given world, even if the world is currently locked. If the world was locked, it is unlocked.

`/lockworld <world_id>`  
Locks the given world until 5:00 AM the next day

`/unlockworld`  
Unlocks the given world

`/config`
Change different bot configuration settings

`/pinbookings`  
Creates a new message with all bookings (reservations and events) that is automatically updated in the future.

`/pinbookings role:<server_role>`  
Creates a new message with all event bookings that is automatically updated in the future.
Only shows bookings for the given role.

`/pinbookings world_id:<foundry_world_id>`  
Creates a new message with all bookings (reservations and events) that is automatically updated in the future.
Only shows bookings for the given world.

`/updatepins`  
Manually updates all pinned booking messages.

`/listpins`  
List all pinned booking messages.

`/updatecache`  
Updates all cached worlds.

`/eventqueue`  
Debugging command to show the current event scheduler queue.

### Configuration Options

You can also use the `/config` command to view and update these values.

* `pterodactylHost`: The hostname of the Pterodactyl panel
* `pterodactylServerID`: The ID of the server on the Pterodactyl panel
* `sessionLength`: The length of a session
* `bookingIntervalStartTime`: The time at which the booking starts in seconds from midnight
* `bookingIntervalEndTime`: The time at which the booking ends in seconds from `bookingIntervalStartTime`
* `sessionReminderTime`: The time how much in advance the bot will remind players about a session. Set to 0 to disable.
* `shouldNotifyAtSessionStart`: Whether the bot should notify players at the start of the session
* `sessionStartReminderTime`: The time how much in advance the bot will remind players that the session is about to start
* `reminderChannel`: The channel where the bot will send reminders
* `pinnedBookingMessages`: This config value is managed by the bot itself and contains references to all pinned booking messages. 

