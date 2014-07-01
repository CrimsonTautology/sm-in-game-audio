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
#include <in_game_audio>

#define PLUGIN_VERSION "1.6.1"

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
    LoadTranslations("in_game_audio.phrases");
    HookEvent("teamplay_game_over", Event_MapChange);
}

public OnMapVoteStarted()
{
    //Don't let the map vote override a pall
    MapTheme(false);
}

public Action:Event_MapChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    //TODO get next map
    MapTheme();
    return Plugin_Continue;
}


