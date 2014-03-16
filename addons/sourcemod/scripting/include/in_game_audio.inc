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

/**
 * Authorize the player to upload music on the webserver.
 *
 * @param client    The client index
 */
native AuthorizeUser(client);

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
 * @param client    The client index
 * @param song      The name of the song to play
 */
native PlaySong(client, const String:song[]);

/**
 * Play a song to all users
 *
 * @param song      The name of the song to play
 * @param force     If true will ignore isinpall and isinp
 */
native PlaySongAll(const String:song[], bool:force);

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
 * Performa song query.  Will search for a song named path and play
 * it, else will assume path is a directory and play a random song
 * in it.
 *
 * @param client    The client index
 * @param path      The path to search for
 * @param pall      If found, play to everyone
 * @param force     If found, force playing
 */
native QuerySong(client, const String:path, bool:pall = false, bool:force=false);

/**
 * Play a map transfer song
 *
 * @param map   The name of the map to check for
 */
native MapTheme(const String:map[]);

/**
 * Play a user's theme song to all
 *
 * @param client    The client index
 */
native UserTheme(client);

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
