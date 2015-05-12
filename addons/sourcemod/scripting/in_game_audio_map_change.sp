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

#define PLUGIN_VERSION "1.8.4"
#define PLUGIN_NAME "In Game Audio Map Change" 

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Play a song during map change",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    decl String:mod_name[PLATFORM_MAX_PATH];
    GetGameFolderName(mod_name, sizeof(mod_name));

    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_map_change_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    if(StrEqual(mod_name, "tf"))
    {
        HookEventEx("teamplay_game_over", Event_MapChange);
    }else{
        HookEventEx("game_end", Event_MapChange);
    }
}

public Action:Event_MapChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Prevent HTTP calls when noone is online
    if(!CanAnyoneHearIGA()) return Plugin_Continue;

    new String:next_map[64];
    GetNextMap(next_map, sizeof(next_map));
    MapTheme(true, next_map);

    return Plugin_Continue;
}
