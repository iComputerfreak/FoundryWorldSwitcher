#  Foundry World Switcher

Available as a Docker Hub image at [icomputerfreak/foundry-world-switcher](https://hub.docker.com/r/icomputerfreak/foundry-world-switcher).

This is a Discord bot written purely in Swift that allows one to change the currently active world on their [Foundry VTT](https://foundryvtt.com) server.
The bot requires Foundry to be run in a [Pterodactyl](https://pterodactyl.io) server instance.

The modified Pterodactyl egg found in `pterodactyl_egg` is taken directly from [parkervcp/eggs](https://github.com/parkervcp/eggs/tree/master/game_eggs/FoundryVTT) and I modified it by adding a new startup variable called `WORLD_NAME`.
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

`/worlds`  
Shows a list of all Foundry worlds together with their world IDs

`/restart`  
Restarts the Foundry server without switching the world

`/switchworld world_id:<foundry_world_id>`  
Restarts the Foundry VTT server, switching to the given world. Fails if the world is currently locked.

`/schedule role:<server_role> world:<foundry_world_id> date:<date> time:<time>`  
Creates a new reservation for a session in the given world and notifies the players about the new session date and time.
This command also creates a new server event for the given date and time.
The server is locked to the given world on the provided date (from 6 AM to 5 AM the following day).

`/book world:<foundry_world_id> date:<date>`  
Create a new reservation for a given world on a given date. Use this, if you need to prepare for a session on a given day. This command will **not** notify the players about a new session and just lock the server on that day.

`/cancelbooking date:<date>`  
Cancel a reservation for a given date.  
**Note**: Only users with `Admin` permissions can cancel reservations made by other users.

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

`/unlockworld <world_id>`  
Unlocks the given world

`/config`
Change different configuration settings

### Configuration Options
* pterodactyl_server_id <Server ID>
* schedule_channel <Channel ID>
* session_notifications_channel <Channel ID>
* session_reminder_time <days> (0 to disable)

