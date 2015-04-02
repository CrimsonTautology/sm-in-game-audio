/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_karaoke
 * Karaoke player for IGA
 *
 * Copyright 2013 CrimsonTautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>

#define PLUGIN_VERSION "1.8.1"
#define PLUGIN_NAME "In Game Audio Karaoke" 

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Karaoke player for IGA",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_karaoke_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

