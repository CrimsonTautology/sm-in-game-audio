# In Game Audio
[![Build Status](https://travis-ci.org/CrimsonTautology/sm_map_votes.png?branch=master)](https://travis-ci.org/CrimsonTautology/sm_map_votes)

Allows users to listen to music while in game.  Uses a hidden MOTD page to play the music [using an external web service](http://iga.crimsontautology.com).  Should work for any Source game that can run [Sourcemod](http://www.sourcemod.net).

##Installation
* Install the [smjansson](https://forums.alliedmods.net/showthread.php?t=184604) extension (Included in repository).
* Install the [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) extension (Included in repository).
* Compile plugins with spcomp (e.g.)
> spcomp in_game_audio_base.sp
* Compiled .smx files into your `"<modname>/addons/sourcemod/plugins"` directory.
* Setup the `sm_iga_url` cvar to point to the root url of the web interface.  
> sm_iga_url "http://iga.example.com"
* Get an api key from the web interface and assign it to the `sm_iga_api_key` cvar.  
> sm_iga_api_key "apikey"

    

##Requirements
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604)
* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556)
* [A Web Site Backend](https://github.com/CrimsonTautology/in_game_audio)
* [Donator Interface](https://forums.alliedmods.net/showthread.php?t=145542)(Optional)
* Players must have HTML Message Of The Days enabled for this to work.  This can be enabled via advanced settings of by typing `cl_disablehtmlmotd 0` into console.

#CVARs

* `sm_iga_url` - the root url for the website you will be interacting with.
* `sm_iga_api_key` - the api key required to interact with the web api.
* `sm_iga_enabled` - sets whether the plugin is enabled or not.
* `sm_iga_donators_only` - sets whether only donators can use certain commands (e.g. `sm_pall`).
* `sm_iga_request_cooldown_time` - the cool down period a user must wait through before they can use another command that makes an HTTP call.

# IGA Base
Handles all calls to the web server and provides a framework to play music for players.  Also controls the user's preferences such as whether they have pall enabled and the volume

* `sm_vol [0-10]` - Set's the user's volume; 10 the loudest and 0 is mute.  Brings up a menu if called without an argument.
* `sm_nopall` - Disables playing music that is played for all users (e.g. `sm_pall`, donator intros).  The user can still play to themselves with commands such as `sm_p`
* `sm_yespall` - Enables playing music that is played for all users.
* `sm_iga` - Bring up the IGA settings and control menu.


# IGA Player
Handles the commands that let players play songs to themselves and to each other.

* `sm_p [category]/[name]` - Plays a song for the user. If given no arguments it will play a random song.  If given a category or a category and subdirectory (separated by '/') it will play a random song in that category or subdirectory.  If given the full path to a song it will play that specific song.  If a matching category or song is not found it will treat the argument as a search key and return a list of songs that match.
* `sm_stop` - Stops the currently playing song for the user.
* `sm_pall [category]/[name]` - The same as `sm_p` but plays for all users on the server (that have `sm_yespall` enabled).  Only donators can use this command if the `sm_donators_only` is set to 1.
* `sm_plist` - Pops up the MOTD browser showing a web page that lists all available songs and categories that can be played.
* `sm_fpall [category]/[name]` - Admin command. Overrides the current pall and plays a song to all users
* `sm_fstop` - Admin command. Stops the currently playing song for all users.

#IGA Map Change
Will play a random "map theme" during the map change transition.  If map voting is enabled on the server it will start when the map vote is called. This will override a pall if it is playing.

#IGA Donator Intro
Will play a donator's "theme song" when they join the server.  Theme songs are generally short, ~10 seconds in length and can be set through the web page.  This will not override a pall if they join while one is playing.

#Extending
This plugin provides a bunch of natives that you can extend and interact with the web service with. Look at the in_game_audio.inc file for documentation.
