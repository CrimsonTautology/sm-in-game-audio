/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_map_change
 * Plays a song to all clients just before the map ends so they can listen to
 * music while the next map loads.  Also triggers when the next map vote starts
 * when a RockTheVote is called.
 *
 * Copyright 2013 CrimsonTautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "0.2"

public Plugin:myinfo =
{
    name = "In Game Audio Map Change",
    author = "CrimsonTautology",
    description = "Play a song during map change",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    HookEvent("teamplay_game_over", Event_MapChange);
}

public OnMapVoteStarted()
{
    MapTheme("current_map");
}

public Action:Event_MapChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    //TODO get next map
    MapTheme("current_map");
    return Plugin_Continue;
}


