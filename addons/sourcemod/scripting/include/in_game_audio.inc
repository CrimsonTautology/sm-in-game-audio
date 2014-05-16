/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio
 * Plays music to players in game through a MOTD popunder.
 *
 * Copyright 2013 CrimsonTautology
 * =============================================================================
 *
 */

#if defined _in_game_audio_included_
    #endinput
#endif
#define _in_game_audio_included_

#define QUERY_SONG_ROUTE "/v1/api/query_song"
#define MAP_THEME_ROUTE "/v1/api/map_theme"
#define USER_THEME_ROUTE "/v1/api/user_theme"
#define AUTHORIZE_USER_ROUTE "/v1/api/authorize_user"
#define GENERATE_LOGIN_TOKEN_ROUTE "/v1/api/generate_login_token"
#define SONGS_ROUTE "/songs"
#define NEW_SONGS_ROUTE "/songs/new"
#define DIRECTORIES_ROUTE "/directories"
#define STOP_ROUTE "/stop"

#define MAX_STEAMID_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 
#define MAX_SONG_LENGTH 64

/**
 * Check if the server has in game audio enabled.
 *
 * @return          True if server has in game audio enabled.
 */
native bool:IsIGAEnabled();

/**
 * Check if the player has elected to listen to music.
 *
 * @param client    The client index
 * @return          True if the player has enabled pall, else false
 */
native bool:ClientHasPallEnabled(client);

/**
 * Set whether the user can listen to music or not.
 *
 * @param client    The client index
 * @param val       True if enabled, false if disabled
 */
native SetPallEnabled(client, bool:val);

/**
 * Check if the player is listening to music through !p
 *
 * @param client    The client index
 * @return          True if the user is playing music for themselves
 */
native bool:IsInP(client);

/**
 * Check if the server is currently playing music through !pall
 *
 * @return          True if server is currently playing music to all
 */
native bool:IsInPall();

/**
 * Play a song to a player
 *
 * @param client        The client index
 * @param song          The name of the song to play
 * @param access_token  The access_token required by the server to play the song
 */
native PlaySong(client, const String:song[], const String:access_token[]);

/**
 * Play a song to all users
 *
 * @param song          The name of the song to play
 * @param force         If true will ignore isinpall and isinp
 * @param access_token  The access_token required by the server to play the song
 */
native PlaySongAll(const String:song[], const String:access_token[], bool:force);

/**
 * Stop a song for a given user
 *
 * @param client    The client index
 */
native StopSong(client);

/**
 * Stop all curently playing songs for all users
 *
 */
native StopSongAll();

/**
 * Popup an IGA webpage via a MOTD panel to the player
 *
 * @param client        The client index
 * @param route         The main route to use
 * @param args          The args and query paramaters to use
 * @param popup         If true it will popup the page for the player to see. else it will popunder
 * @param fullscreen    If true will display as a full screen(TF2 only)
 */
native CreateIGAPopup(client, const String:route[]="", const String:args[]="", bool:popup=true, bool:fullscreen=true);

/**
 * Performa song query.  Will search for a song named path and play
 * it, else will assume path is a directory and play a random song
 * in it.
 *
 * @param client    The client index
 * @param path      The path to search for
 * @param pall      If found, play to everyone
 * @param force     If found, force playing
 */
native QuerySong(client, const String:path[], bool:pall = false, bool:force=false);

/**
 * Play a map transfer song
 *
 * @param map   The name of the map to check for
 */
native MapTheme(bool:force=true, const String:map[]="");

/**
 * Play a user's theme song to all
 *
 * @param client    The client index
 */
native UserTheme(client);

/**
 * Play a user's theme song to all
 *
 * @param client    The client index
 * @param callback  HTTP callback function called when the call returns
 */
native GenerateLoginToken(client, HTTPRequestComplete:callback);

/**
 * Start a user's api calling cool down
 *
 * @param client    The client index
 */
native StartCoolDown(client);

/**
 * Check if a user is currently in an api call cooldown
 *
 * @param client    The client index
 * @return          True if user is in cool down, else false
 */
native bool:IsClientInCooldown(client);

/**
 * Gets the auto-login token for a client so they can use the IGA
 * website via the MOTD without logging in.  Internally caches the
 * token and when it expires so a new one can be generated if need be.
 *
 * @param client        The client index
 * @param login_token   Buffer to hold the login token for this client.  Returned via parameter.
 */
native GetLoginTokenForClient(client, String:login_token[]);

functag IGA_MenuCallback IGAMenu:public(client);

/**
 * Register a menu item.
 * 
 * @param name			Name of the menu item.
 * @param func			Callback for menu items.
 * @return				Menu item ID.
 */
native IGA_RegisterMenuItem(const String:name[], IGA_MenuCallback:func);

/**
 * Unregister a menu item.
 * 
 * @param item			Menu Item ID
 */
native IGA_UnregisterMenuItem(item);
